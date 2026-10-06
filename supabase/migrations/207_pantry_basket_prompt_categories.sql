-- Migration 207: pantry/basket prompt — categories that match the app.
-- The live prompt (0170) offers "proteins" and "personal_care", which aren't
-- GroceryCategory values (the app has "meat", no personal_care), so those
-- items fell back to Other; and with no oils category, cooking oils were
-- filed under spices. The app now has an "oils" category.
--
-- Same approach as 204/205: copy the live prompt (highest active version)
-- into a new version with a CATEGORY RULES block appended. Old rows are
-- kept for rollback. Re-running is safe. Older app builds read "oils" as
-- Other (unknown names fall back), so this is safe to apply before release.

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, is_active, notes, prompt, schema_hint)
SELECT feature, sub_feature, input_type, version + 1, true,
       'categories aligned with the app (meat, oils; no proteins/personal_care)',
       prompt || $RULES$

CATEGORY RULES (these override any category list above):
- "category" must be exactly one of: vegetables, fruits, dairy, meat, grains, beverages, snacks, spices, oils, cleaning, other
- Chicken, mutton, fish, prawns, any meat → meat (never "proteins")
- Cooking oils (coconut, sunflower, groundnut, mustard, olive oil…) → oils (never spices)
- Eggs, milk, curd, paneer, butter, ghee → dairy
- Rice, dal, flour/atta, oats, bread, pasta → grains
- Salt, sugar, masalas, whole and powdered spices → spices
- Soap, shampoo, toothpaste, other personal care → other; detergent, floor cleaner → cleaning
$RULES$,
       schema_hint
FROM ai_prompts
WHERE feature = 'pantry' AND sub_feature = 'basket' AND input_type = 'text'
  AND is_active
  AND prompt NOT LIKE '%CATEGORY RULES (these override%'
ORDER BY version DESC
LIMIT 1
ON CONFLICT (feature, sub_feature, input_type, version) DO UPDATE
  SET prompt      = EXCLUDED.prompt,
      is_active   = true,
      schema_hint = EXCLUDED.schema_hint,
      notes       = EXCLUDED.notes;

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
    WHERE live.prompt LIKE '%CATEGORY RULES (these override%'
  ) THEN
    RAISE EXCEPTION 'pantry/basket prompt: no active text prompt found, or category rules not live';
  END IF;
END $$;
