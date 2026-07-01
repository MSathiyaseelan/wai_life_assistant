-- ============================================================
-- Functions (MOI Tracker) — related tables
-- Backfilled migration: these tables existed on dev via manual
-- SQL Editor changes but were never captured in migration history.
-- Reconstructed from the live dev schema.
-- ============================================================

CREATE TABLE IF NOT EXISTS function_participants (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  function_id     UUID        REFERENCES functions_my(id) ON DELETE CASCADE,
  user_id         UUID        REFERENCES auth.users(id),
  name            TEXT        NOT NULL,
  place           TEXT,
  relation        TEXT,
  phone           TEXT,
  family_members  JSONB       DEFAULT '[]'::jsonb,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE function_participants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_own" ON function_participants;
CREATE POLICY "user_own" ON function_participants
  FOR ALL USING (auth.uid() = user_id);


CREATE TABLE IF NOT EXISTS function_clothing_families (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  function_id   UUID        REFERENCES functions_my(id) ON DELETE CASCADE,
  user_id       UUID        REFERENCES auth.users(id),
  family_name   TEXT        NOT NULL,
  members       JSONB       DEFAULT '[]'::jsonb,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE function_clothing_families ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_own" ON function_clothing_families;
CREATE POLICY "user_own" ON function_clothing_families
  FOR ALL USING (auth.uid() = user_id);


CREATE TABLE IF NOT EXISTS function_bridal_essentials (
  id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  function_id   UUID          REFERENCES functions_my(id) ON DELETE CASCADE,
  user_id       UUID          REFERENCES auth.users(id),
  category      TEXT,
  item          TEXT          NOT NULL,
  details       TEXT,
  status        TEXT          DEFAULT 'pending',
  vendor        TEXT,
  cost          NUMERIC,
  created_at    TIMESTAMPTZ   DEFAULT NOW()
);

ALTER TABLE function_bridal_essentials ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_own" ON function_bridal_essentials;
CREATE POLICY "user_own" ON function_bridal_essentials
  FOR ALL USING (auth.uid() = user_id);


CREATE TABLE IF NOT EXISTS function_return_gifts (
  id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  function_id    UUID          REFERENCES functions_my(id) ON DELETE CASCADE,
  user_id        UUID          REFERENCES auth.users(id),
  gift_name      TEXT          NOT NULL,
  approx_price   NUMERIC,
  where_to_buy   TEXT,
  quantity       INTEGER       DEFAULT 1,
  vendor         TEXT,
  created_at     TIMESTAMPTZ   DEFAULT NOW()
);

ALTER TABLE function_return_gifts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_own" ON function_return_gifts;
CREATE POLICY "user_own" ON function_return_gifts
  FOR ALL USING (auth.uid() = user_id);
