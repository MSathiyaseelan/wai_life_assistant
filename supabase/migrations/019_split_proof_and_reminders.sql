-- ============================================================
--  Split: Proof Storage Bucket + Reminder Tracking
-- ============================================================

-- ── Storage bucket for payment proof images ─────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'split-proof',
  'split-proof',
  false,
  5242880, -- 5 MB
  ARRAY['image/jpeg','image/png','image/webp','image/heic']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "split_proof: authenticated upload"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'split-proof' AND auth.uid() IS NOT NULL);

CREATE POLICY "split_proof: authenticated view"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'split-proof' AND auth.uid() IS NOT NULL);

-- ── Reminder tracking columns on split_shares ────────────────
ALTER TABLE split_shares
  ADD COLUMN IF NOT EXISTS reminder_count   INT          NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_reminder_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_reminder_by TEXT;

-- ── Atomic increment RPC ─────────────────────────────────────
CREATE OR REPLACE FUNCTION increment_split_reminder(
  p_transaction_id  UUID,
  p_participant_id  UUID,
  p_sent_by         TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE split_shares
  SET
    reminder_count   = reminder_count + 1,
    last_reminder_at = NOW(),
    last_reminder_by = p_sent_by
  WHERE transaction_id = p_transaction_id
    AND participant_id  = p_participant_id;
END;
$$;
