-- ================================================================
-- WAI Life Assistant — Subscription System (Migration 054)
--
-- Tables
--   subscription_plans     Master plan catalog (admin-managed)
--   plan_limits            Feature limits per plan (one row per plan)
--   wallet_subscriptions   Which plan a family wallet is on
--
-- Extensions to existing tables
--   feature_usage          Add wallet_id for family-shared monthly counters
--
-- Helper functions
--   get_plan_limits(wallet_id)   Returns the plan_limits row for a wallet
--   check_plan_feature_limit(...)  Unified limit checker (user OR wallet scope)
--
-- Plan tiers
--   personal_free   Personal account — always free, no subscription needed
--   family_plus     Paid family tier — up to max_members configurable
--   family_pro      Premium family tier — higher limits, up to max_members configurable
-- ================================================================


-- ── 1. SUBSCRIPTION PLANS ──────────────────────────────────────────────────────
--    Admin-managed catalog; app reads this to display upgrade screens.

CREATE TABLE IF NOT EXISTS subscription_plans (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_key      TEXT NOT NULL UNIQUE,   -- 'personal_free' | 'family_plus' | 'family_pro'
  name          TEXT NOT NULL,
  description   TEXT,
  price_monthly NUMERIC(10, 2) NOT NULL DEFAULT 0,
  price_yearly  NUMERIC(10, 2) NOT NULL DEFAULT 0,
  target_type   TEXT NOT NULL DEFAULT 'personal',  -- 'personal' | 'family'
  is_active     BOOLEAN NOT NULL DEFAULT true,
  sort_order    INTEGER DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read plans (needed to show upgrade prompts)
CREATE POLICY "Authenticated users can read plans"
  ON subscription_plans FOR SELECT
  USING (auth.uid() IS NOT NULL);


-- ── 2. PLAN LIMITS ────────────────────────────────────────────────────────────
--    One row per plan. -1 means unlimited.
--    Boolean-typed columns for notification/feature flags.

CREATE TABLE IF NOT EXISTS plan_limits (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id     UUID NOT NULL UNIQUE REFERENCES subscription_plans(id) ON DELETE CASCADE,

  -- ── Family ──────────────────────────────────────────────────────────────────
  family_max_members               INTEGER NOT NULL DEFAULT 0,
  -- 0 = not applicable (personal plan). Overridden per-wallet in wallet_subscriptions.

  -- ── AI ──────────────────────────────────────────────────────────────────────
  ai_parser_calls_month            INTEGER NOT NULL DEFAULT 30,
  -- AI Parser (receipt scan, wardrobe scan, grocery scan, etc.)
  ai_assistant_calls_month         INTEGER NOT NULL DEFAULT 20,
  -- Dashboard AI assistant chat messages

  -- ── Wallet ──────────────────────────────────────────────────────────────────
  wallet_transactions_month        INTEGER NOT NULL DEFAULT 100,
  wallet_split_groups_month        INTEGER NOT NULL DEFAULT 3,
  wallet_bill_watch_max            INTEGER NOT NULL DEFAULT 5,
  wallet_custom_categories_max     INTEGER NOT NULL DEFAULT 10,

  -- ── Pantry ──────────────────────────────────────────────────────────────────
  pantry_meal_weeks_ahead          INTEGER NOT NULL DEFAULT 1,
  -- How many weeks into the future a user can pre-plan meals
  pantry_recipes_max               INTEGER NOT NULL DEFAULT 10,
  pantry_grocery_lists_max         INTEGER NOT NULL DEFAULT 2,
  -- Saved/named grocery lists (not items, lists)

  -- ── Functions (MyHub / FamilyHub) ───────────────────────────────────────────
  functions_upcoming_max           INTEGER NOT NULL DEFAULT 15,
  functions_attended_max           INTEGER NOT NULL DEFAULT 30,
  functions_my_max                 INTEGER NOT NULL DEFAULT 5,

  -- ── Item Locator ────────────────────────────────────────────────────────────
  item_locator_containers_max      INTEGER NOT NULL DEFAULT 5,
  item_locator_items_max           INTEGER NOT NULL DEFAULT 50,

  -- ── Wardrobe ────────────────────────────────────────────────────────────────
  wardrobe_items_max               INTEGER NOT NULL DEFAULT 30,
  wardrobe_outfit_log_months       INTEGER NOT NULL DEFAULT 1,
  -- Months of outfit-log history visible; -1 = full history (unlimited)
  wardrobe_wishlist_max            INTEGER NOT NULL DEFAULT 10,
  wardrobe_photo_storage_mb        INTEGER NOT NULL DEFAULT 50,

  -- ── Health Space ────────────────────────────────────────────────────────────
  health_medications_max           INTEGER NOT NULL DEFAULT 15,
  health_appointments_max          INTEGER NOT NULL DEFAULT 20,
  health_vital_logs_month          INTEGER NOT NULL DEFAULT 60,
  health_vaccines_max              INTEGER NOT NULL DEFAULT 20,
  health_doctors_max               INTEGER NOT NULL DEFAULT 10,
  health_insurance_max             INTEGER NOT NULL DEFAULT 5,

  -- ── PlanIt ──────────────────────────────────────────────────────────────────
  planit_tasks_max                 INTEGER NOT NULL DEFAULT 50,
  planit_reminders_max             INTEGER NOT NULL DEFAULT 30,
  planit_notes_max                 INTEGER NOT NULL DEFAULT 20,
  planit_special_days_max          INTEGER NOT NULL DEFAULT 30,
  planit_wishlist_max              INTEGER NOT NULL DEFAULT 25,

  -- ── Notifications ───────────────────────────────────────────────────────────
  notif_push_enabled               BOOLEAN NOT NULL DEFAULT false,
  notif_wallet                     BOOLEAN NOT NULL DEFAULT true,
  notif_pantry                     BOOLEAN NOT NULL DEFAULT true,
  notif_myhub                      BOOLEAN NOT NULL DEFAULT true,
  notif_planit                     BOOLEAN NOT NULL DEFAULT true,
  notif_health                     BOOLEAN NOT NULL DEFAULT true,
  notif_custom_alerts              BOOLEAN NOT NULL DEFAULT false
  -- Custom alerts = user-defined smart triggers (e.g. "alert when grocery spend > X")
);

ALTER TABLE plan_limits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read plan limits"
  ON plan_limits FOR SELECT
  USING (auth.uid() IS NOT NULL);


-- ── 3. WALLET SUBSCRIPTIONS ──────────────────────────────────────────────────
--    Tracks which plan a family wallet is on.
--    Personal wallets are always 'personal_free' — no row needed.
--    family_member_limit overrides plan_limits.family_max_members
--    so Plus and Pro can have different caps per wallet.

CREATE TABLE IF NOT EXISTS wallet_subscriptions (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id            UUID NOT NULL UNIQUE,
  plan_id              UUID NOT NULL REFERENCES subscription_plans(id),
  status               TEXT NOT NULL DEFAULT 'active',
  -- 'active' | 'trial' | 'expired' | 'cancelled'
  family_member_limit  INTEGER,
  -- NULL = use plan_limits.family_max_members; set to override per wallet
  started_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at           TIMESTAMPTZ,
  -- NULL = lifetime / never expires (manual grants, LTD deals, etc.)
  trial_ends_at        TIMESTAMPTZ,
  auto_renew           BOOLEAN NOT NULL DEFAULT true,
  payment_reference    TEXT,
  -- Store Razorpay / Play Store / App Store subscription ID here
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE wallet_subscriptions ENABLE ROW LEVEL SECURITY;

-- Members of a family wallet can read its subscription details
CREATE POLICY "Family members can read their wallet subscription"
  ON wallet_subscriptions FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    wallet_id IN (
      SELECT wallet_id FROM family_members WHERE user_id = auth.uid()
    )
  );

-- Only service-role / admin can write subscription records
-- (App never writes these directly — subscriptions are managed server-side)


-- ── 4. EXTEND feature_usage FOR WALLET-LEVEL (FAMILY SHARED) TRACKING ────────
--    Personal features count per user_id.
--    Family features count per wallet_id (shared across all members).

ALTER TABLE feature_usage
  ADD COLUMN IF NOT EXISTS wallet_id UUID;

-- Drop old single-column unique constraint if it exists
ALTER TABLE feature_usage
  DROP CONSTRAINT IF EXISTS feature_usage_user_id_feature_month_key;

-- Partial unique index: personal usage (no wallet)
CREATE UNIQUE INDEX IF NOT EXISTS feature_usage_personal_unique
  ON feature_usage (user_id, feature, month)
  WHERE wallet_id IS NULL;

-- Partial unique index: family/wallet usage
CREATE UNIQUE INDEX IF NOT EXISTS feature_usage_wallet_unique
  ON feature_usage (wallet_id, feature, month)
  WHERE wallet_id IS NOT NULL;


-- ── 5. SEED DEFAULT PLAN DATA ─────────────────────────────────────────────────

INSERT INTO subscription_plans (plan_key, name, description, price_monthly, price_yearly, target_type, sort_order)
VALUES
  ('personal_free', 'Personal Free',
   'Full personal account at no cost.',
   0, 0, 'personal', 1),

  ('family_plus',   'Family Plus',
   'Family plan for up to 6 members. Unlock shared pantry, wallet and hub features with generous limits.',
   0, 0, 'family', 2),
   -- Price TBD: set price_monthly / price_yearly before launch

  ('family_pro',    'Family Pro',
   'Premium family plan for up to 15 members. Near-unlimited usage across all features.',
   0, 0, 'family', 3)
ON CONFLICT (plan_key) DO NOTHING;

-- Seed limits — insert only if plan_limits row doesn't exist yet
INSERT INTO plan_limits (
  plan_id,

  family_max_members,

  ai_parser_calls_month,
  ai_assistant_calls_month,

  wallet_transactions_month,
  wallet_split_groups_month,
  wallet_bill_watch_max,
  wallet_custom_categories_max,

  pantry_meal_weeks_ahead,
  pantry_recipes_max,
  pantry_grocery_lists_max,

  functions_upcoming_max,
  functions_attended_max,
  functions_my_max,

  item_locator_containers_max,
  item_locator_items_max,

  wardrobe_items_max,
  wardrobe_outfit_log_months,
  wardrobe_wishlist_max,
  wardrobe_photo_storage_mb,

  health_medications_max,
  health_appointments_max,
  health_vital_logs_month,
  health_vaccines_max,
  health_doctors_max,
  health_insurance_max,

  planit_tasks_max,
  planit_reminders_max,
  planit_notes_max,
  planit_special_days_max,
  planit_wishlist_max,

  notif_push_enabled,
  notif_wallet,
  notif_pantry,
  notif_myhub,
  notif_planit,
  notif_health,
  notif_custom_alerts
)
SELECT
  sp.id,

  -- ─────────────────── personal_free ───────────────────────────────────────
  CASE sp.plan_key WHEN 'personal_free' THEN 0   WHEN 'family_plus' THEN 6    WHEN 'family_pro' THEN 15   END,

  -- AI
  CASE sp.plan_key WHEN 'personal_free' THEN 30  WHEN 'family_plus' THEN 150  WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 20  WHEN 'family_plus' THEN 100  WHEN 'family_pro' THEN -1   END,

  -- Wallet
  CASE sp.plan_key WHEN 'personal_free' THEN 100 WHEN 'family_plus' THEN 500  WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 3   WHEN 'family_plus' THEN 20   WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 5   WHEN 'family_plus' THEN 20   WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 10  WHEN 'family_plus' THEN 30   WHEN 'family_pro' THEN -1   END,

  -- Pantry
  CASE sp.plan_key WHEN 'personal_free' THEN 1   WHEN 'family_plus' THEN 2    WHEN 'family_pro' THEN 4    END,
  CASE sp.plan_key WHEN 'personal_free' THEN 10  WHEN 'family_plus' THEN 50   WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 2   WHEN 'family_plus' THEN 10   WHEN 'family_pro' THEN -1   END,

  -- Functions
  CASE sp.plan_key WHEN 'personal_free' THEN 15  WHEN 'family_plus' THEN 50   WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 30  WHEN 'family_plus' THEN 100  WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 5   WHEN 'family_plus' THEN 20   WHEN 'family_pro' THEN -1   END,

  -- Item Locator
  CASE sp.plan_key WHEN 'personal_free' THEN 5   WHEN 'family_plus' THEN 20   WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 50  WHEN 'family_plus' THEN 200  WHEN 'family_pro' THEN -1   END,

  -- Wardrobe
  CASE sp.plan_key WHEN 'personal_free' THEN 30  WHEN 'family_plus' THEN 150  WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 1   WHEN 'family_plus' THEN 6    WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 10  WHEN 'family_plus' THEN 50   WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 50  WHEN 'family_plus' THEN 500  WHEN 'family_pro' THEN -1   END,

  -- Health
  CASE sp.plan_key WHEN 'personal_free' THEN 15  WHEN 'family_plus' THEN 50   WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 20  WHEN 'family_plus' THEN 100  WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 60  WHEN 'family_plus' THEN 300  WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 20  WHEN 'family_plus' THEN 100  WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 10  WHEN 'family_plus' THEN 30   WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 5   WHEN 'family_plus' THEN 20   WHEN 'family_pro' THEN -1   END,

  -- PlanIt
  CASE sp.plan_key WHEN 'personal_free' THEN 50  WHEN 'family_plus' THEN 200  WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 30  WHEN 'family_plus' THEN 150  WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 20  WHEN 'family_plus' THEN 100  WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 30  WHEN 'family_plus' THEN -1   WHEN 'family_pro' THEN -1   END,
  CASE sp.plan_key WHEN 'personal_free' THEN 25  WHEN 'family_plus' THEN 100  WHEN 'family_pro' THEN -1   END,

  -- Notifications
  CASE sp.plan_key WHEN 'personal_free' THEN false WHEN 'family_plus' THEN true  WHEN 'family_pro' THEN true  END,
  true, -- notif_wallet    — on for all tiers
  true, -- notif_pantry    — on for all tiers
  true, -- notif_myhub     — on for all tiers
  true, -- notif_planit    — on for all tiers
  true, -- notif_health    — on for all tiers
  CASE sp.plan_key WHEN 'personal_free' THEN false WHEN 'family_plus' THEN false WHEN 'family_pro' THEN true  END

FROM subscription_plans sp
WHERE NOT EXISTS (
  SELECT 1 FROM plan_limits pl WHERE pl.plan_id = sp.id
);


-- ── 6. HELPER: get_plan_limits ────────────────────────────────────────────────
--    Returns the plan_limits row that applies to a given wallet.
--    For family wallets: looks up their subscription.
--    For personal wallets (or null): returns personal_free limits.

CREATE OR REPLACE FUNCTION get_plan_limits(p_wallet_id UUID DEFAULT NULL)
RETURNS plan_limits AS $$
DECLARE
  result plan_limits;
BEGIN
  IF p_wallet_id IS NOT NULL THEN
    -- Try to find a subscription for this wallet
    SELECT pl.*
      INTO result
      FROM plan_limits pl
      JOIN wallet_subscriptions ws ON ws.plan_id = pl.plan_id
     WHERE ws.wallet_id = p_wallet_id
       AND ws.status IN ('active', 'trial')
       AND (ws.expires_at IS NULL OR ws.expires_at > NOW());

    IF FOUND THEN
      RETURN result;
    END IF;
  END IF;

  -- Fall back to personal_free
  SELECT pl.*
    INTO result
    FROM plan_limits pl
    JOIN subscription_plans sp ON sp.id = pl.plan_id
   WHERE sp.plan_key = 'personal_free';

  RETURN result;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;


-- ── 7. HELPER: check_plan_feature_limit ─────────────────────────────────────
--    Atomically increments usage and returns TRUE if the action is allowed.
--
--    p_user_id      — the acting user
--    p_wallet_id    — NULL for personal features; family wallet UUID for shared features
--    p_feature      — feature key (e.g. 'ai_parser', 'wallet_transaction')
--    p_limit        — the applicable limit value from plan_limits
--                     Pass -1 to mean unlimited (always returns TRUE).
--
--    Usage in app: call get_plan_limits() first to read p_limit, then call this.

CREATE OR REPLACE FUNCTION check_plan_feature_limit(
  p_user_id   UUID,
  p_wallet_id UUID,
  p_feature   TEXT,
  p_limit     INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
  current_count INTEGER;
  current_month TEXT := TO_CHAR(NOW(), 'YYYY-MM');
BEGIN
  -- -1 = unlimited
  IF p_limit = -1 THEN
    RETURN true;
  END IF;

  IF p_wallet_id IS NOT NULL THEN
    -- Family/wallet-scoped usage (shared across members)
    INSERT INTO feature_usage (user_id, wallet_id, feature, month, count)
    VALUES (p_user_id, p_wallet_id, p_feature, current_month, 1)
    ON CONFLICT DO NOTHING;

    -- Use the wallet-level unique index path
    UPDATE feature_usage
       SET count = count + 1
     WHERE wallet_id = p_wallet_id
       AND feature = p_feature
       AND month = current_month
    RETURNING count INTO current_count;
  ELSE
    -- Personal usage (per user)
    INSERT INTO feature_usage (user_id, feature, month, count)
    VALUES (p_user_id, p_feature, current_month, 1)
    ON CONFLICT DO NOTHING;

    UPDATE feature_usage
       SET count = count + 1
     WHERE user_id = p_user_id
       AND wallet_id IS NULL
       AND feature = p_feature
       AND month = current_month
    RETURNING count INTO current_count;
  END IF;

  RETURN current_count <= p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ── 8. KEEP BACKWARD COMPATIBILITY: update old check_feature_limit ────────────
--    The old function (used by bill_scan etc.) now reads the personal_free plan.

CREATE OR REPLACE FUNCTION check_feature_limit(
  p_user_id UUID,
  p_feature TEXT
) RETURNS BOOLEAN AS $$
DECLARE
  allowed_limit INTEGER;
  limits        plan_limits;
BEGIN
  limits := get_plan_limits(NULL);  -- personal, no wallet

  allowed_limit := CASE p_feature
    WHEN 'ai_parser'            THEN limits.ai_parser_calls_month
    WHEN 'ai_assistant'         THEN limits.ai_assistant_calls_month
    WHEN 'bill_scan'            THEN limits.ai_parser_calls_month
    WHEN 'wallet_transaction'   THEN limits.wallet_transactions_month
    ELSE 10  -- safe default for unknown features
  END;

  RETURN check_plan_feature_limit(p_user_id, NULL, p_feature, allowed_limit);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
