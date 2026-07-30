-- ============================================================
-- 134_notif_prefs_recipient_side.sql
--
-- "Family expense added" (and every other per-event notification toggle
-- except pantry_expiry/planit_special_day/functions_upcoming, which
-- migration 130 already got right) was being checked on the SENDER's own
-- device before broadcasting to everyone else — so turning it off only
-- stopped you from notifying other people, and had zero effect on
-- notifications you receive from THEM. The toggle's own label ("Notify
-- when a family member adds a transaction") makes clear it's meant to be
-- a recipient-side mute, not a sender-side broadcast gate.
--
-- Fixing this requires the filtering to happen server-side, per recipient,
-- inside the send-notification edge function — which needs these
-- previously-local-only (SharedPreferences) prefs mirrored onto `profiles`
-- the same way pantry_expiry/planit_special_day/functions_upcoming already
-- are (migration 130).
-- ============================================================

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS notif_wallet_expense     BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notif_wallet_lend_borrow BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notif_planit_alert_me    BOOLEAN NOT NULL DEFAULT true;
