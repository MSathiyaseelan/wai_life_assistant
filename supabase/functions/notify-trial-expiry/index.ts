// ============================================================
// Supabase Edge Function: /notify-trial-expiry
// Called daily by pg_cron to send FCM push notifications
// to family admins when their trial is expiring in 3 days,
// 1 day, or today.
//
// Authorization: service role key OR x-cron-secret header.
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVICE_ACCOUNT  = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
const CRON_SECRET          = Deno.env.get("CRON_SECRET") ?? "";

// ── FCM helpers (mirrors send-notification function) ──────────────────────────

function base64url(data: Uint8Array | string): string {
  const str = typeof data === "string" ? data : String.fromCharCode(...data);
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

function base64urlFromJson(obj: unknown): string {
  return base64url(JSON.stringify(obj));
}

function pemToBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function getFCMAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header  = base64urlFromJson({ alg: "RS256", typ: "JWT" });
  const payload = base64urlFromJson({
    iss:   FCM_SERVICE_ACCOUNT.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud:   "https://oauth2.googleapis.com/token",
    iat:   now,
    exp:   now + 3600,
  });
  const signingInput = `${header}.${payload}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBuffer(FCM_SERVICE_ACCOUNT.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(signingInput));
  const jwt = `${signingInput}.${base64url(new Uint8Array(sig))}`;
  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const data = await resp.json();
  return data.access_token;
}

async function sendFCM(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
  accessToken: string,
): Promise<boolean> {
  const projectId = FCM_SERVICE_ACCOUNT.project_id;
  const resp = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          data,
          android: {
            priority: "high",
            notification: { channel_id: "wai_family_channel", click_action: "FLUTTER_NOTIFICATION_CLICK" },
          },
          apns: {
            payload: { aps: { alert: { title, body }, badge: 1, sound: "default" } },
          },
        },
      }),
    },
  );
  if (!resp.ok) console.error("[trial-expiry] FCM send failed:", await resp.text());
  return resp.ok;
}

// ── Notification copy per days-remaining ─────────────────────────────────────

function notifContent(daysAhead: number): { title: string; body: string } {
  if (daysAhead === 0) return {
    title: "⏰ Trial ends today",
    body:  "Upgrade WAI to keep your family plan features.",
  };
  if (daysAhead === 1) return {
    title: "⏳ Trial ends tomorrow",
    body:  "Upgrade WAI to avoid losing your family plan features.",
  };
  return {
    title: `📅 Trial ends in ${daysAhead} days`,
    body:  "Upgrade WAI to continue all family features.",
  };
}

// ── Main handler ──────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204 });

  // Allow service role key or x-cron-secret
  const authHeader  = req.headers.get("Authorization") ?? "";
  const cronHeader  = req.headers.get("x-cron-secret") ?? "";
  const isService   = authHeader === `Bearer ${SUPABASE_SERVICE_KEY}`;
  const isCron      = CRON_SECRET.length > 0 && cronHeader === CRON_SECRET;

  if (!isService && !isCron) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  // Today at midnight UTC
  const now = new Date();
  now.setUTCHours(0, 0, 0, 0);

  let totalSent = 0;
  let fcmToken: string | null = null;

  for (const daysAhead of [0, 1, 3]) {
    const dayStart = new Date(now);
    dayStart.setUTCDate(dayStart.getUTCDate() + daysAhead);
    const dayEnd = new Date(dayStart);
    dayEnd.setUTCDate(dayEnd.getUTCDate() + 1);

    // 1. Find trials expiring on this date
    const { data: subs, error: subsErr } = await supabase
      .from("wallet_subscriptions")
      .select("wallet_id, trial_ends_at")
      .eq("status", "trial")
      .gte("trial_ends_at", dayStart.toISOString())
      .lt("trial_ends_at", dayEnd.toISOString());

    if (subsErr) {
      console.error(`[trial-expiry] query error (days=${daysAhead}):`, subsErr.message);
      continue;
    }
    if (!subs?.length) {
      console.log(`[trial-expiry] no trials expiring in ${daysAhead} days`);
      continue;
    }

    const walletIds = subs.map((s: { wallet_id: string }) => s.wallet_id);

    // 2. Get family_id for these wallets
    const { data: wallets } = await supabase
      .from("wallets")
      .select("id, family_id")
      .in("id", walletIds)
      .not("family_id", "is", null);

    if (!wallets?.length) continue;

    const familyIds = wallets.map((w: { family_id: string }) => w.family_id);

    // 3. Find admin users for those families
    const { data: admins } = await supabase
      .from("family_members")
      .select("user_id")
      .in("family_id", familyIds)
      .eq("role", "admin")
      .not("user_id", "is", null)
      .is("deleted_at", null);

    if (!admins?.length) continue;

    const adminIds = admins.map((a: { user_id: string }) => a.user_id);

    // 4. Get FCM tokens for those admins
    const { data: tokens } = await supabase
      .from("user_fcm_tokens")
      .select("fcm_token")
      .in("user_id", adminIds);

    if (!tokens?.length) continue;

    // 5. Acquire FCM access token once per run
    if (!fcmToken) {
      try {
        fcmToken = await getFCMAccessToken();
      } catch (e) {
        console.error("[trial-expiry] FCM auth failed:", e);
        break;
      }
    }

    const { title, body } = notifContent(daysAhead);
    const fcmData: Record<string, string> = {
      route:       "settings",
      event_type:  "subscription.trial_expiring",
      days_left:   String(daysAhead),
    };

    const results = await Promise.allSettled(
      tokens.map((t: { fcm_token: string }) =>
        sendFCM(t.fcm_token, title, body, fcmData, fcmToken!)
      ),
    );

    const sent = results.filter(
      (r) => r.status === "fulfilled" && (r as PromiseFulfilledResult<boolean>).value,
    ).length;

    console.log(`[trial-expiry] days=${daysAhead} sent=${sent}/${tokens.length}`);
    totalSent += sent;
  }

  return new Response(JSON.stringify({ success: true, totalSent }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
