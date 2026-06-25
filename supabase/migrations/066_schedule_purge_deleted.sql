-- ============================================================
--  Schedule daily purge of soft-deleted records older than 30 days.
--  Requires pg_cron extension (enabled via Supabase Dashboard →
--  Database → Extensions → pg_cron).
-- ============================================================

-- Enable pg_cron if not already active.
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Remove any existing schedule with the same name before re-creating.
SELECT cron.unschedule('purge-deleted-records')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'purge-deleted-records'
);

-- Run purge_old_deleted_records() every day at 02:00 UTC.
SELECT cron.schedule(
  'purge-deleted-records',
  '0 2 * * *',
  'SELECT purge_old_deleted_records()'
);
