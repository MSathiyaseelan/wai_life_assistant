-- ═══════════════════════════════════════════════════════════════════════════
-- 095_family_aware_feature_limits.sql
--
-- check_feature_limit(p_user_id, p_feature) previously always resolved the
-- applicable plan limit via get_plan_limits(NULL) — i.e. always the
-- personal_free plan — even when the calling user is a member of a family
-- whose wallet has a paid Family Plus/Pro subscription with a higher (or
-- unlimited) allowance for that feature. As a result, family members never
-- actually benefited from their family's plan for ai_parser/ai_assistant/etc.
--
-- Fix: when checking a user's limit, also look at every family wallet they
-- belong to and use the best (highest, or -1/unlimited) limit available to
-- them across their personal plan and any family wallet's plan. Usage is
-- still tracked per-user (feature_usage keyed by user_id, wallet_id NULL) —
-- this does NOT pool usage across family members, it only raises the cap
-- when someone is part of a paid family group.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION check_feature_limit(
  p_user_id UUID,
  p_feature TEXT
) RETURNS BOOLEAN AS $$
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

  RETURN check_plan_feature_limit(p_user_id, NULL, p_feature, best_limit);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
