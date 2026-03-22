-- ── App Remote Config ────────────────────────────────────────────────────────
-- Key-value table for server-controlled feature flags and limits.
-- Readable by any authenticated user; writable only by service_role (admin).

CREATE TABLE IF NOT EXISTS app_config (
  key         TEXT PRIMARY KEY,
  value       TEXT NOT NULL,
  description TEXT
);

-- No RLS needed — the table is not user-scoped.
-- All authenticated users can read; writes require service_role key.
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can read app_config"
  ON app_config FOR SELECT
  USING (auth.role() = 'authenticated');

-- ── V1 seed values ────────────────────────────────────────────────────────────
INSERT INTO app_config (key, value, description) VALUES
  ('max_family_groups', '1', 'V1: max family/group wallets per user. Increase to allow more (V2+).')
ON CONFLICT (key) DO NOTHING;
