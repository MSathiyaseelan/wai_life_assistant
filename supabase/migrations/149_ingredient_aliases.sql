-- ============================================================
-- 149_ingredient_aliases.sql
--
-- Recipe ingredients (master_recipes + custom recipes.ingredients) and
-- Basket grocery_items are matched via normalize_grocery_name()/
-- normalizeIngredientName() (087_grocery_normalized_name.sql), which only
-- strips case/plurals/punctuation — it can't know "Brinjal" and "Eggplant"
-- are the same ingredient. Hardcoding those synonyms in the app would mean
-- every new alias needs a release; instead, keep them as data so they can
-- be added with a plain SQL insert.
--
-- ingredient_aliases maps a normalized alias key to a normalized canonical
-- key. It's global/unscoped (like master_recipes) — ingredient identity
-- isn't family-specific. Client-curated for now (no app UI to manage it,
-- same as master_recipes), read-only to clients.
-- ============================================================

CREATE TABLE IF NOT EXISTS ingredient_aliases (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alias      TEXT NOT NULL UNIQUE,   -- normalize_grocery_name() output
  canonical  TEXT NOT NULL,          -- normalize_grocery_name() output this resolves to
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ingredient_aliases_canonical ON ingredient_aliases(canonical);

ALTER TABLE ingredient_aliases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ingredient_aliases_read" ON ingredient_aliases
  FOR SELECT
  TO authenticated
  USING (true);

-- Resolves a raw ingredient/grocery name to its final canonical comparison
-- key: base-normalize, then follow the alias if one exists.
CREATE OR REPLACE FUNCTION canonical_ingredient_name(raw TEXT)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  base TEXT;
  mapped TEXT;
BEGIN
  base := normalize_grocery_name(raw);
  IF base IS NULL THEN RETURN NULL; END IF;
  SELECT canonical INTO mapped FROM ingredient_aliases WHERE alias = base;
  RETURN COALESCE(mapped, base);
END;
$$;

-- Seed common Indian-pantry synonym pairs. Add more anytime with a plain
-- INSERT — no app release needed. Keys/values must already be in
-- normalize_grocery_name() form (lowercase, singular, no punctuation).
-- Note: keys only need the SINGULAR normalized form — canonical_ingredient_name()
-- always strips plurals via normalize_grocery_name() before the alias lookup,
-- so a plural-only key (e.g. 'bell peppers') would never be queried.
INSERT INTO ingredient_aliases (alias, canonical) VALUES
  ('eggplant', 'brinjal'),
  ('aubergine', 'brinjal'),
  ('bell pepper', 'capsicum'),
  ('yogurt', 'curd'),
  ('yoghurt', 'curd'),
  ('cilantro', 'coriander'),
  ('coriander leaves', 'coriander'),
  ('gram flour', 'besan'),
  ('chickpea flour', 'besan'),
  ('drumstick', 'moringa'),
  ('lady finger', 'okra'),
  ('ladies finger', 'okra'),
  ('bhindi', 'okra'),
  ('scallion', 'spring onion'),
  ('green onion', 'spring onion'),
  ('cottage cheese', 'paneer'),
  ('clarified butter', 'ghee'),
  ('chili powder', 'chilli powder'),
  ('red chili powder', 'chilli powder')
ON CONFLICT (alias) DO NOTHING;

-- One-time backfill so existing grocery_items rows benefit immediately,
-- matching the same backfill approach used in 087 when normalized_name
-- was first introduced.
UPDATE grocery_items
SET normalized_name = canonical_ingredient_name(name)
WHERE normalized_name IS NOT NULL
  AND normalized_name <> canonical_ingredient_name(name);
