-- Migration: 040_error_logs.sql
-- Centralised error log — all app exceptions are stored here for review.

CREATE TABLE error_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Error details
  error_type      TEXT NOT NULL,
  error_message   TEXT NOT NULL,
  stack_trace     TEXT,

  -- Where it happened
  screen_name     TEXT,
  feature         TEXT,
  action          TEXT,

  -- Severity: critical | error | warning | info
  severity        TEXT DEFAULT 'error',

  -- User context
  user_id         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  family_id       UUID,
  app_scope       TEXT,  -- personal | family

  -- Device context
  device_os       TEXT,   -- android | ios
  os_version      TEXT,
  device_model    TEXT,
  app_version     TEXT,
  build_number    TEXT,

  -- Additional context
  extra_data      JSONB,

  -- Review workflow: new | reviewed | fixed | ignored
  status          TEXT DEFAULT 'new',

  -- Network state when error occurred
  was_online      BOOLEAN DEFAULT true,

  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for dashboard filtering
CREATE INDEX idx_error_logs_severity ON error_logs(severity, created_at DESC);
CREATE INDEX idx_error_logs_status   ON error_logs(status,   created_at DESC);
CREATE INDEX idx_error_logs_user     ON error_logs(user_id,  created_at DESC);
CREATE INDEX idx_error_logs_feature  ON error_logs(feature,  created_at DESC);
CREATE INDEX idx_error_logs_created  ON error_logs(created_at DESC);

-- RLS: any client can INSERT (logged-in or anonymous, pre-auth errors included).
-- No user-facing SELECT — only service-role / dashboard reads.
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow_error_insert"
  ON error_logs FOR INSERT
  WITH CHECK (user_id IS NULL OR user_id = auth.uid());
