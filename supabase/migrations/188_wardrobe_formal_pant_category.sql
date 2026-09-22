-- ============================================================
--  Wardrobe Categories — add "Formal Pant" for male
--
--  "Trousers" (male_trousers) already covers casual pants, but there
--  was no distinct formal-wear pant category. Adds one, sorted right
--  after Trousers.
-- ============================================================

INSERT INTO public.wardrobe_categories (key, emoji, label, gender, sort_order) VALUES
  ('male_formal_pants', '👖', 'Formal Pant', 'male', 135)
ON CONFLICT (key) DO NOTHING;
