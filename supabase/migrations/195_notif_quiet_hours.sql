-- ============================================================
-- 195_notif_quiet_hours.sql
--
-- Quiet hours (Settings → Notifications) lived only in the device's local
-- NotificationPrefs, so it could only be applied in the app's foreground
-- FCM handler — pushes arriving while the app was closed/backgrounded are
-- shown by the OS directly and ignored it. Sync it to the profile (like the
-- other notif_* prefs, 130/134) so send-notification and
-- check-scheduled-notifications can deliver those pushes silently instead.
--
-- notif_timezone is the device's IANA zone (e.g. 'Asia/Kolkata'): quiet
-- hours are local wall-clock hours, and the server runs in UTC.
-- ============================================================

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS notif_quiet_enabled BOOLEAN  NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS notif_quiet_start   SMALLINT NOT NULL DEFAULT 22
    CHECK (notif_quiet_start BETWEEN 0 AND 23),
  ADD COLUMN IF NOT EXISTS notif_quiet_end     SMALLINT NOT NULL DEFAULT 7
    CHECK (notif_quiet_end BETWEEN 0 AND 23),
  ADD COLUMN IF NOT EXISTS notif_timezone      TEXT;
