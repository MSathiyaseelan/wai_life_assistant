-- ============================================================
--  WAI Life Assistant — Profile: Gender
-- ============================================================

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS gender TEXT;

ALTER TABLE profiles
  ADD CONSTRAINT profiles_gender_check
  CHECK (gender IS NULL OR gender IN ('male', 'female', 'other'));
