-- Migration 158: Admin/QA bypass accounts.
--
-- admin_users is a plain record-keeping table (no in-app UI — add/remove
-- rows directly via the Supabase dashboard Table Editor). Adding a user here
-- grants them the top-tier ('family_pro') subscription through the SAME
-- mechanism real paid subscriptions use, rather than a parallel bypass path:
--   - profiles.plan is set to 'family_pro' (covers the handful of client-side
--     reads that check this column directly, e.g. fetchMaxFamilyMembers).
--   - Their personal wallet gets an active, non-expiring wallet_subscriptions
--     row on the family_pro plan (covers check_feature_limit /
--     resolve_feature_scope / get_plan_limits, which everything else — AI
--     parsing, wallet transactions, split groups, saved recipes, etc. —
--     resolves through).
-- Removing a row reverts both back to personal_free.
--
-- Caveat: if a user already had a real paid wallet_subscriptions row before
-- being added here, removing them from admin_users resets them to
-- personal_free rather than restoring their prior paid plan — admin_users is
-- meant for staff/QA accounts, not for temporarily comping real subscribers.

CREATE TABLE IF NOT EXISTS admin_users (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  added_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  note       TEXT
);

ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
-- No policies added — locked down by default (service_role / SQL editor
-- only). There's deliberately no client-facing read/write access.

CREATE OR REPLACE FUNCTION grant_admin_top_tier()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_plan_id UUID;
  v_wallet_id UUID;
BEGIN
  SELECT id INTO v_plan_id FROM subscription_plans WHERE plan_key = 'family_pro';
  IF v_plan_id IS NULL THEN
    RAISE EXCEPTION 'family_pro plan not found in subscription_plans';
  END IF;

  UPDATE profiles SET plan = 'family_pro' WHERE id = NEW.user_id;

  SELECT id INTO v_wallet_id FROM wallets
   WHERE owner_id = NEW.user_id AND is_personal = TRUE
   LIMIT 1;

  IF v_wallet_id IS NOT NULL THEN
    INSERT INTO wallet_subscriptions (wallet_id, plan_id, status, expires_at, payment_reference)
    VALUES (v_wallet_id, v_plan_id, 'active', NULL, 'admin_grant')
    ON CONFLICT (wallet_id) DO UPDATE
      SET plan_id = EXCLUDED.plan_id,
          status = 'active',
          expires_at = NULL,
          payment_reference = 'admin_grant',
          updated_at = NOW();
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION revoke_admin_top_tier()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet_id UUID;
BEGIN
  UPDATE profiles SET plan = 'personal_free' WHERE id = OLD.user_id;

  SELECT id INTO v_wallet_id FROM wallets
   WHERE owner_id = OLD.user_id AND is_personal = TRUE
   LIMIT 1;

  IF v_wallet_id IS NOT NULL THEN
    DELETE FROM wallet_subscriptions
     WHERE wallet_id = v_wallet_id AND payment_reference = 'admin_grant';
  END IF;

  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_grant_admin_top_tier ON admin_users;
CREATE TRIGGER trg_grant_admin_top_tier
  AFTER INSERT ON admin_users
  FOR EACH ROW EXECUTE FUNCTION grant_admin_top_tier();

DROP TRIGGER IF EXISTS trg_revoke_admin_top_tier ON admin_users;
CREATE TRIGGER trg_revoke_admin_top_tier
  AFTER DELETE ON admin_users
  FOR EACH ROW EXECUTE FUNCTION revoke_admin_top_tier();
