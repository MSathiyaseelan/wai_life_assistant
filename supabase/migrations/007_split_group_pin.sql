-- ─────────────────────────────────────────────────────────────────────────────
-- 007_split_group_pin.sql
-- Add pinned_to_dashboard flag to split_groups so users can surface active
-- groups on the Dashboard for quick expense entry.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE split_groups
  ADD COLUMN IF NOT EXISTS pinned_to_dashboard BOOLEAN NOT NULL DEFAULT FALSE;
