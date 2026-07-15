-- ═══════════════════════════════════════════════════════════════════════════
-- 096_effective_feature_limit_for_display.sql
--
-- 095_family_aware_feature_limits.sql made check_feature_limit() honor a
-- family wallet's paid plan when *enforcing* the cap. But the app's UI reads
-- the applicable limit for *display* (and for a client-side pre-emptive
-- block before even calling the server) via get_plan_limits(NULL) directly —
-- which only ever returns the personal_free plan. That left the UI showing
-- "X/30" and self-blocking at 30 even for users whose family plan actually
-- allows more.
--
-- Fix: extract the family-aware "best limit for this feature" resolution
-- into its own reusable, read-only function, and have check_feature_limit
-- call it too (avoids duplicating the logic in two places). The app can now
-- call get_effective_feature_limit(user_id, feature) directly to display the
-- real applicable cap.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION get_effective_feature_limit(
  p_user_id UUID,
  p_feature TEXT
) RETURNS INTEGER AS $$
DECLARE
  personal_limits plan_limits;
  wallet_limits    plan_limits;
  best_limit       INTEGER;
  fam_limit        INTEGER;
  fam_wallet       RECORD;
BEGIN
  personal_limits := get_plan_limits(NULL);

  best_limit := CASE p_feature
    WHEN 'ai_parser'            THEN personal_limits.ai_parser_calls_month
    WHEN 'ai_assistant'         THEN personal_limits.ai_assistant_calls_month
    WHEN 'bill_scan'            THEN personal_limits.ai_parser_calls_month
    WHEN 'wallet_transaction'   THEN personal_limits.wallet_transactions_month
    ELSE 10  -- safe default for unknown features
  END;

  -- -1 already means unlimited on the personal plan; nothing can beat that.
  IF best_limit != -1 THEN
    FOR fam_wallet IN
      SELECT w.id AS wallet_id
        FROM family_members fm
        JOIN wallets w ON w.family_id = fm.family_id
       WHERE fm.user_id = p_user_id
         AND fm.deleted_at IS NULL
    LOOP
      wallet_limits := get_plan_limits(fam_wallet.wallet_id);
      fam_limit := CASE p_feature
        WHEN 'ai_parser'            THEN wallet_limits.ai_parser_calls_month
        WHEN 'ai_assistant'         THEN wallet_limits.ai_assistant_calls_month
        WHEN 'bill_scan'            THEN wallet_limits.ai_parser_calls_month
        WHEN 'wallet_transaction'   THEN wallet_limits.wallet_transactions_month
        ELSE 10
      END;

      IF fam_limit = -1 THEN
        best_limit := -1;
        EXIT;
      ELSIF fam_limit > best_limit THEN
        best_limit := fam_limit;
      END IF;
    END LOOP;
  END IF;

  RETURN best_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;


CREATE OR REPLACE FUNCTION check_feature_limit(
  p_user_id UUID,
  p_feature TEXT
) RETURNS BOOLEAN AS $$
DECLARE
  best_limit INTEGER;
BEGIN
  best_limit := get_effective_feature_limit(p_user_id, p_feature);
  RETURN check_plan_feature_limit(p_user_id, NULL, p_feature, best_limit);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
