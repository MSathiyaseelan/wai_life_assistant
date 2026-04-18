// ============================================================
// Supabase Edge Function: /send-notification
// Sends FCM push notifications to family members.
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL        = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVICE_ACCOUNT  = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ── Notification templates ────────────────────────────────────────────────────

type TemplateData = Record<string, string>;
type Template = (d: TemplateData) => { title: string; body: string; route: string };

const TEMPLATES: Record<string, Template> = {
  // Wallet
  "wallet.expense_added":  (d) => ({ title: `💸 ${d.member_name} added expense`,  body: `₹${d.amount} for ${d.category}`,                route: "wallet" }),
  "wallet.income_added":   (d) => ({ title: `💰 ${d.member_name} added income`,   body: `₹${d.amount} — ${d.title}`,                    route: "wallet" }),
  "wallet.lend_added":     (d) => ({ title: `🤝 ${d.member_name} lent money`,     body: `₹${d.amount} to ${d.person}`,                  route: "wallet" }),
  "wallet.split_added":    (d) => ({ title: `🧾 New split added`,                 body: `${d.member_name} split ₹${d.amount} — you owe ₹${d.your_share}`, route: "wallet" }),

  // Pantry
  "pantry.meal_added":         (d) => ({ title: `🍽️ Meal planned`,          body: `${d.member_name} added ${d.meal_name} for ${d.meal_type}`, route: "pantry" }),
  "pantry.basket_item_added":  (d) => ({ title: `🛒 Added to shopping list`, body: `${d.member_name} added ${d.item_name} to ToBuy`,         route: "pantry" }),
  "pantry.item_finished":      (d) => ({ title: `⚠️ Item finished`,          body: `${d.member_name} marked ${d.item_name} as out of stock`, route: "pantry" }),
  "pantry.expiry_alert":       (d) => ({ title: `🔴 Expiry Alert`,           body: `${d.item_name} expires ${d.expiry_text}`,                route: "pantry" }),

  // PlanIt
  "planit.task_added":                (d) => ({ title: `✅ New family task`,           body: `${d.member_name}: ${d.task_title}${d.assignee ? ` → ${d.assignee}` : ""}`, route: "planit" }),
  "planit.task_completed":            (d) => ({ title: `✅ Task completed!`,           body: `${d.member_name} completed "${d.task_title}"`,                              route: "planit" }),
  "planit.reminder_added":            (d) => ({ title: `🔔 Family reminder set`,       body: `${d.member_name}: ${d.reminder_title} at ${d.time}`,                        route: "planit" }),
  "planit.special_day_approaching":   (d) => ({ title: `🎉 ${d.days_left} days to ${d.occasion_title}`, body: `Don't forget to plan something special!`,              route: "planit" }),
  "planit.note_added":                (d) => ({ title: `📌 ${d.member_name} added a note`, body: d.note_title || "Tap to view",                                         route: "planit" }),

  // Functions
  "functions.upcoming_added": (d) => ({ title: `🎊 Upcoming function added`, body: `${d.member_name}: ${d.function_name} on ${d.date}`, route: "planit" }),
};

// ── Base64url helpers ─────────────────────────────────────────────────────────

function base64url(data: Uint8Array | string): string {
  const str = typeof data === "string"
    ? data
    : String.fromCharCode(...data);
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

function base64urlFromJson(obj: unknown): string {
  return base64url(JSON.stringify(obj));
}

// ── FCM access token via service account JWT ──────────────────────────────────

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

  const signatureBytes = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );

  const jwt = `${signingInput}.${base64url(new Uint8Array(signatureBytes))}`;

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const data = await resp.json();
  return data.access_token;
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

// ── Send single FCM message ───────────────────────────────────────────────────

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
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          data,
          android: {
            priority: "high",
            notification: {
              channel_id: "wai_family_channel",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          apns: {
            payload: { aps: { alert: { title, body }, badge: 1, sound: "default" } },
          },
        },
      }),
    },
  );

  if (!resp.ok) {
    const err = await resp.text();
    console.error("[FCM] send failed:", err);
  }
  return resp.ok;
}

// ── Main handler ─────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  let body: {
    event_type: string;
    family_id: string;
    triggered_by: string;
    event_data: TemplateData;
  };

  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const { event_type, family_id, triggered_by, event_data } = body;

  const template = TEMPLATES[event_type];
  if (!template) {
    return new Response(JSON.stringify({ error: `Unknown event: ${event_type}` }), {
      status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const { title, body: notifBody, route } = template(event_data);

  console.log(`[notify] event=${event_type} family=${family_id} triggered_by=${triggered_by}`);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  // Get linked family members (user_id NOT NULL) excluding the triggering user.
  // Note: family_members has no status column — filter by user_id IS NOT NULL.
  const { data: members, error: membersErr } = await supabase
    .from("family_members")
    .select("user_id")
    .eq("family_id", family_id)
    .not("user_id", "is", null)
    .neq("user_id", triggered_by);

  console.log(`[notify] members found=${members?.length ?? 0} error=${membersErr?.message ?? "none"}`);

  if (!members?.length) {
    return new Response(JSON.stringify({ sent: 0, reason: "no members" }), {
      status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const memberIds = members.map((m: { user_id: string }) => m.user_id);

  // Get FCM tokens for all members
  const { data: tokens, error: tokensErr } = await supabase
    .from("user_fcm_tokens")
    .select("fcm_token")
    .in("user_id", memberIds);

  console.log(`[notify] tokens found=${tokens?.length ?? 0} error=${tokensErr?.message ?? "none"}`);

  if (!tokens?.length) {
    return new Response(JSON.stringify({ sent: 0, reason: "no tokens" }), {
      status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  let accessToken: string;
  try {
    accessToken = await getFCMAccessToken();
    console.log("[notify] FCM access token obtained");
  } catch (e) {
    console.error("[notify] FCM access token failed:", e);
    return new Response(JSON.stringify({ sent: 0, reason: "fcm_auth_failed", error: String(e) }), {
      status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const fcmData: Record<string, string> = { route, event_type, ...event_data };

  const results = await Promise.allSettled(
    tokens.map((t: { fcm_token: string }) =>
      sendFCM(t.fcm_token, title, notifBody, fcmData, accessToken)
    ),
  );

  const sent = results.filter((r) => r.status === "fulfilled" && (r as PromiseFulfilledResult<boolean>).value).length;
  console.log(`[notify] sent=${sent}/${tokens.length}`);

  return new Response(JSON.stringify({ sent, total: tokens.length }), {
    status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
});
