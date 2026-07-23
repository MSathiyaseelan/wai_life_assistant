-- ============================================================
-- 111_release_feature_usage.sql
--
-- check_feature_limit() atomically increments the monthly usage
-- counter before the caller's actual insert runs. If that insert then
-- fails for an unrelated reason (network blip, transient RLS/validation
-- error), the quota slot was already consumed even though nothing was
-- saved — the user's monthly count silently drifts from their real usage.
--
-- Adds release_feature_usage(p_user_id, p_feature): resolves the same
-- scope check_feature_limit used (resolve_feature_scope, from 100) and
-- decrements that row by 1 for the current month, floored at 0. Callers
-- should invoke this in the catch-block of any insert that was gated by
-- check_feature_limit, so a failed save doesn't cost the user a slot.
-- ============================================================

CREATE OR REPLACE FUNCTION public.release_feature_usage(p_user_id uuid, p_feature text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  scope         RECORD;
  current_month TEXT := TO_CHAR(NOW(), 'YYYY-MM');
BEGIN
  SELECT * INTO scope FROM resolve_feature_scope(p_user_id, p_feature);

  IF scope.best_wallet_id IS NOT NULL THEN
    UPDATE feature_usage
       SET count = GREATEST(count - 1, 0)
     WHERE wallet_id = scope.best_wallet_id
       AND feature   = p_feature
       AND month     = current_month;
  ELSE
    UPDATE feature_usage
       SET count = GREATEST(count - 1, 0)
     WHERE user_id   = p_user_id
       AND wallet_id IS NULL
       AND feature   = p_feature
       AND month     = current_month;
  END IF;
END;
$function$;
