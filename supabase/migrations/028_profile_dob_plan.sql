-- ============================================================
--  WAI Life Assistant — Profile: DOB, Plan & Photo URL
-- ============================================================

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS dob       DATE,
  ADD COLUMN IF NOT EXISTS plan      TEXT NOT NULL DEFAULT 'Free',
  ADD COLUMN IF NOT EXISTS photo_url TEXT;
