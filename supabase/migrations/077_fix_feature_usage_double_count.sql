-- ══════════════════════════════════════════════════════════════════════════════
-- 077_fix_feature_usage_double_count.sql
--
-- Bug: check_plan_feature_limit used INSERT count=1 followed by UPDATE count+1,
-- which counted the very first call of each month as 2 uses instead of 1.
-- Result: a user with limit=20 could only make 19 real calls before hitting the
-- cap (first call = 2, then 18 × 1 = 20 total).
--
-- Fix: INSERT with count=0 so the subsequent UPDATE increments it to 1 correctly.
-- ══════════════════════════════════════════════════════════════════════════════

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
    VALUES (p_user_id, p_wallet_id, p_feature, current_month, 0)
    ON CONFLICT DO NOTHING;

    UPDATE feature_usage
       SET count = count + 1
     WHERE wallet_id = p_wallet_id
       AND feature   = p_feature
       AND month     = current_month
    RETURNING count INTO current_count;
  ELSE
    -- Personal usage (per user)
    INSERT INTO feature_usage (user_id, feature, month, count)
    VALUES (p_user_id, p_feature, current_month, 0)
    ON CONFLICT DO NOTHING;

    UPDATE feature_usage
       SET count = count + 1
     WHERE user_id   = p_user_id
       AND wallet_id IS NULL
       AND feature   = p_feature
       AND month     = current_month
    RETURNING count INTO current_count;
  END IF;

  RETURN current_count <= p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
