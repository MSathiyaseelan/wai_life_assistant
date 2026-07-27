-- ============================================================
-- 124_sync_split_group_perms_and_update_member.sql
--
-- Full dev-vs-QA schema audit found two real gaps, both from fixes that
-- were applied ad hoc directly to the dev project and never tracked as
-- migrations, so QA never received them:
--
-- 1. split_groups / split_participants RLS on QA was still the old,
--    over-permissive version — ANY participant (not just the creator)
--    had full ALL-command access, meaning any participant could edit or
--    delete the whole split group and other participants' rows. Dev has
--    this correctly tightened to creator-only for writes, view-only for
--    participants (via is_split_group_creator()). Bringing that to QA.
--
-- 2. update_family_member RPC didn't exist on QA at all — editing a
--    family member's name/emoji/role/phone/relation would fail outright.
--    Its dev definition also had NO permission check whatsoever (any
--    authenticated caller could edit any member by guessing an id) —
--    fixing that here too, requiring family admin (matching
--    add_family_member's existing gate).
-- ============================================================

CREATE OR REPLACE FUNCTION is_split_group_creator(p_group_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM split_groups
    WHERE id = p_group_id AND created_by = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION is_split_group_member(p_group_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT is_split_group_creator(p_group_id)
  OR EXISTS (
    SELECT 1 FROM split_participants
    WHERE group_id = p_group_id AND user_id = auth.uid()
  );
$$;

DROP POLICY IF EXISTS "split_groups: participant access" ON split_groups;
DROP POLICY IF EXISTS "split_groups: creator full access" ON split_groups;
DROP POLICY IF EXISTS "split_groups: participants can view" ON split_groups;
CREATE POLICY "split_groups: creator full access" ON split_groups
  FOR ALL USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());
CREATE POLICY "split_groups: participants can view" ON split_groups
  FOR SELECT USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM split_participants
      WHERE split_participants.group_id = split_groups.id
        AND split_participants.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "split_participants: group members" ON split_participants;
DROP POLICY IF EXISTS "split_participants: creator full access" ON split_participants;
DROP POLICY IF EXISTS "split_participants: members can view" ON split_participants;
CREATE POLICY "split_participants: creator full access" ON split_participants
  FOR ALL USING (is_split_group_creator(group_id))
  WITH CHECK (is_split_group_creator(group_id));
CREATE POLICY "split_participants: members can view" ON split_participants
  FOR SELECT USING (user_id = auth.uid() OR is_split_group_creator(group_id));

-- ── update_family_member — now exists on QA, and gated to family admins ──────
CREATE OR REPLACE FUNCTION update_family_member(
  p_member_id UUID,
  p_name      TEXT,
  p_emoji     TEXT,
  p_role      TEXT DEFAULT 'member',
  p_phone     TEXT DEFAULT NULL,
  p_relation  TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid       UUID := auth.uid();
  v_family_id UUID;
BEGIN
  SELECT family_id INTO v_family_id FROM family_members WHERE id = p_member_id;
  IF v_family_id IS NULL THEN RETURN; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = v_family_id
      AND user_id   = v_uid
      AND role      = 'admin'
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Only admins can edit members'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE family_members
  SET name = p_name, emoji = p_emoji, role = p_role,
      phone = p_phone, relation = p_relation
  WHERE id = p_member_id;
END;
$$;
