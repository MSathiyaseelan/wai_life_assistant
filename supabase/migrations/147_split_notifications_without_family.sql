-- ============================================================
-- 147_split_notifications_without_family.sql
--
-- All three split notification RPCs (143/145/146) required a non-null
-- family_id, but a split group's wallet doesn't have to belong to a
-- family at all — splitting an expense with a friend on your PERSONAL
-- wallet is the most common real case, and that friend may share no
-- family with you. Those RPCs already authorize via split-group
-- participation (is_split_group_participant), not family membership —
-- family_id was only ever needed to satisfy notifications' NOT NULL
-- constraint. No RPC changes needed: a UUID parameter already accepts
-- NULL in plpgsql, so relaxing the column is the only change required.
-- ============================================================

ALTER TABLE notifications ALTER COLUMN family_id DROP NOT NULL;
