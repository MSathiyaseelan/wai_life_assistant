-- ============================================================
-- 165_split_group_delete_creator_admin_only.sql
--
-- Deleting a split group is implemented client-side as a soft delete
-- (UPDATE split_groups SET deleted_at = now()), which rides on the same
-- "split_groups: update" RLS policy that 141 deliberately broadened to
-- let ANY participant rename/pin/add-members. That policy doesn't
-- distinguish which column is being changed, so it accidentally also
-- let any participant delete the entire group — not the intended
-- behavior; deleting the whole group (unlike renaming it) should be
-- creator/admin-only, matching the caution already applied to removing
-- the creator as a participant (160_protect_split_group_creator.sql).
--
-- Fix: a BEFORE UPDATE trigger — same pattern as 141's
-- enforce_split_group_wallet_move_perm — that blocks setting deleted_at
-- unless split_group_can_manage() (creator or wallet admin) passes.
-- RAISE EXCEPTION here uses ERRCODE P0001 so the client (wallet_screen.dart)
-- can show its message directly, matching how the wallet-move trigger's
-- and 124's "Only admins can edit members" messages are already surfaced.
-- ============================================================

CREATE OR REPLACE FUNCTION enforce_split_group_delete_perm()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.deleted_at IS DISTINCT FROM OLD.deleted_at
     AND NOT split_group_can_manage(OLD.id) THEN
    RAISE EXCEPTION 'Only the group creator or wallet admin can delete this group'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_split_group_delete_perm ON split_groups;
CREATE TRIGGER trg_enforce_split_group_delete_perm
  BEFORE UPDATE ON split_groups
  FOR EACH ROW
  EXECUTE FUNCTION enforce_split_group_delete_perm();
