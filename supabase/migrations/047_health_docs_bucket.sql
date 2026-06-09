-- ============================================================
--  WAI Life Assistant — Health Documents Storage Bucket
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'health-docs',
  'health-docs',
  true,
  10485760,  -- 10 MB per file
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "health_docs_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'health-docs');

CREATE POLICY "health_docs_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'health-docs'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "health_docs_delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'health-docs'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
