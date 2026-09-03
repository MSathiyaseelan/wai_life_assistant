-- ============================================================
-- 163_split_share_extension_history.sql
--
-- split_shares.extension_date/extension_reason are single-value columns —
-- each new extension request overwrites the previous one, so there was no
-- way to see that a share had been extended multiple times, or what the
-- earlier requests said. This adds an append-only history table, populated
-- automatically via a trigger whenever a share's status transitions to
-- 'extension_requested', so every client code path that requests an
-- extension gets history for free without needing its own INSERT.
-- ============================================================

CREATE TABLE IF NOT EXISTS split_share_extension_history (
  id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  share_id          UUID          NOT NULL REFERENCES split_shares(id) ON DELETE CASCADE,
  requested_by      UUID          REFERENCES profiles(id) ON DELETE SET NULL,
  extension_date    TIMESTAMPTZ   NOT NULL,
  extension_reason  TEXT,
  requested_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_split_share_ext_history_share ON split_share_extension_history(share_id, requested_at DESC);

ALTER TABLE split_share_extension_history ENABLE ROW LEVEL SECURITY;

-- Same visibility as the parent share: any participant of the group the
-- share's transaction belongs to.
DROP POLICY IF EXISTS "split_share_extension_history: select" ON split_share_extension_history;
CREATE POLICY "split_share_extension_history: select" ON split_share_extension_history
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM split_shares ss
      JOIN split_group_transactions sgt ON sgt.id = ss.transaction_id
      JOIN split_participants sp ON sp.group_id = sgt.group_id
      WHERE ss.id = split_share_extension_history.share_id AND sp.user_id = auth.uid()
    )
  );

-- No INSERT/UPDATE/DELETE policy for regular users — only the trigger
-- (SECURITY DEFINER) below writes to this table.

CREATE OR REPLACE FUNCTION record_split_share_extension_history()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'extension_requested'
     AND NEW.extension_date IS NOT NULL
     AND (OLD.status IS DISTINCT FROM NEW.status
          OR OLD.extension_date IS DISTINCT FROM NEW.extension_date
          OR OLD.extension_reason IS DISTINCT FROM NEW.extension_reason) THEN
    INSERT INTO split_share_extension_history (share_id, requested_by, extension_date, extension_reason)
    VALUES (NEW.id, auth.uid(), NEW.extension_date, NEW.extension_reason);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_record_split_share_extension_history ON split_shares;
CREATE TRIGGER trg_record_split_share_extension_history
  AFTER UPDATE ON split_shares
  FOR EACH ROW
  EXECUTE FUNCTION record_split_share_extension_history();
