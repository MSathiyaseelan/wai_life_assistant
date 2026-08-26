-- Migration 161: A plain RLS USING clause on DELETE doesn't raise an error
-- when a row is excluded — it just silently deletes 0 rows, no exception at
-- all. That meant migration 160's protection worked (the creator couldn't
-- actually be removed by a regular member), but gave zero feedback: no
-- error, no explanation, just a save that quietly didn't do what was asked.
--
-- Swap to the same pattern already used for the wallet-move permission
-- (enforce_split_group_wallet_move_perm, migration 141): keep RLS
-- permissive enough that the row is actually considered for deletion, and
-- enforce the actual business rule in a BEFORE DELETE trigger that RAISEs a
-- clear, user-facing message — which the client already knows to surface
-- directly for Postgrest code P0001.

DROP POLICY IF EXISTS "split_participants: delete" ON split_participants;
CREATE POLICY "split_participants: delete" ON split_participants
  FOR DELETE USING (
    split_group_can_manage(group_id) OR is_split_group_participant(group_id)
  );

CREATE OR REPLACE FUNCTION enforce_split_group_creator_removal_perm()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.user_id IS NOT NULL
     AND OLD.user_id = (SELECT sg.created_by FROM split_groups sg WHERE sg.id = OLD.group_id)
     AND NOT split_group_can_manage(OLD.group_id) THEN
    RAISE EXCEPTION 'Only the group creator or a wallet admin can remove them from the group.';
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_split_group_creator_removal_perm ON split_participants;
CREATE TRIGGER trg_enforce_split_group_creator_removal_perm
  BEFORE DELETE ON split_participants
  FOR EACH ROW
  EXECUTE FUNCTION enforce_split_group_creator_removal_perm();
