-- Migration 192: resolve_feature_scope() must also check the user's own
-- personal wallet for an active subscription, not just family wallets.
--
-- 100_shared_family_ai_usage_pool.sql computed personal_limits via
-- get_plan_limits(NULL), which always returns the hardcoded personal_free
-- defaults and ignores any wallet_subscriptions row — even one attached to
-- the user's own personal wallet. The family-wallet loop right after it only
-- looks at wallets under family_members, so a subscription living on the
-- personal wallet was invisible to resolve_feature_scope() entirely.
--
-- This is a real path: 158_admin_users.sql / 167_admin_users_plan_key.sql's
-- staff/QA comp mechanism explicitly grants onto the user's personal wallet
-- (wallets.owner_id = user_id AND is_personal = TRUE) and its own comments
-- say this should flow through resolve_feature_scope() — which migration
-- 100 silently broke. The same gap would affect any real subscription that
-- ever ends up on a personal wallet.
--
-- Fix: resolve the user's personal wallet id and, if it has its own active
-- subscription (checked the same way get_plan_limits does internally),
-- treat it as a scope candidate exactly like a family wallet already is —
-- rather than assuming personal always means the free-tier default.

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
  personal_wallet_id uuid;
  personal_has_sub    boolean;
  personal_limits plan_limits;
  wallet_limits    plan_limits;
  fam_limit        INTEGER;
  fam_wallet       RECORD;
BEGIN
  best_wallet_id := NULL;

  SELECT id INTO personal_wallet_id FROM wallets
   WHERE owner_id = p_user_id AND is_personal = TRUE
   LIMIT 1;

  SELECT EXISTS (
    SELECT 1 FROM wallet_subscriptions ws
     WHERE ws.wallet_id = personal_wallet_id
       AND ws.status IN ('active', 'trial')
       AND (ws.expires_at IS NULL OR ws.expires_at > NOW())
  ) INTO personal_has_sub;

  personal_limits := get_plan_limits(CASE WHEN personal_has_sub THEN personal_wallet_id ELSE NULL END);
  IF personal_has_sub THEN
    best_wallet_id := personal_wallet_id;
  END IF;

  best_limit := CASE p_feature
    WHEN 'ai_parser'            THEN personal_limits.ai_parser_calls_month
    WHEN 'ai_assistant'         THEN personal_limits.ai_assistant_calls_month
    WHEN 'bill_scan'            THEN personal_limits.ai_parser_calls_month
    WHEN 'wallet_transaction'   THEN personal_limits.wallet_transactions_month
    ELSE 10
  END;

  -- -1 already means unlimited; nothing can beat that.
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
