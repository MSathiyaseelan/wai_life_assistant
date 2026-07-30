-- ============================================================
-- 138_fix_split_participants_rls_recursion.sql
--
-- Migration 135's "split_participants: select" policy queries
-- split_participants from inside a policy ON split_participants (a raw
-- self-join via the "sp2" alias) — the exact "infinite recursion detected
-- in policy for relation" bug already hit and fixed for family_members in
-- migration 082. Worse, it also queries split_groups, whose own
-- "split_groups: select" policy (135) queries back into
-- split_participants — a second, cross-table recursion cycle.
--
-- Fix: mirror 082's pattern. A SECURITY DEFINER helper function bypasses
-- RLS on the table it queries internally (it runs as the function owner,
-- which has BYPASSRLS), so wrapping the self/cross-referencing checks in
-- one breaks both recursion cycles. split_group_can_manage/
-- split_tx_can_manage/split_share_can_manage (135) and
-- is_split_group_creator (124) were already SECURITY DEFINER and never
-- had this problem — only these two raw-subquery SELECT policies did.
-- ============================================================

CREATE OR REPLACE FUNCTION is_split_group_participant(p_group_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM split_participants
    WHERE group_id = p_group_id AND user_id = auth.uid()
  );
$$;

DROP POLICY IF EXISTS "split_groups: select" ON split_groups;
CREATE POLICY "split_groups: select" ON split_groups
  FOR SELECT USING (
    created_by = auth.uid() OR is_split_group_participant(id)
  );

DROP POLICY IF EXISTS "split_participants: select" ON split_participants;
CREATE POLICY "split_participants: select" ON split_participants
  FOR SELECT USING (
    is_split_group_participant(group_id) OR is_split_group_creator(group_id)
  );
