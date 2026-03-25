-- ============================================================
--  WAI Life Assistant — Functions Module Schema
--  Tables: functions_my, functions_upcoming, functions_attended
-- ============================================================

-- ── Our Functions ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS functions_my (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id     TEXT        NOT NULL,
  user_id       UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type          TEXT        NOT NULL DEFAULT 'other',
  title         TEXT        NOT NULL,
  who_function  TEXT        NOT NULL DEFAULT '',
  custom_type   TEXT,
  function_date DATE,
  venue         TEXT,
  address       TEXT,
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE functions_my ENABLE ROW LEVEL SECURITY;

CREATE POLICY "functions_my_user_policy" ON functions_my
  FOR ALL USING (user_id = auth.uid());

CREATE TRIGGER trg_functions_my_updated_at
  BEFORE UPDATE ON functions_my
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Upcoming Functions ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS functions_upcoming (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id      TEXT        NOT NULL,
  user_id        UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type           TEXT        NOT NULL DEFAULT 'other',
  person_name    TEXT        NOT NULL DEFAULT '',
  function_title TEXT        NOT NULL,
  date           DATE,
  venue          TEXT,
  notes          TEXT,
  planned_gifts  JSONB       NOT NULL DEFAULT '[]',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE functions_upcoming ENABLE ROW LEVEL SECURITY;

CREATE POLICY "functions_upcoming_user_policy" ON functions_upcoming
  FOR ALL USING (user_id = auth.uid());

CREATE TRIGGER trg_functions_upcoming_updated_at
  BEFORE UPDATE ON functions_upcoming
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Attended Functions ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS functions_attended (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id     TEXT        NOT NULL,
  user_id       UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type          TEXT        NOT NULL DEFAULT 'other',
  function_name TEXT        NOT NULL,
  date          DATE,
  venue         TEXT,
  notes         TEXT,
  gifts         JSONB       NOT NULL DEFAULT '[]',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE functions_attended ENABLE ROW LEVEL SECURITY;

CREATE POLICY "functions_attended_user_policy" ON functions_attended
  FOR ALL USING (user_id = auth.uid());

CREATE TRIGGER trg_functions_attended_updated_at
  BEFORE UPDATE ON functions_attended
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
