-- ============================================================
--  WAI Life Assistant — Item Locator Schema
--  Tables: item_locator_containers, item_locator_items
-- ============================================================

-- ── Storage Containers ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS item_locator_containers (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id   TEXT        NOT NULL,
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type        TEXT        NOT NULL DEFAULT 'other',
  name        TEXT        NOT NULL,
  location    TEXT,
  notes       TEXT,
  color       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE item_locator_containers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "item_locator_containers_user_policy" ON item_locator_containers;
CREATE POLICY "item_locator_containers_user_policy" ON item_locator_containers
  FOR ALL USING (user_id = auth.uid());

DROP TRIGGER IF EXISTS trg_item_locator_containers_updated_at ON item_locator_containers;
CREATE TRIGGER trg_item_locator_containers_updated_at
  BEFORE UPDATE ON item_locator_containers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Stored Items ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS item_locator_items (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id    TEXT        NOT NULL,
  user_id      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  container_id UUID        NOT NULL REFERENCES item_locator_containers(id) ON DELETE CASCADE,
  name         TEXT        NOT NULL,
  description  TEXT,
  category     TEXT,
  emoji        TEXT,
  stored_on    DATE        NOT NULL DEFAULT CURRENT_DATE,
  stored_by    TEXT,
  notes        TEXT,
  is_fragile   BOOLEAN     NOT NULL DEFAULT FALSE,
  is_important BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE item_locator_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "item_locator_items_user_policy" ON item_locator_items;
CREATE POLICY "item_locator_items_user_policy" ON item_locator_items
  FOR ALL USING (user_id = auth.uid());

DROP TRIGGER IF EXISTS trg_item_locator_items_updated_at ON item_locator_items;
CREATE TRIGGER trg_item_locator_items_updated_at
  BEFORE UPDATE ON item_locator_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
