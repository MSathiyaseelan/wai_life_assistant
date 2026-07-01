-- ============================================================
--  WAI Life Assistant — Wallet Budgets
--  Monthly spending limits per expense category per wallet.
-- ============================================================

CREATE TABLE IF NOT EXISTS wallet_budgets (
  id                   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id            UUID          NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  category             TEXT          NOT NULL,
  limit_amount         NUMERIC(12,2) NOT NULL CHECK (limit_amount > 0),
  -- Track which months already received 80% / 100% alert (YYYY-MM).
  -- Prevents duplicate notifications within the same month.
  last_80_alert_month  TEXT,
  last_100_alert_month TEXT,
  created_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  UNIQUE (wallet_id, category)
);

CREATE INDEX IF NOT EXISTS idx_wallet_budgets_wallet ON wallet_budgets(wallet_id);

-- ── RLS ────────────────────────────────────────────────────────
ALTER TABLE wallet_budgets ENABLE ROW LEVEL SECURITY;

-- Personal wallet owners and family wallet members can read/write budgets
DROP POLICY IF EXISTS "wallet_budget_access" ON wallet_budgets;
CREATE POLICY "wallet_budget_access" ON wallet_budgets
  FOR ALL USING (
    wallet_id IN (
      -- Personal wallet owned by this user
      SELECT id FROM wallets WHERE owner_id = auth.uid() AND is_personal = TRUE
      UNION
      -- Family wallets the user belongs to
      SELECT w.id FROM wallets w
      JOIN families f  ON f.id  = w.family_id
      JOIN family_members fm ON fm.family_id = f.id
      WHERE fm.user_id = auth.uid()
    )
  );

-- auto-update updated_at
CREATE OR REPLACE FUNCTION update_wallet_budget_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS wallet_budgets_updated_at ON wallet_budgets;
CREATE TRIGGER wallet_budgets_updated_at
  BEFORE UPDATE ON wallet_budgets
  FOR EACH ROW EXECUTE FUNCTION update_wallet_budget_updated_at();
