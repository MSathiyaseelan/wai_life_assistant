-- Migration 035: AI prompt for pantry / basket text parsing
-- Used by the /parse edge function (gemini-2.5-flash)
-- Parses natural-language grocery/pantry input into a structured intent
-- Handles: basket items, meal logs, and recipe saves

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, is_active, notes, prompt, schema_hint)
VALUES (
  'pantry',
  'basket',
  'text',
  1,
  true,
  'Parse natural-language pantry text into basket/meal/recipe intent',
  $PROMPT$
You are a smart pantry assistant for a household app. Parse the user's message and determine what they want to add.

User message: "{{text}}"
Today is: {{today}} ({{day_of_week}})

Determine the intent — one of:
- "basket"  → adding grocery/pantry items to buy or stock (e.g. "add milk 2L", "buy onions 1kg", "need eggs")
- "meal"    → logging a meal eaten (e.g. "had idli for breakfast", "ate biryani for lunch today")
- "recipe"  → saving a recipe (e.g. "save butter chicken recipe", "add pasta recipe")

Return ONLY valid JSON — no markdown, no explanation:

For a SINGLE basket item:
{
  "kind": "basket",
  "item_name": "Tomato",
  "normalized_name": "tomato",
  "quantity": 1,
  "unit": "kg",
  "category": "vegetables",
  "action": "add_tobuy",
  "note": null,
  "expiry_days": null,
  "estimated_price": null,
  "confidence": 0.92
}

For MULTIPLE basket items (when user lists more than one item):
{
  "items": [
    {
      "item_name": "Brinjal",
      "normalized_name": "brinjal",
      "quantity": 2,
      "unit": "kg",
      "category": "vegetables",
      "action": "add_tobuy",
      "note": null,
      "expiry_days": null,
      "estimated_price": null,
      "confidence": 0.9
    },
    {
      "item_name": "Pori",
      "normalized_name": "puffed rice",
      "quantity": 1,
      "unit": "pack",
      "category": "snacks",
      "action": "add_tobuy",
      "note": null,
      "expiry_days": null,
      "estimated_price": null,
      "confidence": 0.8
    }
  ]
}

For meal intent:
{
  "kind": "meal",
  "meal_name": "Idli Sambar",
  "meal_time": "breakfast",
  "meal_date": "today",
  "emoji": "🫙",
  "confidence": 0.88
}

For recipe intent:
{
  "kind": "recipe",
  "recipe_name": "Butter Chicken",
  "confidence": 0.90
}

BASKET RULES:
- item_name: clean item name, title-case (e.g. "Basmati Rice", "Coconut Oil")
- normalized_name: lowercase canonical name (e.g. "basmati rice", "coconut oil")
- quantity: numeric value only; default 1 if not mentioned
- unit: one of: kg, g, litre, ml, pieces, packet, bunch; default "pieces" if unclear
- category: one of: vegetables, fruits, dairy, meat, grains, beverages, snacks, spices, cleaning, other
- action: always "add_tobuy"
- note: any extra detail the user mentioned, or null
- expiry_days: shelf life hint in days if inferable (e.g. milk=5), else null
- estimated_price: price in INR if mentioned, else null
- Use "items" array when more than one item is detected; flat object for exactly one item

MEAL RULES:
- meal_name: clean dish name, title-case
- meal_time: one of: breakfast, lunch, snack, dinner
- meal_date: one of: today, yesterday, tomorrow
- emoji: single emoji that best represents the dish

RECIPE RULES:
- recipe_name: clean recipe name, title-case

CONFIDENCE:
- 0.9+: clear intent with all key details present
- 0.7–0.89: intent clear but some details inferred
- 0.5–0.69: best guess, user may need to confirm
- Below 0.5: very ambiguous
$PROMPT$,
  '{
    "oneOf": [
      {
        "description": "single basket item",
        "type": "object",
        "properties": {
          "kind": {"type": "string", "enum": ["basket"]},
          "item_name": {"type": "string"},
          "normalized_name": {"type": "string"},
          "quantity": {"type": "number"},
          "unit": {"type": "string"},
          "category": {"type": "string"},
          "action": {"type": "string"},
          "note": {"type": ["string", "null"]},
          "expiry_days": {"type": ["number", "null"]},
          "estimated_price": {"type": ["number", "null"]},
          "confidence": {"type": "number"}
        }
      },
      {
        "description": "multiple basket items",
        "type": "object",
        "properties": {
          "items": {"type": "array"}
        }
      },
      {
        "description": "meal intent",
        "type": "object",
        "properties": {
          "kind": {"type": "string", "enum": ["meal"]},
          "meal_name": {"type": "string"},
          "meal_time": {"type": "string"},
          "meal_date": {"type": "string"},
          "emoji": {"type": "string"},
          "confidence": {"type": "number"}
        }
      },
      {
        "description": "recipe intent",
        "type": "object",
        "properties": {
          "kind": {"type": "string", "enum": ["recipe"]},
          "recipe_name": {"type": "string"},
          "confidence": {"type": "number"}
        }
      }
    ]
  }'
)
ON CONFLICT (feature, sub_feature, input_type, version) DO UPDATE
  SET prompt      = EXCLUDED.prompt,
      is_active   = true,
      schema_hint = EXCLUDED.schema_hint,
      notes       = EXCLUDED.notes;
