-- ============================================================
-- 194_restore_split_group_ai_prompt.sql
--
-- Restores the wallet/split_group AI prompt from 071_split_group_ai_prompt.sql,
-- which was deleted in 08732dd ("migration issues fixed") and never recreated.
-- Existing databases already have the row (dev from the original 071, PROD
-- added by hand), but a fresh environment built from this folder wouldn't —
-- the /parse edge function then finds no prompt and the split group sheet's
-- "describe with AI" (split_group_sheet.dart) fails.
--
-- ON CONFLICT DO NOTHING (rather than 071's DO UPDATE) so the existing
-- rows — possibly tuned since — are left untouched.
-- ============================================================

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, is_active, notes, prompt, schema_hint)
VALUES (
  'wallet',
  'split_group',
  'text',
  1,
  true,
  'Parse natural-language text into a split group name and participant list',
  $PROMPT$
You are a smart expense-splitting assistant. The user wants to create a split group and has described it in natural language. Extract the group name and the list of participants (NOT including the user themselves).

User message: "{{text}}"
Today is: {{today}} ({{day_of_week}})

Rules:
- group_name: A clean, concise name for the group. Title-case. Infer from context (e.g. "Goa Trip", "Office Lunch", "Roommates").
- emoji: A single emoji that best represents the group purpose (e.g. ✈️ for travel, 🍕 for food, 🏠 for home, 🎉 for party, 💼 for work, 👥 for general).
- participants: Array of people mentioned (exclude "me", "I", "myself", "us"). Each entry has:
  - name: The person's name as mentioned (title-case). For @Mentions strip the @.
  - phone: Phone number if mentioned, else omit or null.
- confidence: How confident you are in the parse (0.0–1.0).

Return ONLY valid JSON — no markdown, no explanation:

{
  "group_name": "Goa Trip",
  "emoji": "✈️",
  "participants": [
    {"name": "Rahul"},
    {"name": "Priya", "phone": "+919876543210"},
    {"name": "Suresh"}
  ],
  "confidence": 0.92
}

EXAMPLES:
- "Goa trip with Rahul, Priya and Suresh" → group_name: "Goa Trip", emoji: ✈️, participants: [Rahul, Priya, Suresh]
- "Office team lunch with Kiran and Preethi" → group_name: "Office Lunch", emoji: 💼, participants: [Kiran, Preethi]
- "Flat expenses with @Arun and @Meena" → group_name: "Flat Expenses", emoji: 🏠, participants: [Arun, Meena]
- "Birthday party for Amma with all siblings Raja and Mala" → group_name: "Amma Birthday", emoji: 🎂, participants: [Raja, Mala]
- "Weekend trip with friends Vijay, Karthik" → group_name: "Weekend Trip", emoji: 🏕️, participants: [Vijay, Karthik]

CONFIDENCE:
- 0.9+: Clear group name and participants identified
- 0.7–0.89: Group name or some participants inferred
- 0.5–0.69: Ambiguous, best guess
$PROMPT$,
  '{
    "type": "object",
    "properties": {
      "group_name": {"type": "string"},
      "emoji": {"type": "string"},
      "participants": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "name": {"type": "string"},
            "phone": {"type": ["string", "null"]}
          },
          "required": ["name"]
        }
      },
      "confidence": {"type": "number"}
    },
    "required": ["group_name", "participants", "confidence"]
  }'
)
ON CONFLICT (feature, sub_feature, input_type, version) DO NOTHING;
