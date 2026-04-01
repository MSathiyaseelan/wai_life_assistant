-- ─────────────────────────────────────────────────────────────────────────────
-- 032_tx_groups.sql
-- Transaction Groups — bundle multiple expenses under one named master card.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Group metadata table
CREATE TABLE IF NOT EXISTS tx_groups (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id  UUID        NOT NULL REFERENCES wallets(id)   ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES profiles(id)  ON DELETE CASCADE,
  name       TEXT        NOT NULL,
  emoji      TEXT        NOT NULL DEFAULT '📦',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tx_groups_wallet ON tx_groups(wallet_id);

ALTER TABLE tx_groups ENABLE ROW LEVEL SECURITY;

-- Same access pattern as wallets: personal owner or family member
CREATE POLICY "tx_groups: wallet access" ON tx_groups
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM wallets w
      WHERE w.id = tx_groups.wallet_id
        AND (
          w.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM family_members fm
            WHERE fm.family_id = w.family_id AND fm.user_id = auth.uid()
          )
        )
    )
  );

-- 2. Link transactions → groups (nullable; SET NULL on group delete)
ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES tx_groups(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_group ON transactions(group_id);
