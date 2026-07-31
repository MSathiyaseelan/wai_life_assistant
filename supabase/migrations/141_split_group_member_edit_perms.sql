-- ============================================================
-- 141_split_group_member_edit_perms.sql
--
-- split_group_can_manage() (135) gates renaming the group, toggling
-- "Pin to Dashboard", and adding/removing participants behind
-- "creator or wallet admin" — the same gate used for "move this group to
-- another wallet". That's too strict: a regular (non-admin, non-creator)
-- member could never pin the group to their own dashboard or add someone
-- else to a split they're part of, since the client's Edit sheet does all
-- of these through the same save path.
--
-- Splits that apart: any participant can now rename/pin the group and
-- add/remove participants; moving it to another wallet stays
-- creator-or-admin-only, enforced by a trigger since it's a column
-- (wallet_id) on the same table/statement the broader UPDATE policy now
-- allows.
-- ============================================================

-- ── split_groups: update ─────────────────────────────────────────────────
-- Any participant (not just creator/admin) may rename, re-emoji, or
-- (un)pin the group. wallet_id changes are blocked separately below.
DROP POLICY IF EXISTS "split_groups: update" ON split_groups;
CREATE POLICY "split_groups: update" ON split_groups
  FOR UPDATE
  USING (
    created_by = auth.uid()
    OR wallet_admin(wallet_id)
    OR is_split_group_participant(id)
  )
  WITH CHECK (wallet_accessible(wallet_id));

-- Moving a group to another wallet changes wallet_id — that's still
-- creator/admin-only even though the UPDATE policy above now admits any
-- participant for other columns (name/emoji/pinned_to_dashboard).
CREATE OR REPLACE FUNCTION enforce_split_group_wallet_move_perm()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.wallet_id IS DISTINCT FROM OLD.wallet_id
     AND NOT (OLD.created_by = auth.uid() OR wallet_admin(OLD.wallet_id)) THEN
    RAISE EXCEPTION 'Only the group creator or wallet admin can move this group to another wallet';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_split_group_wallet_move_perm ON split_groups;
CREATE TRIGGER trg_enforce_split_group_wallet_move_perm
  BEFORE UPDATE ON split_groups
  FOR EACH ROW
  EXECUTE FUNCTION enforce_split_group_wallet_move_perm();

-- ── split_participants: insert / delete ──────────────────────────────────
-- Any participant can add or remove members (used by the same Edit sheet),
-- not just the group's creator/admin.
DROP POLICY IF EXISTS "split_participants: insert" ON split_participants;
CREATE POLICY "split_participants: insert" ON split_participants
  FOR INSERT WITH CHECK (
    split_group_can_manage(group_id) OR is_split_group_participant(group_id)
  );

DROP POLICY IF EXISTS "split_participants: delete" ON split_participants;
CREATE POLICY "split_participants: delete" ON split_participants
  FOR DELETE USING (
    split_group_can_manage(group_id) OR is_split_group_participant(group_id)
  );
