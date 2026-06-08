-- ============================================================
--  WAI Life Assistant — Wardrobe Photos Storage Bucket
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'wardrobe-photos',
  'wardrobe-photos',
  true,
  5242880,   -- 5 MB per file
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
ON CONFLICT (id) DO NOTHING;

-- Users can read any photo in the bucket (public bucket)
CREATE POLICY "wardrobe_photos_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'wardrobe-photos');

-- Users can upload only to their own uid folder
CREATE POLICY "wardrobe_photos_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'wardrobe-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Users can delete only their own photos
CREATE POLICY "wardrobe_photos_delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'wardrobe-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
