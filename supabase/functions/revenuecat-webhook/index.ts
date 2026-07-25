// ============================================================
// Supabase Edge Function: /revenuecat-webhook
// WAI Life Assistant — RevenueCat billing events → wallet_subscriptions
// ============================================================
//
// This is the missing server-side half of the subscription system that
// 054_subscription_system.sql's comment always assumed would exist:
// "App never writes these directly — subscriptions are managed
// server-side." Before this function, nothing ever wrote to
// wallet_subscriptions — a successful purchase charged the user's card
// via RevenueCat/Play Billing and then never actually upgraded anything.
//
// Flow:
//   1. RevenueCat calls this URL on every billing event (configure the
//      URL + the same shared secret below as the "Authorization Header
//      Value" in RevenueCat Dashboard → Project Settings → Webhooks).
//   2. Verify the Authorization header matches REVENUECAT_WEBHOOK_SECRET.
//   3. Resolve app_user_id (set client-side via Purchases.logIn(supabaseUid)
//      in SubscriptionService.login()) → the Supabase user's family wallet.
//      V1 constraint: app_config.max_family_groups = '1', so a user
//      belongs to at most one family — no ambiguity about which wallet a
//      purchase applies to.
//   4. Resolve the plan from event.entitlement_ids (RevenueCat entitlement
//      identifiers are configured to match subscription_plans.plan_key,
//      e.g. 'family_plus' / 'family_pro' — see isEntitledTo() doc comment
//      in subscription_service.dart).
//   5. Upsert wallet_subscriptions (wallet_id is UNIQUE, so this is
//      naturally idempotent against RevenueCat's at-least-once delivery —
//      replaying the same event just re-applies the same end state).
//
// Event handling:
//   INITIAL_PURCHASE, RENEWAL, UNCANCELLATION, PRODUCT_CHANGE,
//   NON_RENEWING_PURCHASE  → activate/update the plan, set expires_at.
//   CANCELLATION           → auto_renew = false only; user keeps access
//                             until expiration (RevenueCat still sends
//                             the entitlement as active until then).
//   EXPIRATION              → downgrade to personal_free, status='expired'.
//   BILLING_ISSUE           → no-op; RevenueCat's own grace period keeps
//                             the entitlement active until it either
//                             recovers (RENEWAL) or truly lapses
//                             (EXPIRATION) — both already handled above.
//   anything else            → logged, ignored.
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEBHOOK_SECRET       = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";

const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

interface RevenueCatEvent {
  type: string;
  app_user_id: string;
  entitlement_ids?: string[];
  product_id?: string;
  expiration_at_ms?: number | null;
  store?: string;
  environment?: string;
  id?: string;
  // Set client-side via Purchases.setAttributes({'wai_wallet_id': ...}) in
  // SubscriptionService.purchasePackage() right before the purchase call —
  // the authoritative way to know which family wallet a purchase applies
  // to. A user can belong to more than one family, so app_user_id alone is
  // ambiguous; this removes the ambiguity entirely for anything purchased
  // after this attribute was added.
  subscriber_attributes?: Record<string, { value: string; updated_at_ms?: number }>;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const ACTIVATING_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "PRODUCT_CHANGE",
  "NON_RENEWING_PURCHASE",
]);

serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // ── 1. Verify the shared secret ─────────────────────────────────────────────
  if (!WEBHOOK_SECRET) {
    console.error("[revenuecat-webhook] REVENUECAT_WEBHOOK_SECRET not set — refusing all events");
    return jsonResponse({ error: "Webhook not configured" }, 500);
  }
  const authHeader = req.headers.get("Authorization") ?? "";
  if (authHeader !== WEBHOOK_SECRET && authHeader !== `Bearer ${WEBHOOK_SECRET}`) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  let payload: { event?: RevenueCatEvent };
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const event = payload.event;
  if (!event?.app_user_id || !event.type) {
    return jsonResponse({ error: "Missing event.app_user_id or event.type" }, 400);
  }

  // Sandbox purchases (testing in RevenueCat) must never touch real data.
  if (event.environment === "SANDBOX") {
    console.log(`[revenuecat-webhook] sandbox event ${event.type} for ${event.app_user_id} — ignored`);
    return jsonResponse({ ignored: "sandbox" });
  }

  console.log(`[revenuecat-webhook] ${event.type} for app_user_id=${event.app_user_id} entitlements=${event.entitlement_ids?.join(",")}`);

  try {
    // ── 2. Resolve the target family wallet ───────────────────────────────────
    // Primary source: the wai_wallet_id subscriber attribute set at purchase
    // time (see SubscriptionService.purchasePackage) — unambiguous even when
    // a user belongs to more than one family.
    let walletId: string | null =
      event.subscriber_attributes?.wai_wallet_id?.value || null;

    if (!walletId) {
      // Fallback for events with no attribute yet (e.g. a restore/renewal
      // for a purchase made before this attribute existed). Two plain
      // queries rather than a PostgREST embed — family_members and wallets
      // aren't directly FK-linked (both reference families independently),
      // so embedding isn't valid here. .limit(1) (not .maybeSingle()) since
      // a user CAN belong to more than one family — this is a best-effort
      // guess in that case, not a guarantee; the attribute path above is
      // the one that's actually correct for multi-family users.
      const { data: memberships, error: memberErr } = await supabaseAdmin
        .from("family_members")
        .select("family_id")
        .eq("user_id", event.app_user_id)
        .limit(1);

      if (memberErr) {
        console.error("[revenuecat-webhook] family_members lookup failed:", memberErr);
        return jsonResponse({ error: "Lookup failed" }, 500);
      }

      if (memberships && memberships.length > 0) {
        const { data: wallet, error: walletErr } = await supabaseAdmin
          .from("wallets")
          .select("id")
          .eq("family_id", memberships[0].family_id)
          .eq("is_personal", false)
          .maybeSingle();
        if (walletErr) {
          console.error("[revenuecat-webhook] wallets lookup failed:", walletErr);
          return jsonResponse({ error: "Lookup failed" }, 500);
        }
        walletId = wallet?.id ?? null;
        if (walletId) {
          console.log(`[revenuecat-webhook] no wai_wallet_id attribute — fell back to family_members guess for app_user_id=${event.app_user_id}`);
        }
      }
    }

    if (!walletId) {
      // Not a data-integrity failure worth retrying forever — log loudly and
      // ack so RevenueCat doesn't hammer retries for a user with no family
      // wallet yet (e.g. purchase flow reached before family creation, or a
      // test/anonymous app_user_id).
      console.error(`[revenuecat-webhook] no family wallet found for app_user_id=${event.app_user_id} — cannot apply plan`);
      return jsonResponse({ warning: "No family wallet for this user" });
    }

    // ── 3. Decide the target plan_key + status for this event ────────────────
    let planKey: string;
    let status: "active" | "expired";
    let autoRenew = true;

    if (event.type === "EXPIRATION") {
      planKey = "personal_free";
      status = "expired";
      autoRenew = false;
    } else if (event.type === "CANCELLATION") {
      // Entitlement stays active until expiration — only flip auto_renew.
      const { error: cancelErr } = await supabaseAdmin
        .from("wallet_subscriptions")
        .update({ auto_renew: false, updated_at: new Date().toISOString() })
        .eq("wallet_id", walletId);
      if (cancelErr) console.error("[revenuecat-webhook] cancellation update failed:", cancelErr);
      return jsonResponse({ success: true, action: "auto_renew_disabled" });
    } else if (event.type === "BILLING_ISSUE") {
      // RevenueCat's grace period keeps the entitlement active; nothing to
      // change here — a later RENEWAL or EXPIRATION event will follow.
      return jsonResponse({ success: true, action: "noop_grace_period" });
    } else if (ACTIVATING_EVENTS.has(event.type)) {
      const entitlement = event.entitlement_ids?.[0];
      if (!entitlement) {
        console.error(`[revenuecat-webhook] ${event.type} with no entitlement_ids — cannot resolve plan`);
        return jsonResponse({ warning: "No entitlement_ids on event" });
      }
      planKey = entitlement;
      status = "active";
    } else {
      console.log(`[revenuecat-webhook] event type ${event.type} not handled — ignored`);
      return jsonResponse({ ignored: event.type });
    }

    // ── 4. Resolve plan_id from plan_key ───────────────────────────────────────
    const { data: plan, error: planErr } = await supabaseAdmin
      .from("subscription_plans")
      .select("id")
      .eq("plan_key", planKey)
      .maybeSingle();

    if (planErr || !plan) {
      console.error(`[revenuecat-webhook] unknown plan_key "${planKey}":`, planErr);
      return jsonResponse({ error: `Unknown plan_key: ${planKey}` }, 500);
    }

    // ── 5. Upsert wallet_subscriptions (wallet_id is UNIQUE → idempotent) ─────
    const expiresAt = event.expiration_at_ms
      ? new Date(event.expiration_at_ms).toISOString()
      : null;

    const { error: upsertErr } = await supabaseAdmin
      .from("wallet_subscriptions")
      .upsert(
        {
          wallet_id: walletId,
          plan_id: plan.id,
          status,
          expires_at: expiresAt,
          auto_renew: autoRenew,
          payment_reference: event.product_id ?? null,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "wallet_id" },
      );

    if (upsertErr) {
      console.error("[revenuecat-webhook] wallet_subscriptions upsert failed:", upsertErr);
      return jsonResponse({ error: "Upsert failed" }, 500);
    }

    console.log(`[revenuecat-webhook] wallet ${walletId} → plan ${planKey} (${status})`);
    return jsonResponse({ success: true, wallet_id: walletId, plan_key: planKey, status });
  } catch (err) {
    console.error("[revenuecat-webhook] unexpected error:", err);
    return jsonResponse({ error: "Internal error" }, 500);
  }
});
