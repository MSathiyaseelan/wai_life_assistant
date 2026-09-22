-- ============================================================
--  Wardrobe: share an item into another wallet (Personal <-> Family)
--
--  Rather than "moving" an item (which would reassign ownership and
--  strand its member_id, since family members are scoped to the
--  wallet they belong to), items get an optional shared_wallet_id:
--  when set, the item stays owned by its original wallet/member but
--  also becomes readable from that second wallet's context. Purely a
--  visibility toggle — edit/delete rights stay with the original
--  wallet's members, matching the read-only nature of "share" as
--  opposed to "move."
-- ============================================================

ALTER TABLE wardrobe_items ADD COLUMN IF NOT EXISTS shared_wallet_id TEXT;

DROP POLICY IF EXISTS "wardrobe_items: wallet members read" ON wardrobe_items;
CREATE POLICY "wardrobe_items: wallet members read" ON wardrobe_items
  FOR SELECT USING (
    user_id = auth.uid()
    OR wallet_accessible_txt(wallet_id)
    OR wallet_accessible_txt(shared_wallet_id)
  );
