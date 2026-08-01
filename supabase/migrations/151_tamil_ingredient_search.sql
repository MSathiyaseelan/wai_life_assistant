-- ============================================================
-- 151_tamil_ingredient_search.sql
--
-- Lets a user type/search an ingredient in Tamil (e.g. "கத்தரிக்காய்") and
-- have it resolve to the same canonical ingredient as its English name
-- ("brinjal") — reusing the exact same ingredient_aliases mechanism as the
-- English synonym pairs (149_ingredient_aliases.sql): a Tamil word is just
-- another alias pointing at the same canonical key.
--
-- normalize_grocery_name() previously stripped every non a-z0-9 character,
-- which would erase Tamil script entirely before it ever reached the alias
-- lookup. Fixed by explicitly keeping the Tamil Unicode block (U+0B80-
-- U+0BFF) alongside the existing ASCII allow-list. Plain [:alpha:] is NOT
-- enough here — Tamil vowel signs and the pulli (virama) mark are
-- combining characters, not letters, so [:alpha:] strips them and corrupts
-- the word (verified: "கத்தரிக்காய்" -> "கததரககய", losing the marks that
-- make it a valid, distinct word). Whitelisting the whole block keeps
-- those marks.
--
-- To add another language later: extend the same character class with its
-- Unicode block range and seed its alias rows the same way as below.
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
  s := regexp_replace(s, '[^a-z0-9஀-௿ ]', '', 'g');
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

-- Seed common Tamil grocery/ingredient terms. Add more anytime with a
-- plain INSERT — no app release needed, same as the English synonyms.
INSERT INTO ingredient_aliases (alias, canonical) VALUES
  ('கத்தரிக்காய்', 'brinjal'),
  ('தக்காளி', 'tomato'),
  ('வெங்காயம்', 'onion'),
  ('உருளைக்கிழங்கு', 'potato'),
  ('காரட்', 'carrot'),
  ('பீன்ஸ்', 'beans'),
  ('பூண்டு', 'garlic'),
  ('இஞ்சி', 'ginger'),
  ('மிளகாய்', 'chilli'),
  ('காய்ந்த மிளகாய்', 'dry chilli'),
  ('மிளகு', 'pepper'),
  ('மஞ்சள் தூள்', 'turmeric powder'),
  ('கொத்தமல்லி', 'coriander'),
  ('புதினா', 'mint'),
  ('கறிவேப்பிலை', 'curry leaves'),
  ('பாகற்காய்', 'bitter gourd'),
  ('வெண்டைக்காய்', 'okra'),
  ('முருங்கைக்காய்', 'moringa'),
  ('பீர்க்கங்காய்', 'ridge gourd'),
  ('கீரை', 'spinach'),
  ('தேங்காய்', 'coconut'),
  ('பருப்பு', 'lentils'),
  ('அரிசி', 'rice'),
  ('பால்', 'milk'),
  ('தயிர்', 'curd'),
  ('வெண்ணெய்', 'butter'),
  ('நெய்', 'ghee'),
  ('முட்டை', 'egg'),
  ('சர்க்கரை', 'sugar'),
  ('உப்பு', 'salt')
ON CONFLICT (alias) DO NOTHING;

-- Re-canonicalize existing grocery_items rows affected by the normalizer
-- change, same backfill approach as 087/149/150.
UPDATE grocery_items
SET normalized_name = canonical_ingredient_name(name)
WHERE normalized_name IS NOT NULL
  AND normalized_name <> canonical_ingredient_name(name);
