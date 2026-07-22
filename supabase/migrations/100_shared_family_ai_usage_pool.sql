-- Migration 100: Share AI usage quota across family members instead of
-- tracking it per individual user.
--
-- feature_usage already had full support for wallet-scoped (shared) usage
-- tracking — check_plan_feature_limit(p_user_id, p_wallet_id, ...) increments
-- a row keyed by (wallet_id, feature, month) when p_wallet_id is given, via
-- the feature_usage_wallet_unique partial index (wallet_id, feature, month).
-- It just never actually got a wallet_id passed to it: the only caller,
-- check_feature_limit(p_user_id, p_feature), always called it with NULL,
-- so every user — even family-plan members — was tracked individually via
-- feature_usage_personal_unique (user_id, feature, month).
--
-- This wires it up: when a user belongs to a family whose plan grants a
-- better (or unlimited) quota than their personal plan, usage is now tracked
-- against that family's wallet (shared across every member) instead of the
-- user's own row. Personal-plan-only users are unaffected — still their own
-- 30/20 monthly quota, unshared.

-- Shared resolution logic (which wallet, if any, the user's usage should be
-- pooled against, and what the resulting limit is) — used by both the
-- enforcement check and the usage-for-display lookup below, so they can
-- never disagree with each other.
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

-- Re-point the existing display-only limit lookup at the shared resolver
-- (behaviour unchanged — same values as before, just no duplicated logic).
CREATE OR REPLACE FUNCTION public.get_effective_feature_limit(p_user_id uuid, p_feature text)
RETURNS integer
LANGUAGE plpgsql
STABLE SECURITY DEFINER
AS $function$
DECLARE
  scope RECORD;
BEGIN
  SELECT * INTO scope FROM resolve_feature_scope(p_user_id, p_feature);
  RETURN scope.best_limit;
END;
$function$;

-- The actual enforcement + increment call, now scoped to the shared family
-- wallet when one applies — this is the only behavioural change.
CREATE OR REPLACE FUNCTION public.check_feature_limit(p_user_id uuid, p_feature text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  scope RECORD;
BEGIN
  SELECT * INTO scope FROM resolve_feature_scope(p_user_id, p_feature);
  RETURN check_plan_feature_limit(p_user_id, scope.best_wallet_id, p_feature, scope.best_limit);
END;
$function$;

-- New: read-only "used / quota" lookup for the client's usage counters
-- (Wallet chat bar, Scan Bill sheets, Dashboard WAI Assistant, etc.) — reads
-- from whichever scope (shared family wallet or personal) resolve_feature_scope
-- picks, so the displayed count always matches what check_feature_limit will
-- actually enforce. Previously the client read feature_usage keyed only by
-- user_id, which showed 0/stale for family members whose usage was — as of
-- this migration — tracked against the shared wallet row instead.
CREATE OR REPLACE FUNCTION public.get_effective_feature_usage(p_user_id uuid, p_feature text)
RETURNS json
LANGUAGE plpgsql
STABLE SECURITY DEFINER
AS $function$
DECLARE
  scope         RECORD;
  current_month TEXT := TO_CHAR(NOW(), 'YYYY-MM');
  current_count INTEGER;
BEGIN
  SELECT * INTO scope FROM resolve_feature_scope(p_user_id, p_feature);

  IF scope.best_wallet_id IS NOT NULL THEN
    SELECT count INTO current_count FROM feature_usage
     WHERE wallet_id = scope.best_wallet_id AND feature = p_feature AND month = current_month;
  ELSE
    SELECT count INTO current_count FROM feature_usage
     WHERE user_id = p_user_id AND wallet_id IS NULL AND feature = p_feature AND month = current_month;
  END IF;

  RETURN json_build_object('used', COALESCE(current_count, 0), 'quota', scope.best_limit);
END;
$function$;
