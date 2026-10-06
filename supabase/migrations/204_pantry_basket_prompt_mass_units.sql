-- Migration 204: pantry/basket prompt — stop mass nouns coming back as
-- "pieces". The prompt only said `default "pieces" if unclear`, so "rice 250"
-- or "dal 200" (grams, unit not spoken) were saved as 250 / 200 pcs.
--
-- Prompts get hand-edited in the Table Editor, so the live text can differ
-- from the seed in 035 — don't search-and-replace it. Instead take whatever
-- prompt is live now (highest active version) and append a UNIT RULES block
-- that overrides the old unit line, as a new version. The edge function
-- picks the highest active version; the old row is kept for rollback.
-- Re-running is safe: the source skips rows that already carry the block.

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, is_active, notes, prompt, schema_hint)
SELECT feature, sub_feature, input_type, version + 1, true,
       'mass nouns (rice, dal, flour, oil…) never in pieces',
       prompt || $RULES$

UNIT RULES (these override any unit rule above):
- Items bought by weight or volume are NEVER "pcs": rice, dal/lentils, flour/atta/maida/rava, sugar, salt, jaggery, poha, millets, seeds, spices/powders → kg or g; oil, ghee (loose), milk (loose), water (loose) → L or ml
- If the user gives a number without a unit for such an item, a large number (50 or more) means g / ml ("rice 250" → 250 g, "oil 500" → 500 ml); a small number means kg / L ("rice 5" → 5 kg)
- Use "pcs" only for things you count (eggs, fruits, bread loaves, soap bars); default to "pcs" only when the item is countable and no unit is given
- Write units exactly as: kg, g, L, ml, pcs, pack, bunch
$RULES$,
       schema_hint
FROM ai_prompts
WHERE feature = 'pantry' AND sub_feature = 'basket' AND input_type = 'text'
  AND is_active
  AND prompt NOT LIKE '%UNIT RULES (these override%'
ORDER BY version DESC
LIMIT 1
ON CONFLICT (feature, sub_feature, input_type, version) DO UPDATE
  SET prompt      = EXCLUDED.prompt,
      is_active   = true,
      schema_hint = EXCLUDED.schema_hint,
      notes       = EXCLUDED.notes;

-- The prompt the edge function will now pick must carry the new rules.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM (
      SELECT prompt FROM ai_prompts
      WHERE feature = 'pantry' AND sub_feature = 'basket' AND input_type = 'text'
        AND is_active
      ORDER BY version DESC
      LIMIT 1
    ) live
    WHERE live.prompt LIKE '%UNIT RULES (these override%'
  ) THEN
    RAISE EXCEPTION 'pantry/basket prompt: no active text prompt found, or unit rules not live';
  END IF;
END $$;
