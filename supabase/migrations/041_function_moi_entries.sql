-- ============================================================
--  WAI Life Assistant — Moi Entries
--  Tracks monetary gifts (moi) received at functions
-- ============================================================

CREATE TABLE IF NOT EXISTS function_moi_entries (
  id                    UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID           NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  function_id           TEXT           NOT NULL,
  wallet_id             TEXT           NOT NULL,
  person_name           TEXT           NOT NULL,
  family_name           TEXT,
  place                 TEXT,
  phone                 TEXT,
  relation              TEXT,
  amount                DECIMAL(12, 2) NOT NULL,
  kind                  TEXT           NOT NULL DEFAULT 'newMoi',
  notes                 TEXT,
  returned              BOOLEAN        NOT NULL DEFAULT FALSE,
  returned_amount       DECIMAL(12, 2),
  returned_on           DATE,
  returned_for_function TEXT,
  created_at            TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

ALTER TABLE function_moi_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "function_moi_entries_own" ON function_moi_entries
  FOR ALL USING (auth.uid() = user_id);

-- ── Icon column on functions_my (if not already added) ───────
ALTER TABLE functions_my
  ADD COLUMN IF NOT EXISTS icon TEXT NOT NULL DEFAULT '🎊';
