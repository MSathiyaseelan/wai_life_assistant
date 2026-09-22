-- ============================================================
--  Wardrobe: share an outfit log into another wallet
--  (same shared_wallet_id pattern as 190 for wardrobe_items)
-- ============================================================

ALTER TABLE wardrobe_outfit_logs ADD COLUMN IF NOT EXISTS shared_wallet_id TEXT;

DROP POLICY IF EXISTS "wardrobe_outfit_logs: wallet members read" ON wardrobe_outfit_logs;
CREATE POLICY "wardrobe_outfit_logs: wallet members read" ON wardrobe_outfit_logs
  FOR SELECT USING (
    user_id = auth.uid()
    OR wallet_accessible_txt(wallet_id)
    OR wallet_accessible_txt(shared_wallet_id)
  );
