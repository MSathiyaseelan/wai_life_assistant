-- ============================================================
--  Revert 154: delete_my_account() was intentionally dropped in
--  068_fix_delete_account.sql — the delete-account edge function
--  no longer calls it, relying purely on ON DELETE CASCADE from
--  auth.users. 154 mistakenly recreated it; drop it again so the
--  schema matches the actual (correct) architecture.
-- ============================================================

DROP FUNCTION IF EXISTS delete_my_account();
