-- ─────────────────────────────────────────────────────────────────────────────
-- 174_expiry_notify_days_config.sql
-- Moves the notify-plan-expiry and notify-trial-expiry edge functions'
-- hardcoded `[0, 1, 3]` days-ahead push notification schedule into
-- app_config, mirroring the client's plan_expiry_banner_days pattern
-- (171) — so the schedule can be tuned (e.g. add a 7-day heads-up tier)
-- without redeploying either function.
--
-- Two separate keys, not one shared key: plan-cancellation reminders and
-- trial-ending reminders are different lifecycle events that happen to
-- share the same [0,1,3] schedule today by coincidence, not by design —
-- a shared key would silently couple them if either is ever tuned
-- independently.
--
-- Value is a comma-separated list of non-negative integers (days ahead of
-- expiry/trial-end); each function's fetchNotifyDays() falls back to
-- "0,1,3" if the row is missing, empty, or unparseable.
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO app_config (key, value, description) VALUES
  ('plan_expiry_notify_days', '0,1,3', 'Comma-separated days-ahead schedule for notify-plan-expiry push reminders (cancelled paid plans).'),
  ('trial_expiry_notify_days', '0,1,3', 'Comma-separated days-ahead schedule for notify-trial-expiry push reminders.')
ON CONFLICT (key) DO NOTHING;
