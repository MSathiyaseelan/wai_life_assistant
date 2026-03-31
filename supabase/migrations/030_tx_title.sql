-- Add optional title field to transactions
-- Title is a short user-provided label (e.g. "Dinner at Zomato", "Monthly Salary")
-- Distinct from note (which is longer free-form text) and category (which is a tag)

ALTER TABLE transactions ADD COLUMN IF NOT EXISTS title TEXT;
