-- Migration 026: Seed ai_prompts row for pantry / bill_scan image parsing
-- Used by the /parse edge function with gemini-1.5-flash-8b

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, is_active, notes, prompt, schema_hint)
VALUES (
  'pantry',
  'bill_scan',
  'image',
  1,
  true,
  'Parse grocery bill image into structured items list with qty, unit, price, category',
  $PROMPT$
You are a grocery bill parser. Examine this bill, receipt, or shopping screenshot carefully.

Extract EVERY grocery or household item listed. For each item return:
- name: clean item name (remove brand suffixes like "500g", sizes from name)
- quantity: numeric quantity purchased (default 1 if not shown)
- unit: unit of measure — one of: kg, g, L, ml, pcs, pack, dozen, dozen, box, bottle, bag
- price: item price in {{currency}} (null if not shown)
- category: one of: vegetables, fruits, dairy, meat, grains, beverages, snacks, spices, cleaning, other
- confidence: float 0.0–1.0 how confident you are in this extraction

Return ONLY valid JSON — no markdown, no explanation:
{
  "items": [
    {
      "name": "Basmati Rice",
      "quantity": 5,
      "unit": "kg",
      "price": 450.00,
      "category": "grains",
      "confidence": 0.95
    }
  ],
  "total_amount": 1250.00,
  "confidence": 0.90
}

Rules:
- If quantity not visible, use 1
- If unit not visible, use "pcs"
- If price not visible, use null
- Only include food, grocery, and household items — skip taxes, delivery charges, discounts, store names
- Currency is {{currency}}
$PROMPT$,
  '{"type":"object","properties":{"items":{"type":"array"},"total_amount":{"type":"number"},"confidence":{"type":"number"}}}'
)
ON CONFLICT (feature, sub_feature, input_type, version) DO UPDATE
  SET prompt    = EXCLUDED.prompt,
      is_active = true,
      schema_hint = EXCLUDED.schema_hint;
