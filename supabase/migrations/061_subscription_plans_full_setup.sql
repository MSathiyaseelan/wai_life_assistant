-- ================================================================
-- WAI — Subscription Plans Full Setup (idempotent)
-- Combines migration 054 (tables + seed) + 060 (profile plan keys)
-- Safe to run even if some parts already exist.
-- ================================================================


-- ── 1. subscription_plans ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS subscription_plans (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_key      TEXT        NOT NULL UNIQUE,
  name          TEXT        NOT NULL,
  description   TEXT,
  price_monthly NUMERIC(10,2) NOT NULL DEFAULT 0,
  price_yearly  NUMERIC(10,2) NOT NULL DEFAULT 0,
  target_type   TEXT        NOT NULL DEFAULT 'personal',
  is_active     BOOLEAN     NOT NULL DEFAULT true,
  sort_order    INTEGER     DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'subscription_plans'
      AND policyname = 'Authenticated users can read plans'
  ) THEN
    CREATE POLICY "Authenticated users can read plans"
      ON subscription_plans FOR SELECT
      USING (auth.uid() IS NOT NULL);
  END IF;
END $$;


-- ── 2. plan_limits ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS plan_limits (
  id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id     UUID    NOT NULL UNIQUE REFERENCES subscription_plans(id) ON DELETE CASCADE,

  -- Family
  family_max_members               INTEGER NOT NULL DEFAULT 0,

  -- AI
  ai_parser_calls_month            INTEGER NOT NULL DEFAULT 30,
  ai_assistant_calls_month         INTEGER NOT NULL DEFAULT 20,

  -- Wallet
  wallet_transactions_month        INTEGER NOT NULL DEFAULT 100,
  wallet_split_groups_month        INTEGER NOT NULL DEFAULT 3,
  wallet_bill_watch_max            INTEGER NOT NULL DEFAULT 5,
  wallet_custom_categories_max     INTEGER NOT NULL DEFAULT 10,

  -- Pantry
  pantry_meal_weeks_ahead          INTEGER NOT NULL DEFAULT 1,
  pantry_recipes_max               INTEGER NOT NULL DEFAULT 10,
  pantry_grocery_lists_max         INTEGER NOT NULL DEFAULT 2,

  -- Functions
  functions_upcoming_max           INTEGER NOT NULL DEFAULT 15,
  functions_attended_max           INTEGER NOT NULL DEFAULT 30,
  functions_my_max                 INTEGER NOT NULL DEFAULT 5,

  -- Item Locator
  item_locator_containers_max      INTEGER NOT NULL DEFAULT 5,
  item_locator_items_max           INTEGER NOT NULL DEFAULT 50,

  -- Wardrobe
  wardrobe_items_max               INTEGER NOT NULL DEFAULT 30,
  wardrobe_outfit_log_months       INTEGER NOT NULL DEFAULT 1,
  wardrobe_wishlist_max            INTEGER NOT NULL DEFAULT 10,
  wardrobe_photo_storage_mb        INTEGER NOT NULL DEFAULT 50,

  -- Health
  health_medications_max           INTEGER NOT NULL DEFAULT 15,
  health_appointments_max          INTEGER NOT NULL DEFAULT 20,
  health_vital_logs_month          INTEGER NOT NULL DEFAULT 60,
  health_vaccines_max              INTEGER NOT NULL DEFAULT 20,
  health_doctors_max               INTEGER NOT NULL DEFAULT 10,
  health_insurance_max             INTEGER NOT NULL DEFAULT 5,

  -- PlanIt
  planit_tasks_max                 INTEGER NOT NULL DEFAULT 50,
  planit_reminders_max             INTEGER NOT NULL DEFAULT 30,
  planit_notes_max                 INTEGER NOT NULL DEFAULT 20,
  planit_special_days_max          INTEGER NOT NULL DEFAULT 30,
  planit_wishlist_max              INTEGER NOT NULL DEFAULT 25,

  -- Notifications
  notif_push_enabled               BOOLEAN NOT NULL DEFAULT false,
  notif_wallet                     BOOLEAN NOT NULL DEFAULT true,
  notif_pantry                     BOOLEAN NOT NULL DEFAULT true,
  notif_myhub                      BOOLEAN NOT NULL DEFAULT true,
  notif_planit                     BOOLEAN NOT NULL DEFAULT true,
  notif_health                     BOOLEAN NOT NULL DEFAULT true,
  notif_custom_alerts              BOOLEAN NOT NULL DEFAULT false
);

ALTER TABLE plan_limits ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_limits'
      AND policyname = 'Authenticated users can read plan limits'
  ) THEN
    CREATE POLICY "Authenticated users can read plan limits"
      ON plan_limits FOR SELECT
      USING (auth.uid() IS NOT NULL);
  END IF;
END $$;


-- ── 3. wallet_subscriptions ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS wallet_subscriptions (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id            UUID        NOT NULL UNIQUE,
  plan_id              UUID        NOT NULL REFERENCES subscription_plans(id),
  status               TEXT        NOT NULL DEFAULT 'active',
  family_member_limit  INTEGER,
  started_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at           TIMESTAMPTZ,
  trial_ends_at        TIMESTAMPTZ,
  auto_renew           BOOLEAN     NOT NULL DEFAULT true,
  payment_reference    TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE wallet_subscriptions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'wallet_subscriptions'
      AND policyname = 'Family members can read their wallet subscription'
  ) THEN
    CREATE POLICY "Family members can read their wallet subscription"
      ON wallet_subscriptions FOR SELECT
      USING (
        auth.uid() IS NOT NULL AND
        wallet_id IN (
          SELECT wallet_id FROM family_members WHERE user_id = auth.uid()
        )
      );
  END IF;
END $$;


-- ── 4. Seed subscription_plans ───────────────────────────────────────────────

INSERT INTO subscription_plans (plan_key, name, description, price_monthly, price_yearly, target_type, sort_order)
VALUES
  ('personal_free', 'Personal Free',
   'Full personal account at no cost.',
   0, 0, 'personal', 1),

  ('family_plus', 'Family Plus',
   'Family plan for up to 6 members. Shared pantry, wallet and hub with generous limits.',
   0, 0, 'family', 2),

  ('family_pro', 'Family Pro',
   'Premium family plan for up to 15 members. Near-unlimited usage across all features.',
   0, 0, 'family', 3)
ON CONFLICT (plan_key) DO NOTHING;


-- ── 5. Seed plan_limits ──────────────────────────────────────────────────────

INSERT INTO plan_limits (
  plan_id,
  family_max_members,
  ai_parser_calls_month, ai_assistant_calls_month,
  wallet_transactions_month, wallet_split_groups_month,
  wallet_bill_watch_max, wallet_custom_categories_max,
  pantry_meal_weeks_ahead, pantry_recipes_max, pantry_grocery_lists_max,
  functions_upcoming_max, functions_attended_max, functions_my_max,
  item_locator_containers_max, item_locator_items_max,
  wardrobe_items_max, wardrobe_outfit_log_months,
  wardrobe_wishlist_max, wardrobe_photo_storage_mb,
  health_medications_max, health_appointments_max, health_vital_logs_month,
  health_vaccines_max, health_doctors_max, health_insurance_max,
  planit_tasks_max, planit_reminders_max, planit_notes_max,
  planit_special_days_max, planit_wishlist_max,
  notif_push_enabled, notif_wallet, notif_pantry,
  notif_myhub, notif_planit, notif_health, notif_custom_alerts
)
SELECT
  sp.id,
  -- family_max_members
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
  true, true, true, true, true,  -- notif_wallet/pantry/myhub/planit/health — on for all
  CASE sp.plan_key WHEN 'personal_free' THEN false WHEN 'family_plus' THEN false WHEN 'family_pro' THEN true  END
FROM subscription_plans sp
WHERE NOT EXISTS (
  SELECT 1 FROM plan_limits pl WHERE pl.plan_id = sp.id
);


-- ── 6. Align profiles.plan with plan_key values ──────────────────────────────
-- (from migration 060)

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS plan TEXT NOT NULL DEFAULT 'personal_free';

UPDATE profiles SET plan = 'personal_free' WHERE plan = 'Free';
UPDATE profiles SET plan = 'family_plus'   WHERE plan = 'Plus';
UPDATE profiles SET plan = 'family_pro'    WHERE plan = 'Family';

ALTER TABLE profiles ALTER COLUMN plan SET DEFAULT 'personal_free';


-- ── 7. get_plan_limits helper ─────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_plan_limits(p_wallet_id UUID DEFAULT NULL)
RETURNS plan_limits AS $$
DECLARE
  result plan_limits;
BEGIN
  IF p_wallet_id IS NOT NULL THEN
    SELECT pl.*
      INTO result
      FROM plan_limits pl
      JOIN wallet_subscriptions ws ON ws.plan_id = pl.plan_id
     WHERE ws.wallet_id = p_wallet_id
       AND ws.status IN ('active', 'trial')
       AND (ws.expires_at IS NULL OR ws.expires_at > NOW());
    IF FOUND THEN RETURN result; END IF;
  END IF;

  SELECT pl.*
    INTO result
    FROM plan_limits pl
    JOIN subscription_plans sp ON sp.id = pl.plan_id
   WHERE sp.plan_key = 'personal_free';

  RETURN result;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
