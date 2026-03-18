-- ─────────────────────────────────────────────────────────────────────────────
-- 008_reminders.sql
-- PlanIt Alert Me — reminder storage per wallet
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS reminders (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id    UUID        NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  title        TEXT        NOT NULL,
  emoji        TEXT        NOT NULL DEFAULT '🔔',
  due_date     DATE        NOT NULL,
  due_time     TEXT        NOT NULL DEFAULT '09:00',   -- stored as "HH:MM"
  repeat       TEXT        NOT NULL DEFAULT 'none'
               CHECK (repeat IN ('none','daily','weekly','monthly','yearly')),
  priority     TEXT        NOT NULL DEFAULT 'medium'
               CHECK (priority IN ('low','medium','high','urgent')),
  assigned_to  TEXT        NOT NULL DEFAULT 'me',
  snoozed      BOOLEAN     NOT NULL DEFAULT FALSE,
  done         BOOLEAN     NOT NULL DEFAULT FALSE,
  note         TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER reminders_updated_at
  BEFORE UPDATE ON reminders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage reminders for their wallets"
ON reminders
USING (
  wallet_id IN (
    SELECT id FROM wallets WHERE owner_id = auth.uid()
    UNION
    SELECT w.id FROM wallets w
    JOIN family_members fm ON fm.family_id = w.family_id
    WHERE fm.user_id = auth.uid()
  )
);
