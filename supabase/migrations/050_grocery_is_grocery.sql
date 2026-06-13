-- Add is_grocery flag to distinguish quick-list items (added from dashboard)
-- from regular grocery items (managed in Pantry > Basket).
-- Default true so all existing rows remain grocery items.
ALTER TABLE grocery_items
  ADD COLUMN IF NOT EXISTS is_grocery boolean NOT NULL DEFAULT true;
