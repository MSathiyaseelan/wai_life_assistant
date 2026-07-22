-- Migration 102: Add 'custom_category' to the shared feature-limit resolver.
--
-- plan_limits.wallet_custom_categories_max has existed since 054_subscription_
-- system.sql (default 10 on personal_free) but was never wired into
-- resolve_feature_scope, so get_effective_feature_limit(user_id,
-- 'custom_category') would just fall through to the generic ELSE 10 default
-- instead of actually resolving the plan's real value (or a family plan's
-- higher cap). Client-side enforcement (WalletService.ensureCategory) reads
-- this via get_effective_feature_limit directly — custom categories are
-- stored per-user (user_tx_categories has no wallet_id column), so unlike
-- wallet_transaction/split_group this is a standing count check, not a
-- monthly feature_usage counter, and doesn't need check_feature_limit at all.

CREATE OR REPLACE FUNCTION public.resolve_feature_scope(
  p_user_id uuid,
  p_feature text,
  OUT best_limit integer,
  OUT best_wallet_id uuid
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
AS $function$
DECLARE
  personal_limits plan_limits;
  wallet_limits    plan_limits;
  fam_limit        INTEGER;
  fam_wallet       RECORD;
BEGIN
  best_wallet_id := NULL;
  personal_limits := get_plan_limits(NULL);

  best_limit := CASE p_feature
    WHEN 'ai_parser'            THEN personal_limits.ai_parser_calls_month
    WHEN 'ai_assistant'         THEN personal_limits.ai_assistant_calls_month
    WHEN 'bill_scan'            THEN personal_limits.ai_parser_calls_month
    WHEN 'wallet_transaction'   THEN personal_limits.wallet_transactions_month
    WHEN 'split_group'          THEN personal_limits.wallet_split_groups_month
    WHEN 'custom_category'      THEN personal_limits.wallet_custom_categories_max
    ELSE 10
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
        WHEN 'split_group'          THEN wallet_limits.wallet_split_groups_month
        WHEN 'custom_category'      THEN wallet_limits.wallet_custom_categories_max
        ELSE 10
      END;

      IF fam_limit = -1 THEN
        best_limit := -1;
        best_wallet_id := fam_wallet.wallet_id;
        EXIT;
      ELSIF fam_limit > best_limit THEN
        best_limit := fam_limit;
        best_wallet_id := fam_wallet.wallet_id;
      END IF;
    END LOOP;
  END IF;
END;
$function$;
