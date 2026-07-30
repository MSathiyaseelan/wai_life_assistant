-- ============================================================
-- 133_enable_realtime_publication.sql
--
-- Root cause of "notification badge doesn't update", and very likely every
-- other "doesn't reflect live / needs app restart" complaint this session
-- (family photo sync, new-member-joined sync, health/pantry/wardrobe/
-- functions realtime, wallet split-chat, etc.): the `supabase_realtime`
-- publication has zero tables in it on both dev and QA. Every single
-- Flutter-side `.onPostgresChanges(...)` subscription in the app has been
-- silently receiving nothing, the whole time, on both projects — Postgres
-- logical replication only streams changes for tables actually added to
-- the publication; RLS/policies are irrelevant to this, this is a
-- replication-level gap that predates all of this session's work.
--
-- Adds every table any client-side `.onPostgresChanges(...)` subscription
-- currently listens to (RealtimeSyncService.subscribeAll/subscribeFamilies,
-- NotificationService, WalletService, FunctionsService, HealthService,
-- ItemLocatorService).
--
-- Also sets REPLICA IDENTITY FULL on tables whose subscriptions filter
-- DELETE/UPDATE events by a non-primary-key column (e.g. family_members
-- filtered by family_id) — logical replication only includes the OLD row's
-- primary-key columns by default, so a DELETE's filter on any other column
-- would silently never match without this.
-- ============================================================

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'notifications',
    'families',
    'family_members',
    'transactions',
    'split_group_messages',
    'functions_my',
    'functions_upcoming',
    'functions_attended',
    'notes',
    'reminders',
    'wishes',
    'health_medications',
    'health_doctors',
    'health_documents',
    'health_appointments',
    'health_vaccinations',
    'health_insurance',
    'wardrobe_items',
    'meal_entries',
    'item_locator_containers',
    'item_locator_items'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

ALTER TABLE family_members REPLICA IDENTITY FULL;
