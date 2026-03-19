-- ─────────────────────────────────────────────────────────────────────────────
-- 010_tasks.sql
-- PlanIt My Tasks — per-wallet task storage
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS tasks (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id    UUID        NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  title        TEXT        NOT NULL,
  emoji        TEXT        NOT NULL DEFAULT '✅',
  description  TEXT,
  status       TEXT        NOT NULL DEFAULT 'todo'
               CHECK (status IN ('todo','inProgress','done')),
  priority     TEXT        NOT NULL DEFAULT 'medium'
               CHECK (priority IN ('low','medium','high','urgent')),
  due_date     DATE,
  project      TEXT,
  tags         TEXT[]      NOT NULL DEFAULT '{}',
  assigned_to  TEXT        NOT NULL DEFAULT 'me',
  subtasks     JSONB       NOT NULL DEFAULT '[]',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tasks_wallet ON tasks(wallet_id);
CREATE INDEX idx_tasks_status ON tasks(status);

CREATE TRIGGER trg_tasks_updated_at
  BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Members of a wallet's family (or personal wallet owner) can read tasks
CREATE POLICY "tasks: wallet members can view" ON tasks
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM wallets w
      WHERE w.id = tasks.wallet_id
        AND (
          w.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM family_members fm
            WHERE fm.family_id = w.family_id AND fm.user_id = auth.uid()
          )
        )
    )
  );

CREATE POLICY "tasks: wallet members can insert" ON tasks
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM wallets w
      WHERE w.id = tasks.wallet_id
        AND (
          w.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM family_members fm
            WHERE fm.family_id = w.family_id AND fm.user_id = auth.uid()
          )
        )
    )
  );

CREATE POLICY "tasks: wallet members can update" ON tasks
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM wallets w
      WHERE w.id = tasks.wallet_id
        AND (
          w.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM family_members fm
            WHERE fm.family_id = w.family_id AND fm.user_id = auth.uid()
          )
        )
    )
  );

CREATE POLICY "tasks: wallet members can delete" ON tasks
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM wallets w
      WHERE w.id = tasks.wallet_id
        AND (
          w.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM family_members fm
            WHERE fm.family_id = w.family_id AND fm.user_id = auth.uid()
          )
        )
    )
  );
