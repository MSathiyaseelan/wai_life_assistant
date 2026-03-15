-- ============================================================
--  WAI Life Assistant — Pantry Module Schema
--  Tables: recipes, meal_entries, meal_reactions,
--          grocery_items, member_food_prefs
--
--  Run this in: Supabase Dashboard → SQL Editor
--  Requires: 001_wallet_schema.sql already applied
-- ============================================================


-- ── Reusable wallet-access helper ───────────────────────────────────────────
-- Returns TRUE if auth.uid() owns the wallet or is a family member of it.
CREATE OR REPLACE FUNCTION wallet_accessible(wid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM wallets w
    WHERE w.id = wid
      AND (
        w.owner_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM family_members fm
          WHERE fm.family_id = w.family_id
            AND fm.user_id   = auth.uid()
        )
      )
  );
$$;

-- Returns TRUE if auth.uid() is an admin of the wallet's family.
CREATE OR REPLACE FUNCTION wallet_admin(wid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM wallets w
    JOIN family_members fm ON fm.family_id = w.family_id
    WHERE w.id = wid
      AND fm.user_id = auth.uid()
      AND fm.role    = 'admin'
  ) OR EXISTS (
    SELECT 1 FROM wallets w
    WHERE w.id = wid AND w.owner_id = auth.uid()
  );
$$;


-- ══════════════════════════════════════════════════════════════
--  1. RECIPES  (Recipe Box tab)
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS recipes (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id     UUID        NOT NULL REFERENCES wallets(id)   ON DELETE CASCADE,
  created_by    UUID        NOT NULL REFERENCES profiles(id)  ON DELETE CASCADE,
  name          TEXT        NOT NULL,
  emoji         TEXT        NOT NULL DEFAULT '🍽️',
  cuisine       TEXT        NOT NULL
                            CHECK (cuisine IN (
                              'indian','chinese','italian','mexican',
                              'mediterranean','thai','japanese','continental'
                            )),
  suitable_for  TEXT[]      NOT NULL DEFAULT '{}',   -- e.g. ['breakfast','lunch']
  ingredients   TEXT[]      NOT NULL DEFAULT '{}',   -- free-text list
  social_link   TEXT,
  note          TEXT,
  cook_time_min INTEGER     CHECK (cook_time_min > 0),
  is_favourite  BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_recipes_wallet     ON recipes(wallet_id);
CREATE INDEX idx_recipes_cuisine    ON recipes(cuisine);
CREATE INDEX idx_recipes_favourite  ON recipes(wallet_id, is_favourite);

CREATE TRIGGER trg_recipes_updated_at
  BEFORE UPDATE ON recipes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;

-- Any wallet member can read recipes
CREATE POLICY "recipes: wallet members read" ON recipes
  FOR SELECT USING (wallet_accessible(wallet_id));

-- Any wallet member can add a recipe
CREATE POLICY "recipes: wallet members insert" ON recipes
  FOR INSERT WITH CHECK (
    wallet_accessible(wallet_id) AND created_by = auth.uid()
  );

-- Creator or wallet admin can update
CREATE POLICY "recipes: creator or admin update" ON recipes
  FOR UPDATE USING (
    created_by = auth.uid() OR wallet_admin(wallet_id)
  );

-- Creator or wallet admin can delete
CREATE POLICY "recipes: creator or admin delete" ON recipes
  FOR DELETE USING (
    created_by = auth.uid() OR wallet_admin(wallet_id)
  );


-- ══════════════════════════════════════════════════════════════
--  2. MEAL_ENTRIES  (Meal Map tab — daily meal log)
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS meal_entries (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id   UUID        NOT NULL REFERENCES wallets(id)   ON DELETE CASCADE,
  created_by  UUID        NOT NULL REFERENCES profiles(id)  ON DELETE CASCADE,
  recipe_id   UUID        REFERENCES recipes(id) ON DELETE SET NULL,
  name        TEXT        NOT NULL,
  emoji       TEXT        NOT NULL DEFAULT '🍽️',
  meal_time   TEXT        NOT NULL
                          CHECK (meal_time IN ('breakfast','lunch','snack','dinner')),
  date        DATE        NOT NULL,
  note        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_meal_entries_wallet ON meal_entries(wallet_id);
CREATE INDEX idx_meal_entries_date   ON meal_entries(wallet_id, date DESC);
CREATE INDEX idx_meal_entries_recipe ON meal_entries(recipe_id);

CREATE TRIGGER trg_meal_entries_updated_at
  BEFORE UPDATE ON meal_entries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE meal_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "meal_entries: wallet members read" ON meal_entries
  FOR SELECT USING (wallet_accessible(wallet_id));

CREATE POLICY "meal_entries: wallet members insert" ON meal_entries
  FOR INSERT WITH CHECK (
    wallet_accessible(wallet_id) AND created_by = auth.uid()
  );

CREATE POLICY "meal_entries: creator or admin update" ON meal_entries
  FOR UPDATE USING (
    created_by = auth.uid() OR wallet_admin(wallet_id)
  );

CREATE POLICY "meal_entries: creator or admin delete" ON meal_entries
  FOR DELETE USING (
    created_by = auth.uid() OR wallet_admin(wallet_id)
  );


-- ══════════════════════════════════════════════════════════════
--  3. MEAL_REACTIONS  (family opinions on a meal entry)
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS meal_reactions (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_id         UUID        NOT NULL REFERENCES meal_entries(id) ON DELETE CASCADE,
  user_id         UUID        REFERENCES profiles(id) ON DELETE SET NULL,
  member_name     TEXT        NOT NULL,
  reaction_emoji  TEXT        NOT NULL,    -- e.g. 👍 😋 🤔 ❌ 🔄
  comment         TEXT,
  reply_to        TEXT,                    -- name of person being replied to
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_meal_reactions_meal ON meal_reactions(meal_id);
CREATE INDEX idx_meal_reactions_user ON meal_reactions(user_id);

CREATE TRIGGER trg_meal_reactions_updated_at
  BEFORE UPDATE ON meal_reactions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE meal_reactions ENABLE ROW LEVEL SECURITY;

-- Any wallet member can read reactions on meals they can see
CREATE POLICY "meal_reactions: wallet members read" ON meal_reactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM meal_entries me
      WHERE me.id = meal_reactions.meal_id
        AND wallet_accessible(me.wallet_id)
    )
  );

-- Any wallet member can add a reaction
CREATE POLICY "meal_reactions: wallet members insert" ON meal_reactions
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM meal_entries me
      WHERE me.id = meal_reactions.meal_id
        AND wallet_accessible(me.wallet_id)
    )
    AND user_id = auth.uid()
  );

-- Own reaction or wallet admin can update/delete
CREATE POLICY "meal_reactions: own or admin update" ON meal_reactions
  FOR UPDATE USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM meal_entries me
      WHERE me.id = meal_reactions.meal_id
        AND wallet_admin(me.wallet_id)
    )
  );

CREATE POLICY "meal_reactions: own or admin delete" ON meal_reactions
  FOR DELETE USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM meal_entries me
      WHERE me.id = meal_reactions.meal_id
        AND wallet_admin(me.wallet_id)
    )
  );


-- ══════════════════════════════════════════════════════════════
--  4. GROCERY_ITEMS  (Basket tab — in-stock & shopping list)
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS grocery_items (
  id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id     UUID          NOT NULL REFERENCES wallets(id)   ON DELETE CASCADE,
  created_by    UUID          NOT NULL REFERENCES profiles(id)  ON DELETE CASCADE,
  name          TEXT          NOT NULL,
  category      TEXT          NOT NULL
                              CHECK (category IN (
                                'vegetables','fruits','dairy','meat','grains',
                                'beverages','snacks','spices','cleaning','other'
                              )),
  quantity      NUMERIC(10,3) NOT NULL DEFAULT 1  CHECK (quantity >= 0),
  unit          TEXT          NOT NULL DEFAULT 'pcs',
  in_stock      BOOLEAN       NOT NULL DEFAULT TRUE,
  to_buy        BOOLEAN       NOT NULL DEFAULT FALSE,
  expiry_date   DATE,
  last_updated  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_grocery_wallet   ON grocery_items(wallet_id);
CREATE INDEX idx_grocery_category ON grocery_items(wallet_id, category);
CREATE INDEX idx_grocery_to_buy   ON grocery_items(wallet_id, to_buy);
CREATE INDEX idx_grocery_expiry   ON grocery_items(expiry_date) WHERE expiry_date IS NOT NULL;

ALTER TABLE grocery_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "grocery_items: wallet members read" ON grocery_items
  FOR SELECT USING (wallet_accessible(wallet_id));

CREATE POLICY "grocery_items: wallet members insert" ON grocery_items
  FOR INSERT WITH CHECK (
    wallet_accessible(wallet_id) AND created_by = auth.uid()
  );

-- Any wallet member can update (e.g. mark in-stock, tick off shopping list)
CREATE POLICY "grocery_items: wallet members update" ON grocery_items
  FOR UPDATE USING (wallet_accessible(wallet_id));

CREATE POLICY "grocery_items: creator or admin delete" ON grocery_items
  FOR DELETE USING (
    created_by = auth.uid() OR wallet_admin(wallet_id)
  );


-- ══════════════════════════════════════════════════════════════
--  5. MEMBER_FOOD_PREFS  (Family Food Guide card)
--     Allergies, Likes, Dislikes, Mandatory foods per member
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS member_food_prefs (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id       UUID        NOT NULL REFERENCES wallets(id)   ON DELETE CASCADE,
  created_by      UUID        NOT NULL REFERENCES profiles(id)  ON DELETE CASCADE,
  member_id       TEXT        NOT NULL,   -- family_members.id, or 'me' for personal
  member_name     TEXT        NOT NULL,
  member_emoji    TEXT        NOT NULL DEFAULT '👤',
  allergies       TEXT[]      NOT NULL DEFAULT '{}',
  likes           TEXT[]      NOT NULL DEFAULT '{}',
  dislikes        TEXT[]      NOT NULL DEFAULT '{}',
  mandatory_foods TEXT[]      NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (wallet_id, member_id)
);

CREATE INDEX idx_food_prefs_wallet ON member_food_prefs(wallet_id);

CREATE TRIGGER trg_member_food_prefs_updated_at
  BEFORE UPDATE ON member_food_prefs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE member_food_prefs ENABLE ROW LEVEL SECURITY;

-- All wallet members can read prefs
CREATE POLICY "food_prefs: wallet members read" ON member_food_prefs
  FOR SELECT USING (wallet_accessible(wallet_id));

-- Any wallet member can create their own prefs entry
CREATE POLICY "food_prefs: wallet members insert" ON member_food_prefs
  FOR INSERT WITH CHECK (
    wallet_accessible(wallet_id) AND created_by = auth.uid()
  );

-- Own prefs or wallet admin can update
CREATE POLICY "food_prefs: own or admin update" ON member_food_prefs
  FOR UPDATE USING (
    created_by = auth.uid() OR wallet_admin(wallet_id)
  );

-- Own prefs or wallet admin can delete
CREATE POLICY "food_prefs: own or admin delete" ON member_food_prefs
  FOR DELETE USING (
    created_by = auth.uid() OR wallet_admin(wallet_id)
  );


-- ══════════════════════════════════════════════════════════════
--  USEFUL VIEWS
-- ══════════════════════════════════════════════════════════════

-- Today's meals for the current user's wallets
CREATE OR REPLACE VIEW todays_meals AS
SELECT
  me.id,
  me.wallet_id,
  me.name,
  me.emoji,
  me.meal_time,
  me.date,
  me.note,
  me.recipe_id,
  r.name        AS recipe_name,
  COUNT(mr.id)  AS reaction_count
FROM meal_entries me
LEFT JOIN recipes r  ON r.id  = me.recipe_id
LEFT JOIN meal_reactions mr ON mr.meal_id = me.id
WHERE me.date = CURRENT_DATE
GROUP BY me.id, r.name;

-- Weekly shopping list summary
CREATE OR REPLACE VIEW shopping_summary AS
SELECT
  wallet_id,
  category,
  COUNT(*)                               AS total_items,
  COUNT(*) FILTER (WHERE to_buy  = TRUE) AS to_buy_count,
  COUNT(*) FILTER (WHERE in_stock = TRUE) AS in_stock_count
FROM grocery_items
GROUP BY wallet_id, category;

-- Members with allergy alerts (for meal planning warnings)
CREATE OR REPLACE VIEW allergy_alerts AS
SELECT
  wallet_id,
  member_name,
  member_emoji,
  allergies
FROM member_food_prefs
WHERE array_length(allergies, 1) > 0;


-- ── Done ─────────────────────────────────────────────────────────────────────
