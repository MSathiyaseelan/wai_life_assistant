-- ============================================================
-- WAI AI Assistant — add is_grocery field to add_grocery schema
-- Food/beverage items → is_grocery: true  (Grocery sub-list)
-- Non-food items (electronics, personal care, household) → is_grocery: false (Personal Care sub-list)
-- ============================================================

UPDATE ai_prompts
SET prompt = replace(
  prompt,
  'add_grocery — add item to shopping list
  data: { "name": "Milk", "qty": 2, "unit": "L", "category": "dairy" }
  categories: vegetables, fruits, dairy, grains, meat, snacks, beverages, cleaning, personal_care, other',

  'add_grocery — add item to shopping list
  data: { "name": "Milk", "qty": 2, "unit": "L", "category": "dairy", "is_grocery": true }
  categories: vegetables, fruits, dairy, grains, meat, snacks, beverages, cleaning, personal_care, other
  is_grocery rules — set true for: food, vegetables, fruits, dairy, eggs, meat, fish, beverages, snacks, grains, spices, cooking ingredients
                   — set false for: electronics, gadgets, appliances, personal care (shampoo, soap, toothpaste), cleaning supplies, stationery, clothing, medicine, toys, home decor, batteries, remote controls, cables, furniture, tools'
)
WHERE feature = 'dashboard'
  AND sub_feature = 'ai_assistant'
  AND is_active = true;
