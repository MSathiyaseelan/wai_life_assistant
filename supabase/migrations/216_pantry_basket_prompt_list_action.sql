-- Migration 216: pantry/basket prompt — one verb covers the whole list.
-- "bought brinjal 1kg, onion 1.5 kg and sugar 2 kg" came back with every
-- item as add_tobuy: 205's multi-item block says each item gets its own
-- action and its example is all add_tobuy, so the model judged each item
-- in isolation and lost the single leading "bought".
--
-- The app now also forces the sentence-level action client-side
-- (PantryNlpParser.stockIntent); this fixes it at the source for older
-- builds. Same approach as 204/205/207: copy the live prompt (highest
-- active version) into a new version with a rules block appended. Old rows
-- are kept for rollback. Re-running is safe. No edge function change needed.

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, is_active, notes, prompt, schema_hint)
SELECT feature, sub_feature, input_type, version + 1, true,
       'list-level action: one verb applies to every item',
       prompt || $RULES$

LIST ACTION RULES (these override any action guidance above):
- A verb said once applies to EVERY item in the list that follows it:
  "bought brinjal 1kg, onion 1.5kg and sugar 2kg" → all three add_stock;
  "need milk, eggs and bread" → all three add_tobuy.
- add_stock: bought, purchased, got, received, brought, picked up, have
- add_tobuy: need, buy, to buy, want, get, order, running low, out of, finished
- Only give items different actions when the text gives them different
  verbs ("bought milk, need eggs" → milk add_stock, eggs add_tobuy).
- No verb at all → add_tobuy.
$RULES$,
       schema_hint
FROM ai_prompts
WHERE feature = 'pantry' AND sub_feature = 'basket' AND input_type = 'text'
  AND is_active
  AND prompt NOT LIKE '%LIST ACTION RULES (these override%'
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
    WHERE live.prompt LIKE '%LIST ACTION RULES (these override%'
  ) THEN
    RAISE EXCEPTION 'pantry/basket prompt: no active text prompt found, or list action rules not live';
  END IF;
END $$;
