-- ============================================================
--  WAI Life Assistant — Wardrobe Categories (DB-driven, gender-scoped)
--
--  Moves the "which clothing categories exist" list out of the
--  hardcoded ClothingCategory Dart enum into a table, so gender-
--  specific categories can be added later without an app release.
--  Seeded with today's 12 categories unchanged, all 'unisex' (shown
--  to everyone) — no behavior change yet, this just relocates the
--  source of truth. gender = 'unisex' is the sentinel meaning "show
--  for every gender", vs. 'male' / 'female' for gender-restricted
--  categories added in the future.
-- ============================================================

CREATE TABLE IF NOT EXISTS wardrobe_categories (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  key         TEXT        NOT NULL UNIQUE,
  emoji       TEXT        NOT NULL,
  label       TEXT        NOT NULL,
  gender      TEXT        NOT NULL DEFAULT 'unisex'
                          CHECK (gender IN ('male', 'female', 'unisex')),
  sort_order  INT         NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE wardrobe_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wardrobe_categories_read" ON wardrobe_categories;
CREATE POLICY "wardrobe_categories_read" ON wardrobe_categories
  FOR SELECT USING (true);

INSERT INTO wardrobe_categories (key, emoji, label, gender, sort_order) VALUES
  ('topwear',       '👕', 'Topwear',               'unisex', 1),
  ('bottomwear',    '👖', 'Bottomwear',            'unisex', 2),
  ('ethnic',        '🛕', 'Ethnic / Traditional',  'unisex', 3),
  ('footwear',      '👟', 'Footwear',              'unisex', 4),
  ('innerwear',     '🩲', 'Innerwear',             'unisex', 5),
  ('accessories',   '💍', 'Accessories',           'unisex', 6),
  ('formal',        '👔', 'Formal / Office',       'unisex', 7),
  ('sportswear',    '🏃', 'Sportswear',            'unisex', 8),
  ('winterwear',    '🧥', 'Winter / Outerwear',    'unisex', 9),
  ('nightwear',     '🌙', 'Nightwear',             'unisex', 10),
  ('schoolUniform', '🏫', 'School Uniform',        'unisex', 11),
  ('adaptive',      '♿', 'Medical / Adaptive',    'unisex', 12)
ON CONFLICT (key) DO NOTHING;
