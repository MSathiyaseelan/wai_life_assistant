-- ─────────────────────────────────────────────────────────────────────────────
-- 080_attended_function_groups.sql
-- Attended Function Groups — bundle multiple attended functions (e.g. all
-- functions attended for the same family) under one named master card.
-- Mirrors the tx_groups pattern from 032_tx_groups.sql, adapted to
-- functions_attended's ownership model (user_id, not wallet/family-shared).
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Group metadata table
CREATE TABLE IF NOT EXISTS attended_function_groups (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id  TEXT        NOT NULL,
  user_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name       TEXT        NOT NULL,
  emoji      TEXT        NOT NULL DEFAULT '👨‍👩‍👧',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_attended_function_groups_wallet ON attended_function_groups(wallet_id);

ALTER TABLE attended_function_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attended_function_groups_user_policy" ON attended_function_groups;
CREATE POLICY "attended_function_groups_user_policy" ON attended_function_groups
  FOR ALL USING (user_id = auth.uid());

-- 2. Link functions_attended → groups (nullable; SET NULL on group delete)
ALTER TABLE functions_attended
  ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES attended_function_groups(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_functions_attended_group ON functions_attended(group_id);
