-- ============================================================
-- user_fcm_tokens
-- Backfilled migration: this table existed on dev via manual
-- SQL Editor changes but was never captured in migration history.
-- Reconstructed from the live dev schema.
-- ============================================================

CREATE TABLE IF NOT EXISTS user_fcm_tokens (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token   TEXT        NOT NULL,
  platform    TEXT        NOT NULL,
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, platform)
);

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user ON user_fcm_tokens(user_id);
