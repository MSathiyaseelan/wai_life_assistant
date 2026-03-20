-- ─────────────────────────────────────────────────────────────────────────────
-- 011_special_days.sql
-- PlanIt Special Days — per-wallet birthday/anniversary/festival storage
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS special_days (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id        UUID        NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  title            TEXT        NOT NULL,
  emoji            TEXT        NOT NULL DEFAULT '📅',
  type             TEXT        NOT NULL DEFAULT 'custom'
                   CHECK (type IN ('birthday','anniversary','festival','govtHoliday','holiday','custom')),
  date             DATE        NOT NULL,
  yearly_recur     BOOLEAN     NOT NULL DEFAULT TRUE,
  members          TEXT[]      NOT NULL DEFAULT '{}',
  note             TEXT,
  alert_days_before INT        NOT NULL DEFAULT 1,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_special_days_wallet ON special_days(wallet_id);
CREATE INDEX idx_special_days_date   ON special_days(date);

CREATE TRIGGER trg_special_days_updated_at
  BEFORE UPDATE ON special_days
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE special_days ENABLE ROW LEVEL SECURITY;

CREATE POLICY "special_days: wallet members can view" ON special_days
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM wallets w
      WHERE w.id = special_days.wallet_id
        AND (
          w.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM family_members fm
            WHERE fm.family_id = w.family_id AND fm.user_id = auth.uid()
          )
        )
    )
  );

CREATE POLICY "special_days: wallet members can insert" ON special_days
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM wallets w
      WHERE w.id = special_days.wallet_id
        AND (
          w.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM family_members fm
            WHERE fm.family_id = w.family_id AND fm.user_id = auth.uid()
          )
        )
    )
  );

CREATE POLICY "special_days: wallet members can update" ON special_days
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM wallets w
      WHERE w.id = special_days.wallet_id
        AND (
          w.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM family_members fm
            WHERE fm.family_id = w.family_id AND fm.user_id = auth.uid()
          )
        )
    )
  );

CREATE POLICY "special_days: wallet members can delete" ON special_days
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM wallets w
      WHERE w.id = special_days.wallet_id
        AND (
          w.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM family_members fm
            WHERE fm.family_id = w.family_id AND fm.user_id = auth.uid()
          )
        )
    )
  );
