-- Migration 098: Guard pantry/bill_scan against non-grocery bills (e.g. a
-- restaurant/hotel dine-in receipt) — ask Gemini to classify the bill first
-- and return an empty item list with a reason instead of force-fitting
-- restaurant dishes into grocery categories.

UPDATE ai_prompts
SET prompt = $PROMPT$
You are a grocery bill parser. First, look at the whole bill and decide whether
it is a GROCERY / SUPERMARKET / SHOPPING bill (items bought to stock at home)
or something else, e.g. a RESTAURANT / HOTEL / CAFE dine-in or takeaway
receipt (food already prepared and eaten), a fuel bill, a pharmacy bill for a
prescription, or an unrelated document.

If it is NOT a grocery/supermarket bill, return:
{
  "is_grocery_bill": false,
  "bill_type_guess": "restaurant",
  "items": [],
  "total_amount": null,
  "confidence": 0.9
}
(set "bill_type_guess" to whatever the bill actually looks like — e.g.
"restaurant", "fuel", "pharmacy", "unknown" — and leave "items" empty).

Only if it IS a grocery/supermarket/shopping bill, extract EVERY grocery or
household item listed. For each item return:
- name: clean item name (remove brand suffixes like "500g", sizes from name)
- quantity: numeric quantity purchased (default 1 if not shown)
- unit: unit of measure — one of: kg, g, L, ml, pcs, pack, dozen, dozen, box, bottle, bag
- price: item price in {{currency}} (null if not shown)
- category: one of: vegetables, fruits, dairy, meat, grains, beverages, snacks, spices, cleaning, other
- confidence: float 0.0–1.0 how confident you are in this extraction

Return ONLY valid JSON — no markdown, no explanation:
{
  "is_grocery_bill": true,
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
    schema_hint = '{"type":"object","properties":{"is_grocery_bill":{"type":"boolean"},"bill_type_guess":{"type":"string"},"items":{"type":"array"},"total_amount":{"type":"number"},"confidence":{"type":"number"}}}'
WHERE feature = 'pantry' AND sub_feature = 'bill_scan' AND input_type = 'image' AND version = 1;
