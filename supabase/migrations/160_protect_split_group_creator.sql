-- Migration 160: A regular (non-creator, non-admin) participant could remove
-- the split group's creator/admin from the group — migration 141 made
-- add/remove available to any participant (needed so a member could add
-- someone to a split they're part of), but that same permissive DELETE
-- policy let anyone remove ANY participant, including the creator.
--
-- Now: removing a regular member still works for any participant (unchanged
-- from 141); removing the group's creator specifically requires
-- split_group_can_manage(group_id) — i.e. the creator themselves or a
-- wallet admin, not a plain member.

DROP POLICY IF EXISTS "split_participants: delete" ON split_participants;
CREATE POLICY "split_participants: delete" ON split_participants
  FOR DELETE USING (
    CASE
      WHEN user_id IS NOT NULL
       AND user_id = (SELECT sg.created_by FROM split_groups sg WHERE sg.id = group_id)
        THEN split_group_can_manage(group_id)
      ELSE split_group_can_manage(group_id) OR is_split_group_participant(group_id)
    END
  );
