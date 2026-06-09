-- ============================================================
--  WAI Life Assistant — Medication timing columns
-- ============================================================

ALTER TABLE health_medications
  ADD COLUMN IF NOT EXISTS schedule_times TEXT[]    NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS meal_timing    TEXT;
