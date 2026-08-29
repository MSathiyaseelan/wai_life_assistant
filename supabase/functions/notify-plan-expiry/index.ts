// ============================================================
// Supabase Edge Function: /notify-plan-expiry
// Called daily by pg_cron to send FCM push notifications to family
// admins whose PAID plan is cancelled (auto_renew=false) and about to
// lapse — 3 days, 1 day, or today. Mirrors notify-trial-expiry, but
// covers the paid-and-cancelled case instead of the trial case.
//
// Auto-renewing subscribers are NOT notified here — nothing bad
// happens to them on their renewal date, so a heads-up would just be
// noise. This only targets users who cancelled and are about to lose
// access.
//
// Authorization: service role key OR x-cron-secret header.
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVICE_ACCOUNT  = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
const CRON_SECRET          = Deno.env.get("CRON_SECRET") ?? "";

// ── FCM helpers (mirrors notify-trial-expiry/index.ts) ────────────────────────

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

interface SendResult {
  ok: boolean;
  /** True when FCM reports this specific token as permanently dead
   * (UNREGISTERED/INVALID_ARGUMENT) — caller should delete the row. */
  deadToken: boolean;
}

async function sendFCM(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
  accessToken: string,
): Promise<SendResult> {
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
  if (resp.ok) return { ok: true, deadToken: false };

  const errText = await resp.text();
  console.error("[plan-expiry] FCM send failed:", errText);
  return { ok: false, deadToken: isDeadTokenError(errText) };
}

/** See send-notification/index.ts for the full explanation — mirrors that
 * function's dead-token detection (only UNREGISTERED/INVALID_ARGUMENT). */
function isDeadTokenError(errText: string): boolean {
  try {
    const parsed = JSON.parse(errText);
    const errorCode = parsed?.error?.details?.find(
      (d: { errorCode?: string }) => d?.errorCode,
    )?.errorCode;
    return errorCode === "UNREGISTERED" || errorCode === "INVALID_ARGUMENT";
  } catch {
    return false;
  }
}

async function cleanupDeadTokens(
  supabase: ReturnType<typeof createClient>,
  deadTokens: string[],
): Promise<void> {
  if (!deadTokens.length) return;
  const { error } = await supabase.from("user_fcm_tokens").delete().in("fcm_token", deadTokens);
  if (error) {
    console.error("[plan-expiry] dead token cleanup failed:", error);
  } else {
    console.log(`[plan-expiry] removed ${deadTokens.length} dead token(s)`);
  }
}

// ── Notification copy per days-remaining ─────────────────────────────────────

function notifContent(daysAhead: number): { title: string; body: string } {
  if (daysAhead === 0) return {
    title: "⏰ Plan access ends today",
    body:  "Your family plan wasn't renewed — resubscribe to keep your features.",
  };
  if (daysAhead === 1) return {
    title: "⏳ Plan access ends tomorrow",
    body:  "Resubscribe to avoid losing your family plan features.",
  };
  return {
    title: `📅 Plan access ends in ${daysAhead} days`,
    body:  "Your subscription was cancelled — resubscribe to keep all family features.",
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

    // 1. Find cancelled-but-still-active plans lapsing on this date.
    // status='active' && auto_renew=false is exactly the window
    // revenuecat-webhook's CANCELLATION handler creates (access stays
    // until expires_at, only auto_renew flips) — see that function's
    // header comment for the full event flow.
    const { data: subs, error: subsErr } = await supabase
      .from("wallet_subscriptions")
      .select("wallet_id, expires_at")
      .eq("status", "active")
      .eq("auto_renew", false)
      .not("expires_at", "is", null)
      .gte("expires_at", dayStart.toISOString())
      .lt("expires_at", dayEnd.toISOString());

    if (subsErr) {
      console.error(`[plan-expiry] query error (days=${daysAhead}):`, subsErr.message);
      continue;
    }
    if (!subs?.length) {
      console.log(`[plan-expiry] no cancelled plans expiring in ${daysAhead} days`);
      continue;
    }

    const walletIds = subs.map((s: { wallet_id: string }) => s.wallet_id);

    // 2. Get owner_id/family_id for these wallets.
    const { data: wallets } = await supabase
      .from("wallets")
      .select("id, family_id, owner_id")
      .in("id", walletIds);

    if (!wallets?.length) continue;

    const familyIds = wallets
      .map((w: { family_id: string | null }) => w.family_id)
      .filter((id: string | null): id is string => id !== null);
    const personalOwnerIds = wallets
      .map((w: { family_id: string | null; owner_id: string | null }) =>
        w.family_id === null ? w.owner_id : null)
      .filter((id: string | null): id is string => id !== null);

    // 3. Recipients: family admins for family wallets, the owner directly
    // for personal wallets.
    const recipientIds = new Set<string>(personalOwnerIds);
    if (familyIds.length) {
      const { data: admins } = await supabase
        .from("family_members")
        .select("user_id")
        .in("family_id", familyIds)
        .eq("role", "admin")
        .not("user_id", "is", null)
        .is("deleted_at", null);
      for (const a of admins ?? []) recipientIds.add((a as { user_id: string }).user_id);
    }

    if (!recipientIds.size) continue;

    // 4. Get FCM tokens for those recipients
    const { data: tokens } = await supabase
      .from("user_fcm_tokens")
      .select("fcm_token")
      .in("user_id", [...recipientIds]);

    if (!tokens?.length) continue;

    // 5. Acquire FCM access token once per run
    if (!fcmToken) {
      try {
        fcmToken = await getFCMAccessToken();
      } catch (e) {
        console.error("[plan-expiry] FCM auth failed:", e);
        break;
      }
    }

    const { title, body } = notifContent(daysAhead);
    const fcmData: Record<string, string> = {
      route:       "settings",
      event_type:  "subscription.plan_expiring",
      days_left:   String(daysAhead),
    };

    const results = await Promise.allSettled(
      tokens.map((t: { fcm_token: string }) =>
        sendFCM(t.fcm_token, title, body, fcmData, fcmToken!)
      ),
    );

    const sent = results.filter(
      (r) => r.status === "fulfilled" && (r as PromiseFulfilledResult<SendResult>).value.ok,
    ).length;

    const deadTokens = tokens
      .filter((_: unknown, i: number) => {
        const r = results[i];
        return r.status === "fulfilled" && (r as PromiseFulfilledResult<SendResult>).value.deadToken;
      })
      .map((t: { fcm_token: string }) => t.fcm_token);
    await cleanupDeadTokens(supabase, deadTokens);

    console.log(`[plan-expiry] days=${daysAhead} sent=${sent}/${tokens.length}`);
    totalSent += sent;
  }

  return new Response(JSON.stringify({ success: true, totalSent }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
