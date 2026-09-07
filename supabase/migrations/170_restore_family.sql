-- ============================================================
--  Migration 170 — Restore a soft-deleted family group
--
--  delete_family() (034_soft_delete_family.sql) only ever soft-deletes:
--  it sets families.is_archived/deleted_at and marks that family's
--  transactions deleted_at — family_members rows are left untouched, so
--  membership survives indefinitely (purge_old_deleted_records only purges
--  rows that actually have deleted_at set, and removeMember() — the only
--  path that sets deleted_at on family_members — is unrelated to a whole
--  family delete). That means a full restore is possible up until
--  purge_old_deleted_records() hard-deletes the family's transactions,
--  which only happens after recycle_bin_retention_days (086), and the
--  families row itself is never purged.
--
--  This adds the missing other half: restore_family() un-archives the
--  family and un-deletes exactly the transactions that were soft-deleted
--  alongside it — matched by deleted_at timestamp equality, since NOW()
--  is stable for the whole delete_family() call, so every row it touched
--  shares one identical timestamp. This avoids resurrecting transactions
--  a user had separately, individually soft-deleted before the group was
--  removed.
-- ============================================================

CREATE OR REPLACE FUNCTION restore_family(p_family_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_at TIMESTAMPTZ;
  v_cutoff     TIMESTAMPTZ;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id AND user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can restore a family';
  END IF;

  SELECT deleted_at INTO v_deleted_at FROM families WHERE id = p_family_id;

  IF v_deleted_at IS NULL THEN
    RAISE EXCEPTION 'This group is not deleted';
  END IF;

  SELECT NOW() - (COALESCE(
    (SELECT value FROM app_config WHERE key = 'recycle_bin_retention_days'),
    '30'
  ) || ' days')::interval
  INTO v_cutoff;

  IF v_deleted_at < v_cutoff THEN
    RAISE EXCEPTION 'This group can no longer be restored';
  END IF;

  -- Restore only the transactions soft-deleted in the same delete_family() call
  UPDATE transactions
  SET deleted_at = NULL
  WHERE wallet_id IN (
    SELECT id FROM wallets WHERE family_id = p_family_id
  )
  AND deleted_at = v_deleted_at;

  UPDATE families
  SET is_archived = FALSE,
      deleted_at  = NULL
  WHERE id = p_family_id;
END;
$$;
