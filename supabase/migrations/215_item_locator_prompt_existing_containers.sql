-- Migration 215: item locator prompt — reuse the user's existing containers.
-- The app sends the user's containers ("Bedroom box (Bedroom), ...") as
-- context, but the live prompt (0170) never referenced them and only offered
-- generic container types, so "add screw driver into bedroom box" came back
-- as container "box" and the app created a new "Box" container instead of
-- using "Bedroom box". Also asks for an "item_names" array so a sentence
-- naming several items is stored as separate items (app reads it from the
-- multi-item release on; older builds keep using "item_name").
--
-- Requires the parse edge function that fills {{containers}} — deploy it
-- BEFORE applying this, or the literal placeholder reaches the model.
--
-- Same approach as 204/205/207: copy the live prompt (highest active
-- version) into a new version with a rules block appended. Old rows are
-- kept for rollback. Re-running is safe. Older app builds already read
-- container_label, so this is safe to apply before release.

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, is_active, notes, prompt, schema_hint)
SELECT feature, sub_feature, input_type, version + 1, true,
       'match existing containers via container_label',
       prompt || $RULES$

EXISTING CONTAINER RULES (these override the container guidance above):
The user's existing containers are: {{containers}}
- If the text refers to one of these containers (even partially, or with
  the room said separately — "bedroom box" → "Bedroom box"), set
  "container_label" to that container's name EXACTLY as listed.
- Only leave "container_label" null when no listed container fits; then
  describe the new place in "container" and "location" as before.

MULTIPLE ITEMS:
- Also return "item_names": a JSON array with one entry per distinct item,
  each a short Title Case name. "screw driver and power bank" →
  ["Screw driver", "Power bank"]; "passport, PAN card and keys" →
  ["Passport", "PAN card", "Keys"].
- Do NOT split a single item whose name contains "and" ("salt and pepper
  shaker", "Tom and Jerry DVD") — that is one entry.
- For a single item, "item_names" has exactly one entry. Keep "item_name"
  as the full phrase for older app versions.
$RULES$,
       schema_hint
FROM ai_prompts
WHERE feature = 'mylife' AND sub_feature = 'item_locator' AND input_type = 'text'
  AND is_active
  AND prompt NOT LIKE '%EXISTING CONTAINER RULES (these override%'
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
      WHERE feature = 'mylife' AND sub_feature = 'item_locator' AND input_type = 'text'
        AND is_active
      ORDER BY version DESC
      LIMIT 1
    ) live
    WHERE live.prompt LIKE '%EXISTING CONTAINER RULES (these override%'
  ) THEN
    RAISE EXCEPTION 'mylife/item_locator prompt: no active text prompt found, or container rules not live';
  END IF;
END $$;
