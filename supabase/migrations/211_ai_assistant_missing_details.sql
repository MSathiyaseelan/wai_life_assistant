-- Migration 211: dashboard/ai_assistant — ask for missing details instead of
-- guessing an action, and keep follow-up chips self-contained.
--
-- Bug: after "How much did I spend this month?" the assistant offered the
-- follow-up chip "Add an expense?". Tapping a chip sends its text as the next
-- message, so the model received an action request with no amount, title or
-- category. The prompt had no rule for that case; the model deliberated until
-- its output was truncated (ai_parse_logs 2026-09-23: "JSON parse failed",
-- ~3870 tokens, twice). With a larger output budget (parse edge function) it
-- would no longer fail outright, but would likely invent an expense instead.
--
-- Fix:
--   1. If an action's required details are missing, answer with a short
--      question asking for them — never return an action with guessed values.
--   2. Follow-up suggestions must make sense when sent on their own: either
--      a question about the user's data, or a complete action with example
--      values ("Spent ₹200 on lunch today").
--
-- Same approach as 207/210: copy the live prompt (highest active version) into
-- a new version with a rules block appended. Old rows are kept for rollback.
-- Re-running is safe. Works with every app build (no new action types).

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, is_active, notes, prompt, schema_hint)
SELECT feature, sub_feature, input_type, version + 1, true,
       'ask for missing action details; self-contained follow-up chips',
       prompt || $RULES$

MISSING DETAILS (these override the rules above):
- Never return an ACTION with invented values. Required details per action:
    add_expense / add_income  → amount (title/category can be inferred from the message)
    add_lend / add_borrow     → amount and person
    add_grocery               → item name
    add_task / add_reminder   → what it is about (date/time may default as described above)
    add_wish                  → what the item is
    add_function_upcoming     → whose function or what function
    add_special_day           → whose occasion and the date
    add_appointment           → doctor or reason
- If the user clearly wants an action but a required detail is missing
  (e.g. "Add an expense", "remind me", "add to wish list"), return an ANSWER
  (response_type "answer") that asks for exactly what is missing in one short
  sentence, e.g. "Sure — how much did you spend, and on what?". Put 2
  complete example messages in "suggestions" that the user can tap, e.g.
  ["Spent ₹200 on lunch today", "Paid ₹1,500 electricity bill online"].

FOLLOW-UP SUGGESTIONS:
- Tapping a suggestion sends its text as the user's next message, so every
  suggestion must work on its own:
    • a question about their data ("How much did I spend on food this month?"), or
    • a complete action with example values ("Spent ₹200 on lunch today").
- Never suggest a bare action with no details ("Add an expense?", "Set a reminder?").
$RULES$,
       schema_hint
FROM ai_prompts
WHERE feature = 'dashboard' AND sub_feature = 'ai_assistant' AND input_type = 'text'
  AND is_active
  AND prompt NOT LIKE '%MISSING DETAILS (these override%'
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
    WHERE live.prompt LIKE '%MISSING DETAILS (these override%'
      AND live.prompt LIKE '%PLANNED PURCHASES & WISHES (these override%'
  ) THEN
    RAISE EXCEPTION 'dashboard/ai_assistant prompt: missing-details rules not live, or built on a version without the wish rules (apply 210 first)';
  END IF;
END $$;
