// ============================================================
// Supabase Edge Function: /check-scheduled-notifications
// Called daily by pg_cron to send FCM push notifications for
// "days before X" event types that can't be triggered by a simple insert:
//   - planit.special_day_approaching
//   - pantry.expiry_alert
//   - functions.upcoming_reminder
//
// Each family member can have their own on/off toggle (and, for pantry
// expiry / functions upcoming, their own "days before" count) via
// profiles.notif_* columns — synced from the app's local NotificationPrefs
// (see ProfileService.updateNotificationPrefs). special_days already has
// its own per-record alert_days_before, so only the on/off toggle applies
// there; pantry expiry and functions upcoming have no per-record
// threshold, so each member's own day-count is used to decide eligibility
// individually rather than sending one blanket push to the whole family.
//
// Authorization: service role key OR x-cron-secret header.
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVICE_ACCOUNT  = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
const CRON_SECRET          = Deno.env.get("CRON_SECRET") ?? "";

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
  console.error("[scheduled-notif] FCM send failed:", errText);
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
    console.error("[scheduled-notif] dead token cleanup failed:", error);
  } else {
    console.log(`[scheduled-notif] removed ${deadTokens.length} dead token(s)`);
  }
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

// ── Sender: one push per already-resolved recipient ──────────────────────────
// Unlike a blanket per-family send, each job here already carries the exact
// set of user_ids eligible for it (resolved per-member against their own
// profiles.notif_* toggle/day-count before the job was ever created).

interface PushJob {
  userIds: string[];
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
    if (!job.userIds.length) continue;

    const { data: tokens } = await supabase
      .from("user_fcm_tokens")
      .select("fcm_token")
      .in("user_id", job.userIds);
    if (!tokens?.length) continue;

    const fcmData = { route: job.route, event_type: job.eventType, ...job.data };
    const results = await Promise.allSettled(
      tokens.map((t: { fcm_token: string }) =>
        sendFCM(t.fcm_token, job.title, job.body, fcmData, accessToken)
      ),
    );
    sent += results.filter(
      (r) => r.status === "fulfilled" && (r as PromiseFulfilledResult<SendResult>).value.ok,
    ).length;

    const deadTokens = tokens
      .filter((_: unknown, i: number) => {
        const r = results[i];
        return r.status === "fulfilled" && (r as PromiseFulfilledResult<SendResult>).value.deadToken;
      })
      .map((t: { fcm_token: string }) => t.fcm_token);
    await cleanupDeadTokens(supabase, deadTokens);
  }
  return sent;
}

interface MemberNotifPrefs {
  notif_master: boolean;
  notif_pantry_expiry: boolean;
  notif_pantry_expiry_days: number;
  notif_planit_special_day: boolean;
  notif_functions_upcoming: boolean;
  notif_functions_upcoming_days: number;
}

/** Every member of [familyId] together with their own notification prefs. */
async function familyMembersWithPrefs(
  supabase: ReturnType<typeof createClient>,
  familyId: string,
): Promise<Array<{ user_id: string } & MemberNotifPrefs>> {
  const { data: members } = await supabase
    .from("family_members")
    .select("user_id")
    .eq("family_id", familyId)
    .not("user_id", "is", null);
  if (!members?.length) return [];

  const memberIds = members.map((m: { user_id: string }) => m.user_id);
  const { data: profiles } = await supabase
    .from("profiles")
    .select(
      "id, notif_master, notif_pantry_expiry, notif_pantry_expiry_days, notif_planit_special_day, notif_functions_upcoming, notif_functions_upcoming_days",
    )
    .in("id", memberIds);

  return (profiles ?? []).map((p: MemberNotifPrefs & { id: string }) => ({
    user_id: p.id,
    notif_master: p.notif_master,
    notif_pantry_expiry: p.notif_pantry_expiry,
    notif_pantry_expiry_days: p.notif_pantry_expiry_days,
    notif_planit_special_day: p.notif_planit_special_day,
    notif_functions_upcoming: p.notif_functions_upcoming,
    notif_functions_upcoming_days: p.notif_functions_upcoming_days,
  }));
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
  // Caches familyMembersWithPrefs() per family across all three sections
  // below, since the same family often recurs across multiple items.
  const memberCache = new Map<string, Awaited<ReturnType<typeof familyMembersWithPrefs>>>();
  async function membersFor(familyId: string) {
    let m = memberCache.get(familyId);
    if (!m) {
      m = await familyMembersWithPrefs(supabase, familyId);
      memberCache.set(familyId, m);
    }
    return m;
  }

  // ── 1. Special days approaching ─────────────────────────────────────────────
  // alert_days_before is per-record (set by the user on each special day) —
  // only the on/off toggle is a per-member preference here.
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

        const members = await membersFor(familyId);
        const userIds = members
          .filter((m) => m.notif_master && m.notif_planit_special_day)
          .map((m) => m.user_id);
        if (!userIds.length) continue;

        jobs.push({
          userIds,
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
  // No per-item threshold column, so each member's own "days before" pick
  // decides eligibility individually — query a broad window covering every
  // possible chip option (1/2/3/7) and match per member below.
  {
    const maxWindow = new Date(today);
    maxWindow.setUTCDate(maxWindow.getUTCDate() + 7);
    const maxWindowStr = maxWindow.toISOString().split("T")[0];
    const todayStr = today.toISOString().split("T")[0];

    const { data: items, error } = await supabase
      .from("grocery_items")
      .select("wallet_id, name, expiry_date")
      .eq("in_stock", true)
      .is("deleted_at", null)
      .not("expiry_date", "is", null)
      .gte("expiry_date", todayStr)
      .lte("expiry_date", maxWindowStr);

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

        const daysLeft = daysBetween(today, new Date(item.expiry_date + "T00:00:00Z"));
        const members = await membersFor(familyId);
        const userIds = members
          .filter((m) => m.notif_master && m.notif_pantry_expiry && m.notif_pantry_expiry_days === daysLeft)
          .map((m) => m.user_id);
        if (!userIds.length) continue;

        jobs.push({
          userIds,
          eventType: "pantry.expiry_alert",
          route: "pantry",
          title: "🔴 Expiry Alert",
          body: `${item.name} expires in ${daysLeft} day${daysLeft === 1 ? "" : "s"}`,
          data: { item_name: item.name, expiry_text: `in ${daysLeft} day${daysLeft === 1 ? "" : "s"}` },
        });
      }
    }
  }

  // ── 3. Functions/events approaching ─────────────────────────────────────────
  // Same per-member "days before" matching as pantry expiry — this reminder
  // never existed before (only an immediate "someone added this" notify did).
  {
    const maxWindow = new Date(today);
    maxWindow.setUTCDate(maxWindow.getUTCDate() + 14);
    const maxWindowStr = maxWindow.toISOString().split("T")[0];
    const todayStr = today.toISOString().split("T")[0];

    const { data: fns, error } = await supabase
      .from("functions_upcoming")
      .select("wallet_id, function_title, date")
      .is("deleted_at", null)
      .not("date", "is", null)
      .gte("date", todayStr)
      .lte("date", maxWindowStr);

    if (error) {
      console.error("[scheduled-notif] functions_upcoming query error:", error.message);
    } else if (fns?.length) {
      const walletIds = [...new Set(fns.map((f: { wallet_id: string }) => f.wallet_id))];
      const { data: wallets } = await supabase
        .from("wallets")
        .select("id, family_id")
        .in("id", walletIds)
        .not("family_id", "is", null);
      const familyByWallet = new Map<string, string>(
        (wallets ?? []).map((w: { id: string; family_id: string }) => [w.id, w.family_id]),
      );

      for (const fn of fns as Array<{ wallet_id: string; function_title: string; date: string }>) {
        const familyId = familyByWallet.get(fn.wallet_id);
        if (!familyId) continue;

        const daysLeft = daysBetween(today, new Date(fn.date + "T00:00:00Z"));
        const members = await membersFor(familyId);
        const userIds = members
          .filter((m) => m.notif_master && m.notif_functions_upcoming && m.notif_functions_upcoming_days === daysLeft)
          .map((m) => m.user_id);
        if (!userIds.length) continue;

        jobs.push({
          userIds,
          eventType: "functions.upcoming_reminder",
          route: "myhub",
          title: `📅 ${daysLeft} day${daysLeft === 1 ? "" : "s"} to ${fn.function_title}`,
          body: "Don't forget to prepare!",
          data: { days_left: String(daysLeft), function_name: fn.function_title },
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
