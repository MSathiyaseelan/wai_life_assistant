-- ============================================================
-- 164_plan_expiry_notifications.sql
--
-- Schedules a daily pg_cron job that calls the notify-plan-expiry
-- edge function to push FCM alerts to family admins whose PAID plan
-- was cancelled (auto_renew=false) and access lapses in 3 days, 1
-- day, or today. Companion to trial-expiry-notifications (070/117),
-- reading config from cron_config per 117's fix (current_setting()
-- GUCs are rejected by Supabase's hosted Postgres).
--
-- Prerequisites:
--   1. pg_cron / pg_net extensions already enabled (070/109 did this)
--   2. Edge function deployed: supabase functions deploy notify-plan-expiry
--   3. cron_config already has 'supabase_url' and 'cron_secret' rows
--      (seeded by 117_cron_config_table.sql) — nothing new to insert.
-- ============================================================

CREATE OR REPLACE FUNCTION trigger_plan_expiry_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_url    TEXT;
  v_secret TEXT;
BEGIN
  SELECT value INTO v_url    FROM cron_config WHERE key = 'supabase_url';
  SELECT value INTO v_secret FROM cron_config WHERE key = 'cron_secret';

  IF v_url IS NULL OR v_url = '' THEN
    RAISE WARNING '[plan-expiry] supabase_url not configured in cron_config — skipping';
    RETURN;
  END IF;

  PERFORM net.http_post(
    url     := v_url || '/functions/v1/notify-plan-expiry',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'x-cron-secret', COALESCE(v_secret, '')
    ),
    body    := '{"scheduled":true}'::jsonb
  );
END;
$$;

-- ── Schedule: daily at 08:15 UTC (13:45 IST) — offset from
-- trial-expiry-notifications (08:00) so they don't race on the same
-- FCM access-token fetch window. ─────────────────────────────────

SELECT cron.unschedule('plan-expiry-notifications')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'plan-expiry-notifications'
);

SELECT cron.schedule(
  'plan-expiry-notifications',
  '15 8 * * *',
  'SELECT trigger_plan_expiry_notifications()'
);
