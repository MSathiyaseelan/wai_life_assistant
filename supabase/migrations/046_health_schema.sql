-- ============================================================
--  WAI Life Assistant — Health Space Schema
-- ============================================================

-- ── Health Profile (one per member per wallet) ────────────────────────────────
CREATE TABLE IF NOT EXISTS health_profiles (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id         TEXT        NOT NULL,
  user_id           UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id         TEXT        NOT NULL DEFAULT 'me',
  blood_group       TEXT,
  height            TEXT,
  weight            TEXT,
  allergies         JSONB       NOT NULL DEFAULT '[]',
  conditions        JSONB       NOT NULL DEFAULT '[]',
  disabilities      JSONB       NOT NULL DEFAULT '[]',
  emergency_contact TEXT,
  emergency_phone   TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (wallet_id, member_id)
);
ALTER TABLE health_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "health_profiles_user_policy" ON health_profiles
  FOR ALL USING (user_id = auth.uid());
CREATE TRIGGER trg_health_profiles_updated_at
  BEFORE UPDATE ON health_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Medications ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS health_medications (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id    TEXT        NOT NULL,
  user_id      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id    TEXT        NOT NULL DEFAULT 'me',
  name         TEXT        NOT NULL,
  dosage       TEXT        NOT NULL,
  frequency    TEXT        NOT NULL,
  timing       TEXT,
  is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
  start_date   DATE        NOT NULL DEFAULT CURRENT_DATE,
  end_date     DATE,
  refill_date  DATE,
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE health_medications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "health_medications_user_policy" ON health_medications
  FOR ALL USING (user_id = auth.uid());
CREATE TRIGGER trg_health_medications_updated_at
  BEFORE UPDATE ON health_medications
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Doctors ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS health_doctors (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id   TEXT        NOT NULL,
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id   TEXT        NOT NULL DEFAULT 'me',
  name        TEXT        NOT NULL,
  specialty   TEXT,
  hospital    TEXT,
  phone       TEXT,
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE health_doctors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "health_doctors_user_policy" ON health_doctors
  FOR ALL USING (user_id = auth.uid());
CREATE TRIGGER trg_health_doctors_updated_at
  BEFORE UPDATE ON health_doctors
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Medical Documents ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS health_documents (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id   TEXT        NOT NULL,
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id   TEXT        NOT NULL DEFAULT 'me',
  title       TEXT        NOT NULL,
  doc_type    TEXT        NOT NULL DEFAULT 'other',
  file_url    TEXT,
  notes       TEXT,
  doc_date    DATE        NOT NULL DEFAULT CURRENT_DATE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE health_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "health_documents_user_policy" ON health_documents
  FOR ALL USING (user_id = auth.uid());
CREATE TRIGGER trg_health_documents_updated_at
  BEFORE UPDATE ON health_documents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Appointments ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS health_appointments (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id    TEXT        NOT NULL,
  user_id      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id    TEXT        NOT NULL DEFAULT 'me',
  doctor_name  TEXT        NOT NULL,
  appt_date    DATE        NOT NULL,
  appt_time    TEXT,
  location     TEXT,
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE health_appointments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "health_appointments_user_policy" ON health_appointments
  FOR ALL USING (user_id = auth.uid());
CREATE TRIGGER trg_health_appointments_updated_at
  BEFORE UPDATE ON health_appointments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Vitals ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS health_vitals (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id   TEXT        NOT NULL,
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id   TEXT        NOT NULL DEFAULT 'me',
  vital_type  TEXT        NOT NULL,
  value       NUMERIC     NOT NULL,
  value2      NUMERIC,
  sub_type    TEXT,
  notes       TEXT,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE health_vitals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "health_vitals_user_policy" ON health_vitals
  FOR ALL USING (user_id = auth.uid());

-- ── Vaccinations ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS health_vaccinations (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id    TEXT        NOT NULL,
  user_id      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id    TEXT        NOT NULL DEFAULT 'me',
  vaccine_name TEXT        NOT NULL,
  date_given   DATE        NOT NULL,
  next_due     DATE,
  dose_number  INT,
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE health_vaccinations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "health_vaccinations_user_policy" ON health_vaccinations
  FOR ALL USING (user_id = auth.uid());
CREATE TRIGGER trg_health_vaccinations_updated_at
  BEFORE UPDATE ON health_vaccinations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Insurance Policies ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS health_insurance (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id        TEXT        NOT NULL,
  user_id          UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id        TEXT        NOT NULL DEFAULT 'me',
  policy_name      TEXT        NOT NULL,
  policy_number    TEXT,
  provider         TEXT,
  coverage_amount  NUMERIC,
  expiry_date      DATE,
  notes            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE health_insurance ENABLE ROW LEVEL SECURITY;
CREATE POLICY "health_insurance_user_policy" ON health_insurance
  FOR ALL USING (user_id = auth.uid());
CREATE TRIGGER trg_health_insurance_updated_at
  BEFORE UPDATE ON health_insurance
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
