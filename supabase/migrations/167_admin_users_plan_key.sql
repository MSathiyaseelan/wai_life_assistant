-- ============================================================
-- 167_admin_users_plan_key.sql
--
-- 158_admin_users.sql hardcoded every admin_users grant to 'family_pro'
-- ("top tier") — there was no way to comp a staff/QA account onto
-- family_plus specifically (e.g. to test Plus-tier limits without
-- Pro's near-unlimited usage masking them). This adds a plan_key column
-- (defaulting to 'family_pro' so existing rows/behavior are unchanged)
-- and makes both trigger functions grant/revoke whichever plan the row
-- specifies instead of the hardcoded tier.
--
-- Usage (still no in-app UI — Supabase dashboard Table Editor or SQL
-- editor only, same as before):
--   INSERT INTO admin_users (user_id, plan_key, note)
--   VALUES ('<uuid>', 'family_plus', 'QA — Plus tier testing');
-- ============================================================

ALTER TABLE admin_users
  ADD COLUMN IF NOT EXISTS plan_key TEXT NOT NULL DEFAULT 'family_pro'
    CHECK (plan_key IN ('family_plus', 'family_pro'));

CREATE OR REPLACE FUNCTION grant_admin_top_tier()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_plan_id UUID;
  v_wallet_id UUID;
BEGIN
  SELECT id INTO v_plan_id FROM subscription_plans WHERE plan_key = NEW.plan_key;
  IF v_plan_id IS NULL THEN
    RAISE EXCEPTION '% plan not found in subscription_plans', NEW.plan_key;
  END IF;

  UPDATE profiles SET plan = NEW.plan_key WHERE id = NEW.user_id;

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

-- Also re-grant on UPDATE (e.g. changing an existing row's plan_key from
-- family_pro to family_plus) — 158 only handled INSERT/DELETE, so editing
-- plan_key in place previously had no effect until a delete+re-insert.
DROP TRIGGER IF EXISTS trg_regrant_admin_plan_change ON admin_users;
CREATE TRIGGER trg_regrant_admin_plan_change
  AFTER UPDATE OF plan_key ON admin_users
  FOR EACH ROW
  WHEN (NEW.plan_key IS DISTINCT FROM OLD.plan_key)
  EXECUTE FUNCTION grant_admin_top_tier();
