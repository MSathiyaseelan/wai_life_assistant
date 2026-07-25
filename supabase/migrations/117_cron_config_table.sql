-- ============================================================
-- 117_cron_config_table.sql
--
-- 070_trial_expiry_notifications.sql and 109_scheduled_notifications_cron.sql
-- both read app.supabase_url / app.cron_secret via current_setting(), which
-- requires `ALTER DATABASE postgres SET ...` (or `ALTER ROLE ... SET ...`)
-- to populate. Supabase's hosted Postgres now denies both — even from the
-- Dashboard SQL Editor ("permission denied to set parameter") — so those
-- two cron trigger functions have been silently no-op'ing on every run
-- since neither setting was ever (or could ever be) populated this way.
--
-- Fix: a dedicated cron_config table instead of a database-level GUC.
-- RLS is enabled with NO policies — this blocks all access via the
-- PostgREST API (anon/authenticated roles), while the table owner (the
-- role migrations run as) and any SECURITY DEFINER function it owns
-- still bypass RLS by default, per standard Postgres behavior for table
-- owners. So this is readable only from inside these trigger functions,
-- never queryable by a client.
--
-- app.supabase_url wasn't a secret (it's the project's public URL) — safe
-- to seed here directly. cron_secret IS a secret and is NOT seeded by
-- this migration; it must be inserted once via a direct `supabase db
-- query` call (not committed to a migration file, matching how edge
-- function secrets are never committed either):
--   INSERT INTO cron_config (key, value) VALUES ('cron_secret', '<value>')
--   ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
-- (Use the exact same value as the CRON_SECRET edge function secret.)
-- ============================================================

CREATE TABLE IF NOT EXISTS cron_config (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

ALTER TABLE cron_config ENABLE ROW LEVEL SECURITY;
-- Deliberately no policies — see header note.

INSERT INTO cron_config (key, value)
VALUES ('supabase_url', 'https://oeclczbamrnouuzooitx.supabase.co')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- ── Redefine both trigger functions to read from cron_config ─────────────

CREATE OR REPLACE FUNCTION trigger_trial_expiry_notifications()
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
    RAISE WARNING '[trial-expiry] supabase_url not configured in cron_config — skipping';
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

CREATE OR REPLACE FUNCTION trigger_scheduled_notifications()
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
    RAISE WARNING '[scheduled-notif] supabase_url not configured in cron_config — skipping';
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
