# AI Prompts Reference

---

## Overview

WAI has **28 AI prompts** across 6 feature areas + 1 dashboard prompt. All prompts are stored in the `ai_prompts` Supabase table. The active version is fetched at parse time — no code deploy needed to update a prompt.

---

## Prompt Versioning

```sql
CREATE TABLE ai_prompts (
  id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  feature     TEXT    NOT NULL,
  sub_feature TEXT    NOT NULL,
  version     INTEGER NOT NULL DEFAULT 1,
  prompt_text TEXT    NOT NULL,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (feature, sub_feature, version)
);
```

**Active version selection:** `is_active = true AND highest version wins`.

To update a prompt without downtime:
1. INSERT a new row with `version = current + 1`
2. The edge function picks it up immediately on the next request

To rollback: `UPDATE ai_prompts SET is_active = false WHERE version = <bad-version>`.

---

## Context Placeholders

All prompts support these 10 runtime placeholders, injected by the edge function:

| Placeholder | Value source | Example |
|---|---|---|
| `{{TODAY}}` | `context.today` | `2026-04-28` |
| `{{DAY_OF_WEEK}}` | `context.day_of_week` | `Monday` |
| `{{CURRENT_MONTH}}` | `context.current_month` | `April 2026` |
| `{{CURRENCY}}` | `context.currency` | `INR` |
| `{{CATEGORIES}}` | `context.categories` joined | `Food, Transport, Shopping` |
| `{{RECENT_ITEMS}}` | `context.recent_items` joined | `Milk, Rice, Dal` |
| `{{USER_PREFS}}` | `context.user_prefs` | `vegetarian` |
| `{{WALLET_NAME}}` | `context.wallet_name` | `Kumar Family` |
| `{{FAMILY_MEMBERS}}` | `context.family_members` joined | `Raj, Priya, Arjun` |
| `{{LOCALE}}` | `context.locale` | `en-IN` |

---

## Prompt Inventory

### Wallet (6 prompts)

| sub_feature | What it produces |
|---|---|
| `expense` | `{ amount, category, title, type, pay_mode, person, note, date, confidence }` |
| `income` | `{ amount, category, title, source, pay_mode, note, date, confidence }` |
| `lend_borrow` | `{ amount, type (lend/borrow), person, pay_mode, note, due_date, confidence }` |
| `split` | `{ amount, persons[], category, pay_mode, note, date, confidence }` |
| `sms_parse` | `{ is_transaction, transactionType, amount, merchant, bank, date, paymentMode, confidence }` |
| `receipt` | `{ items[{name,qty,price}], total, merchant, date, category, confidence }` |

**Key notes:**
- `expense` is the most-used prompt — optimized for Indian expense patterns including auspicious amounts (₹51, ₹101, ₹501)
- `sms_parse` handles mixed-script merchant names (e.g. "Swiggy India பயன்பாடு")
- `receipt` is used for manual photo of paper receipts (not bill_scan)

---

### Pantry (4 prompts)

| sub_feature | What it produces |
|---|---|
| `meal` | `{ name, meal_time, emoji, date, ingredients[], confidence }` |
| `basket` | `{ items[{name, quantity, unit, category}], confidence }` |
| `bill_scan` | `{ items[{name, quantity, unit, price}], total, merchant, date, confidence }` |
| `recipe_suggest` | `{ recipes[{name, cuisine, cook_time_min, ingredients[]}], confidence }` |

**Key notes:**
- `bill_scan` uses `gemini-2.0-flash` (vision model), not 2.5-flash
- `bill_scan` does NOT use `responseMimeType: "application/json"` — it causes 422 errors with image requests
- `basket` handles mixed-unit shopping lists: "2kg atta, 500g butter, 1 dozen eggs"

---

### PlanIt (6 prompts)

| sub_feature | What it produces |
|---|---|
| `reminder` | `{ title, date, time, repeat, priority, assigned_to, emoji, confidence }` |
| `task` | `{ title, description, priority, project, tags[], due_date, subtasks[{title}], assigned_to, emoji, confidence }` |
| `special_day` | `{ title, type, date, members[], yearly_recur, alert_days_before, emoji, confidence }` |
| `wish` | `{ title, category, target_price, target_date, priority, link, note, emoji, confidence }` |
| `note` | `{ title, content, note_type, color, emoji, confidence }` |
| `event` | `{ title, date, type, venue, description, confidence }` |

---

### MyLife / Lifestyle (4 prompts)

| sub_feature | What it produces |
|---|---|
| `habit` | `{ name, frequency, target, category, reminder_time, confidence }` |
| `journal` | `{ title, content, mood, tags[], confidence }` |
| `goal` | `{ title, description, category, target_date, milestones[], confidence }` |
| `health_log` | `{ metric, value, unit, date, note, confidence }` |

These prompts exist in the DB but the MyLife tab is hidden (V2).

---

### Functions (7 prompts)

| sub_feature | What it produces |
|---|---|
| `my_function` | `{ title, type, who_function, date, venue, family_name, icon, confidence }` |
| `upcoming_function` | `{ person_name, function_title, type, date, venue, planned_gifts[{item,amount}], confidence }` |
| `received_gift` | `{ person_name, family_name, relation, amount, kind, place, phone, notes, confidence }` |
| `attended_function` | `{ function_name, type, date, venue, gifts[{item,amount}], confidence }` |
| `bulk_moi` | `{ entries[{person_name, family_name, amount, relation, place}], confidence }` |
| `moi_return` | `{ returned_amount, returned_on, returned_for_function, confidence }` |
| `function_search` | `{ query_type, filters{}, sort_by, confidence }` |

**Key notes:**
- `bulk_moi` is optimized for rapid multi-person entry at the function venue itself
- `received_gift` handles informal Tamil/Telugu/Hindi person descriptions: "Selvam uncle from Coimbatore"

---

### Dashboard (1 prompt)

| sub_feature | What it produces |
|---|---|
| `ai_assistant` | `{ answer, highlights[{title,value}], suggestions[], actions[{label,route}] }` |

The dashboard prompt receives a full `HouseholdContext` text block injected by `ContextFetcher` before the user's question. This grounds Gemini in real data.

---

## Adding or Updating a Prompt

### To update an existing prompt (no code change needed):

```sql
-- Step 1: Find the current version
SELECT id, version, is_active FROM ai_prompts
WHERE feature = 'wallet' AND sub_feature = 'expense'
ORDER BY version DESC LIMIT 1;

-- Step 2: Insert new version
INSERT INTO ai_prompts (feature, sub_feature, version, prompt_text, is_active)
VALUES (
  'wallet',
  'expense',
  3,  -- increment from current
  'You are a financial assistant for WAI, an Indian household management app.
Today is {{TODAY}} ({{DAY_OF_WEEK}}).
The user says: "{{INPUT}}"

Extract and return JSON:
{
  "amount": number,
  "category": string,
  "title": string,
  ...
}',
  true
);

-- Step 3: Optionally deactivate old version
UPDATE ai_prompts SET is_active = false
WHERE feature = 'wallet' AND sub_feature = 'expense' AND version < 3;
```

### To add a new sub_feature:

1. INSERT a new row into `ai_prompts`
2. Add the corresponding case in `lib/core/services/ai_parser.dart` → `_buildContext()`
3. Add a mapper in the relevant feature's screen to handle the new `data` shape

---

## Prompt Engineering Guidelines

- **Always request JSON output explicitly.** State the expected shape in the prompt with exact field names.
- **Include Indian context.** Mention INR, Indian date formats (DD-MM-YYYY), common Indian merchants, auspicious amounts.
- **Handle mixed scripts.** Tamil, Hindi, and English are all valid merchant names and person names.
- **Set temperature = 0.1** for parsing tasks. Higher temperatures produce inconsistent JSON field names.
- **Include "confidence" in the output schema.** The edge function uses this to set `needs_review`.
- **Test with the curl command** in [gemini.md](../integrations/gemini.md) before deploying.

---

## Related Documentation

- [Smart Parser Architecture](smart-parser.md) — how prompts are selected and used
- [Training Data](training-data.md) — how corrections improve prompts over time
- [Gemini Integration](../integrations/gemini.md) — API and cost details
