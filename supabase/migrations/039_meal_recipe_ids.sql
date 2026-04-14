-- Add recipe_ids text[] column to meal_entries to support linking a meal to
-- multiple recipes. The legacy recipe_id column is kept for backward compat.

ALTER TABLE meal_entries
  ADD COLUMN IF NOT EXISTS recipe_ids text[] NOT NULL DEFAULT '{}';

-- Backfill: copy existing single recipe_id into the new array column.
UPDATE meal_entries
SET recipe_ids = ARRAY[recipe_id]
WHERE recipe_id IS NOT NULL
  AND recipe_ids = '{}';
