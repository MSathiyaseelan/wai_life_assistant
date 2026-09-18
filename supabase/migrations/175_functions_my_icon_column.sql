-- ─────────────────────────────────────────────────────────────────────────────
-- 175_functions_my_icon_column.sql
-- FunctionModel (the "Our Functions" tab) has always sent an `icon` field
-- on insert/update (lib/data/models/lifestyle/lifestyle_models.dart), but
-- functions_my never actually had a matching column — every save has been
-- failing with PostgrestException PGRST204 "Could not find the 'icon'
-- column of 'functions_my' in the schema cache". UpcomingFunction/
-- AttendedFunction never reference `icon`, which is why only this tab was
-- affected, every time, on every wallet.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE functions_my ADD COLUMN IF NOT EXISTS icon TEXT NOT NULL DEFAULT '🎊';
