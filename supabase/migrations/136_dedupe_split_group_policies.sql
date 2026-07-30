-- ============================================================
-- 136_dedupe_split_group_policies.sql
--
-- Migration 135 added new per-command policies on split_groups /
-- split_participants ("split_groups: select/insert/update/delete", etc.)
-- without realizing migration 124 had already replaced the original
-- "...: participant access" / "...: group members" policies those DROP
-- IF EXISTS statements targeted — 124 renamed them to
-- "split_groups: creator full access" / "split_groups: participants can
-- view" (and the split_participants equivalents), which were still
-- active alongside 135's new ones.
--
-- Not a security hole — RLS policies are OR'd, and 135's policies (creator
-- OR wallet_admin) are already a strict superset of 124's (creator only),
-- so the combined effect matched 135's intent regardless. But leaving both
-- active is confusing and error-prone for future changes, so this drops
-- 124's now-redundant policies, leaving 135's as the single source of
-- truth for these two tables.
-- ============================================================

DROP POLICY IF EXISTS "split_groups: creator full access" ON split_groups;
DROP POLICY IF EXISTS "split_groups: participants can view" ON split_groups;

DROP POLICY IF EXISTS "split_participants: creator full access" ON split_participants;
DROP POLICY IF EXISTS "split_participants: members can view" ON split_participants;
