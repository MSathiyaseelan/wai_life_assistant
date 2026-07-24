-- ============================================================
-- 115_deactivate_expired_medications.sql
--
-- HealthService.fetchMedications used to run an UPDATE (deactivate any
-- medication past its end_date) as a side effect of every read — meaning
-- just opening Health Space silently mutated data, cost an extra round
-- trip on every load, and (after 114_myhub_family_sharing.sql gated
-- health_medications UPDATE by perm_edit) would only fire for members
-- with edit rights, so a view-only family member's read wouldn't
-- deactivate anything either.
--
-- Moves this to a daily pg_cron job instead — same pattern already used
-- for trial-expiry (070) and scheduled notifications (109). Runs with
-- elevated (SECURITY DEFINER) privilege, independent of RLS/who's
-- looking at the screen, so it always keeps is_active in sync with
-- end_date exactly once a day, and fetchMedications is now a pure read.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE OR REPLACE FUNCTION public.deactivate_expired_medications()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $function$
  UPDATE health_medications
     SET is_active = FALSE
   WHERE is_active = TRUE
     AND end_date IS NOT NULL
     AND end_date < CURRENT_DATE;
$function$;

SELECT cron.unschedule('deactivate-expired-medications')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'deactivate-expired-medications'
);

SELECT cron.schedule(
  'deactivate-expired-medications',
  '0 0 * * *',
  'SELECT deactivate_expired_medications()'
);
