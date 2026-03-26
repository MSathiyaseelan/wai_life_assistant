-- Migration 022: Track which user recipes were tagged from the master library
-- library_recipe_id links back to master_recipes so the card can show an "Untag" option.

ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS library_recipe_id TEXT
  REFERENCES master_recipes(id) ON DELETE SET NULL;
