-- ─────────────────────────────────────────────────────────────────────────────
-- 006_bill_watch.sql
-- Recurring bill / subscription tracker per wallet
-- Schema matches planit BillModel so the same widget can be used in both tabs.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS bills (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id      UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,
  category       TEXT NOT NULL DEFAULT 'other'
                 CHECK (category IN (
                   'electricity','water','gas','internet','phone',
                   'insurance','school','rent','subscription','medical','emi','other'
                 )),
  amount         DECIMAL(12, 2) NOT NULL DEFAULT 0,
  due_date       DATE NOT NULL,
  repeat         TEXT NOT NULL DEFAULT 'monthly'
                 CHECK (repeat IN ('none','daily','weekly','monthly','yearly')),
  paid           BOOLEAN NOT NULL DEFAULT FALSE,
  provider       TEXT,
  account_number TEXT,
  note           TEXT,
  history        JSONB NOT NULL DEFAULT '[]',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER bills_updated_at
  BEFORE UPDATE ON bills
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE bills ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage bills for their wallets"
ON bills
USING (
  wallet_id IN (
    SELECT id FROM wallets WHERE owner_id = auth.uid()
    UNION
    SELECT w.id FROM wallets w
    JOIN family_members fm ON fm.family_id = w.family_id
    WHERE fm.user_id = auth.uid()
  )
);
