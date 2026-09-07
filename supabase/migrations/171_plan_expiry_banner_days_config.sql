-- ─────────────────────────────────────────────────────────────────────────────
-- 171_plan_expiry_banner_days_config.sql
-- Makes the dashboard's "your plan is about to expire" renewal banner's
-- lead time (currently hardcoded as 7 days in the client) configurable via
-- app_config, following the same pattern as recycle_bin_retention_days
-- (086) — so it can be tuned with an UPDATE statement, no app deployment
-- required.
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO app_config (key, value, description) VALUES
  ('plan_expiry_banner_days', '7', 'Days before a cancelled family plan''s expiry that the dashboard renewal banner starts showing.')
ON CONFLICT (key) DO NOTHING;
