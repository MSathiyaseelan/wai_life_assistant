-- ============================================================
-- 070_trial_expiry_notifications.sql
--
-- Schedules a daily pg_cron job that calls the
-- notify-trial-expiry edge function to push FCM alerts
-- to family admins whose trial ends in 3 days, 1 day, or today.
--
-- Prerequisites:
--   1. pg_cron extension enabled (Supabase Dashboard → Database → Extensions)
--   2. pg_net extension enabled (same location)
--   3. Edge function deployed: supabase functions deploy notify-trial-expiry
--   4. Set CRON_SECRET in edge function secrets:
--        supabase secrets set CRON_SECRET=<your-random-secret>
--   5. Run these two commands once in SQL Editor to store config:
--        ALTER DATABASE postgres SET app.supabase_url = 'https://<project>.supabase.co';
--        ALTER DATABASE postgres SET app.cron_secret  = '<same-secret-as-step-4>';
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ── Function called by pg_cron ─────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION trigger_trial_expiry_notifications()
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
    RAISE WARNING '[trial-expiry] app.supabase_url not configured — skipping';
    RETURN;
  END IF;

  PERFORM net.http_post(
    url     := v_url || '/functions/v1/notify-trial-expiry',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'x-cron-secret', COALESCE(v_secret, '')
    ),
    body    := '{"scheduled":true}'::jsonb
  );
END;
$$;

-- ── Schedule: daily at 08:00 UTC (13:30 IST) ──────────────────────────────────

SELECT cron.unschedule('trial-expiry-notifications')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'trial-expiry-notifications'
);

SELECT cron.schedule(
  'trial-expiry-notifications',
  '0 8 * * *',
  'SELECT trigger_trial_expiry_notifications()'
);
