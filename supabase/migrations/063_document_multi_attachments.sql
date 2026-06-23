-- ─────────────────────────────────────────────────────────────────────────────
-- 063 · Medical Documents — multi-attachment support
-- ─────────────────────────────────────────────────────────────────────────────

-- Add array column for multiple file URLs
ALTER TABLE health_documents
  ADD COLUMN IF NOT EXISTS file_urls TEXT[] NOT NULL DEFAULT '{}';

-- Migrate existing single-file rows into the array
UPDATE health_documents
   SET file_urls = ARRAY[file_url]
 WHERE file_url IS NOT NULL AND file_url <> '' AND array_length(file_urls, 1) IS NULL;
