-- ============================================================
--  AI Prompt — Wallet Split Expense (split_expense)
-- ============================================================

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, notes, schema_hint, prompt)
VALUES (
  'wallet',
  'split_expense',
  'text',
  1,
  'Parse a group split expense from plain text',
  '{
    "description": "string",
    "amount": "number",
    "paid_by": "string|null",
    "category": "string|null",
    "split_type": "equally|unequally|percentage",
    "confidence": "number"
  }'::jsonb,
  $$ROLE: You are a group expense parser for a household split-expense app.

TASK: Extract split expense details from a plain text message for a shared group.

Input: "{{text}}"
Today is: {{today}}
Group members: {{members}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "description": "short description of what was spent on",
  "amount": 0,
  "paid_by": null,
  "category": "Food",
  "split_type": "equally",
  "confidence": 0.9
}

AMOUNT RULES:
- Extract numeric value only (no currency symbol)
- "500 rupees" → 500
- "1.5k" or "1500" → 1500
- "₹1200" → 1200
- Common Indian amounts: 500, 1000, 1500, 2000, 5000

PAID BY:
- Match name to group members: {{members}}
- "I paid" → first member in list if identifiable, else null
- "Ravi paid" → "Ravi" (exact or closest match from members)
- Not mentioned → null

SPLIT TYPE:
- "equally" / "split equally" / no mention → "equally"
- "unequally" / "different amounts" → "unequally"
- "percentage" / "40-60" / "percent" → "percentage"
- Default when unclear: "equally"

CATEGORY OPTIONS (pick the closest):
Food, Travel, Shopping, Entertainment, Utilities, Health, Others

DESCRIPTION:
- Short, clear title for the expense
- "lunch at restaurant" → "Lunch"
- "uber to airport" → "Uber"
- "grocery shopping" → "Groceries"
- "electricity bill" → "Electricity Bill"

CONFIDENCE:
- 0.9+: amount and description clearly mentioned
- 0.7–0.9: some inference needed
- Below 0.7: very ambiguous$$
)
ON CONFLICT (feature, sub_feature, input_type, version)
DO UPDATE SET
  prompt = EXCLUDED.prompt,
  schema_hint = EXCLUDED.schema_hint,
  notes = EXCLUDED.notes,
  updated_at = NOW();
