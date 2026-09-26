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
  quiet = false,
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
            priority: quiet ? "normal" : "high",
            notification: {
              channel_id: quiet ? "wai_family_quiet" : "wai_family_channel",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          apns: {
            payload: {
              aps: quiet
                ? { alert: { title, body }, badge: 1, "interruption-level": "passive" }
                : { alert: { title, body }, badge: 1, sound: "default" },
            },
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

// ── Query helpers ───────────────────────────────────────────────────────────
// This job scans every family's data in one run, so a plain .select() would
// be cut off at PostgREST's max-rows cap (1000 by default) without an error,
// and an .in() over thousands of ids would exceed the URL length limit.
// Every multi-row read below pages through results and chunks its id lists.

const PAGE_SIZE  = 1000; // PostgREST's default max-rows
const IN_CHUNK   = 200;  // ids per .in() filter — keeps request URLs short
const FCM_PARALLEL = 50; // concurrent FCM sends

type Page = PromiseLike<{ data: unknown[] | null; error: { message: string } | null }>;

/** All rows of a query, fetched PAGE_SIZE at a time. [page] must apply a
 * stable .order() before .range(from, to), or pages can overlap/skip rows. */
async function fetchAll<T>(page: (from: number, to: number) => Page): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0; ; from += PAGE_SIZE) {
    const { data, error } = await page(from, from + PAGE_SIZE - 1);
    if (error) throw new Error(error.message);
    rows.push(...((data ?? []) as T[]));
    if (!data || data.length < PAGE_SIZE) return rows;
  }
}

function chunk<T>(items: T[], size = IN_CHUNK): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

/** fetchAll() over an id list, split into IN_CHUNK-sized .in() filters. */
async function fetchIn<T>(
  ids: string[],
  page: (ids: string[], from: number, to: number) => Page,
): Promise<T[]> {
  const unique = [...new Set(ids)];
  const parts = await Promise.all(
    chunk(unique).map((c) => fetchAll<T>((from, to) => page(c, from, to))),
  );
  return parts.flat();
}

/** Runs [worker] over [items] with at most [limit] in flight at once. */
async function runPool<T>(items: T[], limit: number, worker: (item: T) => Promise<void>): Promise<void> {
  let next = 0;
  const lanes = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const item = items[next++];
      try {
        await worker(item);
      } catch (e) {
        console.error("[scheduled-notif] send failed:", e);
      }
    }
  });
  await Promise.all(lanes);
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
  quietUserIds: Set<string>,
): Promise<number> {
  if (!jobs.length) return 0;

  let accessToken: string;
  try {
    accessToken = await getFCMAccessToken();
  } catch (e) {
    console.error("[scheduled-notif] FCM auth failed:", e);
    return 0;
  }

  // One token lookup for every recipient across all jobs, instead of one
  // query per job.
  let tokenRows: Array<{ user_id: string; fcm_token: string }>;
  try {
    tokenRows = await fetchIn(jobs.flatMap((j) => j.userIds), (ids, from, to) =>
      supabase
        .from("user_fcm_tokens")
        .select("user_id, fcm_token")
        .in("user_id", ids)
        .order("id")
        .range(from, to)
    );
  } catch (e) {
    console.error("[scheduled-notif] FCM token lookup failed:", e);
    return 0;
  }
  const tokensByUser = new Map<string, string[]>();
  for (const t of tokenRows) {
    const list = tokensByUser.get(t.user_id) ?? [];
    list.push(t.fcm_token);
    tokensByUser.set(t.user_id, list);
  }

  const sends = jobs.flatMap((job) => {
    const fcmData = { route: job.route, event_type: job.eventType, ...job.data };
    return job.userIds.flatMap((userId) =>
      (tokensByUser.get(userId) ?? []).map((token) => ({ job, fcmData, userId, token }))
    );
  });

  let sent = 0;
  const deadTokens = new Set<string>();
  await runPool(sends, FCM_PARALLEL, async ({ job, fcmData, userId, token }) => {
    const r = await sendFCM(token, job.title, job.body, fcmData, accessToken, quietUserIds.has(userId));
    if (r.ok) sent++;
    else if (r.deadToken) deadTokens.add(token);
  });

  for (const c of chunk([...deadTokens])) await cleanupDeadTokens(supabase, c);
  return sent;
}

// ── Quiet hours (195_notif_quiet_hours.sql) ───────────────────────────────────
// Mirrors send-notification/index.ts. Same rule as the app's
// NotificationPrefs.isHourQuiet, evaluated in the recipient's own timezone.
// Recipients inside their quiet hours still get the push, just silently.

const QUIET_COLUMNS = "notif_quiet_enabled, notif_quiet_start, notif_quiet_end, notif_timezone";

interface QuietPrefs {
  notif_quiet_enabled?: boolean | null;
  notif_quiet_start?: number | null;
  notif_quiet_end?: number | null;
  notif_timezone?: string | null;
}

function isInQuietHours(p: QuietPrefs, now: Date = new Date()): boolean {
  if (!p.notif_quiet_enabled || !p.notif_timezone) return false;
  let hour: number;
  try {
    hour = Number(new Intl.DateTimeFormat("en-US", {
      timeZone: p.notif_timezone, hour: "numeric", hourCycle: "h23",
    }).format(now));
  } catch {
    return false; // unknown zone — don't silence
  }
  const start = p.notif_quiet_start ?? 22;
  const end = p.notif_quiet_end ?? 7;
  // Handles overnight window (e.g. 22 → 07)
  return start > end ? (hour >= start || hour < end) : (hour >= start && hour < end);
}

interface MemberNotifPrefs extends QuietPrefs {
  notif_master: boolean;
  notif_pantry_expiry: boolean;
  notif_pantry_expiry_days: number;
  notif_planit_special_day: boolean;
  notif_functions_upcoming: boolean;
  notif_functions_upcoming_days: number;
}

type FamilyMember = { user_id: string } & MemberNotifPrefs;

/** Every member (with their own notification prefs) of each of [familyIds],
 * loaded in bulk. Families with no active members map to []. */
async function familyMembersWithPrefs(
  supabase: ReturnType<typeof createClient>,
  familyIds: string[],
): Promise<Map<string, FamilyMember[]>> {
  // removeMember() soft-deletes via deleted_at rather than dropping the
  // row — see 121_fix_family_switcher_deleted_members.sql and
  // send-notification/index.ts's familyMembers query for the same fix.
  const members = await fetchIn<{ family_id: string; user_id: string }>(familyIds, (ids, from, to) =>
    supabase
      .from("family_members")
      .select("family_id, user_id")
      .in("family_id", ids)
      .not("user_id", "is", null)
      .is("deleted_at", null)
      .order("id")
      .range(from, to)
  );

  const profiles = await fetchIn<MemberNotifPrefs & { id: string }>(
    members.map((m) => m.user_id),
    (ids, from, to) =>
      supabase
        .from("profiles")
        .select(
          `id, notif_master, notif_pantry_expiry, notif_pantry_expiry_days, notif_planit_special_day, notif_functions_upcoming, notif_functions_upcoming_days, ${QUIET_COLUMNS}`,
        )
        .in("id", ids)
        .order("id")
        .range(from, to),
  );
  const prefsById = new Map<string, FamilyMember>(profiles.map((p) => [p.id, {
    user_id: p.id,
    notif_master: p.notif_master,
    notif_pantry_expiry: p.notif_pantry_expiry,
    notif_pantry_expiry_days: p.notif_pantry_expiry_days,
    notif_planit_special_day: p.notif_planit_special_day,
    notif_functions_upcoming: p.notif_functions_upcoming,
    notif_functions_upcoming_days: p.notif_functions_upcoming_days,
    notif_quiet_enabled: p.notif_quiet_enabled,
    notif_quiet_start: p.notif_quiet_start,
    notif_quiet_end: p.notif_quiet_end,
    notif_timezone: p.notif_timezone,
  }]));

  const byFamily = new Map<string, FamilyMember[]>(familyIds.map((id) => [id, []]));
  const seen = new Set<string>();
  for (const m of members) {
    const prefs = prefsById.get(m.user_id);
    const key = `${m.family_id}:${m.user_id}`;
    if (!prefs || seen.has(key)) continue;
    seen.add(key);
    byFamily.get(m.family_id)?.push(prefs);
  }
  return byFamily;
}

/** wallet_id -> family_id for the family wallets among [walletIds];
 * personal wallets are left out. */
async function walletFamilies(
  supabase: ReturnType<typeof createClient>,
  walletIds: string[],
): Promise<Map<string, string>> {
  const wallets = await fetchIn<{ id: string; family_id: string }>(walletIds, (ids, from, to) =>
    supabase
      .from("wallets")
      .select("id, family_id")
      .in("id", ids)
      .not("family_id", "is", null)
      .order("id")
      .range(from, to)
  );
  return new Map(wallets.map((w) => [w.id, w.family_id]));
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
  // Members per family, shared across all three sections below since the
  // same family often recurs. Each section bulk-loads the families it needs
  // up front, so there's no per-family query inside the loops.
  const memberCache = new Map<string, FamilyMember[]>();
  async function loadFamilies(familyIds: Iterable<string>) {
    const missing = [...new Set(familyIds)].filter((id) => !memberCache.has(id));
    if (!missing.length) return;
    for (const [id, m] of await familyMembersWithPrefs(supabase, missing)) memberCache.set(id, m);
  }
  const membersFor = (familyId: string) => memberCache.get(familyId) ?? [];

  // ── 1. Special days approaching ─────────────────────────────────────────────
  // alert_days_before is per-record (set by the user on each special day) —
  // only the on/off toggle is a per-member preference here.
  try {
    const allDays = await fetchAll<{
      wallet_id: string; title: string; emoji: string; date: string;
      yearly_recur: boolean; alert_days_before: number;
    }>((from, to) =>
      supabase
        .from("special_days")
        .select("wallet_id, title, emoji, date, yearly_recur, alert_days_before")
        .is("deleted_at", null)
        .order("id")
        .range(from, to)
    );
    // Only days whose alert fires today need their family resolved.
    const days = allDays
      .map((day) => ({ day, daysLeft: daysBetween(today, nextOccurrence(day.date, day.yearly_recur, today)) }))
      .filter(({ day, daysLeft }) => daysLeft === day.alert_days_before);

    if (days.length) {
      const familyByWallet = await walletFamilies(supabase, days.map(({ day }) => day.wallet_id));
      await loadFamilies(familyByWallet.values());

      for (const { day, daysLeft } of days) {
        const familyId = familyByWallet.get(day.wallet_id);
        if (!familyId) continue; // personal wallet — no one else to notify

        const members = membersFor(familyId);
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
  } catch (e) {
    console.error("[scheduled-notif] special_days query error:", e);
  }

  // ── 2. Grocery items expiring soon ──────────────────────────────────────────
  // No per-item threshold column, so each member's own "days before" pick
  // decides eligibility individually — query a broad window covering every
  // possible chip option (1/2/3/7) and match per member below.
  try {
    const maxWindow = new Date(today);
    maxWindow.setUTCDate(maxWindow.getUTCDate() + 7);
    const maxWindowStr = maxWindow.toISOString().split("T")[0];
    const todayStr = today.toISOString().split("T")[0];

    const items = await fetchAll<{ wallet_id: string; name: string; expiry_date: string }>((from, to) =>
      supabase
        .from("grocery_items")
        .select("wallet_id, name, expiry_date")
        .eq("in_stock", true)
        .is("deleted_at", null)
        .not("expiry_date", "is", null)
        .gte("expiry_date", todayStr)
        .lte("expiry_date", maxWindowStr)
        .order("id")
        .range(from, to)
    );

    if (items.length) {
      const familyByWallet = await walletFamilies(supabase, items.map((i) => i.wallet_id));
      await loadFamilies(familyByWallet.values());

      for (const item of items) {
        const familyId = familyByWallet.get(item.wallet_id);
        if (!familyId) continue;

        const daysLeft = daysBetween(today, new Date(item.expiry_date + "T00:00:00Z"));
        const members = membersFor(familyId);
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
  } catch (e) {
    console.error("[scheduled-notif] grocery_items query error:", e);
  }

  // ── 3. Functions/events approaching ─────────────────────────────────────────
  // Same per-member "days before" matching as pantry expiry — this reminder
  // never existed before (only an immediate "someone added this" notify did).
  try {
    const maxWindow = new Date(today);
    maxWindow.setUTCDate(maxWindow.getUTCDate() + 14);
    const maxWindowStr = maxWindow.toISOString().split("T")[0];
    const todayStr = today.toISOString().split("T")[0];

    const fns = await fetchAll<{ wallet_id: string; function_title: string; date: string }>((from, to) =>
      supabase
        .from("functions_upcoming")
        .select("wallet_id, function_title, date")
        .is("deleted_at", null)
        .not("date", "is", null)
        .gte("date", todayStr)
        .lte("date", maxWindowStr)
        .order("id")
        .range(from, to)
    );

    if (fns.length) {
      const familyByWallet = await walletFamilies(supabase, fns.map((f) => f.wallet_id));
      await loadFamilies(familyByWallet.values());

      for (const fn of fns) {
        const familyId = familyByWallet.get(fn.wallet_id);
        if (!familyId) continue;

        const daysLeft = daysBetween(today, new Date(fn.date + "T00:00:00Z"));
        const members = membersFor(familyId);
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
  } catch (e) {
    console.error("[scheduled-notif] functions_upcoming query error:", e);
  }

  const quietUserIds = new Set<string>();
  for (const members of memberCache.values()) {
    for (const m of members) if (isInQuietHours(m)) quietUserIds.add(m.user_id);
  }
  const sent = await sendGrouped(supabase, jobs, quietUserIds);
  console.log(`[scheduled-notif] jobs=${jobs.length} sent=${sent}`);

  return new Response(JSON.stringify({ jobs: jobs.length, sent }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
