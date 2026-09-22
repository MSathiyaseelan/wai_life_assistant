-- ============================================================
--  Functions: Dishes — add Meal Type
--
--  A function's catering menu is usually organised by which meal
--  it's served at (Breakfast / Lunch / Dinner / Snacks / Beverages),
--  same taxonomy as Pantry's MealTime. Optional — a dish can be
--  logged without pinning it to a specific meal.
-- ============================================================

ALTER TABLE function_dishes ADD COLUMN IF NOT EXISTS meal_time TEXT;

ALTER TABLE function_dishes DROP CONSTRAINT IF EXISTS function_dishes_meal_time_check;
ALTER TABLE function_dishes
  ADD CONSTRAINT function_dishes_meal_time_check
    CHECK (meal_time IS NULL OR meal_time IN ('breakfast','lunch','dinner','snack','beverages'));
