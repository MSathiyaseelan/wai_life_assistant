-- ============================================================
-- 202_grocery_items_realtime.sql
--
-- Live sync for the Pantry Basket / Dashboard Shopping List: one family
-- member's add / tick / move on a family wallet's list now reaches the
-- other members' phones without a manual refresh.
--
-- RealtimeSyncService subscribes to grocery_items filtered by wallet_id.
-- Ticking an item hard-deletes its row, and Postgres Changes can only filter
-- DELETE events when the table has REPLICA IDENTITY FULL (by default the old
-- row carries only the primary key, so a wallet_id filter never matches).
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'grocery_items'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.grocery_items;
  END IF;
END $$;

ALTER TABLE grocery_items REPLICA IDENTITY FULL;
