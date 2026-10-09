-- Migration 210: dashboard/ai_assistant — "planning to buy" goes to the Wish List.
--
-- Bug: "I am planning to buy new A/C with cost around 40k" failed with
-- "AI returned an unexpected response" (ai_parse_logs: "JSON parse failed",
-- 4049 tokens both times). The prompt had no action for a planned purchase,
-- so the model deliberated between add_expense / add_grocery / add_task,
-- spent its output budget, and the JSON came back truncated. Had it
-- finished, the closest fit was add_expense — wrongly recording ₹40,000 as
-- already spent. (The parse edge function's output budget is raised in the
-- same change.)
--
-- Fix: a new add_wish action (PlanIt → Wish List). Older app builds can't
-- execute it and would show the confirmation text without saving anything,
-- so the prompt only offers add_wish when the client lists it in
-- client_actions (sent at the end of HOUSEHOLD CONTEXT by builds that
-- support it); otherwise it answers as a normal query.
--
-- Same approach as 207: copy the live prompt (highest active version) into a
-- new version with a rules block appended. Old rows are kept for rollback.
-- Re-running is safe.

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, is_active, notes, prompt, schema_hint)
SELECT feature, sub_feature, input_type, version + 1, true,
       'add_wish action for planned purchases (gated on client_actions)',
       prompt || $RULES$

PLANNED PURCHASES & WISHES (these override the rules above):
- Money not yet spent is NEVER add_expense. "planning to buy", "want to buy",
  "thinking of buying", "saving for", "wish", "need a new ..." for anything
  that is not a grocery/household consumable is a planned purchase.
- Amount shorthand: "40k" = 40000, "1.5L" / "1.5 lakh" = 150000.
- If HOUSEHOLD CONTEXT contains a line "client_actions:" that includes add_wish,
  return an ACTION with action_type "add_wish":
    data: { "title": "New A/C", "emoji": "❄️", "category": "home",
            "priority": "medium", "target_price": 40000,
            "target_date": "YYYY-MM-DD or null", "note": "" }
    category: electronics | fashion | home | travel | food | experience | other
      (appliances such as A/C, fridge, washing machine → home; phones, laptops, TVs → electronics)
    priority: low | medium | high | urgent (default medium)
    target_date: only if the user gave a time ("next month", "by Diwali"), else null
    confirm_message example: "Add New A/C (₹40,000) to your wish list?"
- If add_wish is NOT listed in client_actions, return an ANSWER instead:
  acknowledge the plan, and if all_expenses_this_period / budget data is
  available, say briefly how it fits this month. Add a deep_link
  { "label": "Open Wish List", "tab": "planit" }.
$RULES$,
       schema_hint
FROM ai_prompts
WHERE feature = 'dashboard' AND sub_feature = 'ai_assistant' AND input_type = 'text'
  AND is_active
  AND prompt NOT LIKE '%PLANNED PURCHASES & WISHES (these override%'
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
      WHERE feature = 'dashboard' AND sub_feature = 'ai_assistant' AND input_type = 'text'
        AND is_active
      ORDER BY version DESC
      LIMIT 1
    ) live
    WHERE live.prompt LIKE '%PLANNED PURCHASES & WISHES (these override%'
  ) THEN
    RAISE EXCEPTION 'dashboard/ai_assistant prompt: no active text prompt found, or wish rules not live';
  END IF;
END $$;
