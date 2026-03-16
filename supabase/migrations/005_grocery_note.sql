-- Add note column to grocery_items
ALTER TABLE grocery_items ADD COLUMN IF NOT EXISTS note TEXT;
