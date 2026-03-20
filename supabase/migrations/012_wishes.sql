-- ─────────────────────────────────────────────────────────────────────────────
-- 012_wishes.sql
-- PlanIt Wish List — per-wallet savings goals
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS wishes (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id        UUID        NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  title            TEXT        NOT NULL,
  emoji            TEXT        NOT NULL DEFAULT '🎁',
  category         TEXT        NOT NULL DEFAULT 'other'
                   CHECK (category IN ('electronics','fashion','home','travel','food','experience','other')),
  priority         TEXT        NOT NULL DEFAULT 'medium'
                   CHECK (priority IN ('low','medium','high','urgent')),
  target_price     NUMERIC,
  saved_amount     NUMERIC     NOT NULL DEFAULT 0,
  link             TEXT,
  note             TEXT,
  purchased        BOOLEAN     NOT NULL DEFAULT FALSE,
  target_date      DATE,
  savings_history  JSONB       NOT NULL DEFAULT '[]',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wishes_wallet ON wishes(wallet_id);

CREATE TRIGGER trg_wishes_updated_at
  BEFORE UPDATE ON wishes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE wishes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wishes: wallet members can view" ON wishes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM wallets w
      WHERE w.id = wishes.wallet_id
        AND (
          w.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM family_members fm
            WHERE fm.family_id = w.family_id AND fm.user_id = auth.uid()
          )
        )
    )
  );

CREATE POLICY "wishes: wallet members can insert" ON wishes
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM wallets w
      WHERE w.id = wishes.wallet_id
        AND (
          w.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM family_members fm
            WHERE fm.family_id = w.family_id AND fm.user_id = auth.uid()
          )
        )
    )
  );

CREATE POLICY "wishes: wallet members can update" ON wishes
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM wallets w
      WHERE w.id = wishes.wallet_id
        AND (
          w.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM family_members fm
            WHERE fm.family_id = w.family_id AND fm.user_id = auth.uid()
          )
        )
    )
  );

CREATE POLICY "wishes: wallet members can delete" ON wishes
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM wallets w
      WHERE w.id = wishes.wallet_id
        AND (
          w.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM family_members fm
            WHERE fm.family_id = w.family_id AND fm.user_id = auth.uid()
          )
        )
    )
  );
