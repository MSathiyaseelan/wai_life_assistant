# Pantry Feature

---

## Overview

The Pantry tab is a three-section food management hub:

| Index | Name | Purpose |
|---|---|---|
| 0 | **MealMap** | Weekly meal calendar — plan, log, and track daily meals |
| 1 | **Basket** | Grocery inventory — In Stock tracking and To Buy list |
| 2 | **Recipe Box** | Personal recipe library with AI-assisted meal logging |

All three sections share the same `walletId` scope. Switching wallets reloads all three. An AI input bar runs at the bottom of the tab, shared across all sections.

---

## User Flows

### Flow 1 — Log a Meal via Chat (quick)

1. User types or speaks: *"had idli for breakfast"*
2. `PantryNlpParser.parse(text)` → `PantryIntent` with `kind=meal`, `mealTime=breakfast`, `mealName="Idli"`, `confidence≈0.8`
3. `PantryIntentConfirmSheet` opens pre-filled
4. User reviews → **Save to Meal Map**
5. `PantryService.addMealEntry()` inserts to Supabase; `mealChangeSignal` triggers MealMap refresh

### Flow 2 — Log a Meal via Manual Form

1. User taps **+** in empty chat input → `PantryFlowSelector`
2. Taps **Meal Map** → `AddMealSheet.show()` opens at 90% screen height
3. Two tabs: **Chat** (step-by-step) and **Manual** (form)
4. If the selected time slot is already occupied, saving **updates** the existing meal (not insert)
5. Multiple recipes can be selected; names are concatenated with " + "

### Flow 3 — Add / Search Recipe

1. Taps **+** → **Recipe Box** → `AddRecipeSheet`
2. Default tab: **Library** — pre-loads `master_recipes` catalogue with empty search
3. **Preview sheet:** shows ingredients with "Check Stock" and "Add All to Basket"
4. **Custom tab:** full form — emoji, name, ingredients, cook time, social link, cuisine, suitable-for meal times

### Flow 4 — Scan Grocery Bill

1. Taps **+** → **Scan Bill** → `ScanBillSheet` (phase: `pick`)
2. **On open:** queries `feature_usage` count + `feature_limits.monthly_limit` for `'bill_scan'`
3. User picks image (camera or gallery)
4. **Right before API call:** RPC `check_feature_limit(p_user_id, 'bill_scan')` — increments usage counter; if `false`, shows limit-exceeded message
5. `AIParser.parseImage(feature:'pantry', subFeature:'bill_scan', bytes, mimeType)` → Gemini
6. Phase transitions to `confirm` — editable scanned item tiles
7. Optional: **Also push to Wallet?** toggle → creates wallet expense
8. On save → batch `PantryService.addGroceryItem()` for each accepted item

**Model used for bill scan:** `gemini-2.0-flash` (not 2.5-flash). Using `responseMimeType: application/json` on image requests causes a 422 error — it is intentionally disabled for this subFeature.

**Free tier limit:** 3 bill scans per month (`feature_limits.bill_scan = 3`).

### Flow 5 — Meal Copy / Paste

- **Copy single meal:** long-press meal chip → `onCopyMeal(meal)`
- **Copy day:** long-press day header → **Copy Day** (all meals for that day)
- **Copy full week:** long-press → **Copy Week** (preserves day-of-week offsets)
- **Paste:** banner at top of MealMap when clipboard is non-empty; tapping a day header shows **Paste Here**
- Paste skips duplicate meals (same name + mealTime) in the target day
- Week paste: deletes target week first, then re-inserts

### Flow 6 — Family Food Preferences

- Visible on MealMap when on a family wallet
- `FamilyFoodPrefsCard` → horizontal member chips → `_MemberPrefsSheet`
- 4 sections per member: allergies, likes, dislikes, mandatory foods
- Admin can edit any member; regular member can only edit their own
- `PantryService.upsertFoodPrefs()` with conflict target `wallet_id, member_id`

---

## MealMap — Technical Detail

```
PantryScreen._meals ← PantryService.fetchMealEntriesForWeek(walletId, weekStart)
                        (fetches Sun–Sat, returns List<MealEntry>)
                                │
                                ▼
PantryScreen._buildMealMap()
  │
  └── WeekMealGrid  [day columns × meal-time rows]
         │
         ├── each cell: MealChip (if meal exists) or AddMealHint (tap to add)
         └── MealChip: shows emoji + name; long-press for copy/edit/delete
```

**`mealChangeSignal`** (`ValueNotifier<int>`) — any write to Supabase increments this notifier; `PantryScreen` listens and re-fetches. This avoids prop-drilling callbacks.

---

## Basket — Technical Detail

```
grocery_items table
  in_stock = TRUE  → shown in "In Stock" section
  to_buy   = TRUE  → shown in "To Buy" section
  (both can be true simultaneously)
```

`GroceryController` (Provider) owns the in-memory list. Mutations call `PantryService` and then `notifyListeners()`.

**Expiry alerts:** items with `expiry_date < TODAY + 3 days` surface a warning badge. The `allergy_alerts` view surfaces family members with non-empty allergy arrays for meal planning warnings.

---

## Recipe Box — Technical Detail

**Master catalogue** (`master_recipes`): a static Supabase table populated by seed data. Not user-owned — all users can read, none can write. The client's Library tab searches it with `ilike('%name%', '%${query}%')`.

**Linking recipes:** `recipes.recipe_ids` (TEXT[]) stores IDs of other recipes this recipe was combined from. Added in migration 039.

---

## AI Prompts Used

| sub_feature | What it parses |
|---|---|
| `meal` | Free-text meal description → name, mealTime, date |
| `basket` | Shopping list text → list of items with name, qty, unit |
| `bill_scan` | Image of a grocery receipt → list of items with name, qty, price |
| `recipe_suggest` | Ingredients list → recipe suggestions |

---

## Folder Structure

```
lib/features/pantry/
├── data/
│   └── services/
│       └── pantry_service.dart     ← Supabase CRUD
├── models/
│   ├── meal_entry.dart
│   ├── grocery_item.dart
│   └── recipe.dart
├── screens/
│   └── pantry_screen.dart          ← TabController (MealMap / Basket / Recipe Box)
└── widgets/
    ├── add_meal_sheet.dart
    ├── scan_bill_sheet.dart
    ├── add_recipe_sheet.dart
    └── ...
```

---

## Common Issues

**Bill scan quota:** `check_feature_limit()` is called *before* the Gemini API call. If the call fails mid-flight, the quota is still consumed. There is no rollback mechanism.

**Week paste deletes first:** Week-paste deletes the entire target week's meals before re-inserting. A failed insert mid-way leaves the target week partially empty. This is a known limitation.

**`in_stock` and `to_buy` are independent flags:** An item can be both in stock and on the buy list simultaneously (e.g. "low stock, need to buy more"). UI treats them as two separate sections, not exclusive states.

---

## Related Documentation

- [Database Schema](../database.md) — `recipes`, `meal_entries`, `grocery_items`, `member_food_prefs`
- [Gemini AI](../integrations/gemini.md) — image parsing for bill scan
- [AI Smart Parser](../ai/smart-parser.md) — NLP + Gemini pipeline
