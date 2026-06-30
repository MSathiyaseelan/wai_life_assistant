-- ══════════════════════════════════════════════════════════════════════════════
-- 078_reminders_repeat_end_date.sql
--
-- Adds an optional end date to repeating reminders so alerts stop firing after
-- a set date (e.g. "EMI payment monthly for 6 months").
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE reminders
  ADD COLUMN IF NOT EXISTS repeat_end_date DATE NULL;
