-- ============================================================
--  Drop the broken delete_my_account() RPC from migration 067.
--  Account deletion is now handled entirely by the delete-account
--  edge function via auth.admin.deleteUser(), which triggers
--  Postgres CASCADE DELETE across all linked tables:
--    auth.users → profiles → wallets → transactions / wishes /
--    reminders / notes / recipes / meal_entries / …
--  and directly: auth.users → wardrobe_items / health_* /
--    item_locator_* / functions_* / family_members
-- ============================================================

DROP FUNCTION IF EXISTS delete_my_account();
