-- Migration 023: Track meal preparation status and serving count
-- meal_status: 'planned' (default) | 'cooked' (prepared at home) | 'ordered' (bought outside)
-- servings_count: how many members it was prepared for (defaults to 1)

ALTER TABLE meal_entries
  ADD COLUMN IF NOT EXISTS meal_status TEXT DEFAULT 'planned'
    CHECK (meal_status IN ('planned', 'cooked', 'ordered')),
  ADD COLUMN IF NOT EXISTS servings_count INTEGER DEFAULT 1;
