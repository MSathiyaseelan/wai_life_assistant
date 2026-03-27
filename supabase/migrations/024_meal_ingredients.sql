-- Migration 024: Add manual ingredients list to meal_entries
-- Allows manually added meals (without a recipe link) to list their own ingredients
-- so they can be checked against basket In Stock items.

ALTER TABLE meal_entries
  ADD COLUMN IF NOT EXISTS ingredients TEXT[] DEFAULT '{}';
