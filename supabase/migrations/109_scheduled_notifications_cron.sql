-- ============================================================
-- 109_scheduled_notifications_cron.sql
--
-- Schedules a daily pg_cron job that calls the
-- check-scheduled-notifications edge function to push FCM
-- alerts for the two "days before X" event types that can't be
-- triggered by a simple insert: special_day_approaching and
-- pantry.expiry_alert.
--
-- Reuses the same app.supabase_url / app.cron_secret DB settings
-- already configured for trial-expiry-notifications (070) — no
-- new one-time config step needed if that one is already set up.
-- If it isn't, run once in SQL Editor:
--   ALTER DATABASE postgres SET app.supabase_url = 'https://<project>.supabase.co';
--   ALTER DATABASE postgres SET app.cron_secret  = '<same-secret-as-CRON_SECRET-edge-fn-secret>';
--
-- Prerequisite: supabase functions deploy check-scheduled-notifications
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION trigger_scheduled_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_url    TEXT;
  v_secret TEXT;
BEGIN
  v_url    := current_setting('app.supabase_url', true);
  v_secret := current_setting('app.cron_secret',  true);

  IF v_url IS NULL OR v_url = '' THEN
    RAISE WARNING '[scheduled-notif] app.supabase_url not configured — skipping';
    RETURN;
  END IF;

  PERFORM net.http_post(
    url     := v_url || '/functions/v1/check-scheduled-notifications',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'x-cron-secret', COALESCE(v_secret, '')
    ),
    body    := '{"scheduled":true}'::jsonb
  );
END;
$$;

-- ── Schedule: daily at 08:00 UTC (13:30 IST) — same time as trial-expiry ──────

SELECT cron.unschedule('scheduled-notifications-check')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'scheduled-notifications-check'
);

SELECT cron.schedule(
  'scheduled-notifications-check',
  '0 8 * * *',
  'SELECT trigger_scheduled_notifications()'
);
