-- Migration 205: pantry/basket prompt — bring back multi-item parsing.
-- The live prompt (seeded by 0170; 035's multi-item version never went live)
-- returns one flat object, so "add brinjal 2kg and pori 1 pack" only ever
-- added the first item. The app already handles {"items": [...]}
-- (pantry_screen.dart _mapBasketItems), it just never received one.
--
-- Same approach as 204: copy the live prompt (highest active version) into a
-- new version with a MULTIPLE ITEMS block appended, so hand edits and 204's
-- UNIT RULES carry over. Old rows are kept for rollback. Re-running is safe.

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, is_active, notes, prompt, schema_hint)
SELECT feature, sub_feature, input_type, version + 1, true,
       'multi-item: {"items": [...]} when more than one item is listed',
       prompt || $RULES$

MULTIPLE ITEMS (this overrides the single-object format above when it applies):
- If the user lists MORE THAN ONE item ("brinjal 2kg, pori 1 pack and milk"), return {"items": [ ... ]} — one object per item, each with the same fields as the single-item format (item_name, quantity, unit, category, action, estimated_price, expiry_days, note, confidence)
- Also add "normalized_name" to each item: lowercase canonical name ("Pori" → "puffed rice", "Brinjal" → "brinjal")
- Each item gets its own quantity, unit and action; apply the UNIT and ACTION rules to every item
- For exactly ONE item, keep returning the single flat object — never an "items" array of one
- Example: "need brinjal 2kg and pori 1 pack" →
{"items": [
  {"item_name": "Brinjal", "normalized_name": "brinjal", "quantity": 2, "unit": "kg", "category": "vegetables", "action": "add_tobuy", "estimated_price": null, "expiry_days": null, "note": null, "confidence": 0.9},
  {"item_name": "Pori", "normalized_name": "puffed rice", "quantity": 1, "unit": "pack", "category": "snacks", "action": "add_tobuy", "estimated_price": null, "expiry_days": null, "note": null, "confidence": 0.8}
]}
$RULES$,
       schema_hint
FROM ai_prompts
WHERE feature = 'pantry' AND sub_feature = 'basket' AND input_type = 'text'
  AND is_active
  AND prompt NOT LIKE '%MULTIPLE ITEMS (this overrides%'
ORDER BY version DESC
LIMIT 1
ON CONFLICT (feature, sub_feature, input_type, version) DO UPDATE
  SET prompt      = EXCLUDED.prompt,
      is_active   = true,
      schema_hint = EXCLUDED.schema_hint,
      notes       = EXCLUDED.notes;

-- The prompt the edge function will now pick must carry the new block.
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
    WHERE live.prompt LIKE '%MULTIPLE ITEMS (this overrides%'
  ) THEN
    RAISE EXCEPTION 'pantry/basket prompt: no active text prompt found, or multi-item block not live';
  END IF;
END $$;
