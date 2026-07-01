-- ============================================================
-- AI PROMPTS DATABASE + EDGE FUNCTION SETUP
-- App: WAI Life Assistant
-- Generated: March 2026
-- ============================================================

-- ── 1. PROMPTS TABLE ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_prompts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature       TEXT NOT NULL,
  sub_feature   TEXT NOT NULL,
  input_type    TEXT NOT NULL DEFAULT 'text', -- text | image | both
  version       INTEGER NOT NULL DEFAULT 1,
  prompt        TEXT NOT NULL,
  schema_hint   JSONB,                        -- expected JSON keys for validation
  is_active     BOOLEAN NOT NULL DEFAULT true,
  notes         TEXT,                         -- why this version exists
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(feature, sub_feature, input_type, version)
);

CREATE INDEX IF NOT EXISTS idx_prompts_lookup
  ON ai_prompts(feature, sub_feature, input_type, is_active);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_prompt_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ai_prompts_updated_at
  BEFORE UPDATE ON ai_prompts
  FOR EACH ROW EXECUTE FUNCTION update_prompt_timestamp();

-- ── 2. PARSE LOGS TABLE ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_parse_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES auth.users(id),
  feature       TEXT NOT NULL,
  sub_feature   TEXT NOT NULL,
  input_type    TEXT NOT NULL,
  prompt_id     UUID REFERENCES ai_prompts(id),
  raw_input     TEXT,
  parsed_output JSONB,
  confidence    FLOAT,
  was_corrected BOOLEAN DEFAULT false,
  correction    JSONB,
  tokens_used   INTEGER,
  latency_ms    INTEGER,
  error         TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_parse_logs_user
  ON ai_parse_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_parse_logs_feature
  ON ai_parse_logs(feature, sub_feature, created_at DESC);

-- ── 3. ROW LEVEL SECURITY ─────────────────────────────────────
ALTER TABLE ai_prompts ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_parse_logs ENABLE ROW LEVEL SECURITY;

-- Prompts: anyone authenticated can read, only service role can write
CREATE POLICY "prompts_read" ON ai_prompts
  FOR SELECT TO authenticated USING (true);

-- Logs: users see only their own logs
CREATE POLICY "logs_own" ON ai_parse_logs
  FOR ALL TO authenticated
  USING (user_id = auth.uid());

-- ── 4. SEED PROMPTS ───────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════
-- WALLET PROMPTS
-- ══════════════════════════════════════════════════════════════

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, notes, schema_hint, prompt) VALUES

('wallet', 'expense', 'text', 1, 'Parse expense/income/lend/borrow from plain text',
'{
  "title": "string",
  "amount": "number",
  "type": "expense|income|lend|borrow",
  "category": "string",
  "payment_mode": "string|null",
  "scope": "personal|family",
  "person": "string|null",
  "date": "YYYY-MM-DD",
  "note": "string|null",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a financial transaction parser for an Indian household expense tracking app.

TASK: Extract structured transaction details from this plain text input.

Input: "{{text}}"
Today is: {{today}}
Current scope context: {{scope}}
User''s existing categories: {{categories}}
Family members: {{members}}

Return ONLY valid JSON matching this exact structure — no explanation, no markdown:
{
  "title": "concise transaction name (max 5 words)",
  "amount": 0,
  "type": "expense",
  "category": "Food",
  "payment_mode": null,
  "scope": "personal",
  "person": null,
  "date": "{{today}}",
  "note": null,
  "confidence": 0.9
}

TYPE RULES:
- expense: paid, spent, bought, bill, fee
- income: received, salary, got, earned, credited
- lend: gave, lent, gave to, lend to
- borrow: borrowed, took from, got from person

CATEGORY OPTIONS (pick closest):
Food, Transport, Shopping, Health, Education, Entertainment,
Utilities, Rent, Salary, Freelance, Investment, Groceries,
Medical, Travel, Fuel, Clothing, Subscription, Other

PAYMENT MODE:
- cash: cash, notes, physically paid
- upi: UPI, GPay, PhonePe, Paytm, BHIM
- card: card, debit, credit, swipe
- online: net banking, NEFT, IMPS, transfer
- null: if not mentioned

SCOPE RULES:
- personal: I, me, my, for myself
- family: family, home, house, everyone, we, Amma, Appa, kids

PERSON (for lend/borrow only):
- Extract name if type is lend or borrow
- Must be one of family members if mentioned: {{members}}

DATE RULES:
- today → {{today}}
- yesterday → one day before {{today}}
- Use {{today}} if no date mentioned

CONFIDENCE:
- 0.9+ : all fields clearly mentioned
- 0.7-0.9: some fields inferred
- below 0.7: significant guessing$$),

('wallet', 'receipt', 'image', 1, 'Parse receipt/bill photo to extract transaction',
'{
  "merchant_name": "string",
  "total_amount": "number",
  "date": "YYYY-MM-DD|null",
  "items": "array",
  "payment_mode": "string|null",
  "category": "string",
  "tax_amount": "number",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a receipt and bill image parser for an Indian expense tracking app.

TASK: Carefully examine this receipt/bill image and extract all transaction details.

Today is: {{today}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "merchant_name": "store or vendor name",
  "total_amount": 0,
  "date": null,
  "items": [
    { "name": "item name", "qty": 1, "price": 0 }
  ],
  "payment_mode": null,
  "category": "Food",
  "tax_amount": 0,
  "gst_number": null,
  "confidence": 0.9
}

RULES:
- total_amount: always use GRAND TOTAL or TOTAL AMOUNT (the final number to be paid)
- items: only include if line items are clearly readable
- date: convert any date format to YYYY-MM-DD
- tax_amount: look for GST, CGST, SGST, Tax fields
- gst_number: 15-character GST number if visible
- category: infer from merchant type
- If image is blurry or unclear, set confidence below 0.5
- If total not visible, set total_amount: 0 and confidence below 0.4$$),

('wallet', 'split', 'text', 1, 'Parse group bill split from plain text',
'{
  "title": "string",
  "total_amount": "number",
  "paid_by": "string|null",
  "split_type": "equal|custom|percentage",
  "splits": "array",
  "category": "string",
  "date": "YYYY-MM-DD",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a bill splitting parser for a group expense tracking app.

TASK: Extract bill split details from this plain text input.

Input: "{{text}}"
Today is: {{today}}
Group members available: {{members}}
Number of people if mentioned: {{people_count}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "title": "what was split",
  "total_amount": 0,
  "paid_by": null,
  "split_type": "equal",
  "splits": [
    { "member": "name", "amount": 0, "percentage": 0 }
  ],
  "category": "Food",
  "date": "{{today}}",
  "note": null,
  "confidence": 0.9
}

SPLIT TYPE RULES:
- equal: split equally among all
- custom: specific amounts per person mentioned
- percentage: percentages mentioned

CALCULATION RULES:
- For equal split: each person''s amount = total / count
- Always include all mentioned members in splits array
- If paid_by mentioned, that person''s net is (their_share - total)
- Others'' net is their_share (they owe paid_by)

MEMBER RULES:
- Match names to available members if possible
- "me" or "I" = current user
- Extract all names mentioned in input$$),

('wallet', 'bill', 'text', 1, 'Parse bill/subscription details for bill watch',
'{
  "bill_name": "string",
  "amount": "number|null",
  "is_estimated": "boolean",
  "due_date": "YYYY-MM-DD",
  "recurrence": "once|monthly|quarterly|yearly",
  "category": "string",
  "scope": "personal|family",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a bill and subscription tracker parser for a household finance app.

TASK: Extract bill details from this plain text input.

Input: "{{text}}"
Today is: {{today}}
Current month: {{current_month}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "bill_name": "descriptive bill name",
  "amount": null,
  "is_estimated": true,
  "due_date": "{{today}}",
  "recurrence": "monthly",
  "recurrence_day": null,
  "category": "utility",
  "scope": "family",
  "biller_hint": null,
  "confidence": 0.9
}

CATEGORY OPTIONS:
utility, telecom, rent, emi, subscription, credit_card, insurance, custom

RECURRENCE RULES:
- monthly: every month, monthly, each month
- quarterly: every 3 months, quarterly
- yearly: annual, yearly, once a year
- once: one-time, single payment

DUE DATE RULES:
- "15th every month" → recurrence_day: 15
- "due in 5 days" → today + 5 days
- "end of month" → last day of current month

SCOPE RULES:
- family: electricity, water, rent, gas, WiFi, internet, household
- personal: credit card, personal loan, OTT subscription, gym$$),

-- ══════════════════════════════════════════════════════════════
-- PANTRY PROMPTS
-- ══════════════════════════════════════════════════════════════

('pantry', 'meal', 'text', 1, 'Parse meal addition to MealMap from plain text',
'{
  "meal_name": "string",
  "meal_type": "breakfast|lunch|snacks|dinner",
  "date": "YYYY-MM-DD",
  "scope": "personal|family",
  "servings": "number",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a meal planning assistant for an Indian household app.

TASK: Extract meal planning details from this plain text input.

Input: "{{text}}"
Today is: {{today}}
Day of week: {{day_of_week}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "meal_name": "dish name",
  "meal_type": "breakfast",
  "date": "{{today}}",
  "scope": "family",
  "servings": 2,
  "from_recipe_box": false,
  "note": null,
  "confidence": 0.9
}

MEAL TYPE RULES:
- breakfast: morning, bf, breakfast, tiffin, 7am-10am
- lunch: noon, afternoon, lunch, 12pm-3pm
- snacks: evening, snack, tea time, 4pm-6pm
- dinner: night, dinner, supper, 7pm-10pm
- If unclear and morning → breakfast, night → dinner

DATE RULES:
- today → {{today}}
- tomorrow → tomorrow''s date
- "Monday" → next upcoming Monday
- Day not mentioned → {{today}}

SCOPE RULES:
- family: everyone, family, we, all of us (default for meals)
- personal: just me, only me, for myself

SERVINGS:
- Extract number if mentioned ("for 4 people" → 4)
- Default: 2 for personal, 4 for family

FROM RECIPE BOX:
- true if meal sounds like a saved/known recipe
- false if it''s a custom or one-off meal$$),

('pantry', 'basket', 'text', 1, 'Parse grocery/stock item from plain text',
'{
  "item_name": "string",
  "quantity": "number",
  "unit": "string",
  "category": "string",
  "action": "string",
  "estimated_price": "number|null",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a pantry and grocery tracker parser for an Indian household app.

TASK: Extract grocery item details from this plain text input.

Input: "{{text}}"
Today is: {{today}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "item_name": "item name",
  "quantity": 1,
  "unit": "pcs",
  "category": "vegetables",
  "action": "add_tobuy",
  "estimated_price": null,
  "expiry_days": null,
  "note": null,
  "confidence": 0.9
}

ACTION RULES:
- add_stock: got, bought, received, have, added ("got tomatoes")
- add_tobuy: need, buy, get, want, running low ("need tomatoes")
- mark_finished: finished, ran out, empty, used up, over
- update_quantity: have X left, remaining, only X left

UNIT INFERENCE (if not mentioned):
- Rice, dal, flour, sugar, salt → kg
- Milk, oil, water → L
- Eggs, bread, fruits (whole) → pcs
- Vegetables (loose) → kg
- Packaged items → pack
- Herbs/greens → bunch

CATEGORY OPTIONS:
vegetables, dairy, grains, proteins, spices, fruits, beverages, snacks, cleaning, personal_care, other

PRICE:
- Extract if mentioned ("tomatoes for 40 rupees" → 40)
- null if not mentioned

EXPIRY DAYS:
- Extract if mentioned ("expires in 3 days" → 3)
- null if not mentioned$$),

('pantry', 'scan', 'image', 1, 'Scan fridge/pantry/grocery bag photo to detect items',
'{
  "items": "array",
  "scan_confidence": "number",
  "notes": "string"
}'::jsonb,
$$ROLE: You are a pantry and refrigerator scanner for an Indian household food tracking app.

TASK: Carefully examine this image of a fridge, pantry shelf, kitchen counter, or grocery bag and identify all visible food items.

Return ONLY valid JSON — no explanation, no markdown:
{
  "items": [
    {
      "item_name": "tomatoes",
      "estimated_quantity": 4,
      "unit": "pcs",
      "category": "vegetables",
      "freshness": "fresh",
      "confidence": 0.9
    }
  ],
  "scan_confidence": 0.8,
  "notes": "any observation about pantry state"
}

IDENTIFICATION RULES:
- Only list items you can clearly identify
- Common Indian pantry items: rice, dal, atta, spices, oil, vegetables, fruits, dairy
- Estimate quantity from visual cues (half bottle = 0.5L, 5 tomatoes = 5 pcs)
- For packaged items: include brand only if clearly visible

FRESHNESS ASSESSMENT:
- fresh: bright color, good texture, no wilting
- nearly_expired: slight discoloration, some wilting
- expired: clearly spoiled, mold visible, very wilted
- unknown: cannot assess from image

UNITS:
- Loose items (tomatoes, onions, fruits) → pcs or kg estimate
- Liquids (milk, oil) → L
- Packaged items → pack
- Leafy vegetables → bunch

CONFIDENCE PER ITEM:
- 0.9+: clearly identifiable
- 0.7-0.9: fairly sure
- below 0.7: uncertain, include with low confidence flag$$),

-- ══════════════════════════════════════════════════════════════
-- PLANIT PROMPTS
-- ══════════════════════════════════════════════════════════════

('planit', 'reminder', 'text', 1, 'Parse reminder/alert from plain text',
'{
  "title": "string",
  "date": "YYYY-MM-DD|null",
  "time": "HH:MM|null",
  "repeat": "none|daily|weekly|monthly",
  "scope": "personal|family",
  "priority": "high|medium|low",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a smart reminder parser for a personal and family planning app.

TASK: Extract reminder details from this natural language input.

Input: "{{text}}"
Today is: {{today}}
Day of week today: {{day_of_week}}
Family members: {{members}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "title": "concise reminder title",
  "date": null,
  "time": null,
  "repeat": "none",
  "repeat_day": null,
  "repeat_months": null,
  "scope": "personal",
  "priority": "medium",
  "notify_before_minutes": 15,
  "note": null,
  "confidence": 0.9
}

TITLE RULES:
- Remove words like "remind me to", "don''t forget to", "remember to"
- Keep it action-oriented ("Call Ravi", "Pay electricity bill", "Take medicine")

DATE RULES:
- today → {{today}}
- tomorrow → next day
- "next Monday" → nearest upcoming Monday from {{today}}
- "in 3 days" → {{today}} + 3 days
- "15th" → 15th of current or next month
- No date mentioned → null (user will pick)

TIME RULES (24-hour format):
- "6" without am/pm → infer: morning context=06:00, evening context=18:00
- "morning" → 08:00, "afternoon" → 14:00, "evening" → 18:00, "night" → 21:00
- No time → null

REPEAT RULES:
- none: one-time reminder
- daily: every day, daily, each day, everyday
- weekly: every week, weekly, every [day name]
- monthly: every month, monthly, every [Nth]

PRIORITY:
- high: urgent, ASAP, important, bill, payment, medicine, doctor
- low: someday, whenever, casual
- medium: default

SCOPE:
- family: remind everyone, tell family, family dinner, notify all
- personal: default$$),

('planit', 'task', 'text', 1, 'Parse task/to-do from plain text',
'{
  "title": "string",
  "due_date": "YYYY-MM-DD|null",
  "priority": "high|medium|low",
  "tag": "string",
  "scope": "personal|family",
  "assignee": "string|null",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a task and to-do list parser for a personal productivity app.

TASK: Extract task details from this plain text input.

Input: "{{text}}"
Today is: {{today}}
Family members: {{members}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "title": "clear actionable task title",
  "due_date": null,
  "priority": "medium",
  "tag": "Personal",
  "scope": "personal",
  "assignee": null,
  "subtasks": [],
  "note": null,
  "confidence": 0.9
}

TITLE RULES:
- Start with a verb if possible (Buy, Call, Fix, Submit, Book)
- Remove "I need to", "have to", "must" etc.
- Max 8 words

PRIORITY RULES:
- high: urgent, ASAP, deadline today/tomorrow, important, critical
- low: someday, maybe, whenever possible, low priority
- medium: default for everything else

TAG OPTIONS:
Work, Personal, Home, Health, Finance, Learning, Shopping, Travel, Family, Other

SCOPE + ASSIGNEE RULES:
- If assignee mentioned → scope: family automatically
- "assign to Ravi" or "Ravi should" → assignee: Ravi
- Match assignee to family members: {{members}}
- No assignee mentioned → scope: personal

DUE DATE:
- Extract relative dates (tomorrow, next week, by Friday)
- "end of month" → last day of current month
- "no rush" or "someday" → null

SUBTASKS:
- Only if input explicitly breaks down steps
- "first do X then Y" → subtasks: ["X", "Y"]
- Otherwise empty array$$),

('planit', 'special_day', 'text', 1, 'Parse birthday/anniversary/festival/event from plain text',
'{
  "title": "string",
  "date": "YYYY-MM-DD",
  "type": "string",
  "recurs_yearly": "boolean",
  "scope": "personal|family",
  "person": "string|null",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a special occasions and events parser for a family planning app.

TASK: Extract special day details from this plain text input.

Input: "{{text}}"
Today is: {{today}}
Family members: {{members}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "title": "occasion name",
  "date": "{{today}}",
  "type": "birthday",
  "recurs_yearly": true,
  "scope": "family",
  "person": null,
  "reminder_days_before": 3,
  "note": null,
  "confidence": 0.9
}

TYPE OPTIONS:
birthday, anniversary, festival, holiday, personal_milestone,
graduation, promotion, wedding, other

RECURRENCE RULES:
- true: birthdays, anniversaries, festivals, annual events
- false: one-time events (wedding happening this year, exam date)

DATE RULES:
- Extract day and month (year optional, default to next occurrence)
- "Apr 15" → next Apr 15 from {{today}}
- Festival dates may vary yearly — use this year''s date if mentioned

PERSON RULES:
- Extract whose occasion it is ("Amma''s birthday" → person: Amma)
- Match to family members: {{members}}
- My/personal → person: null (it''s the user''s own)

REMINDER:
- Birthdays/anniversaries → 3 days before (default)
- Festivals → 1 day before
- Adjust if user mentions ("remind me a week before" → 7)$$),

('planit', 'wishlist', 'text', 1, 'Parse wish/goal/savings target from plain text',
'{
  "title": "string",
  "target_amount": "number|null",
  "category": "string",
  "scope": "personal|family",
  "target_date": "YYYY-MM-DD|null",
  "priority": "high|medium|low",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a wish list and savings goal parser for a personal finance planning app.

TASK: Extract wish or goal details from this plain text input.

Input: "{{text}}"
Today is: {{today}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "title": "what they want",
  "target_amount": null,
  "already_saved": 0,
  "category": "other",
  "scope": "personal",
  "target_date": null,
  "priority": "medium",
  "note": null,
  "confidence": 0.9
}

CATEGORY OPTIONS:
gadget, travel, vehicle, home_appliance, furniture, clothing,
experience, education, health, investment, gift, other

AMOUNT RULES:
- Extract if mentioned ("save 50000 for laptop" → 50000)
- Lakh conversion: "1.5 lakh" → 150000
- null if no amount mentioned

ALREADY SAVED:
- "already have 10000" or "saved 10k" → already_saved: 10000
- Default: 0

SCOPE RULES:
- family: family trip, our new car, home renovation, we want
- personal: I want, my laptop, personal goal, for myself

DATE:
- "by Diwali" → Diwali date
- "in 6 months" → today + 6 months
- null if no date mentioned$$),

('planit', 'plan_party', 'text', 1, 'Parse event/party planning details from plain text',
'{
  "event_name": "string",
  "date": "YYYY-MM-DD|null",
  "venue": "string|null",
  "guest_count": "number|null",
  "budget": "number|null",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are an event planning parser for a family life management app.

TASK: Extract party or event planning details from this plain text input.

Input: "{{text}}"
Today is: {{today}}
Family members: {{members}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "event_name": "event name",
  "event_type": "birthday_party",
  "date": null,
  "venue": null,
  "guest_count": null,
  "budget": null,
  "scope": "family",
  "tasks": [],
  "note": null,
  "confidence": 0.9
}

EVENT TYPE OPTIONS:
birthday_party, anniversary_celebration, festival_celebration,
house_warming, get_together, wedding, baby_shower, farewell, other

TASKS (auto-suggested based on event type):
- birthday_party: ["Order cake", "Send invites", "Book venue", "Arrange decorations"]
- Extract if user mentions specific tasks$$),

-- ══════════════════════════════════════════════════════════════
-- MYLIFE PROMPTS
-- ══════════════════════════════════════════════════════════════

('mylife', 'garage', 'text', 1, 'Parse vehicle/garage item from plain text',
'{
  "item_type": "string",
  "name": "string",
  "action": "string",
  "due_date": "YYYY-MM-DD|null",
  "amount": "number|null",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a vehicle and garage management parser for a home life app.

TASK: Extract vehicle or garage item details from this plain text input.

Input: "{{text}}"
Today is: {{today}}
User''s vehicles: {{vehicles}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "item_type": "vehicle",
  "name": "item or service name",
  "vehicle_name": null,
  "action": "add",
  "due_date": null,
  "amount": null,
  "document_type": null,
  "reminder": true,
  "note": null,
  "confidence": 0.9
}

ITEM TYPE OPTIONS:
vehicle, tool, spare_part, accessory, document, service_record

ACTION OPTIONS:
- add: adding new vehicle or item
- service_due: service is due or scheduled
- insurance_due: insurance renewal due
- puc_due: PUC/emission test due
- document_added: adding RC, insurance copy, PUC
- repair_needed: something needs fixing
- repair_done: repair completed

DOCUMENT TYPE (when action is document_added):
RC, insurance, PUC, license, warranty, invoice, other

VEHICLE MATCHING:
- Match to user''s known vehicles: {{vehicles}}
- Extract vehicle number/name if mentioned$$),

('mylife', 'wardrobe', 'image', 1, 'Catalogue clothing item from image',
'{
  "item_type": "string",
  "color": "string",
  "occasion": "string",
  "season": "string",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a wardrobe cataloguing assistant for a personal clothing management app.

TASK: Carefully examine this image of a clothing item and extract all details.

Return ONLY valid JSON — no explanation, no markdown:
{
  "item_type": "t-shirt",
  "color": "navy",
  "color_secondary": null,
  "pattern": "solid",
  "fabric_guess": "cotton",
  "occasion": "casual",
  "brand": null,
  "season": "all-season",
  "gender": "unisex",
  "size_visible": null,
  "notes": null,
  "confidence": 0.9
}

ITEM TYPE OPTIONS:
shirt, t-shirt, trouser, jeans, shorts, dress, saree, salwar_kameez,
kurta, lehenga, jacket, blazer, sweater, hoodie, shoes, sandals,
sneakers, heels, bag, belt, watch, accessory, ethnic_wear, other

COLOR: Use common descriptive names (navy, olive, cream, burgundy, charcoal)

PATTERN: solid, striped, checked, printed, floral, geometric, abstract, embroidered

FABRIC (visual guess only):
cotton, silk, denim, polyester, wool, linen, synthetic, unknown

OCCASION: casual, formal, ethnic, party, sports, home, beach, office

SEASON: summer, winter, monsoon, all-season

BRAND: Only if clearly visible on tag, label, or embroidery. Otherwise null.$$),

('mylife', 'item_locator', 'text', 1, 'Parse item storage location from plain text',
'{
  "item_name": "string",
  "location": "string",
  "room": "string",
  "container": "string",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a home item location tracker for a household management app.

TASK: Extract where an item was stored from this plain text input.

Input: "{{text}}"
Today is: {{today}}
Family members: {{members}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "item_name": "item that was stored",
  "location": "specific location description",
  "room": "bedroom",
  "container": "drawer",
  "container_label": null,
  "stored_by": null,
  "date_stored": "{{today}}",
  "note": null,
  "confidence": 0.9
}

ROOM OPTIONS:
bedroom, master_bedroom, kids_room, kitchen, living_room,
dining_room, bathroom, garage, store_room, balcony, study, other

CONTAINER OPTIONS:
drawer, shelf, cupboard, wardrobe, box, bag, cabinet,
refrigerator, freezer, counter, table, floor, wall_hook, other

STORED_BY:
- "I kept" → stored_by: current user (return "me")
- "Amma kept" → stored_by: Amma
- Match to family members: {{members}}

LOCATION SPECIFICITY:
- As specific as possible ("second drawer from top in bedroom cupboard")
- Extract labels if mentioned ("red box", "box labeled medicines")

SEARCH KEYWORDS (for item locator search):
- Generate 3-5 keywords that would help find this item later$$),

('mylife', 'wardrobe', 'text', 1, 'Parse clothing item details from plain text description',
'{
  "item_type": "string",
  "color": "string",
  "occasion": "string",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a wardrobe management parser for a personal clothing inventory app.

TASK: Extract clothing item details from this plain text description.

Input: "{{text}}"

Return ONLY valid JSON — no explanation, no markdown:
{
  "item_type": "shirt",
  "color": "blue",
  "color_secondary": null,
  "pattern": "solid",
  "brand": null,
  "occasion": "casual",
  "season": "all-season",
  "size": null,
  "purchase_date": null,
  "purchase_price": null,
  "note": null,
  "confidence": 0.9
}

Same field rules as image-based wardrobe parser but from text description.
Extract size if mentioned (S, M, L, XL, 32, 34, etc.)
Extract purchase price if mentioned.$$),

('planit', 'note', 'text', 1, 'Parse sticky note from plain text',
'{
  "title": "string",
  "content": "string",
  "note_type": "text|list|link|secret",
  "color": "yellow|pink|blue|green|purple|orange|mint|white",
  "is_pinned": "boolean",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a sticky note parser for a personal planning app.

TASK: Extract sticky note details from this plain text input.

Input: "{{text}}"
Today is: {{today}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "title": "concise note title (optional, max 6 words)",
  "content": "the note content",
  "note_type": "text",
  "color": "yellow",
  "is_pinned": false,
  "confidence": 0.9
}

NOTE TYPE RULES:
- text: general notes, thoughts, memos, reminders, quotes
- list: bullet points, items, steps, multiple things to do/buy ("milk, eggs, bread", "steps: 1. 2. 3.")
- link: URLs, web addresses, http/https links, "check out this site"
- secret: passwords, PINs, account credentials, private/sensitive info ("password", "PIN", "secret", "private")

COLOR RULES (pick the most fitting):
- yellow: general notes, memos, thoughts (default)
- pink: personal, emotional, love notes, wishes
- blue: links, work, professional, technology topics
- green: lists, groceries, tasks, nature topics
- purple: creative, ideas, secrets, private notes
- orange: important, warnings, reminders, urgent notes
- mint: health, wellness, recipes, fresh topics
- white: neutral, clean, minimal notes

TITLE RULES:
- Extract a short title from the first sentence or main topic
- Remove filler words ("note about", "reminder to", "I need to remember")
- If input is very short (< 5 words), leave title empty and put everything in content
- Max 6 words

CONTENT RULES:
- For list type: format each item on its own line
- For link type: put the URL as content, description in title
- Keep content faithful to original input
- Do not truncate

IS_PINNED:
- true: "important", "pin this", "don''t forget", "urgent", "remember"
- false: default

CONFIDENCE:
- 0.9+: clear, complete input
- 0.7-0.9: some inference needed
- below 0.7: ambiguous input$$)

ON CONFLICT (feature, sub_feature, input_type, version) DO UPDATE
  SET prompt = EXCLUDED.prompt,
      schema_hint = EXCLUDED.schema_hint,
      notes = EXCLUDED.notes,
      updated_at = NOW();

-- ── 5. HELPER VIEW ────────────────────────────────────────────
CREATE OR REPLACE VIEW active_prompts AS
SELECT
  id, feature, sub_feature, input_type,
  version, prompt, schema_hint, notes,
  created_at, updated_at
FROM ai_prompts
WHERE is_active = true
ORDER BY feature, sub_feature, input_type;

-- ── 6. VERIFICATION QUERY ─────────────────────────────────────
SELECT
  feature,
  sub_feature,
  input_type,
  version,
  LENGTH(prompt) as prompt_length,
  notes
FROM ai_prompts
ORDER BY feature, sub_feature, input_type;
