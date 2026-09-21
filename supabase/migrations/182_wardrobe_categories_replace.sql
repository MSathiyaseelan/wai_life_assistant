-- ============================================================
--  WAI Life Assistant — Wardrobe Categories: replace catalog
--
--  Replaces the initial 12 placeholder categories (seeded in
--  181_wardrobe_categories_table.sql, unchanged from the old
--  ClothingCategory enum) with a real gender-scoped catalog.
--
--  Existing wardrobe_items rows still carrying an old category key
--  (e.g. 'topwear') won't match any row here — the app's
--  WardrobeCategoryCache.of() falls back to a generic icon/label for
--  an unknown key rather than crashing, so those items keep working
--  and can be re-categorized by editing them.
-- ============================================================

DELETE FROM wardrobe_categories;

INSERT INTO public.wardrobe_categories (key, emoji, label, gender, sort_order) VALUES
-- Unisex (shown to everyone)
('unisex_footwear',    '👟', 'Footwear',     'unisex', 10),
('unisex_sportswear',  '🏃', 'Sportswear',   'unisex', 20),
('unisex_nightwear',   '😴', 'Nightwear',    'unisex', 30),
('unisex_winterwear',  '🧥', 'Winter Wear',  'unisex', 40),
('unisex_jeans',       '👖', 'Jeans',        'unisex', 50),
('unisex_jackets',     '🧥', 'Jackets',      'unisex', 60),
('unisex_socks',       '🧦', 'Socks',        'unisex', 70),
('unisex_caps',        '🧢', 'Caps & Hats',  'unisex', 80),
('unisex_bags',        '🎒', 'Bags',         'unisex', 90),
('unisex_accessories', '⌚', 'Accessories',  'unisex', 100),

-- Male
('male_tshirts',    '👕', 'T-Shirts',         'male', 110),
('male_shirts',     '👔', 'Shirts',           'male', 120),
('male_trousers',   '👖', 'Trousers',         'male', 130),
('male_shorts',     '🩳', 'Shorts',           'male', 140),
('male_kurtas',     '👘', 'Kurtas',           'male', 150),
('male_veshti',     '🩲', 'Dhoti / Veshti',   'male', 160),
('male_sherwani',   '🤵', 'Sherwanis',        'male', 170),
('male_suits',      '🕴️', 'Suits & Blazers',  'male', 180),
('male_innerwear',  '🩲', 'Innerwear',        'male', 190),

-- Female
('female_sarees',       '🥻', 'Sarees',          'female', 210),
('female_blouses',      '👚', 'Blouses',         'female', 220),
('female_salwar',       '👗', 'Salwar Suits',    'female', 230),
('female_kurtis',       '👚', 'Kurtis',          'female', 240),
('female_lehengas',     '💃', 'Lehengas',        'female', 250),
('female_tops',         '👚', 'Tops',            'female', 260),
('female_dresses',      '👗', 'Dresses',         'female', 270),
('female_skirts',       '👗', 'Skirts',          'female', 280),
('female_leggings',     '🩱', 'Leggings',        'female', 290),
('female_dupattas',     '🧣', 'Dupattas',        'female', 300),
('female_innerwear',    '🩱', 'Innerwear',       'female', 310),
('female_jewellery',    '💍', 'Jewellery',       'female', 320)
on conflict (key) do nothing;
