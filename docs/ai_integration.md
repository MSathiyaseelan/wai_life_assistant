# WAI Life Assistant — Technical Documentation
### Section 4: AI Integration

---

> **Note on requested files:** `lib/shared/ai/smart_parser.dart`, `rule_engine.dart`, `local_model.dart`, and `parse_result.dart` do not exist in the codebase. The actual AI architecture is documented here based on the real implementation: `supabase/functions/parse/index.ts`, `supabase/migrations/ai_prompts.sql`, `supabase/migrations/functions_ai_prompts.sql`, and the per-module local NLP parsers.

---

## 4.1 Architecture Overview

WAI uses a **2-layer hybrid parsing system** with a special 3-step flow for the Dashboard AI assistant.

```
User input (text or image)
        │
        ▼
┌──────────────────────────────┐
│  Layer 1: Local NLP Parser   │  ← Deterministic regex/keyword matching
│  (per module, client-side)   │    Zero API cost · Zero latency
│                              │    Used as primary in PantryNlpParser
│                              │    Used as FALLBACK in all other modules
└──────────────────────────────┘
        │ fails or bypassed
        ▼
┌──────────────────────────────┐
│  Layer 2: Cloud AI (Gemini)  │  ← Supabase Edge Function /parse
│  Prompt fetched from DB      │    Gemini 2.5 Flash (text)
│  Context injected at runtime │    Gemini 2.0 Flash (images)
│  Response logged to DB       │
└──────────────────────────────┘
        │
        ▼
AIParseResult { success, data, confidence, needs_review, meta }
```

### Dashboard AI — 3-Step Flow (special case)

```
User asks: "How much did I spend this month?"
        │
        ▼
Step 1: IntentClassifier.classify(question)
  └─ Deterministic regex → QuestionIntent
     { dataSources: [wallet], timeRange: thisMonth, queryType: specific }
        │
        ▼
Step 2: ContextFetcher.fetch(intent, walletId)
  └─ Fetches real data from Supabase (parallel queries)
     → HouseholdContext { wallet: {...}, pantry: {}, planit: {}, ... }
     → Serialised as labelled text block
        │
        ▼
Step 3: AIParser.parseText(
           feature: 'dashboard',
           subFeature: 'ai_assistant',
           text: contextBlock + "\nQUESTION: " + question
        )
  └─ Gemini answers with context grounded in real data
     → AssistantResponse { answer, highlights, suggestions, actions }
```

---

## 4.2 Parse Edge Function (`/parse`)

**File:** `supabase/functions/parse/index.ts`

**Runtime:** Deno on Supabase Edge Functions
**Models:**
- `gemini-2.5-flash` — all text parsing tasks (default)
- `gemini-2.0-flash` — image parsing for `pantry/bill_scan` specifically

### Request Format

```typescript
POST /parse
Authorization: Bearer <user_jwt>
{
  "feature":      "wallet | pantry | planit | mylife | functions | lifestyle | dashboard",
  "sub_feature":  "expense | meal | reminder | ...",
  "input_type":   "text | image | voice_transcript",
  "text":         "user input string",           // required for text
  "image_base64": "base64 encoded image",         // required for image
  "image_mime_type": "image/jpeg",                // optional, default jpeg
  "context": {
    "today":         "YYYY-MM-DD",
    "day_of_week":   "Monday",
    "current_month": "April 2026",
    "currency":      "INR",
    "scope":         "personal | family",
    "members":       ["Arjun", "Priya", "Amma"],
    "categories":    ["Food", "Transport", ...],
    "vehicles":      ["Honda Activa", "Maruti Swift"],
    "people_count":  4
  }
}
```

### Response Format

```typescript
{
  "success":      true,
  "feature":      "wallet",
  "sub_feature":  "expense",
  "input_type":   "text",
  "data": {
    // Prompt-specific fields — see Section 4.5
    "confidence": 0.92
  },
  "confidence":   0.92,
  "needs_review": false,   // true when confidence < 0.7
  "meta": {
    "tokens_used": 312,
    "latency_ms":  840,
    "prompt_id":   "uuid",
    "model":       "gemini-2.5-flash"
  }
}
```

### Prompt Lookup Logic

The edge function tries three `input_type` fallbacks before giving a 404:

```
1. exact input_type match (e.g. "text")
2. "both"  (prompts marked as applicable to both text and image)
3. "text"  (final fallback)
```

### Context Injection

Prompt templates use `{{placeholder}}` syntax. All replacements happen server-side:

| Placeholder | Value Source |
|---|---|
| `{{text}}` | `body.text` |
| `{{today}}` | `body.context.today` or `new Date().toISOString().split('T')[0]` |
| `{{day_of_week}}` | `body.context.day_of_week` or computed |
| `{{current_month}}` | `body.context.current_month` or computed |
| `{{scope}}` | `body.context.scope` or `"personal"` |
| `{{members}}` | `body.context.members?.join(", ")` or `"not specified"` |
| `{{categories}}` | Custom categories or `"Food, Transport, Shopping, Health, Other"` |
| `{{vehicles}}` | User's registered vehicles or `"not specified"` |
| `{{people_count}}` | Group size or `"not specified"` |
| `{{currency}}` | `body.context.currency` or `"INR"` |

### JSON Cleaning

Gemini's text responses are cleaned before parsing:
1. Strip leading ` ```json ` and trailing ` ``` ` fences
2. If still invalid JSON, extract first `{...}` block with regex
3. If no JSON found → return HTTP 422 error

### Gemini Configuration

```json
{
  "temperature": 0.1,
  "maxOutputTokens": 2048,
  "responseMimeType": "application/json"   // only for text (not image)
}
```

Safety settings are all set to `BLOCK_NONE` — the prompts are non-harmful household management tasks and strict safety settings caused false positives.

---

## 4.3 Client-Side AI Client (`AIParser`)

**File:** `lib/core/services/ai_parser.dart`

```dart
class AIParser {
  static Future<AIParseResult> parseText({
    required String feature,
    required String subFeature,
    required String text,
    Map<String, dynamic>? context,
  });

  static Future<AIParseResult> parseImage({
    required String feature,
    required String subFeature,
    required List<int> imageBytes,
    String mimeType = 'image/jpeg',
    Map<String, dynamic>? context,
  });
}
```

The client automatically injects `{today, day_of_week, current_month, currency: 'INR'}` into every request context.

```dart
class AIParseResult {
  final bool success;
  final Map<String, dynamic>? data;  // parsed fields from AI
  final double? confidence;          // 0.0 – 1.0
  final bool needsReview;            // true when confidence < 0.7
  final String? error;               // error message if failed
  final Map<String, dynamic>? meta;  // tokens, latency, prompt_id, model
}
```

---

## 4.4 Module-Level Parse Pattern

Every feature follows the same two-step flow:

```dart
// Step 1: Try cloud AI
final aiResult = await AIParser.parseText(
  feature: 'planit',
  subFeature: 'reminder',
  text: userInput,
);

if (aiResult.success && aiResult.data != null) {
  // Use AI result — badge shown as "✨ AI"
  setState(() => _usingClaudeAI = true);
  return _parseFromAI(aiResult.data!);
}

// Step 2: Fall back to local NLP
try {
  return _NlpParser.parse(userInput);   // deterministic, no API
  // Badge shown as "🔍 Local NLP"
} catch (e) {
  // Show error banner, keep manual form open
}
```

> ⚠️ **UI/Backend mismatch:** The badge in the UI says "✨ Claude AI" but the backend calls Google Gemini. The prompt templates are written in Claude's instruction style but executed by Gemini 2.5 Flash.

### Per-Module Local NLP Parsers

| Module | Class | Location |
|---|---|---|
| Alert Me (Reminders) | `_NlpParser` | `alert_me_screen.dart` |
| My Tasks | `_TaskNlpParser` | `my_tasks_screen.dart` |
| Sticky Notes | `_NoteNlpParser` | `notes_screen.dart` |
| Pantry (Chat Input) | `PantryNlpParser` | `pantry/flows/pantry_nlp_parser.dart` |
| Wallet (Basic) | inline regex | `wallet_screen.dart` |

The Pantry NLP parser is the most complete standalone implementation and is used as the **primary layer** for the Pantry chat input (Gemini is only called after the intent confirmation sheet). All other local NLP parsers are strict fallbacks.

---

## 4.5 All Prompts — Complete Reference

### `ai_prompts` Table Schema

```sql
CREATE TABLE ai_prompts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature     TEXT NOT NULL,
  sub_feature TEXT NOT NULL,
  input_type  TEXT NOT NULL DEFAULT 'text',  -- text | image | both
  version     INTEGER NOT NULL DEFAULT 1,
  prompt      TEXT NOT NULL,
  schema_hint JSONB,   -- expected JSON shape (documentation, not enforced)
  is_active   BOOLEAN NOT NULL DEFAULT true,
  notes       TEXT,
  created_at  TIMESTAMPTZ,
  updated_at  TIMESTAMPTZ,
  UNIQUE(feature, sub_feature, input_type, version)
);
```

**Active prompt selection:** highest `version` where `is_active = true`, per `(feature, sub_feature, input_type)`.

---

### WALLET PROMPTS

---

#### `wallet / expense / text`

**Purpose:** Parse any plain-text financial transaction — expense, income, lend, or borrow.

**Used by:** Wallet screen quick-add bar, SparkBottomSheet AI input

**Context used:** `{{text}}`, `{{today}}`, `{{scope}}`, `{{categories}}`, `{{members}}`

**Returns:**
```json
{
  "title": "Swiggy Order",
  "amount": 350,
  "type": "expense",
  "category": "Food",
  "payment_mode": "upi",
  "scope": "personal",
  "person": null,
  "date": "2026-04-28",
  "note": null,
  "confidence": 0.94
}
```

| Field | Values | Notes |
|---|---|---|
| `type` | `expense \| income \| lend \| borrow` | Inferred from keywords |
| `payment_mode` | `cash \| upi \| card \| online \| null` | null if not mentioned |
| `scope` | `personal \| family` | family if household keywords present |
| `person` | string or null | Only for lend/borrow; matched to `{{members}}` |
| `confidence` | 0.0–1.0 | ≥0.9 all explicit, 0.7–0.9 inferred |

**Example input:** `"paid swiggy 350 upi yesterday"`

**Edge cases:**
- Indian auspicious amounts (₹101, ₹501, ₹1001) → treated as-is
- "Amma paid" → `person: "Amma"`, `type: lend`
- Amount with lakh notation: `"1.5 lakh"` → `150000`

---

#### `wallet / receipt / image`

**Purpose:** Extract full transaction details from a receipt or bill photo.

**Used by:** Wallet receipt scanner (camera/gallery flow)

**Model:** `gemini-2.5-flash` (text+vision)

**Returns:**
```json
{
  "merchant_name": "DMart",
  "total_amount": 1250.00,
  "date": "2026-04-20",
  "items": [
    { "name": "Basmati Rice 5kg", "qty": 1, "price": 450 }
  ],
  "payment_mode": "upi",
  "category": "Groceries",
  "tax_amount": 62.5,
  "gst_number": "29ABCDE1234F1Z5",
  "confidence": 0.88
}
```

**Edge cases:**
- Blurry/unclear image → `confidence < 0.5`
- Total not visible → `total_amount: 0, confidence < 0.4`
- GST number extracted if 15-char pattern visible
- Tax extracted from CGST/SGST breakdown

---

#### `wallet / split / text`

**Purpose:** Parse a group bill split description.

**Used by:** Wallet split entry (when adding a split from text)

**Context used:** `{{text}}`, `{{today}}`, `{{members}}`, `{{people_count}}`

**Returns:**
```json
{
  "title": "Dinner at Adyar Ananda Bhavan",
  "total_amount": 2400,
  "paid_by": "Arjun",
  "split_type": "equal",
  "splits": [
    { "member": "Arjun", "amount": 800, "percentage": 33.3 },
    { "member": "Priya", "amount": 800, "percentage": 33.3 },
    { "member": "Me",    "amount": 800, "percentage": 33.3 }
  ],
  "category": "Food",
  "date": "2026-04-28",
  "note": null,
  "confidence": 0.91
}
```

| Field | Values |
|---|---|
| `split_type` | `equal \| custom \| percentage` |
| `paid_by` | Name matched to `{{members}}`, or null |
| `splits` | All members with their share; `amount = total / count` for equal split |

---

#### `wallet / bill / text`

**Purpose:** Parse a recurring bill or subscription.

**Used by:** Bill Watch quick-add

**Returns:**
```json
{
  "bill_name": "Airtel Postpaid",
  "amount": null,
  "is_estimated": true,
  "due_date": "2026-05-05",
  "recurrence": "monthly",
  "recurrence_day": 5,
  "category": "telecom",
  "scope": "personal",
  "biller_hint": "Airtel",
  "confidence": 0.87
}
```

| Category | Keywords |
|---|---|
| `utility` | electricity, water, gas |
| `telecom` | internet, WiFi, mobile bill, Airtel, Jio |
| `rent` | house rent, room rent, PG |
| `emi` | loan EMI, home loan, car loan |
| `subscription` | Netflix, Prime, Hotstar, Spotify, gym |
| `credit_card` | credit card, CC bill |
| `insurance` | insurance premium |
| `custom` | anything else |

---

#### `wallet / split_expense / text`

**Purpose:** Parse a group expense for an existing split group.

**Used by:** Split Group Detail screen AI input

**Returns:**
```json
{
  "description": "Lunch",
  "amount": 1200,
  "paid_by": "Ravi",
  "category": "Food",
  "split_type": "equally",
  "confidence": 0.93
}
```

**Difference from `wallet/split`:** Simpler output — used when group members are already known; no per-member split array.

---

#### `wallet / sms_parse / text`

**Purpose:** Parse Indian bank transaction SMS into structured data.

**Used by:** SMS auto-scan service (`SmsParserService`) — currently pending Play Store approval

**Context used:** `{{text}}` (the SMS body), `{{sender}}` (sender ID like `HDFCBK`), `{{today}}`

**Returns:**
```json
{
  "is_transaction": true,
  "transaction_type": "debit",
  "amount": 500.00,
  "merchant": "Swiggy",
  "account_last4": "1234",
  "bank_name": "HDFC",
  "available_balance": 24500.00,
  "transaction_date": "2026-04-28",
  "transaction_time": "14:32",
  "reference_number": "TXN123456",
  "category": "Food",
  "payment_mode": "UPI",
  "confidence": 0.95
}
```

**Non-transaction SMS:** Returns `{ "is_transaction": false }`.

**Supported banks via sender ID:** HDFC, ICICI, SBI, Axis, Kotak, Paytm Bank.

**Merchant extraction patterns:**
- `Info: SWIGGY` → `"Swiggy"`
- `UPI/9876543210/Ravi Kumar` → `"Ravi Kumar"`
- `POS DMART CHENNAI` → `"DMart"`
- `ATW/HDFC ATM` → `"ATM Withdrawal"`
- `NEFT/Salary/TCS` → `"TCS Salary"`

---

### PANTRY PROMPTS

---

#### `pantry / basket / text` *(version 2 — active)*

**Purpose:** Multi-intent pantry text parser. Detects whether input is a basket item, meal log, or recipe save.

**Used by:** Pantry screen chat input (after local NLP intent confirmation)

**Returns (basket — single item):**
```json
{
  "kind": "basket",
  "item_name": "Coconut Oil",
  "normalized_name": "coconut oil",
  "quantity": 1,
  "unit": "litre",
  "category": "other",
  "action": "add_tobuy",
  "note": null,
  "expiry_days": null,
  "estimated_price": null,
  "confidence": 0.92
}
```

**Returns (basket — multiple items):**
```json
{
  "items": [
    {
      "item_name": "Brinjal", "normalized_name": "brinjal",
      "quantity": 2, "unit": "kg", "category": "vegetables",
      "action": "add_tobuy", "confidence": 0.9
    },
    {
      "item_name": "Pori", "normalized_name": "puffed rice",
      "quantity": 1, "unit": "pack", "category": "snacks",
      "action": "add_tobuy", "confidence": 0.8
    }
  ]
}
```

**Returns (meal intent):**
```json
{
  "kind": "meal",
  "meal_name": "Idli Sambar",
  "meal_time": "breakfast",
  "meal_date": "today",
  "emoji": "🫙",
  "confidence": 0.88
}
```

**Returns (recipe intent):**
```json
{
  "kind": "recipe",
  "recipe_name": "Butter Chicken",
  "confidence": 0.90
}
```

**Action values:** `add_tobuy` (only value — basket items always go to the To Buy list initially).

**`normalized_name`:** lowercase canonical name for fuzzy matching against existing stock.

**Edge cases:**
- Indian regional names: `"Pori"` → `normalized_name: "puffed rice"`, `"Murungakkai"` → `"drumstick"`
- Expiry hint for known perishables: milk → `expiry_days: 5`, bread → `expiry_days: 3`

---

#### `pantry / bill_scan / image`

**Purpose:** Extract structured items list from a grocery bill or shopping receipt photo.

**Used by:** Pantry Basket → Scan Bill flow (2-scan monthly limit for free users)

**Model:** `gemini-2.0-flash` (lighter vision model — chosen for cost vs. quality trade-off)

**Returns:**
```json
{
  "items": [
    {
      "name": "Basmati Rice",
      "quantity": 5,
      "unit": "kg",
      "price": 450.00,
      "category": "grains",
      "confidence": 0.95
    },
    {
      "name": "Amul Butter",
      "quantity": 2,
      "unit": "pack",
      "price": 120.00,
      "category": "dairy",
      "confidence": 0.90
    }
  ],
  "total_amount": 1250.00,
  "confidence": 0.90
}
```

**Rules:** Taxes, delivery charges, discounts, and store names are excluded from items. Brand removed from name (`"Amul Butter 500g"` → `"Amul Butter"`, size moved to unit).

**Feature limit:** `check_feature_limit(userId, 'bill_scan', 2)` enforced before calling this prompt.

---

#### `pantry / scan / image`

**Purpose:** Scan a fridge/pantry shelf/grocery bag and identify all visible items.

**Used by:** Pantry home scan flow

**Returns:**
```json
{
  "items": [
    {
      "item_name": "tomatoes",
      "estimated_quantity": 5,
      "unit": "pcs",
      "category": "vegetables",
      "freshness": "fresh",
      "confidence": 0.92
    }
  ],
  "scan_confidence": 0.85,
  "notes": "3 items visible in produce drawer"
}
```

**Freshness values:** `fresh | nearly_expired | expired | unknown`

---

#### `pantry / meal / text`

**Purpose:** Parse a meal log from plain text — name, type, date, servings.

**Used by:** MealMap add flow (text path)

**Returns:**
```json
{
  "meal_name": "Chicken Biryani",
  "meal_type": "lunch",
  "date": "2026-04-28",
  "scope": "family",
  "servings": 4,
  "from_recipe_box": false,
  "note": null,
  "confidence": 0.91
}
```

**Meal type detection:**
- `breakfast`: morning, tiffin, 7am–10am context
- `lunch`: noon, 12pm–3pm context
- `snacks`: evening, tea time, 4pm–6pm
- `dinner`: night, supper, 7pm–10pm

**Default servings:** 2 for personal scope, 4 for family.

---

### PLANIT PROMPTS

---

#### `planit / reminder / text`

**Used by:** Alert Me screen AI Parse tab

**Returns:**
```json
{
  "title": "Pay Electricity Bill",
  "date": "2026-05-05",
  "time": "10:00",
  "repeat": "monthly",
  "repeat_day": 5,
  "repeat_months": null,
  "scope": "personal",
  "priority": "high",
  "notify_before_minutes": 15,
  "note": null,
  "confidence": 0.93
}
```

**Input example:** `"Pay electricity bill on the 5th every month at 10am"`

**Time inference for ambiguous "6":**
- Morning context → `06:00`
- Evening context → `18:00`

**Priority auto-elevation:** bill, payment, medicine, doctor → always `high`.

---

#### `planit / task / text`

**Used by:** My Tasks screen AI Parse tab

**Returns:**
```json
{
  "title": "Book venue for Diwali party",
  "due_date": "2026-10-01",
  "priority": "high",
  "tag": "Family",
  "scope": "family",
  "assignee": "Arjun",
  "subtasks": ["Search venues", "Compare prices", "Confirm booking"],
  "note": null,
  "confidence": 0.88
}
```

**Tag options:** `Work | Personal | Home | Health | Finance | Learning | Shopping | Travel | Family | Other`

**Subtask extraction:** Only when input explicitly breaks into steps — `"first do X then Y"`.

---

#### `planit / special_day / text`

**Used by:** Special Days screen AI Parse tab

**Returns:**
```json
{
  "title": "Amma's Birthday",
  "date": "2026-09-15",
  "type": "birthday",
  "recurs_yearly": true,
  "scope": "family",
  "person": "Amma",
  "reminder_days_before": 3,
  "note": null,
  "confidence": 0.95
}
```

**Type options:** `birthday | anniversary | festival | holiday | personal_milestone | graduation | promotion | wedding | other`

**Recurrence default:** `true` for birthdays, anniversaries, festivals; `false` for one-time events like `"wedding happening this year"`.

**Reminder defaults:** Birthdays/anniversaries → 3 days before. Festivals → 1 day before.

---

#### `planit / wishlist / text`

**Used by:** Wish List screen AI Parse tab

**Returns:**
```json
{
  "title": "MacBook Pro M3",
  "target_amount": 200000,
  "already_saved": 50000,
  "category": "gadget",
  "scope": "personal",
  "target_date": "2026-12-01",
  "priority": "medium",
  "note": null,
  "confidence": 0.89
}
```

**Lakh conversion:** `"2 lakh"` → `200000`, `"1.5 lakh"` → `150000`.

**Category options:** `gadget | travel | vehicle | home_appliance | furniture | clothing | experience | education | health | investment | gift | other`

---

#### `planit / note / text`

**Used by:** Sticky Notes screen AI Parse tab

**Returns:**
```json
{
  "title": "Team Meeting Notes",
  "content": "- Update landing page\n- Call vendor\n- Send report by Friday",
  "note_type": "list",
  "color": "green",
  "is_pinned": false,
  "confidence": 0.91
}
```

**Note type detection:**

| Input Signal | Note Type | Default Color |
|---|---|---|
| `http://`, `https://`, `www.` | `link` | blue |
| `password`, `PIN`, `secret`, `private` | `secret` | purple |
| Multi-line with `-` / `*` / numbered list | `list` | green |
| General text | `text` | yellow |

**Color selection logic:** yellow (general), pink (emotional/personal), blue (links/work), green (lists/nature), purple (creative/secrets), orange (urgent/warnings), mint (health/wellness), white (neutral).

**`is_pinned: true`** when input contains: "important", "pin this", "don't forget", "urgent".

---

#### `planit / plan_party / text`

**Used by:** Plan Party module (V2 — module is hidden but prompt is seeded)

**Returns:**
```json
{
  "event_name": "Riya's 5th Birthday Party",
  "event_type": "birthday_party",
  "date": "2026-06-15",
  "venue": "Home",
  "guest_count": 30,
  "budget": 15000,
  "scope": "family",
  "tasks": ["Order cake", "Send invites", "Book venue", "Arrange decorations"],
  "note": null,
  "confidence": 0.86
}
```

**Auto-suggested tasks** by event type:
- `birthday_party`: Order cake, Send invites, Book venue, Arrange decorations
- Other types: no auto-suggestions unless user mentions specific tasks

---

### MYLIFE PROMPTS

---

#### `mylife / garage / text`

**Used by:** MyLife → My Garage module (add vehicle/service/document from text)

**Context used:** `{{vehicles}}` — user's registered vehicle names

**Returns:**
```json
{
  "item_type": "vehicle",
  "name": "Honda Activa Service",
  "vehicle_name": "Honda Activa",
  "action": "service_due",
  "due_date": "2026-05-15",
  "amount": 1800,
  "document_type": null,
  "reminder": true,
  "note": null,
  "confidence": 0.90
}
```

**Action options:** `add | service_due | insurance_due | puc_due | document_added | repair_needed | repair_done`

**Document types:** `RC | insurance | PUC | license | warranty | invoice | other`

---

#### `mylife / wardrobe / image`

**Used by:** My Wardrobe → Add from Camera/Gallery

**Returns:**
```json
{
  "item_type": "kurta",
  "color": "cream",
  "color_secondary": "gold",
  "pattern": "embroidered",
  "fabric_guess": "silk",
  "occasion": "ethnic",
  "brand": "Manyavar",
  "season": "all-season",
  "gender": "male",
  "size_visible": "L",
  "notes": "gold embroidery on neckline",
  "confidence": 0.88
}
```

**Item types:** shirt, t-shirt, trouser, jeans, shorts, dress, saree, salwar_kameez, kurta, lehenga, jacket, blazer, sweater, hoodie, shoes, sandals, sneakers, heels, bag, belt, watch, accessory, ethnic_wear, other.

**Brand extraction:** Only if clearly visible on tag or embroidery — never inferred.

---

#### `mylife / wardrobe / text`

**Used by:** My Wardrobe → Add from text description

Same structure as image wardrobe parser but from text. Also extracts `size` (S/M/L/XL/32/34) and `purchase_price` if mentioned.

---

#### `mylife / item_locator / text`

**Used by:** MyLife → Item Locator (track where household items are stored)

**Returns:**
```json
{
  "item_name": "spare house key",
  "location": "top drawer in study room cupboard",
  "room": "study",
  "container": "drawer",
  "container_label": "keys",
  "stored_by": "me",
  "date_stored": "2026-04-28",
  "note": null,
  "confidence": 0.93
}
```

**Room options:** bedroom, master_bedroom, kids_room, kitchen, living_room, dining_room, bathroom, garage, store_room, balcony, study, other.

---

### FUNCTIONS PROMPTS

All Functions prompts use `feature: 'functions'`. The sub-feature is dynamically selected by `_FunctionAIParser` based on the active tab index.

---

#### `functions / my_function / text` (Tab 0)

**Purpose:** Add a function/ceremony hosted by the user's family.

**Returns:**
```json
{
  "function_name": "Karthik's Ear Piercing Ceremony",
  "function_type": "ear_piercing",
  "function_date": "2026-06-20",
  "venue": "Sri Krishna Mahal",
  "hosted_by": "self",
  "scope": "family",
  "expected_guests": 150,
  "budget": 200000,
  "note": null,
  "confidence": 0.90
}
```

**Function type options:** wedding, engagement, ear_piercing, naming_ceremony, first_rice, thread_ceremony, mundan, housewarming, birthday_function, anniversary_function, graduation, retirement, baby_shower, upanayanam, seemantham, other.

---

#### `functions / received_gift / text`

**Purpose:** Log a gift or cash received at the user's function from a contact.

**Returns:**
```json
{
  "from_contact": "Ravi Mama",
  "relationship": "maternal_relative",
  "gift_type": "cash",
  "cash_amount": 5001,
  "gold_grams": null,
  "gold_approx_value": null,
  "gift_description": null,
  "saree_count": null,
  "vessel_description": null,
  "mixed_items": [],
  "given_by_members": [],
  "note": null,
  "confidence": 0.95
}
```

**Auspicious Indian amounts:** 11, 21, 51, 101, 501, 1001, 5001, 11001 — extracted as-is.

**Gold conversion:** `"1 sovereign"` → `gold_grams: 8`.

**Mixed gift example:** `"cash 5000 and a saree"` → `gift_type: "mixed", mixed_items: ["cash: ₹5000", "saree: 1"]`.

---

#### `functions / upcoming_function / text` (Tab 1)

**Purpose:** Add an upcoming function of someone else that you plan to attend.

**Returns:**
```json
{
  "contact_name": "Chithappa",
  "contact_relationship": "paternal_relative",
  "function_name": "Chithappa's Daughter's Wedding",
  "function_type": "wedding",
  "function_date": "2026-05-10",
  "function_date_text": "May 10th",
  "venue": "Kalyana Mahal, Madurai",
  "scope": "family",
  "obligation_hint": 7000,
  "past_received_hint": 7000,
  "reminder_days_before": 3,
  "note": null,
  "confidence": 0.92
}
```

**`obligation_hint`:** What the user plans to give — extracted if mentioned.

**`past_received_hint`:** What this contact gave at your function previously. Critical for MOI obligation calculation. Example: `"they gave us 7000 at our wedding"` → `past_received_hint: 7000`.

---

#### `functions / attended_function / text` (Tab 2)

**Purpose:** Log a function you attended and what gift you gave.

**Returns:**
```json
{
  "contact_name": "Senthil Uncle",
  "contact_relationship": "relative",
  "function_name": "Senthil Uncle's Son's Wedding",
  "function_type": "wedding",
  "function_date": "2026-04-27",
  "attended_by": ["self", "Amma"],
  "gift_type": "cash",
  "cash_amount": 11000,
  "gold_grams": null,
  "gift_description": null,
  "saree_count": null,
  "vessel_description": null,
  "mixed_items": [],
  "total_estimated_value": 11000,
  "scope": "family",
  "note": null,
  "confidence": 0.93
}
```

**Gold value estimation:** `"gold chain 10 grams"` → `total_estimated_value: 60000` (at ₹6000/gram approximation).

**Date handling:** `"yesterday"` → today minus 1 day. `"last Sunday"` → calculated. Default: today (assume recent).

---

#### `functions / attended_gift_image / image`

**Purpose:** Parse a gift receipt or product photo for functions logging.

**Returns:**
```json
{
  "gift_type": "vessel_utensil",
  "item_description": "Stainless steel vessel set (5 pieces)",
  "brand": "Vinod",
  "quantity": 1,
  "unit_price": null,
  "total_amount": 3500.00,
  "estimated_value": 3500.00,
  "shop_name": "Saravana Stores",
  "purchase_date": "2026-04-27",
  "is_gold_silver": false,
  "gold_grams": null,
  "confidence": 0.88
}
```

**`is_gold_silver: true`** for any precious metal; extracts purity (22K, 18K) into `item_description`.

---

#### `functions / net_obligation / text`

**Purpose:** Parse a natural language query about how much you owe someone (or they owe you).

**Returns:**
```json
{
  "contact_name": "Ravi Mama",
  "query_type": "net_balance",
  "time_filter": null,
  "function_type_filter": null,
  "confidence": 0.94
}
```

**Query types:** `net_balance | history | upcoming | last_given | last_received | summary`

**Example inputs:**
- `"What do I owe Ravi mama?"` → `query_type: "net_balance"`
- `"What did I give at Chithappa's last function?"` → `query_type: "last_given"`
- `"Show Ravi's full history for this year"` → `time_filter: "current_year"`

---

#### `functions / gift_suggestion / text`

**Purpose:** Parse context for generating a smart gift amount suggestion.

**Returns:**
```json
{
  "contact_name": "Senthil Uncle",
  "function_type": "wedding",
  "relationship": "relative",
  "budget_hint": 5000,
  "previous_given": null,
  "previous_received": 7000,
  "region_hint": "Tamil",
  "preference_hint": null,
  "confidence": 0.89
}
```

**`previous_received`** is the most important field — if they gave ₹7,000 at your function, the obligation suggests giving back approximately ₹7,000+.

**`region_hint`** inferred from contact names or explicit mention — affects culturally appropriate gift types and amounts.

**Relationship priority for gift amounts:** `relative > family_friend > friend > colleague > neighbor`

---

### DASHBOARD PROMPT

---

#### `dashboard / ai_assistant / text`

**Purpose:** Answer natural language household management questions using injected context data.

**Used by:** Dashboard AI widget (WAI Assistant bar)

**Note:** The `text` field contains **both** the serialised household context block AND the user's question:
```
=== WALLET ===
income: ₹45000
expenses: ₹28500
top_categories: Food ₹8200, Transport ₹3400, Shopping ₹2100
recent: Swiggy ₹350 (expense), Salary ₹45000 (income), ...

=== PANTRY ===
low_stock: ["Milk", "Rice"]
...

QUESTION: How much did I spend this month?
```

**Returns:**
```json
{
  "answer": "You've spent ₹28,500 this month. Food (₹8,200), Transport (₹3,400), and Shopping (₹2,100) are your top three categories.",
  "highlights": ["₹28,500 total expenses", "Food is biggest spend"],
  "suggestions": ["Consider setting a monthly food budget"],
  "actions": [{ "label": "View Wallet", "tab": 1 }],
  "confidence": 0.92
}
```

> The `dashboard/ai_assistant` prompt is seeded separately and not visible in the SQL migrations discovered during this review.

---

## 4.6 Dashboard Intent Classification

`IntentClassifier` is a **purely deterministic, zero-cost** classifier that decides which data sources to query before calling the AI.

**File:** `lib/features/dashboard/ai_assistant/intent_classifier.dart`

### Data Source Mapping

| Data Source | Trigger Keywords |
|---|---|
| `wallet` | spend, expense, income, salary, balance, money, ₹, paid, transaction, budget, earn, cash, transfer, lend, borrow, split, finance, credit, debit, bill, cost, price, fee, charge, pay, purchase, buy, wallet |
| `pantry` | pantry, grocery, food, cook, recipe, meal, ingredient, eat, basket, shopping, fridge, tobuy, breakfast, lunch, dinner, snack, cuisine, dish, menu |
| `planit` | task, todo, plan, bill, remind, schedule, appointment, upcoming, due, deadline, wish, note, pending |
| `functions` | function, upcoming function, attended function, moi, event, wedding, birthday, occasion, ceremony, attend, party, celebration |
| `family` | family, member, together, group, shared, husband, wife, son, daughter, parent → also adds `wallet` |
| `crossTab` | summarise, summary, overview, everything, all, total, overall, report → adds all sources |

**Default:** When no keywords match → `[wallet, planit]`

### Time Range Detection

| Range | Keywords |
|---|---|
| `today` | today, tonight, this morning |
| `thisWeek` | this week, week |
| `lastMonth` | last month, previous month |
| `thisMonth` | this month, month (default) |
| `allTime` | all time, ever, history |

### Query Type Detection

| Type | Keywords |
|---|---|
| `specific` | how much, total, balance, amount (default) |
| `comparison` | compare, vs, versus, difference, between |
| `suggestion` | suggest, recommend, should I, tip, advice, help me |
| `prediction` | will, predict, forecast, next month, future |
| `summary` | summarise, summary, overview, all, report |

---

## 4.7 Context Fetcher — What Data Reaches the AI

`ContextFetcher` queries Supabase in parallel based on detected intent, then formats the result as a readable text block for the AI prompt.

**File:** `lib/features/dashboard/ai_assistant/context_fetcher.dart`

### Data Fetched Per Source

**`wallet` (last 50 transactions, time-filtered):**
```
income: ₹45000
expenses: ₹28500
lent: ₹2000
top_categories: Food ₹8200, Transport ₹3400, Shopping ₹2100
recent: Swiggy ₹350 (expense), Salary ₹45000 (income), ...
```

**`pantry`:**
```
low_stock: ["Milk", "Eggs", "Rice"]
meal_plan_today: breakfast: Idli Sambar, lunch: Chicken Biryani
recipes_count: 12
```

**`planit`:**
```
pending_tasks: 5
overdue_reminders: 2
upcoming_bills: Electricity ₹1200 due in 3 days
```

**`functions`:**
```
my_functions_count: 3
upcoming_functions: "Ravi's son's wedding on May 10"
pending_moi_count: 7
```

**`family`:**
```
members: [Arjun, Priya, Amma]
active_wallet: Family Wallet
```

---

## 4.8 Parse Logs and Correction Tracking

Every AI parse attempt is logged to the `ai_parse_logs` table (fire-and-forget — does not block the response).

```sql
CREATE TABLE ai_parse_logs (
  id            UUID PRIMARY KEY,
  user_id       UUID,           -- authenticated user
  feature       TEXT,
  sub_feature   TEXT,
  input_type    TEXT,
  prompt_id     UUID,           -- which prompt version was used
  raw_input     TEXT,           -- original text or "[image]"
  parsed_output JSONB,          -- what the AI returned
  confidence    FLOAT,          -- confidence from AI response
  was_corrected BOOLEAN,        -- user corrected the parse
  correction    JSONB,          -- what the user actually intended
  tokens_used   INTEGER,
  latency_ms    INTEGER,
  error         TEXT,           -- null on success
  created_at    TIMESTAMPTZ
);
```

**Correction fields** (`was_corrected`, `correction`) are present in the schema but **not yet written from the client**. They are designed for a future training pipeline:

```
User accepts AI result → was_corrected: false
User edits result     → was_corrected: true, correction: {actual_values}
```

This correction data could power:
- Per-user pattern learning (e.g. "this user always says 'monthly salary' = income")
- Prompt version improvement analytics
- Low-confidence result flagging for manual review

**RLS:** Users can read only their own logs. Service role writes all logs.

---

## 4.9 Prompt Versioning and Management

### Version Control

Multiple versions of each prompt can coexist in the table. The edge function always selects the **highest version where `is_active = true`** for the given `(feature, sub_feature, input_type)`.

**To release a new prompt version without downtime:**
```sql
-- Insert new version (does not affect active v1)
INSERT INTO ai_prompts (feature, sub_feature, input_type, version, prompt, notes)
VALUES ('wallet', 'expense', 'text', 2, '...improved prompt...', 'Added INR lakh support');

-- Disable old version
UPDATE ai_prompts SET is_active = false
WHERE feature = 'wallet' AND sub_feature = 'expense' AND version = 1;
```

**To roll back:**
```sql
UPDATE ai_prompts SET is_active = true  WHERE version = 1 AND ...;
UPDATE ai_prompts SET is_active = false WHERE version = 2 AND ...;
```

### Schema Hint (documentation only)

The `schema_hint` JSONB column documents the expected output structure. It is **not enforced** at the database or edge function level — it exists for developer reference and potential future validation.

### Active Prompts View

```sql
CREATE VIEW active_prompts AS
SELECT id, feature, sub_feature, input_type, version, schema_hint, notes
FROM ai_prompts
WHERE is_active = true
ORDER BY feature, sub_feature, input_type;
```

---

## 4.10 Feature Usage Limits

High-cost image parse operations are rate-limited per user per calendar month.

```sql
CREATE TABLE feature_usage (
  user_id  UUID,
  feature  TEXT,   -- e.g. 'bill_scan'
  month    TEXT,   -- 'YYYY-MM'
  count    INTEGER,
  UNIQUE(user_id, feature, month)
);

-- Atomic increment + check (returns TRUE if under limit)
CREATE FUNCTION check_feature_limit(
  p_user_id UUID, p_feature TEXT, p_limit INTEGER
) RETURNS BOOLEAN;
```

**Current limits:**

| Feature | Limit | Cost Driver |
|---|---|---|
| `bill_scan` | 2 scans/month | Gemini 2.0 Flash image calls |

The limit is checked in the Dart client **before** making the `/parse` call. If over limit, the user is shown an upgrade prompt.

---

## 4.11 Complete Prompt Inventory

| # | Feature | Sub-feature | Input | Module |
|---|---|---|---|---|
| 1 | wallet | expense | text | Wallet quick-add, Spark AI |
| 2 | wallet | receipt | image | Wallet receipt scanner |
| 3 | wallet | split | text | Wallet split entry |
| 4 | wallet | bill | text | Bill Watch quick-add |
| 5 | wallet | split_expense | text | Split Group detail |
| 6 | wallet | sms_parse | text | SMS auto-scan |
| 7 | pantry | basket | text | Pantry chat input (multi-intent) |
| 8 | pantry | bill_scan | image | Pantry Scan Bill (limited) |
| 9 | pantry | scan | image | Pantry shelf scanner |
| 10 | pantry | meal | text | MealMap text add |
| 11 | planit | reminder | text | Alert Me AI Parse |
| 12 | planit | task | text | My Tasks AI Parse |
| 13 | planit | special_day | text | Special Days AI Parse |
| 14 | planit | wishlist | text | Wish List AI Parse |
| 15 | planit | note | text | Sticky Notes AI Parse |
| 16 | planit | plan_party | text | Plan Party (V2, seeded) |
| 17 | mylife | garage | text | My Garage add |
| 18 | mylife | wardrobe | image | My Wardrobe camera |
| 19 | mylife | wardrobe | text | My Wardrobe text add |
| 20 | mylife | item_locator | text | Item Locator |
| 21 | functions | my_function | text | Functions Tab 0 |
| 22 | functions | received_gift | text | Functions gift logging |
| 23 | functions | upcoming_function | text | Functions Tab 1 |
| 24 | functions | attended_function | text | Functions Tab 2 |
| 25 | functions | attended_gift_image | image | Functions gift receipt |
| 26 | functions | net_obligation | text | MOI obligation query |
| 27 | functions | gift_suggestion | text | Gift suggestion |
| 28 | dashboard | ai_assistant | text | Dashboard AI bar |

**Total: 28 active prompts** across 6 features.

---

## 4.12 Cost Analysis

### Model Pricing (Google Gemini — approximate)

| Model | Input | Output | Notes |
|---|---|---|---|
| Gemini 2.5 Flash | ~$0.075/M tokens | ~$0.30/M tokens | All text tasks |
| Gemini 2.0 Flash | ~$0.10/M tokens | ~$0.40/M tokens | Image parsing only |

### Per-Parse Cost Estimates

| Sub-feature | Input Type | Avg Tokens | Estimated Cost |
|---|---|---|---|
| expense | text | ~300 | $0.00009 |
| reminder | text | ~350 | $0.00011 |
| task | text | ~380 | $0.00012 |
| note | text | ~320 | $0.00010 |
| basket (multi-intent) | text | ~420 | $0.00013 |
| sms_parse | text | ~280 | $0.00009 |
| received_gift | text | ~400 | $0.00013 |
| upcoming_function | text | ~450 | $0.00014 |
| attended_function | text | ~480 | $0.00015 |
| ai_assistant | text | ~800–1500 | $0.00030–$0.00056 |
| bill_scan | image | ~600 | ~$0.00020 |
| receipt | image | ~650 | ~$0.00022 |

> Token estimates include prompt template + context injection + response. The `ai_assistant` prompt is the most expensive because it includes the full household context block.

### Projected Monthly Cost by Scale

Assumptions: average user makes 10 AI parses/day, local NLP handles ~40% of requests, `ai_assistant` used ~3 times/day.

| MAU | Daily AI Calls | Monthly AI Calls | Estimated Monthly Cost |
|---|---|---|---|
| 100 | 600 | 18,000 | ~$2–4 |
| 1,000 | 6,000 | 180,000 | ~$20–40 |
| 10,000 | 60,000 | 1,800,000 | ~$200–400 |
| 100,000 | 600,000 | 18,000,000 | ~$2,000–4,000 |

**The local NLP fallback reduces Gemini token consumption by an estimated 35–45%**, depending on the module:

| Module | NLP Interception Rate | Notes |
|---|---|---|
| Pantry basket | ~60% | PantryNlpParser handles common grocery inputs well |
| Alert Me | ~45% | NLP handles date/time patterns; AI needed for complex repeats |
| My Tasks | ~30% | Subtask extraction and date parsing rarely handled by NLP |
| Sticky Notes | ~50% | Type detection (list/link/secret) is mostly rule-based |
| Wallet expense | ~25% | Amount/type inference often needs AI for complex sentences |
| Functions | ~10% | Complex social context requires AI |

**The `bill_scan` 2-scan/month limit** prevents image parsing from dominating costs. At 1,000 MAU, bill scan adds at most 2,000 image calls/month ≈ $0.40–0.50 extra.

### Cost Reduction Strategies

1. **Local NLP first, AI only on failure.** Already implemented across all modules.
2. **Feature limits for expensive operations.** Already implemented for `bill_scan`.
3. **Prompt versioning.** Allows tuning token usage in prompts without code changes.
4. **Context minimisation for `ai_assistant`.** `ContextFetcher` caps wallet transactions at 50; further reduction possible if response quality holds.
5. **`gemini-2.0-flash` for images.** Lighter model used for all image tasks while `gemini-2.5-flash` is reserved for text quality.
6. **Future: user-correction learning.** The `was_corrected` / `correction` columns in `ai_parse_logs` enable a future pipeline where high-confidence patterns are moved to the local NLP layer, eliminating API calls entirely for those inputs.

---

*Next: **Section 5 — Third-Party Integrations***
