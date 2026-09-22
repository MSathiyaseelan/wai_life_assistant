-- ============================================================
--  Pantry: add "Beverages" as a 5th Meal Type
--  (Breakfast, Lunch, Dinner, Snacks, Beverages)
--
--  meal_entries.meal_time was CHECK-constrained to the original
--  4 values ('breakfast','lunch','snack','dinner') — widen it to
--  also accept 'beverages' so the new Add Meal chip can be saved.
-- ============================================================

ALTER TABLE meal_entries
  DROP CONSTRAINT IF EXISTS meal_entries_meal_time_check,
  ADD CONSTRAINT meal_entries_meal_time_check
    CHECK (meal_time IN ('breakfast','lunch','snack','dinner','beverages'));
