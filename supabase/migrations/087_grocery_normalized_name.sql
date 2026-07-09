-- ─────────────────────────────────────────────────────────────────────────────
-- 087_grocery_normalized_name.sql
-- Pantry ingredient matching (recipe ingredients vs basket In Stock/To Buy)
-- was comparing raw item names with case-insensitive substring containment,
-- which breaks on capitalization, pluralization, and free-text noise (see
-- lib/features/pantry/pantry_screen.dart _analyzeIngredients/_reduceStockForMeal).
--
-- Adds a normalized_name column to grocery_items as a stable comparison key.
-- The app computes and writes this value on every insert/update going
-- forward (lib/core/utils/ingredient_normalizer.dart, mirrored below in SQL
-- for backfilling existing rows). Recipe ingredients stay free text (no
-- column to add there — they're a TEXT[]) and are normalized on the fly at
-- match time using the same algorithm.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE grocery_items ADD COLUMN IF NOT EXISTS normalized_name TEXT;

CREATE OR REPLACE FUNCTION normalize_grocery_name(raw TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  s TEXT;
BEGIN
  IF raw IS NULL THEN RETURN NULL; END IF;
  s := lower(trim(raw));
  s := regexp_replace(s, '[^a-z0-9 ]', '', 'g');
  s := regexp_replace(s, '\s+', ' ', 'g');
  s := trim(s);
  IF length(s) > 3 AND s ~ 'ies$' THEN
    s := left(s, length(s) - 3) || 'y';
  ELSIF length(s) > 4 AND s ~ '(shes|ches|xes|ses)$' THEN
    s := left(s, length(s) - 2);
  ELSIF length(s) > 3 AND right(s, 1) = 's' AND s !~ '(ss|us|as|os)$' THEN
    s := left(s, length(s) - 1);
  END IF;
  RETURN s;
END;
$$;

UPDATE grocery_items
SET normalized_name = normalize_grocery_name(name)
WHERE normalized_name IS NULL;

CREATE INDEX IF NOT EXISTS idx_grocery_items_normalized_name ON grocery_items(normalized_name);
