-- ============================================================
--  Migration 034 — Soft Delete for Family & Transactions
--  Instead of hard-deleting, marks families and their
--  transactions as deleted so records are preserved as archive.
-- ============================================================

-- Add deleted_at to families (timestamp of when soft-deleted)
ALTER TABLE families
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Add deleted_at to transactions (timestamp of when soft-deleted)
ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_tx_deleted_at ON transactions(deleted_at)
  WHERE deleted_at IS NOT NULL;


-- ══════════════════════════════════════════════════════════════
--  FUNCTION: delete_family  (soft-delete version)
--  Marks the family as archived + deleted, and marks all
--  transactions belonging to that family's wallets as deleted.
-- ══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION delete_family(p_family_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id AND user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can delete a family';
  END IF;

  -- Soft-delete all transactions linked to this family's wallets
  UPDATE transactions
  SET deleted_at = NOW()
  WHERE wallet_id IN (
    SELECT id FROM wallets WHERE family_id = p_family_id
  )
  AND deleted_at IS NULL;

  -- Soft-delete the family (is_archived hides it from the view)
  UPDATE families
  SET is_archived = TRUE,
      deleted_at  = NOW()
  WHERE id = p_family_id;
END;
$$;
