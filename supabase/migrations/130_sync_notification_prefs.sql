-- ============================================================
-- 130_sync_notification_prefs.sql
--
-- NotificationPrefs (Settings > Notifications) was entirely local-only
-- (SharedPreferences) — the server-side scheduled-notification cron
-- (check-scheduled-notifications) sends pantry expiry alerts and special
-- day reminders using a fixed default, with no way to know a given user
-- turned that category off or customized the day count, since nothing
-- was ever synced to the database. Same gap existed for a
-- "functions upcoming, N days before" reminder, which never existed at
-- all server-side (only an immediate "someone added this" notify did).
--
-- Adding per-user columns so the cron can look these up individually
-- per family member, not just apply one blanket setting to everyone.
-- ============================================================

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS notif_master BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notif_pantry_expiry BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notif_pantry_expiry_days INTEGER NOT NULL DEFAULT 2,
  ADD COLUMN IF NOT EXISTS notif_planit_special_day BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notif_functions_upcoming BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notif_functions_upcoming_days INTEGER NOT NULL DEFAULT 7;
