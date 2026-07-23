// ============================================================
// Supabase Edge Function: /check-scheduled-notifications
// Called daily by pg_cron to send FCM push notifications for
// the two "days before X" event types that can't be triggered
// by a simple insert:
//   - planit.special_day_approaching
//   - pantry.expiry_alert
//
// special_days.alert_days_before is per-record (set by the user
// when creating the special day), so that threshold is respected
// exactly. Grocery expiry has no per-item threshold column, so a
// fixed default (2 days) is used, matching NotificationPrefs'
// pantryExpiryDays default — the app-side per-user customization
// of that number is local-only (SharedPreferences) and never
// synced to the DB, so it can't be honored server-side yet.
//
// Authorization: service role key OR x-cron-secret header.
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVICE_ACCOUNT  = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
const CRON_SECRET          = Deno.env.get("CRON_SECRET") ?? "";

// Server-side default for grocery expiry alerts — see file header note.
const DEFAULT_PANTRY_EXPIRY_ALERT_DAYS = 2;

// ── FCM helpers (mirrors send-notification / notify-trial-expiry) ─────────────

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
  if (!resp.ok) console.error("[scheduled-notif] FCM send failed:", await resp.text());
  return resp.ok;
}

// ── Date helpers ────────────────────────────────────────────────────────────

function todayUTC(): Date {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  return d;
}

function daysBetween(a: Date, b: Date): number {
  return Math.round((b.getTime() - a.getTime()) / 86_400_000);
}

/// Next occurrence of a special day: same month/day this year (or next year
/// if that's already passed) when yearlyRecur, otherwise the literal date.
function nextOccurrence(dateStr: string, yearlyRecur: boolean, today: Date): Date {
  const d = new Date(dateStr + "T00:00:00Z");
  if (!yearlyRecur) return d;
  const next = new Date(Date.UTC(today.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  if (next.getTime() < today.getTime()) {
    next.setUTCFullYear(next.getUTCFullYear() + 1);
  }
  return next;
}

// ── Sender: groups eligible rows by family, sends one push per family ────────

interface PushJob {
  familyId: string;
  eventType: string;
  title: string;
  body: string;
  route: string;
  data: Record<string, string>;
}

async function sendGrouped(
  supabase: ReturnType<typeof createClient>,
  jobs: PushJob[],
): Promise<number> {
  if (!jobs.length) return 0;

  let accessToken: string;
  try {
    accessToken = await getFCMAccessToken();
  } catch (e) {
    console.error("[scheduled-notif] FCM auth failed:", e);
    return 0;
  }

  let sent = 0;
  for (const job of jobs) {
    const { data: members } = await supabase
      .from("family_members")
      .select("user_id")
      .eq("family_id", job.familyId)
      .not("user_id", "is", null);
    if (!members?.length) continue;

    const memberIds = members.map((m: { user_id: string }) => m.user_id);
    const { data: tokens } = await supabase
      .from("user_fcm_tokens")
      .select("fcm_token")
      .in("user_id", memberIds);
    if (!tokens?.length) continue;

    const fcmData = { route: job.route, event_type: job.eventType, ...job.data };
    const results = await Promise.allSettled(
      tokens.map((t: { fcm_token: string }) =>
        sendFCM(t.fcm_token, job.title, job.body, fcmData, accessToken)
      ),
    );
    sent += results.filter(
      (r) => r.status === "fulfilled" && (r as PromiseFulfilledResult<boolean>).value,
    ).length;
  }
  return sent;
}

// ── Main handler ──────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204 });

  const authHeader = req.headers.get("Authorization") ?? "";
  const cronHeader  = req.headers.get("x-cron-secret") ?? "";
  const isService   = authHeader === `Bearer ${SUPABASE_SERVICE_KEY}`;
  const isCron      = CRON_SECRET.length > 0 && cronHeader === CRON_SECRET;
  if (!isService && !isCron) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  const today = todayUTC();
  const jobs: PushJob[] = [];

  // ── 1. Special days approaching ─────────────────────────────────────────────
  {
    const { data: days, error } = await supabase
      .from("special_days")
      .select("wallet_id, title, emoji, date, yearly_recur, alert_days_before")
      .is("deleted_at", null);

    if (error) {
      console.error("[scheduled-notif] special_days query error:", error.message);
    } else if (days?.length) {
      const walletIds = [...new Set(days.map((d: { wallet_id: string }) => d.wallet_id))];
      const { data: wallets } = await supabase
        .from("wallets")
        .select("id, family_id")
        .in("id", walletIds)
        .not("family_id", "is", null);
      const familyByWallet = new Map<string, string>(
        (wallets ?? []).map((w: { id: string; family_id: string }) => [w.id, w.family_id]),
      );

      for (const day of days as Array<{
        wallet_id: string; title: string; emoji: string; date: string;
        yearly_recur: boolean; alert_days_before: number;
      }>) {
        const familyId = familyByWallet.get(day.wallet_id);
        if (!familyId) continue; // personal wallet — no one else to notify

        const occurrence = nextOccurrence(day.date, day.yearly_recur, today);
        const daysLeft = daysBetween(today, occurrence);
        if (daysLeft !== day.alert_days_before) continue;

        jobs.push({
          familyId,
          eventType: "planit.special_day_approaching",
          route: "planit",
          title: `🎉 ${daysLeft} day${daysLeft === 1 ? "" : "s"} to ${day.title}`,
          body: "Don't forget to plan something special!",
          data: { days_left: String(daysLeft), occasion_title: day.title },
        });
      }
    }
  }

  // ── 2. Grocery items expiring soon ──────────────────────────────────────────
  {
    const cutoff = new Date(today);
    cutoff.setUTCDate(cutoff.getUTCDate() + DEFAULT_PANTRY_EXPIRY_ALERT_DAYS);
    const cutoffStr = cutoff.toISOString().split("T")[0];

    const { data: items, error } = await supabase
      .from("grocery_items")
      .select("wallet_id, name, expiry_date")
      .eq("in_stock", true)
      .is("deleted_at", null)
      .not("expiry_date", "is", null)
      .eq("expiry_date", cutoffStr); // exactly N days out — fires once per item

    if (error) {
      console.error("[scheduled-notif] grocery_items query error:", error.message);
    } else if (items?.length) {
      const walletIds = [...new Set(items.map((i: { wallet_id: string }) => i.wallet_id))];
      const { data: wallets } = await supabase
        .from("wallets")
        .select("id, family_id")
        .in("id", walletIds)
        .not("family_id", "is", null);
      const familyByWallet = new Map<string, string>(
        (wallets ?? []).map((w: { id: string; family_id: string }) => [w.id, w.family_id]),
      );

      for (const item of items as Array<{ wallet_id: string; name: string; expiry_date: string }>) {
        const familyId = familyByWallet.get(item.wallet_id);
        if (!familyId) continue;

        jobs.push({
          familyId,
          eventType: "pantry.expiry_alert",
          route: "pantry",
          title: "🔴 Expiry Alert",
          body: `${item.name} expires in ${DEFAULT_PANTRY_EXPIRY_ALERT_DAYS} days`,
          data: { item_name: item.name, expiry_text: `in ${DEFAULT_PANTRY_EXPIRY_ALERT_DAYS} days` },
        });
      }
    }
  }

  const sent = await sendGrouped(supabase, jobs);
  console.log(`[scheduled-notif] jobs=${jobs.length} sent=${sent}`);

  return new Response(JSON.stringify({ jobs: jobs.length, sent }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
