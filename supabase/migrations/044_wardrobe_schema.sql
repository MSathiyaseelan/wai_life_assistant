-- ============================================================
--  WAI Life Assistant — Wardrobe Schema
--  Tables: wardrobe_items, wardrobe_outfit_logs
-- ============================================================

-- ── Clothing Items ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wardrobe_items (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id       TEXT        NOT NULL,
  user_id         UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id       TEXT        NOT NULL DEFAULT 'me',
  name            TEXT        NOT NULL,
  category        TEXT        NOT NULL DEFAULT 'topwear',
  gender          TEXT        NOT NULL DEFAULT 'unisex',
  brand           TEXT,
  size            TEXT,
  color           TEXT,
  photo_path      TEXT,
  notes           TEXT,
  wishlist        BOOLEAN     NOT NULL DEFAULT FALSE,
  wishlist_source TEXT,
  match_with      JSONB       NOT NULL DEFAULT '[]',
  added_on        DATE        NOT NULL DEFAULT CURRENT_DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE wardrobe_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wardrobe_items_user_policy" ON wardrobe_items
  FOR ALL USING (user_id = auth.uid());

CREATE TRIGGER trg_wardrobe_items_updated_at
  BEFORE UPDATE ON wardrobe_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Outfit Logs ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wardrobe_outfit_logs (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id   TEXT        NOT NULL,
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id   TEXT        NOT NULL DEFAULT 'me',
  item_ids    JSONB       NOT NULL DEFAULT '[]',
  date        DATE        NOT NULL DEFAULT CURRENT_DATE,
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE wardrobe_outfit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wardrobe_outfit_logs_user_policy" ON wardrobe_outfit_logs
  FOR ALL USING (user_id = auth.uid());

CREATE TRIGGER trg_wardrobe_outfit_logs_updated_at
  BEFORE UPDATE ON wardrobe_outfit_logs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
