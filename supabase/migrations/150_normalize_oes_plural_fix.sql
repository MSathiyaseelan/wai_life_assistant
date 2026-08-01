-- ============================================================
-- 150_normalize_oes_plural_fix.sql
--
-- normalize_grocery_name() (087) stripped only a trailing 's' for words
-- like "Tomatoes", giving "tomatoe" instead of "tomato" — so a recipe
-- ingredient "Tomatoes" and a basket item "Tomato" normalized to different
-- keys and silently failed to match. Same bug mirrored in
-- lib/core/utils/ingredient_normalizer.dart's normalizeIngredientName(),
-- fixed there in the same change as this migration.
--
-- Adds an explicit "-oes" -> "-o" branch (tomato/potato/mango/hero/echo
-- pattern) ahead of the generic single-s strip. This is ambiguous with the
-- rarer "-oe" + s pattern (shoe -> shoes, canoe -> canoes), but those never
-- occur as pantry ingredients, so the "-o" base is the right default here.
-- ============================================================

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
  ELSIF length(s) > 3 AND s ~ 'oes$' THEN
    s := left(s, length(s) - 2);
  ELSIF length(s) > 3 AND right(s, 1) = 's' AND s !~ '(ss|us|as|os)$' THEN
    s := left(s, length(s) - 1);
  END IF;
  RETURN s;
END;
$$;

-- Re-canonicalize existing rows affected by the fix (e.g. stored
-- "tomatoe" -> "tomato"), same backfill approach as 087 and 149.
UPDATE grocery_items
SET normalized_name = canonical_ingredient_name(name)
WHERE normalized_name IS NOT NULL
  AND normalized_name <> canonical_ingredient_name(name);
