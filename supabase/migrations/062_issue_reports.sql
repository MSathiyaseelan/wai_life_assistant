-- ─────────────────────────────────────────────────────────────────────────────
-- 062 · Issue Reports
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS issue_reports (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category      TEXT        NOT NULL DEFAULT 'bug',
    -- bug | crash | feature_request | performance | ui | other
  title         TEXT        NOT NULL,
  description   TEXT        NOT NULL DEFAULT '',
  screenshots   TEXT[]      NOT NULL DEFAULT '{}',
  device_info   JSONB       NOT NULL DEFAULT '{}',
  priority      TEXT        NOT NULL DEFAULT 'medium',
    -- low | medium | high
  status        TEXT        NOT NULL DEFAULT 'open',
    -- open | in_progress | resolved | closed
  admin_note    TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast user lookups
CREATE INDEX IF NOT EXISTS issue_reports_user_idx ON issue_reports(user_id, created_at DESC);

-- Updated-at trigger
CREATE OR REPLACE FUNCTION set_issue_report_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS issue_reports_updated_at ON issue_reports;
CREATE TRIGGER issue_reports_updated_at
  BEFORE UPDATE ON issue_reports
  FOR EACH ROW EXECUTE FUNCTION set_issue_report_updated_at();

-- RLS
ALTER TABLE issue_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own reports"
  ON issue_reports FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can read own reports"
  ON issue_reports FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Users cannot update status (admin-only via service-role); allow updating
-- non-status fields if you ever add an edit flow.
CREATE POLICY "Users can delete own open reports"
  ON issue_reports FOR DELETE TO authenticated
  USING (user_id = auth.uid() AND status = 'open');

-- ── Storage bucket ───────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'issue-screenshots',
  'issue-screenshots',
  true,
  5242880,   -- 5 MB per file
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Authenticated users can upload issue screenshots"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'issue-screenshots'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Issue screenshots are publicly readable"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'issue-screenshots');

CREATE POLICY "Users can delete own issue screenshots"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'issue-screenshots'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
