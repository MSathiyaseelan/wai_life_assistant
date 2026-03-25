-- Make split-proof bucket public so Image.network can load without auth headers.
-- The URL is only discoverable via split_shares (DB has RLS), so it's safe.
UPDATE storage.buckets SET public = true WHERE id = 'split-proof';
