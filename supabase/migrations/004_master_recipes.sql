-- ─────────────────────────────────────────────────────────────────────────────
-- Master Recipes  (shared catalogue, read-only for all authenticated users)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE master_recipes (
  id             TEXT        PRIMARY KEY,
  name           TEXT        NOT NULL,
  emoji          TEXT        NOT NULL DEFAULT '🍽️',
  cuisine        TEXT        NOT NULL,
  meal_types     TEXT[]      NOT NULL DEFAULT '{}',
  ingredients    JSONB       NOT NULL DEFAULT '[]',
  cook_time_min  INT,
  prep_time_min  INT,
  servings       INT,
  calories       INT,
  youtube_search TEXT,
  tags           TEXT[]      NOT NULL DEFAULT '{}'
);

ALTER TABLE master_recipes ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read; nobody writes from client
CREATE POLICY "master_recipes_read"
  ON master_recipes FOR SELECT TO authenticated USING (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- Seed data (56 recipes)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO master_recipes
  (id, name, emoji, cuisine, meal_types, ingredients, cook_time_min, prep_time_min, servings, calories, youtube_search, tags)
VALUES

-- ── South Indian ──────────────────────────────────────────────────────────────
('SI001','Idli','🥘','South Indian',
 ARRAY['breakfast'],
 '[{"name":"Idli rice","qty":2,"unit":"cups"},{"name":"Urad dal","qty":0.5,"unit":"cups"},{"name":"Fenugreek seeds","qty":0.5,"unit":"tsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 15,20,4,150,'Idli recipe',ARRAY['veg','steamed','healthy']),

('SI002','Dosa','🫓','South Indian',
 ARRAY['breakfast','dinner'],
 '[{"name":"Idli rice","qty":3,"unit":"cups"},{"name":"Urad dal","qty":1,"unit":"cup"},{"name":"Fenugreek seeds","qty":1,"unit":"tsp"},{"name":"Salt","qty":1,"unit":"tsp"},{"name":"Oil","qty":2,"unit":"tbsp"}]',
 20,480,4,180,'Crispy Dosa recipe',ARRAY['veg','crispy','fermented']),

('SI003','Masala Dosa','🫓','South Indian',
 ARRAY['breakfast','lunch'],
 '[{"name":"Dosa batter","qty":2,"unit":"cups"},{"name":"Potato","qty":3,"unit":"pcs"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Mustard seeds","qty":0.5,"unit":"tsp"},{"name":"Turmeric","qty":0.25,"unit":"tsp"},{"name":"Green chilli","qty":2,"unit":"pcs"},{"name":"Curry leaves","qty":8,"unit":"pcs"},{"name":"Oil","qty":2,"unit":"tbsp"}]',
 25,30,4,280,'Masala Dosa recipe',ARRAY['veg','popular','spicy']),

('SI004','Sambar','🍲','South Indian',
 ARRAY['breakfast','lunch','dinner'],
 '[{"name":"Toor dal","qty":1,"unit":"cup"},{"name":"Tamarind","qty":1,"unit":"lemon sized"},{"name":"Tomato","qty":2,"unit":"pcs"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Sambar powder","qty":2,"unit":"tbsp"},{"name":"Mustard seeds","qty":0.5,"unit":"tsp"},{"name":"Curry leaves","qty":8,"unit":"pcs"},{"name":"Dried red chilli","qty":2,"unit":"pcs"},{"name":"Oil","qty":2,"unit":"tbsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 30,15,4,120,'Sambar recipe',ARRAY['veg','lentil','tangy']),

('SI005','Coconut Chutney','🥥','South Indian',
 ARRAY['breakfast','snacks'],
 '[{"name":"Fresh coconut","qty":1,"unit":"cup"},{"name":"Roasted chana dal","qty":2,"unit":"tbsp"},{"name":"Green chilli","qty":2,"unit":"pcs"},{"name":"Ginger","qty":0.5,"unit":"inch"},{"name":"Mustard seeds","qty":0.5,"unit":"tsp"},{"name":"Curry leaves","qty":6,"unit":"pcs"},{"name":"Dried red chilli","qty":1,"unit":"pcs"},{"name":"Oil","qty":1,"unit":"tsp"},{"name":"Salt","qty":0.5,"unit":"tsp"}]',
 5,10,4,80,'Coconut Chutney recipe',ARRAY['veg','condiment','fresh']),

('SI006','Upma','🥣','South Indian',
 ARRAY['breakfast','snacks'],
 '[{"name":"Rava (semolina)","qty":1,"unit":"cup"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Green chilli","qty":2,"unit":"pcs"},{"name":"Mustard seeds","qty":0.5,"unit":"tsp"},{"name":"Chana dal","qty":1,"unit":"tbsp"},{"name":"Urad dal","qty":1,"unit":"tbsp"},{"name":"Curry leaves","qty":8,"unit":"pcs"},{"name":"Ginger","qty":0.5,"unit":"inch"},{"name":"Water","qty":2.5,"unit":"cups"},{"name":"Oil","qty":2,"unit":"tbsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 15,5,2,200,'Upma recipe',ARRAY['veg','quick','savory']),

('SI007','Pongal','🍚','South Indian',
 ARRAY['breakfast','lunch'],
 '[{"name":"Rice","qty":1,"unit":"cup"},{"name":"Moong dal","qty":0.5,"unit":"cup"},{"name":"Black pepper","qty":1,"unit":"tsp"},{"name":"Cumin seeds","qty":1,"unit":"tsp"},{"name":"Ginger","qty":1,"unit":"inch"},{"name":"Ghee","qty":3,"unit":"tbsp"},{"name":"Cashews","qty":10,"unit":"pcs"},{"name":"Curry leaves","qty":8,"unit":"pcs"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 25,10,3,320,'Ven Pongal recipe',ARRAY['veg','comfort','festive']),

('SI008','Rasam','🍵','South Indian',
 ARRAY['lunch','dinner'],
 '[{"name":"Tomato","qty":3,"unit":"pcs"},{"name":"Tamarind","qty":1,"unit":"gooseberry sized"},{"name":"Toor dal water","qty":0.5,"unit":"cup"},{"name":"Rasam powder","qty":1.5,"unit":"tsp"},{"name":"Mustard seeds","qty":0.5,"unit":"tsp"},{"name":"Dried red chilli","qty":2,"unit":"pcs"},{"name":"Curry leaves","qty":8,"unit":"pcs"},{"name":"Garlic","qty":3,"unit":"cloves"},{"name":"Coriander leaves","qty":2,"unit":"tbsp"},{"name":"Oil","qty":1,"unit":"tsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 20,10,4,60,'Rasam recipe',ARRAY['veg','soup','digestive']),

('SI009','Medu Vada','🍩','South Indian',
 ARRAY['breakfast','snacks'],
 '[{"name":"Urad dal","qty":1,"unit":"cup"},{"name":"Green chilli","qty":2,"unit":"pcs"},{"name":"Ginger","qty":0.5,"unit":"inch"},{"name":"Curry leaves","qty":8,"unit":"pcs"},{"name":"Black pepper","qty":0.5,"unit":"tsp"},{"name":"Oil","qty":2,"unit":"cups"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 20,240,4,220,'Medu Vada recipe',ARRAY['veg','fried','crispy']),

('SI010','Curd Rice','🍚','South Indian',
 ARRAY['lunch','dinner'],
 '[{"name":"Cooked rice","qty":2,"unit":"cups"},{"name":"Curd","qty":1,"unit":"cup"},{"name":"Milk","qty":0.25,"unit":"cup"},{"name":"Mustard seeds","qty":0.5,"unit":"tsp"},{"name":"Green chilli","qty":1,"unit":"pcs"},{"name":"Ginger","qty":0.25,"unit":"inch"},{"name":"Curry leaves","qty":6,"unit":"pcs"},{"name":"Pomegranate seeds","qty":2,"unit":"tbsp"},{"name":"Coriander","qty":1,"unit":"tbsp"},{"name":"Oil","qty":1,"unit":"tsp"},{"name":"Salt","qty":0.5,"unit":"tsp"}]',
 5,10,2,250,'Curd Rice recipe',ARRAY['veg','cooling','summer']),

('SI011','Pesarattu','🥞','South Indian',
 ARRAY['breakfast'],
 '[{"name":"Green moong dal","qty":1,"unit":"cup"},{"name":"Rice","qty":2,"unit":"tbsp"},{"name":"Ginger","qty":0.5,"unit":"inch"},{"name":"Green chilli","qty":2,"unit":"pcs"},{"name":"Onion","qty":0.5,"unit":"pcs"},{"name":"Cumin seeds","qty":0.5,"unit":"tsp"},{"name":"Oil","qty":2,"unit":"tbsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 20,240,3,200,'Pesarattu recipe',ARRAY['veg','protein','healthy']),

('SI012','Appam','🥞','South Indian',
 ARRAY['breakfast','dinner'],
 '[{"name":"Raw rice","qty":2,"unit":"cups"},{"name":"Cooked rice","qty":0.5,"unit":"cup"},{"name":"Coconut milk","qty":1,"unit":"cup"},{"name":"Yeast","qty":0.5,"unit":"tsp"},{"name":"Sugar","qty":1,"unit":"tsp"},{"name":"Salt","qty":0.5,"unit":"tsp"}]',
 20,480,4,180,'Appam recipe Kerala',ARRAY['veg','Kerala','soft']),

('SI013','Bisi Bele Bath','🍲','South Indian',
 ARRAY['lunch','dinner'],
 '[{"name":"Rice","qty":1,"unit":"cup"},{"name":"Toor dal","qty":0.5,"unit":"cup"},{"name":"Mixed vegetables","qty":2,"unit":"cups"},{"name":"Tamarind","qty":1,"unit":"lemon sized"},{"name":"Bisi bele bath powder","qty":3,"unit":"tbsp"},{"name":"Ghee","qty":3,"unit":"tbsp"},{"name":"Mustard seeds","qty":0.5,"unit":"tsp"},{"name":"Cashews","qty":10,"unit":"pcs"},{"name":"Curry leaves","qty":8,"unit":"pcs"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 40,20,4,380,'Bisi Bele Bath recipe',ARRAY['veg','one-pot','Karnataka']),

-- ── North Indian ──────────────────────────────────────────────────────────────
('NI001','Dal Tadka','🍛','North Indian',
 ARRAY['lunch','dinner'],
 '[{"name":"Toor dal","qty":1,"unit":"cup"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Tomato","qty":2,"unit":"pcs"},{"name":"Garlic","qty":4,"unit":"cloves"},{"name":"Ginger","qty":0.5,"unit":"inch"},{"name":"Cumin seeds","qty":1,"unit":"tsp"},{"name":"Turmeric","qty":0.5,"unit":"tsp"},{"name":"Red chilli powder","qty":1,"unit":"tsp"},{"name":"Coriander powder","qty":1,"unit":"tsp"},{"name":"Ghee","qty":2,"unit":"tbsp"},{"name":"Coriander leaves","qty":2,"unit":"tbsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 30,15,4,220,'Dal Tadka recipe',ARRAY['veg','protein','comfort']),

('NI002','Palak Paneer','🥬','North Indian',
 ARRAY['lunch','dinner'],
 '[{"name":"Spinach","qty":500,"unit":"g"},{"name":"Paneer","qty":200,"unit":"g"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Tomato","qty":2,"unit":"pcs"},{"name":"Garlic","qty":4,"unit":"cloves"},{"name":"Ginger","qty":1,"unit":"inch"},{"name":"Green chilli","qty":2,"unit":"pcs"},{"name":"Cream","qty":2,"unit":"tbsp"},{"name":"Garam masala","qty":0.5,"unit":"tsp"},{"name":"Cumin seeds","qty":1,"unit":"tsp"},{"name":"Oil","qty":2,"unit":"tbsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 25,15,4,280,'Palak Paneer recipe',ARRAY['veg','paneer','iron-rich']),

('NI003','Butter Chicken','🍗','North Indian',
 ARRAY['lunch','dinner'],
 '[{"name":"Chicken","qty":500,"unit":"g"},{"name":"Tomato puree","qty":1,"unit":"cup"},{"name":"Onion","qty":2,"unit":"pcs"},{"name":"Cashews","qty":10,"unit":"pcs"},{"name":"Butter","qty":3,"unit":"tbsp"},{"name":"Cream","qty":0.25,"unit":"cup"},{"name":"Ginger garlic paste","qty":2,"unit":"tbsp"},{"name":"Kashmiri red chilli","qty":2,"unit":"tsp"},{"name":"Garam masala","qty":1,"unit":"tsp"},{"name":"Fenugreek leaves","qty":1,"unit":"tbsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 40,30,4,420,'Butter Chicken recipe',ARRAY['non-veg','creamy','popular']),

('NI004','Chana Masala','🫘','North Indian',
 ARRAY['breakfast','lunch','dinner'],
 '[{"name":"Chickpeas","qty":1.5,"unit":"cups"},{"name":"Onion","qty":2,"unit":"pcs"},{"name":"Tomato","qty":3,"unit":"pcs"},{"name":"Garlic","qty":4,"unit":"cloves"},{"name":"Ginger","qty":1,"unit":"inch"},{"name":"Chana masala powder","qty":2,"unit":"tbsp"},{"name":"Cumin seeds","qty":1,"unit":"tsp"},{"name":"Turmeric","qty":0.5,"unit":"tsp"},{"name":"Amchur","qty":0.5,"unit":"tsp"},{"name":"Oil","qty":3,"unit":"tbsp"},{"name":"Coriander leaves","qty":2,"unit":"tbsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 40,480,4,300,'Chana Masala recipe',ARRAY['veg','protein','spicy']),

('NI005','Aloo Paratha','🫓','North Indian',
 ARRAY['breakfast','lunch'],
 '[{"name":"Wheat flour","qty":2,"unit":"cups"},{"name":"Potato","qty":3,"unit":"pcs"},{"name":"Green chilli","qty":2,"unit":"pcs"},{"name":"Ginger","qty":0.5,"unit":"inch"},{"name":"Coriander leaves","qty":3,"unit":"tbsp"},{"name":"Cumin seeds","qty":0.5,"unit":"tsp"},{"name":"Amchur","qty":0.25,"unit":"tsp"},{"name":"Butter","qty":3,"unit":"tbsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 25,20,3,350,'Aloo Paratha recipe',ARRAY['veg','flatbread','Punjab']),

('NI006','Paneer Butter Masala','🧀','North Indian',
 ARRAY['lunch','dinner'],
 '[{"name":"Paneer","qty":250,"unit":"g"},{"name":"Tomato","qty":4,"unit":"pcs"},{"name":"Onion","qty":2,"unit":"pcs"},{"name":"Cashews","qty":10,"unit":"pcs"},{"name":"Butter","qty":3,"unit":"tbsp"},{"name":"Cream","qty":3,"unit":"tbsp"},{"name":"Ginger garlic paste","qty":2,"unit":"tbsp"},{"name":"Kashmiri red chilli","qty":2,"unit":"tsp"},{"name":"Garam masala","qty":1,"unit":"tsp"},{"name":"Fenugreek leaves","qty":1,"unit":"tbsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 30,15,4,380,'Paneer Butter Masala recipe',ARRAY['veg','paneer','creamy']),

('NI007','Rajma Chawal','🫘','North Indian',
 ARRAY['lunch','dinner'],
 '[{"name":"Kidney beans","qty":1.5,"unit":"cups"},{"name":"Rice","qty":1.5,"unit":"cups"},{"name":"Onion","qty":2,"unit":"pcs"},{"name":"Tomato","qty":3,"unit":"pcs"},{"name":"Garlic","qty":5,"unit":"cloves"},{"name":"Ginger","qty":1,"unit":"inch"},{"name":"Rajma masala","qty":2,"unit":"tbsp"},{"name":"Cumin seeds","qty":1,"unit":"tsp"},{"name":"Oil","qty":3,"unit":"tbsp"},{"name":"Coriander leaves","qty":2,"unit":"tbsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 45,480,4,420,'Rajma Chawal recipe',ARRAY['veg','protein','comfort']),

('NI008','Poha','🍚','North Indian',
 ARRAY['breakfast','snacks'],
 '[{"name":"Flattened rice (Poha)","qty":2,"unit":"cups"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Potato","qty":1,"unit":"pcs"},{"name":"Green chilli","qty":2,"unit":"pcs"},{"name":"Mustard seeds","qty":0.5,"unit":"tsp"},{"name":"Curry leaves","qty":8,"unit":"pcs"},{"name":"Turmeric","qty":0.25,"unit":"tsp"},{"name":"Lemon juice","qty":1,"unit":"tbsp"},{"name":"Oil","qty":2,"unit":"tbsp"},{"name":"Coriander leaves","qty":2,"unit":"tbsp"},{"name":"Salt","qty":0.75,"unit":"tsp"}]',
 15,10,2,250,'Poha recipe',ARRAY['veg','quick','light']),

('NI009','Pav Bhaji','🥖','North Indian',
 ARRAY['snacks','dinner'],
 '[{"name":"Mixed vegetables","qty":3,"unit":"cups"},{"name":"Pav bread","qty":8,"unit":"pcs"},{"name":"Onion","qty":2,"unit":"pcs"},{"name":"Tomato","qty":4,"unit":"pcs"},{"name":"Capsicum","qty":1,"unit":"pcs"},{"name":"Pav bhaji masala","qty":3,"unit":"tbsp"},{"name":"Butter","qty":4,"unit":"tbsp"},{"name":"Lemon juice","qty":1,"unit":"tbsp"},{"name":"Coriander leaves","qty":3,"unit":"tbsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 30,20,4,450,'Pav Bhaji recipe',ARRAY['veg','street food','Mumbai']),

('NI010','Dal Makhani','🍛','North Indian',
 ARRAY['lunch','dinner'],
 '[{"name":"Black urad dal","qty":1,"unit":"cup"},{"name":"Kidney beans","qty":0.25,"unit":"cup"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Tomato","qty":3,"unit":"pcs"},{"name":"Garlic","qty":5,"unit":"cloves"},{"name":"Ginger","qty":1,"unit":"inch"},{"name":"Butter","qty":4,"unit":"tbsp"},{"name":"Cream","qty":0.25,"unit":"cup"},{"name":"Garam masala","qty":1,"unit":"tsp"},{"name":"Red chilli powder","qty":1,"unit":"tsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 60,480,4,360,'Dal Makhani recipe',ARRAY['veg','rich','restaurant-style']),

('NI011','Aloo Gobi','🥦','North Indian',
 ARRAY['lunch','dinner'],
 '[{"name":"Potato","qty":2,"unit":"pcs"},{"name":"Cauliflower","qty":1,"unit":"small"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Tomato","qty":2,"unit":"pcs"},{"name":"Ginger garlic paste","qty":1,"unit":"tbsp"},{"name":"Turmeric","qty":0.5,"unit":"tsp"},{"name":"Coriander powder","qty":1.5,"unit":"tsp"},{"name":"Cumin seeds","qty":1,"unit":"tsp"},{"name":"Garam masala","qty":0.5,"unit":"tsp"},{"name":"Oil","qty":3,"unit":"tbsp"},{"name":"Coriander leaves","qty":2,"unit":"tbsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 25,15,4,220,'Aloo Gobi recipe',ARRAY['veg','dry','everyday']),

('NI012','Jeera Rice','🍚','North Indian',
 ARRAY['lunch','dinner'],
 '[{"name":"Basmati rice","qty":1.5,"unit":"cups"},{"name":"Cumin seeds","qty":1.5,"unit":"tsp"},{"name":"Bay leaf","qty":1,"unit":"pcs"},{"name":"Ghee","qty":2,"unit":"tbsp"},{"name":"Salt","qty":1,"unit":"tsp"},{"name":"Water","qty":3,"unit":"cups"}]',
 20,20,3,280,'Jeera Rice recipe',ARRAY['veg','simple','aromatic']),

-- ── Rice Dishes ───────────────────────────────────────────────────────────────
('RD001','Chicken Biryani','🍗','Rice Dishes',
 ARRAY['lunch','dinner'],
 '[{"name":"Basmati rice","qty":2,"unit":"cups"},{"name":"Chicken","qty":500,"unit":"g"},{"name":"Onion","qty":3,"unit":"pcs"},{"name":"Tomato","qty":2,"unit":"pcs"},{"name":"Curd","qty":0.5,"unit":"cup"},{"name":"Biryani masala","qty":3,"unit":"tbsp"},{"name":"Ginger garlic paste","qty":2,"unit":"tbsp"},{"name":"Mint leaves","qty":0.25,"unit":"cup"},{"name":"Saffron","qty":1,"unit":"pinch"},{"name":"Ghee","qty":3,"unit":"tbsp"},{"name":"Oil","qty":3,"unit":"tbsp"},{"name":"Salt","qty":1.5,"unit":"tsp"}]',
 60,60,5,520,'Chicken Biryani Hyderabadi recipe',ARRAY['non-veg','festive','Hyderabad']),

('RD002','Vegetable Biryani','🍚','Rice Dishes',
 ARRAY['lunch','dinner'],
 '[{"name":"Basmati rice","qty":2,"unit":"cups"},{"name":"Mixed vegetables","qty":2,"unit":"cups"},{"name":"Onion","qty":2,"unit":"pcs"},{"name":"Tomato","qty":2,"unit":"pcs"},{"name":"Curd","qty":0.5,"unit":"cup"},{"name":"Biryani masala","qty":2,"unit":"tbsp"},{"name":"Ginger garlic paste","qty":2,"unit":"tbsp"},{"name":"Mint leaves","qty":0.25,"unit":"cup"},{"name":"Saffron","qty":1,"unit":"pinch"},{"name":"Ghee","qty":3,"unit":"tbsp"},{"name":"Salt","qty":1.5,"unit":"tsp"}]',
 50,45,5,420,'Vegetable Biryani recipe',ARRAY['veg','festive','aromatic']),

('RD003','Egg Fried Rice','🍳','Rice Dishes',
 ARRAY['lunch','dinner'],
 '[{"name":"Cooked rice","qty":3,"unit":"cups"},{"name":"Eggs","qty":3,"unit":"pcs"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Carrot","qty":1,"unit":"pcs"},{"name":"Capsicum","qty":0.5,"unit":"pcs"},{"name":"Spring onion","qty":3,"unit":"stalks"},{"name":"Soy sauce","qty":2,"unit":"tbsp"},{"name":"Pepper","qty":0.5,"unit":"tsp"},{"name":"Oil","qty":3,"unit":"tbsp"},{"name":"Salt","qty":0.75,"unit":"tsp"}]',
 15,10,3,380,'Egg Fried Rice recipe',ARRAY['non-veg','quick','Indo-Chinese']),

('RD004','Lemon Rice','🍚','Rice Dishes',
 ARRAY['breakfast','lunch'],
 '[{"name":"Cooked rice","qty":2,"unit":"cups"},{"name":"Lemon juice","qty":3,"unit":"tbsp"},{"name":"Mustard seeds","qty":0.5,"unit":"tsp"},{"name":"Chana dal","qty":1,"unit":"tbsp"},{"name":"Urad dal","qty":1,"unit":"tbsp"},{"name":"Peanuts","qty":2,"unit":"tbsp"},{"name":"Curry leaves","qty":8,"unit":"pcs"},{"name":"Turmeric","qty":0.25,"unit":"tsp"},{"name":"Dried red chilli","qty":2,"unit":"pcs"},{"name":"Oil","qty":2,"unit":"tbsp"},{"name":"Salt","qty":0.75,"unit":"tsp"}]',
 10,5,2,280,'Lemon Rice recipe',ARRAY['veg','tangy','South Indian']),

('RD005','Tomato Rice','🍅','Rice Dishes',
 ARRAY['lunch','dinner'],
 '[{"name":"Cooked rice","qty":2,"unit":"cups"},{"name":"Tomato","qty":3,"unit":"pcs"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Mustard seeds","qty":0.5,"unit":"tsp"},{"name":"Chana dal","qty":1,"unit":"tbsp"},{"name":"Curry leaves","qty":8,"unit":"pcs"},{"name":"Red chilli powder","qty":1,"unit":"tsp"},{"name":"Turmeric","qty":0.25,"unit":"tsp"},{"name":"Oil","qty":2,"unit":"tbsp"},{"name":"Salt","qty":0.75,"unit":"tsp"}]',
 15,10,2,300,'Tomato Rice recipe',ARRAY['veg','tangy','everyday']),

('RD006','Mutton Biryani','🥩','Rice Dishes',
 ARRAY['lunch','dinner'],
 '[{"name":"Basmati rice","qty":2,"unit":"cups"},{"name":"Mutton","qty":500,"unit":"g"},{"name":"Onion","qty":3,"unit":"pcs"},{"name":"Tomato","qty":2,"unit":"pcs"},{"name":"Curd","qty":0.75,"unit":"cup"},{"name":"Biryani masala","qty":3,"unit":"tbsp"},{"name":"Ginger garlic paste","qty":3,"unit":"tbsp"},{"name":"Mint leaves","qty":0.5,"unit":"cup"},{"name":"Saffron","qty":1,"unit":"pinch"},{"name":"Ghee","qty":4,"unit":"tbsp"},{"name":"Oil","qty":3,"unit":"tbsp"},{"name":"Salt","qty":1.5,"unit":"tsp"}]',
 90,90,5,580,'Mutton Biryani recipe',ARRAY['non-veg','festive','rich']),

('RD007','Puliyodarai','🍚','Rice Dishes',
 ARRAY['breakfast','lunch'],
 '[{"name":"Cooked rice","qty":2,"unit":"cups"},{"name":"Tamarind","qty":1,"unit":"lemon sized"},{"name":"Puliyodarai paste","qty":3,"unit":"tbsp"},{"name":"Peanuts","qty":3,"unit":"tbsp"},{"name":"Mustard seeds","qty":0.5,"unit":"tsp"},{"name":"Chana dal","qty":1,"unit":"tbsp"},{"name":"Curry leaves","qty":8,"unit":"pcs"},{"name":"Oil","qty":3,"unit":"tbsp"},{"name":"Salt","qty":0.75,"unit":"tsp"}]',
 15,10,2,320,'Puliyodarai recipe',ARRAY['veg','tangy','temple food']),

-- ── Snacks & Street Food ──────────────────────────────────────────────────────
('SS002','Samosa','🥟','Snacks & Street Food',
 ARRAY['snacks'],
 '[{"name":"Maida","qty":2,"unit":"cups"},{"name":"Potato","qty":4,"unit":"pcs"},{"name":"Green peas","qty":0.5,"unit":"cup"},{"name":"Cumin seeds","qty":1,"unit":"tsp"},{"name":"Coriander powder","qty":1,"unit":"tsp"},{"name":"Garam masala","qty":0.5,"unit":"tsp"},{"name":"Amchur","qty":0.5,"unit":"tsp"},{"name":"Green chilli","qty":2,"unit":"pcs"},{"name":"Ginger","qty":0.5,"unit":"inch"},{"name":"Oil","qty":2,"unit":"cups"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 30,30,4,320,'Samosa recipe',ARRAY['veg','fried','popular']),

('SS003','Bhel Puri','🍿','Snacks & Street Food',
 ARRAY['snacks'],
 '[{"name":"Puffed rice","qty":3,"unit":"cups"},{"name":"Sev","qty":0.5,"unit":"cup"},{"name":"Puri","qty":10,"unit":"pcs"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Tomato","qty":1,"unit":"pcs"},{"name":"Boiled potato","qty":1,"unit":"pcs"},{"name":"Tamarind chutney","qty":2,"unit":"tbsp"},{"name":"Green chutney","qty":2,"unit":"tbsp"},{"name":"Chaat masala","qty":1,"unit":"tsp"},{"name":"Coriander leaves","qty":2,"unit":"tbsp"}]',
 0,15,2,280,'Bhel Puri recipe',ARRAY['veg','chaat','Mumbai']),

('SS004','Vada Pav','🥖','Snacks & Street Food',
 ARRAY['breakfast','snacks'],
 '[{"name":"Potato","qty":4,"unit":"pcs"},{"name":"Pav bread","qty":6,"unit":"pcs"},{"name":"Gram flour","qty":1,"unit":"cup"},{"name":"Mustard seeds","qty":0.5,"unit":"tsp"},{"name":"Green chilli","qty":3,"unit":"pcs"},{"name":"Garlic chutney","qty":3,"unit":"tbsp"},{"name":"Green chutney","qty":3,"unit":"tbsp"},{"name":"Turmeric","qty":0.5,"unit":"tsp"},{"name":"Oil","qty":2,"unit":"cups"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 25,20,3,380,'Vada Pav recipe',ARRAY['veg','Mumbai','street food']),

('SS005','Onion Pakoda','🧅','Snacks & Street Food',
 ARRAY['snacks'],
 '[{"name":"Onion","qty":3,"unit":"pcs"},{"name":"Gram flour","qty":1,"unit":"cup"},{"name":"Rice flour","qty":2,"unit":"tbsp"},{"name":"Green chilli","qty":3,"unit":"pcs"},{"name":"Ginger","qty":0.5,"unit":"inch"},{"name":"Red chilli powder","qty":0.5,"unit":"tsp"},{"name":"Curry leaves","qty":8,"unit":"pcs"},{"name":"Coriander leaves","qty":2,"unit":"tbsp"},{"name":"Oil","qty":2,"unit":"cups"},{"name":"Salt","qty":0.75,"unit":"tsp"}]',
 15,10,3,250,'Onion Pakoda recipe',ARRAY['veg','rainy day','crispy']),

('SS006','Pani Puri','🫙','Snacks & Street Food',
 ARRAY['snacks'],
 '[{"name":"Puri shells","qty":30,"unit":"pcs"},{"name":"Boiled potato","qty":2,"unit":"pcs"},{"name":"Boiled chickpeas","qty":0.5,"unit":"cup"},{"name":"Tamarind chutney","qty":3,"unit":"tbsp"},{"name":"Mint leaves","qty":0.5,"unit":"cup"},{"name":"Coriander leaves","qty":0.25,"unit":"cup"},{"name":"Green chilli","qty":3,"unit":"pcs"},{"name":"Roasted cumin","qty":1,"unit":"tsp"},{"name":"Black salt","qty":0.5,"unit":"tsp"},{"name":"Chaat masala","qty":1,"unit":"tsp"}]',
 0,20,4,200,'Pani Puri recipe',ARRAY['veg','chaat','popular']),

('SS007','Aloo Tikki','🥔','Snacks & Street Food',
 ARRAY['snacks'],
 '[{"name":"Potato","qty":4,"unit":"pcs"},{"name":"Bread slices","qty":2,"unit":"pcs"},{"name":"Cumin seeds","qty":0.5,"unit":"tsp"},{"name":"Garam masala","qty":0.5,"unit":"tsp"},{"name":"Red chilli powder","qty":0.5,"unit":"tsp"},{"name":"Coriander leaves","qty":2,"unit":"tbsp"},{"name":"Lemon juice","qty":1,"unit":"tbsp"},{"name":"Oil","qty":3,"unit":"tbsp"},{"name":"Salt","qty":0.75,"unit":"tsp"}]',
 20,20,3,220,'Aloo Tikki recipe',ARRAY['veg','crispy','Delhi']),

-- ── Chinese / Indo-Chinese ────────────────────────────────────────────────────
('IC001','Chicken Manchurian','🍗','Indo-Chinese',
 ARRAY['snacks','dinner'],
 '[{"name":"Chicken","qty":300,"unit":"g"},{"name":"Maida","qty":3,"unit":"tbsp"},{"name":"Cornflour","qty":3,"unit":"tbsp"},{"name":"Egg","qty":1,"unit":"pcs"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Capsicum","qty":1,"unit":"pcs"},{"name":"Garlic","qty":5,"unit":"cloves"},{"name":"Ginger","qty":1,"unit":"inch"},{"name":"Soy sauce","qty":2,"unit":"tbsp"},{"name":"Chilli sauce","qty":2,"unit":"tbsp"},{"name":"Vinegar","qty":1,"unit":"tbsp"},{"name":"Spring onion","qty":3,"unit":"stalks"},{"name":"Oil","qty":3,"unit":"cups"},{"name":"Salt","qty":0.75,"unit":"tsp"}]',
 25,20,3,380,'Chicken Manchurian recipe',ARRAY['non-veg','Indo-Chinese','popular']),

('IC002','Gobi Manchurian','🥦','Indo-Chinese',
 ARRAY['snacks','dinner'],
 '[{"name":"Cauliflower","qty":1,"unit":"medium"},{"name":"Maida","qty":4,"unit":"tbsp"},{"name":"Cornflour","qty":4,"unit":"tbsp"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Capsicum","qty":1,"unit":"pcs"},{"name":"Garlic","qty":5,"unit":"cloves"},{"name":"Ginger","qty":1,"unit":"inch"},{"name":"Soy sauce","qty":2,"unit":"tbsp"},{"name":"Chilli sauce","qty":2,"unit":"tbsp"},{"name":"Tomato ketchup","qty":1,"unit":"tbsp"},{"name":"Spring onion","qty":3,"unit":"stalks"},{"name":"Oil","qty":2,"unit":"cups"},{"name":"Salt","qty":0.75,"unit":"tsp"}]',
 25,20,3,300,'Gobi Manchurian recipe',ARRAY['veg','Indo-Chinese','popular']),

('IC003','Hakka Noodles','🍜','Indo-Chinese',
 ARRAY['lunch','dinner'],
 '[{"name":"Hakka noodles","qty":200,"unit":"g"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Carrot","qty":1,"unit":"pcs"},{"name":"Cabbage","qty":1,"unit":"cup"},{"name":"Capsicum","qty":1,"unit":"pcs"},{"name":"Spring onion","qty":3,"unit":"stalks"},{"name":"Garlic","qty":4,"unit":"cloves"},{"name":"Soy sauce","qty":2,"unit":"tbsp"},{"name":"Vinegar","qty":1,"unit":"tbsp"},{"name":"Chilli sauce","qty":1,"unit":"tbsp"},{"name":"Oil","qty":3,"unit":"tbsp"},{"name":"Salt","qty":0.75,"unit":"tsp"}]',
 15,15,3,340,'Hakka Noodles recipe',ARRAY['veg','Indo-Chinese','quick']),

('IC004','Veg Fried Rice','🍚','Indo-Chinese',
 ARRAY['lunch','dinner'],
 '[{"name":"Cooked rice","qty":3,"unit":"cups"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Carrot","qty":1,"unit":"pcs"},{"name":"Beans","qty":0.5,"unit":"cup"},{"name":"Capsicum","qty":0.5,"unit":"pcs"},{"name":"Spring onion","qty":3,"unit":"stalks"},{"name":"Garlic","qty":3,"unit":"cloves"},{"name":"Soy sauce","qty":2,"unit":"tbsp"},{"name":"Pepper","qty":0.5,"unit":"tsp"},{"name":"Vinegar","qty":0.5,"unit":"tbsp"},{"name":"Oil","qty":3,"unit":"tbsp"},{"name":"Salt","qty":0.75,"unit":"tsp"}]',
 15,10,3,360,'Veg Fried Rice recipe',ARRAY['veg','Indo-Chinese','quick']),

('IC005','Chilli Paneer','🧀','Indo-Chinese',
 ARRAY['snacks','dinner'],
 '[{"name":"Paneer","qty":250,"unit":"g"},{"name":"Maida","qty":3,"unit":"tbsp"},{"name":"Cornflour","qty":3,"unit":"tbsp"},{"name":"Onion","qty":1,"unit":"pcs"},{"name":"Capsicum","qty":1,"unit":"pcs"},{"name":"Garlic","qty":5,"unit":"cloves"},{"name":"Green chilli","qty":3,"unit":"pcs"},{"name":"Soy sauce","qty":2,"unit":"tbsp"},{"name":"Chilli sauce","qty":2,"unit":"tbsp"},{"name":"Vinegar","qty":1,"unit":"tbsp"},{"name":"Spring onion","qty":3,"unit":"stalks"},{"name":"Oil","qty":2,"unit":"cups"},{"name":"Salt","qty":0.75,"unit":"tsp"}]',
 20,15,3,340,'Chilli Paneer recipe',ARRAY['veg','Indo-Chinese','spicy']),

('IC006','Sweet Corn Soup','🌽','Indo-Chinese',
 ARRAY['snacks','dinner'],
 '[{"name":"Sweet corn","qty":1,"unit":"cup"},{"name":"Carrot","qty":0.5,"unit":"pcs"},{"name":"Cabbage","qty":0.5,"unit":"cup"},{"name":"Vegetable stock","qty":3,"unit":"cups"},{"name":"Cornflour","qty":2,"unit":"tbsp"},{"name":"Ginger","qty":0.5,"unit":"inch"},{"name":"Garlic","qty":2,"unit":"cloves"},{"name":"Pepper","qty":0.5,"unit":"tsp"},{"name":"Soy sauce","qty":1,"unit":"tbsp"},{"name":"Vinegar","qty":0.5,"unit":"tbsp"},{"name":"Salt","qty":0.75,"unit":"tsp"}]',
 20,10,3,120,'Sweet Corn Soup recipe',ARRAY['veg','soup','winter']),

-- ── Continental ───────────────────────────────────────────────────────────────
('CO001','Veg Sandwich','🥪','Continental',
 ARRAY['breakfast','snacks'],
 '[{"name":"Bread","qty":4,"unit":"slices"},{"name":"Cucumber","qty":0.5,"unit":"pcs"},{"name":"Tomato","qty":1,"unit":"pcs"},{"name":"Onion","qty":0.5,"unit":"pcs"},{"name":"Capsicum","qty":0.25,"unit":"pcs"},{"name":"Cheese slice","qty":2,"unit":"pcs"},{"name":"Butter","qty":2,"unit":"tbsp"},{"name":"Green chutney","qty":2,"unit":"tbsp"},{"name":"Chaat masala","qty":0.5,"unit":"tsp"},{"name":"Salt","qty":0.25,"unit":"tsp"}]',
 5,10,2,280,'Veg Sandwich recipe',ARRAY['veg','quick','kids']),

('CO002','Pasta Arrabiata','🍝','Continental',
 ARRAY['lunch','dinner'],
 '[{"name":"Penne pasta","qty":200,"unit":"g"},{"name":"Tomato","qty":4,"unit":"pcs"},{"name":"Garlic","qty":5,"unit":"cloves"},{"name":"Red chilli flakes","qty":1,"unit":"tsp"},{"name":"Olive oil","qty":3,"unit":"tbsp"},{"name":"Basil leaves","qty":10,"unit":"pcs"},{"name":"Oregano","qty":1,"unit":"tsp"},{"name":"Salt","qty":1,"unit":"tsp"}]',
 25,10,3,380,'Pasta Arrabiata recipe',ARRAY['veg','Italian','spicy']),

('CO003','French Toast','🍞','Continental',
 ARRAY['breakfast'],
 '[{"name":"Bread","qty":4,"unit":"slices"},{"name":"Eggs","qty":2,"unit":"pcs"},{"name":"Milk","qty":3,"unit":"tbsp"},{"name":"Sugar","qty":1,"unit":"tbsp"},{"name":"Vanilla essence","qty":0.25,"unit":"tsp"},{"name":"Cinnamon powder","qty":0.25,"unit":"tsp"},{"name":"Butter","qty":2,"unit":"tbsp"},{"name":"Maple syrup","qty":2,"unit":"tbsp"}]',
 10,5,2,320,'French Toast recipe',ARRAY['non-veg','sweet','breakfast']),

('CO004','Omelette','🍳','Continental',
 ARRAY['breakfast'],
 '[{"name":"Eggs","qty":3,"unit":"pcs"},{"name":"Onion","qty":0.5,"unit":"pcs"},{"name":"Tomato","qty":0.5,"unit":"pcs"},{"name":"Green chilli","qty":1,"unit":"pcs"},{"name":"Coriander leaves","qty":1,"unit":"tbsp"},{"name":"Butter","qty":1,"unit":"tbsp"},{"name":"Salt","qty":0.25,"unit":"tsp"},{"name":"Pepper","qty":0.25,"unit":"tsp"}]',
 10,5,1,250,'Masala Omelette recipe',ARRAY['non-veg','quick','protein']),

('CO005','Grilled Sandwich','🥪','Continental',
 ARRAY['breakfast','snacks'],
 '[{"name":"Bread","qty":4,"unit":"slices"},{"name":"Cheese slice","qty":2,"unit":"pcs"},{"name":"Butter","qty":2,"unit":"tbsp"},{"name":"Tomato","qty":1,"unit":"pcs"},{"name":"Onion","qty":0.5,"unit":"pcs"},{"name":"Capsicum","qty":0.25,"unit":"pcs"},{"name":"Mixed herbs","qty":0.5,"unit":"tsp"},{"name":"Chilli flakes","qty":0.25,"unit":"tsp"}]',
 8,10,2,300,'Grilled Cheese Sandwich recipe',ARRAY['veg','crispy','kids']),

-- ── Desserts & Sweets ─────────────────────────────────────────────────────────
('DS001','Kheer','🍮','Desserts & Sweets',
 ARRAY['dessert'],
 '[{"name":"Milk","qty":1,"unit":"L"},{"name":"Rice","qty":3,"unit":"tbsp"},{"name":"Sugar","qty":4,"unit":"tbsp"},{"name":"Cardamom","qty":3,"unit":"pcs"},{"name":"Saffron","qty":1,"unit":"pinch"},{"name":"Cashews","qty":10,"unit":"pcs"},{"name":"Almonds","qty":10,"unit":"pcs"},{"name":"Raisins","qty":1,"unit":"tbsp"},{"name":"Rose water","qty":1,"unit":"tsp"}]',
 60,10,4,280,'Rice Kheer recipe',ARRAY['veg','festive','creamy']),

('DS002','Gulab Jamun','🟤','Desserts & Sweets',
 ARRAY['dessert'],
 '[{"name":"Milk powder","qty":1,"unit":"cup"},{"name":"Maida","qty":2,"unit":"tbsp"},{"name":"Baking powder","qty":0.25,"unit":"tsp"},{"name":"Ghee","qty":1,"unit":"tbsp"},{"name":"Milk","qty":3,"unit":"tbsp"},{"name":"Sugar","qty":2,"unit":"cups"},{"name":"Water","qty":1,"unit":"cup"},{"name":"Cardamom","qty":3,"unit":"pcs"},{"name":"Rose water","qty":1,"unit":"tsp"},{"name":"Oil","qty":2,"unit":"cups"}]',
 30,15,4,350,'Gulab Jamun recipe',ARRAY['veg','festive','popular']),

('DS003','Rasgulla','🫧','Desserts & Sweets',
 ARRAY['dessert'],
 '[{"name":"Full fat milk","qty":1,"unit":"L"},{"name":"Lemon juice","qty":2,"unit":"tbsp"},{"name":"Sugar","qty":2,"unit":"cups"},{"name":"Water","qty":4,"unit":"cups"},{"name":"Rose water","qty":1,"unit":"tsp"},{"name":"Cardamom","qty":2,"unit":"pcs"}]',
 30,20,6,200,'Rasgulla recipe',ARRAY['veg','Bengali','soft']),

('DS004','Halwa','🍮','Desserts & Sweets',
 ARRAY['breakfast','dessert'],
 '[{"name":"Rava (semolina)","qty":1,"unit":"cup"},{"name":"Sugar","qty":0.75,"unit":"cup"},{"name":"Ghee","qty":4,"unit":"tbsp"},{"name":"Milk","qty":1,"unit":"cup"},{"name":"Water","qty":1,"unit":"cup"},{"name":"Cardamom","qty":3,"unit":"pcs"},{"name":"Cashews","qty":10,"unit":"pcs"},{"name":"Raisins","qty":1,"unit":"tbsp"}]',
 20,5,3,320,'Rava Halwa recipe',ARRAY['veg','festive','quick']),

('DS005','Payasam','🍮','Desserts & Sweets',
 ARRAY['dessert'],
 '[{"name":"Milk","qty":1,"unit":"L"},{"name":"Vermicelli","qty":0.5,"unit":"cup"},{"name":"Sugar","qty":4,"unit":"tbsp"},{"name":"Ghee","qty":2,"unit":"tbsp"},{"name":"Cardamom","qty":3,"unit":"pcs"},{"name":"Cashews","qty":10,"unit":"pcs"},{"name":"Raisins","qty":1,"unit":"tbsp"},{"name":"Saffron","qty":1,"unit":"pinch"}]',
 30,5,4,260,'Semiya Payasam recipe',ARRAY['veg','South Indian','festive']),

('DS006','Ladoo','🟡','Desserts & Sweets',
 ARRAY['dessert','snacks'],
 '[{"name":"Gram flour","qty":2,"unit":"cups"},{"name":"Sugar","qty":1.5,"unit":"cups"},{"name":"Ghee","qty":0.5,"unit":"cup"},{"name":"Cardamom","qty":5,"unit":"pcs"},{"name":"Cashews","qty":15,"unit":"pcs"},{"name":"Raisins","qty":2,"unit":"tbsp"}]',
 30,15,20,180,'Besan Ladoo recipe',ARRAY['veg','festive','Diwali']),

-- ── Beverages ─────────────────────────────────────────────────────────────────
('SS001','Masala Chai','☕','Beverages',
 ARRAY['snacks'],
 '[{"name":"Water","qty":1,"unit":"cup"},{"name":"Milk","qty":0.5,"unit":"cup"},{"name":"Tea leaves","qty":1.5,"unit":"tsp"},{"name":"Sugar","qty":1.5,"unit":"tsp"},{"name":"Ginger","qty":0.25,"unit":"inch"},{"name":"Cardamom","qty":2,"unit":"pcs"},{"name":"Cloves","qty":2,"unit":"pcs"},{"name":"Cinnamon","qty":0.5,"unit":"inch"}]',
 8,2,2,80,'Masala Chai recipe',ARRAY['veg','hot','everyday']),

('BV001','Mango Lassi','🥭','Beverages',
 ARRAY['beverage'],
 '[{"name":"Curd","qty":1,"unit":"cup"},{"name":"Mango pulp","qty":0.5,"unit":"cup"},{"name":"Milk","qty":0.25,"unit":"cup"},{"name":"Sugar","qty":2,"unit":"tbsp"},{"name":"Cardamom","qty":1,"unit":"pcs"},{"name":"Ice cubes","qty":4,"unit":"pcs"}]',
 0,5,2,180,'Mango Lassi recipe',ARRAY['veg','summer','refreshing']),

('BV002','Filter Coffee','☕','Beverages',
 ARRAY['beverage','breakfast'],
 '[{"name":"Coffee powder","qty":2,"unit":"tbsp"},{"name":"Milk","qty":1,"unit":"cup"},{"name":"Water","qty":0.25,"unit":"cup"},{"name":"Sugar","qty":1.5,"unit":"tsp"}]',
 8,2,1,90,'South Indian Filter Coffee recipe',ARRAY['veg','South Indian','morning']),

('BV003','Buttermilk','🥛','Beverages',
 ARRAY['beverage','lunch'],
 '[{"name":"Curd","qty":0.5,"unit":"cup"},{"name":"Water","qty":1.5,"unit":"cups"},{"name":"Ginger","qty":0.25,"unit":"inch"},{"name":"Green chilli","qty":0.5,"unit":"pcs"},{"name":"Curry leaves","qty":4,"unit":"pcs"},{"name":"Coriander leaves","qty":1,"unit":"tbsp"},{"name":"Roasted cumin","qty":0.25,"unit":"tsp"},{"name":"Salt","qty":0.25,"unit":"tsp"}]',
 0,5,2,45,'Masala Buttermilk recipe',ARRAY['veg','cooling','summer']),

('BV004','Rose Milk','🌹','Beverages',
 ARRAY['beverage'],
 '[{"name":"Milk","qty":1,"unit":"cup"},{"name":"Rose syrup","qty":2,"unit":"tbsp"},{"name":"Sugar","qty":1,"unit":"tsp"},{"name":"Ice cubes","qty":4,"unit":"pcs"},{"name":"Basil seeds","qty":0.5,"unit":"tsp"}]',
 0,3,1,160,'Rose Milk recipe',ARRAY['veg','summer','Tamil Nadu']),

('BV005','Turmeric Milk','🌿','Beverages',
 ARRAY['beverage'],
 '[{"name":"Milk","qty":1,"unit":"cup"},{"name":"Turmeric","qty":0.5,"unit":"tsp"},{"name":"Ginger","qty":0.25,"unit":"inch"},{"name":"Honey","qty":1,"unit":"tsp"},{"name":"Cardamom","qty":1,"unit":"pcs"},{"name":"Black pepper","qty":1,"unit":"pinch"}]',
 5,2,1,120,'Golden Milk Turmeric recipe',ARRAY['veg','healthy','immunity']),

('BV006','Lemonade','🍋','Beverages',
 ARRAY['beverage'],
 '[{"name":"Lemon juice","qty":4,"unit":"tbsp"},{"name":"Water","qty":2,"unit":"cups"},{"name":"Sugar","qty":3,"unit":"tbsp"},{"name":"Black salt","qty":0.25,"unit":"tsp"},{"name":"Roasted cumin","qty":0.25,"unit":"tsp"},{"name":"Mint leaves","qty":5,"unit":"pcs"},{"name":"Ice cubes","qty":6,"unit":"pcs"}]',
 0,5,2,60,'Nimbu Pani recipe',ARRAY['veg','summer','refreshing']);
