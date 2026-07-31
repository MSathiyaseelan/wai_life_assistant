-- ============================================================
-- 142_split_group_pin_per_participant.sql
--
-- split_groups.pinned_to_dashboard (007_split_group_pin.sql) is a single
-- boolean on the shared group row — "Pin to Dashboard" was meant to be a
-- personal preference ("show this on MY dashboard"), but since it lives on
-- the group itself, any one participant toggling it changes what every
-- other participant sees on their own dashboard too.
--
-- Moves the flag to split_participants (one row per participant per
-- group already), so each person's pin state is theirs alone.
-- ============================================================

ALTER TABLE split_participants
  ADD COLUMN IF NOT EXISTS pinned_to_dashboard BOOLEAN NOT NULL DEFAULT FALSE;

-- Best-effort backfill: attribute the previous group-wide pin state to the
-- group's creator only, since that's the one participant we can plausibly
-- say "probably pinned it" — everyone else defaults to unpinned rather than
-- inheriting a pin state they never actually chose.
UPDATE split_participants sp
SET pinned_to_dashboard = TRUE
FROM split_groups sg
WHERE sp.group_id = sg.id
  AND sg.pinned_to_dashboard = TRUE
  AND sp.user_id = sg.created_by;

ALTER TABLE split_groups DROP COLUMN IF EXISTS pinned_to_dashboard;

-- A participant needs to update their OWN row to toggle their own pin —
-- previously only the group's creator/admin could update any participant
-- row at all (migration 135), which was fine when pin was group-level but
-- now blocks a regular member from writing their own pin state.
DROP POLICY IF EXISTS "split_participants: update" ON split_participants;
CREATE POLICY "split_participants: update" ON split_participants
  FOR UPDATE USING (
    split_group_can_manage(group_id) OR user_id = auth.uid()
  );
