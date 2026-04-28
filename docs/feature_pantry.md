# WAI Life Assistant — Technical Documentation
### Section 3b: Pantry Tab

---

## Overview

The Pantry tab is a three-section food management hub:

| Index | Name | Purpose |
|---|---|---|
| 0 | **MealMap** | Weekly meal calendar — plan, log, and track what the family eats each day |
| 1 | **Basket** | Grocery inventory — In Stock tracking and To Buy list |
| 2 | **Recipe Box** | Personal recipe library with master catalogue and AI-assisted meal logging |

Navigation is a `TabController` with `length: 3` driven from `PantryScreen`. All three sections share the same `walletId` scope — switching wallets (personal ↔ family) reloads all three. An AI input bar runs at the bottom of the tab, shared across all three sections.

---

## 3b.1 User Flows

### Flow 1 — Log a Meal via Chat (quick)
1. User types or speaks in the Pantry AI input bar: *"had idli for breakfast"*
2. `PantryNlpParser.parse(text)` runs locally → returns `PantryIntent` with `kind=meal`, `mealTime=breakfast`, `mealName="Idli"`, `confidence≈0.8`
3. `PantryIntentConfirmSheet` opens, pre-filling name, meal time, date
4. User reviews, optionally changes emoji/time/date, taps **Save to Meal Map**
5. `PantryService.addMealEntry()` inserts to Supabase; `mealChangeSignal` triggers MealMap refresh

### Flow 2 — Log a Meal via Manual Form
1. User taps **+** in empty chat input → `PantryFlowSelector` opens
2. Taps **Meal Map** → `AddMealSheet.show()` opens at 90% screen height
3. Two tabs: **Chat** (conversational) and **Manual** (form)
   - **Chat tab**: step-by-step flow — mealTime → mealName (with recipe picker) → emoji → confirm
   - **Manual tab**: meal time buttons, recipe picker, emoji row, name field, optional ingredients
4. If user has recipes, the sheet shows a horizontal recipe picker sorted by meal-time suitability
5. Multiple recipes can be selected; names are concatenated with " + " in the name field
6. If the selected time slot is already occupied, saving **updates** the existing meal (not insert)
7. On save → `PantryService.addMealEntry()` or `updateMealEntry()`

### Flow 3 — Add / Search Recipe
1. Taps **+** → **Recipe Box** → `AddRecipeSheet` opens
2. Default tab: **Library** — pre-loads `master_recipes` catalogue with empty search
3. User searches by name or cuisine; taps **+ Add** for quick-add, or taps row to preview
4. Preview sheet shows ingredients with "Check Stock" and "Add All to Basket"
5. **Custom tab**: full form — emoji, name, ingredients (comma-separated), cook time, social link, notes, cuisine, suitable-for meal times, favourite toggle
6. On save → `PantryService.addRecipe()` (if from library, sets `libraryRecipeId`)

### Flow 4 — Scan Grocery Bill
1. Taps **+** → **Scan Bill** → `ScanBillSheet` opens (phase: `pick`)
2. Limit check on open: queries `feature_usage` count + `feature_limits.monthly_limit` for `'bill_scan'`
3. User picks image (camera or gallery)
4. **Right before API call**: RPC `check_feature_limit(p_user_id, 'bill_scan')` — increments usage counter and returns `bool`; if `false`, shows limit-exceeded message
5. `AIParser.parseImage(feature:'pantry', subFeature:'bill_scan', bytes, mimeType)` → Gemini
6. Phase transitions to `confirm` — shows editable scanned item tiles
7. User edits name/qty/unit/price per item, toggles items to include
8. Optional: **Also push to Wallet?** toggle → creates `WalletService.addTransaction(type:'expense', category:'groceries')`
9. On save → batch `PantryService.addGroceryItem()` for each accepted item

### Flow 5 — Meal Copy / Paste
- **Copy single meal**: long-press a meal chip → `onCopyMeal(meal)` callback → clipboard stores one meal
- **Copy day**: long-press a day header → **Copy Day** → clipboard stores all meals for that day
- **Copy full week**: long-press → **Copy Week** → clipboard stores entire week, preserves day-of-week offsets
- **Paste**: when clipboard is non-empty, a banner appears at the top of MealMap with the clipboard label; tapping a day header shows **Paste Here** option
- Paste skips duplicate meals (same name + mealTime) in the target day
- Week paste: deletes target week first, then re-inserts with day offsets preserved

### Flow 6 — Family Food Preferences
- Visible on MealMap section when on a family wallet
- `FamilyFoodPrefsCard` shows all wallet members as horizontal chips
- Tapping a member opens `_MemberPrefsSheet` with 4 sections: allergies, likes, dislikes, mandatory foods
- **Edit permission**: admin can edit any member; regular member can only edit their own
- Changes saved via `PantryService.upsertFoodPrefs()` with conflict target `wallet_id, member_id`

---

## 3b.2 MealMap — Technical Detail

### Data Flow
```
PantryScreen._meals ← PantryService.fetchMealEntriesForWeek(walletId, weekStart)
                                                ↕
                          Supabase: meal_entries (wallet_id scoped)
```

### MealMapSection Widget (`lib/features/pantry/widgets/meal_map_section.dart`)
- Column width: `_columnWidth = 165.0`
- 7-day horizontal `ListView` (Mon–Sun of selected week)
- On init: auto-scrolls to today's column via `ScrollController` + `addPostFrameCallback`
- `_mealsForDay(date)` — filters `_meals` by `walletId` + date (year/month/day comparison), sorted by `mealTime.index`
- Long-press day header → `_showDayCopyMenu()` bottom sheet with copy/paste options
- Long-press meal chip → `onCopyMeal(meal)` callback to `PantryScreen`
- `TodaysPlateSection` — separate widget embedded below the week calendar; vertical meal-by-time layout for current day

### _MealChip Widget
- Shows: `mealTime.emoji`, meal name, status badge (`MealStatus.color`)
- `_ReactionBadgeRow` — top-level reactions only (`replyTo == null`); shows first word of `memberName`
- Reaction badge aggregates emoji + name initial

### Clipboard Logic (in `PantryScreen`)
```dart
List<MealEntry> _clipboardMeals
String _clipboardLabel           // e.g. "Monday meals" or "Week of Jan 6"
bool _clipboardIsWeek
DateTime? _clipboardSourceWeekStart
```
`_pasteToDay(targetDate)` — skips meals where `name + mealTime` already exists in `dayMeals`

### `MealEntry` Model
```dart
MealEntry {
  id, name, emoji, mealTime: MealTime, date: DateTime, walletId, status: MealStatus,
  recipeIds: List<String>,        // new multi-recipe column
  ingredients: List<String>,      // used when no recipe linked
  servingsCount: int?,
  reactions: List<MealReaction>,
  // legacy: recipe_id (single) — supported in fromMap() for backward compat
}
```

### MealTime Enum
| Value | Emoji | Color |
|---|---|---|
| `breakfast` | 🌅 | orange |
| `lunch` | ☀️ | yellow |
| `snack` | 🌤️ | teal |
| `dinner` | 🌙 | indigo |

### MealStatus Enum
| Value | Badge |
|---|---|
| `planned` | grey |
| `cooked` | green |
| `ordered` | blue |

---

## 3b.3 Recipe Box — Technical Detail

### Data Sources

| Source | Table | Purpose |
|---|---|---|
| User's own recipes | `recipes` | wallet-scoped personal/family recipes |
| Master catalogue | `master_recipes` | Shared read-only library, curated by admin |

`MasterRecipe.libraryRecipeId` is stored on the user's `RecipeModel` when added from the catalogue, linking back to the source.

### Recipe Data Structure
```dart
RecipeModel {
  id, walletId, name, emoji,
  cuisine: CuisineType,
  suitableFor: List<MealTime>,
  ingredients: List<String>,      // "Name (qty unit)" or "Name qty"
  socialLink: String?,            // user-supplied YouTube/Instagram URL
  note: String?,
  cookTimeMin: int?,
  isFavourite: bool,
  libraryRecipeId: String?,       // non-null → sourced from master catalogue
}

MasterRecipe {
  id, name, emoji, cuisine: String, ingredients: List<String>,
  mealTypes: List<String>, tags: List<String>,
  youtubeSearch: String?,         // search term (NOT a URL)
  cookTimeMin: int?, calories: int?,
}
```

**YouTube URL generation**: `MasterRecipe.youtubeSearch` is a raw search term. The UI constructs the full URL as:
```
https://www.youtube.com/results?search_query=${Uri.encodeComponent(youtubeSearch)}
```

### RecipeBoxSection Widget (`lib/features/pantry/widgets/recipe_box_section.dart`)
- Search field — matches `recipe.name`, `recipe.cuisine.label`, `recipe.ingredients`
- Cuisine filter chips — dynamically built from cuisines present in the list; auto-resets if selected cuisine disappears after wallet switch
- Library recipes show **Untag** button → calls `onUntagRecipe(recipe)`
- `RecipeCard` shows: emoji, name, cuisine badge, suitable-for meal time badges, cook time badge, "Recipe link saved" indicator

### AddRecipeSheet (`lib/features/pantry/sheets/add_recipe_sheet.dart`)
Default tab: **Library** (pre-loads on open). Two tabs:

| Tab | Behaviour |
|---|---|
| `Library` | Live search `master_recipes`; quick-add or preview; preview shows stock check & "Add All to Basket" |
| `Custom` | Full form: emoji palette, name, ingredients, cook time, social link, notes, cuisine selector, suitable-for selector |

`_quickAdd` → calls `MasterRecipe.toRecipeModel()` which maps cuisine string to `CuisineType` enum and meal_type strings to `MealTime` list.

### RecipeDetailSheet
Part of `add_recipe_sheet.dart`. Opens from `RecipeBoxSection.onRecipeTapped`. Features:
- Ingredient list with inline `TextEditingController` for qty/unit editing (commits on blur/submit)
- **Check Stock** button → `_checkAvailability()` — fuzzy-matches each ingredient against In Stock items using `g.name.contains(name) || name.contains(g.name)`
- `_IngredientCheckSheet` — shows per-ingredient status (In Stock / In To Buy / Missing), allows selecting missing items to bulk-add to To Buy
- **Log as Meal** section — meal time selector + log button (creates `MealEntry` with recipe link)
- **Add All Ingredients to Basket** — batch-creates `GroceryItem` entries from ingredient strings

### CuisineType Enum
`indian`, `chinese`, `italian`, `mexican`, `mediterranean`, `thai`, `japanese`, `continental`

Each has `.label` and `.emoji` extensions.

---

## 3b.4 Basket — Technical Detail

### ShoppingBasketSection Widget (`lib/features/pantry/widgets/shopping_basket_section.dart`)
Two sub-tabs via `TabController`:
- **In Stock** (index 0) — items where `inStock == true`
- **To Buy** (index 1) — items where `toBuy == true`

Uses `IndexedStack` (not `TabBarView`) to avoid conflicting with horizontal swipe gestures on the parent `TabBarView`.

Category filter chips — dynamically built from categories present in the current tab's items only.

### GroceryItem Model
```dart
GroceryItem {
  id, name, walletId,
  category: GroceryCategory,
  quantity: double, unit: String,
  inStock: bool,      // ← independent boolean (item can be in both lists)
  toBuy: bool,        // ← independent boolean
  note: String?,
  expiryDate: DateTime?,
}
```

**Important**: `inStock` and `toBuy` are fully independent. An item can appear in both tabs simultaneously (e.g., you have some in stock but also ordered more).

### Expiry Alert Logic
```dart
// Expiry warning shown when:
expiryDate != null && expiryDate!.isBefore(DateTime.now())
// Day-level comparison, not timestamp
```
Expired items show a red warning badge. No push notification is generated — this is a visual-only indicator.

### Sources of "To Buy" Items
1. **Manual** — user adds via form or AI input
2. **Recipe basket push** — "Add All Ingredients" in `RecipeDetailSheet`
3. **Ingredient check** — "Add N to To Buy" from `_IngredientCheckSheet`
4. **Bill scan** — scanned items from `ScanBillSheet` (confirmed items go to In Stock by default)

### _EditItemSheet (inline in shopping_basket_section.dart)
Fields: name, quantity, unit, category, expiry date, note.
Units: `kg / g / litre / ml / pieces / packet / bunch`

---

## 3b.5 AI Integration

### Architecture — Two Layers

| Layer | Class | Where used |
|---|---|---|
| Local NLP (free, offline) | `PantryNlpParser` | Text input in Pantry AI bar |
| Cloud AI (Gemini via Edge Fn) | `AIParser.parseImage()` | Bill scan only |

There is no `AIParser.parseText()` call in the Pantry tab's main text flow — Pantry uses the local NLP parser directly, unlike the Wallet tab which also has a cloud text parser.

---

### PantryNlpParser (`lib/features/pantry/flows/pantry_nlp_parser.dart`)

**Intent classification** (priority order):
1. Recipe triggers (score += 2): `recipe`, `how to make`, `how to cook`, `save recipe`, `add recipe`
2. Basket triggers (score += 1): `add`, `buy`, `get`, `need`, `purchase`, `order`, `pick up`, `stock` — **only if no meal triggers also present**
3. Meal triggers (default): `had`, `ate`, `eat`, `having`, `cooked`, `made`, `prepared`, `lunch`, `dinner`, `breakfast`, `snack`

**Meal parsing**:
- Meal time: 12 keyword-to-MealTime mappings (`'morning' → breakfast`, `'tea time' → snack`, `'night' → dinner`, etc.)
- Date: `yesterday` / `tomorrow` / `today` (default)
- Dish name: strips trigger/time/date words from input, title-cases remainder
- Emoji: 35 dish-to-emoji mappings (idli→🫙, biryani→🍛, chicken→🍗, etc.)
- Confidence = `(name.isNotEmpty ? 0.4 : 0.1) + (mealTime != null ? 0.4 : 0.0) + (trigger found ? 0.2 : 0.0)`

**Basket parsing**:
- Qty + unit: `RegExp(r'(\d+(?:\.\d+)?)\s*(kg|g|gm|gram|l|ltr|litre|ml|pcs|pieces|dozen|pack|packet|bottle|box|bag|bunch)\b')`
- Fallback: number-only match (e.g. "3 eggs") → qty=3, unit='pcs'
- Category: 50+ keyword-to-`GroceryCategory` mappings
- Confidence = `(name ? 0.4 : 0.1) + (qty ? 0.3 : 0.0) + (category ? 0.3 : 0.0)`

**Unit normalisation**: `gram/grams/gm → g`, `litre/liters/ltr → L`, `pieces/piece → pcs`

**`PantryIntent` model**:
```dart
PantryIntent {
  kind: PantryIntentKind,   // meal | recipe | basket
  mealName, mealTime, mealDate,
  recipeName,
  groceryName, qty, unit, groceryCat,
  confidence: double,
  addToStock: bool,          // true → In Stock tab; false → To Buy
}
```

---

### PantryIntentConfirmSheet (`lib/features/pantry/flows/PantryIntentConfirmSheet.dart`)

Shown after `PantryNlpParser.parse()` returns. Not the AI — this is the local NLP post-parse UI.

**Kind-specific fields**:

| Kind | Fields shown |
|---|---|
| `meal` | name, emoji picker (20 emojis), meal time (4 animated cards), date (Yesterday / Today / Tomorrow) |
| `recipe` | name only + info hint ("Full Form to add details") |
| `basket` | item name, qty (number field), unit (text field), category chips (all 10 `GroceryCategory` values) |

**Save logic** (`_save()`):
- Meal: requires `name.isNotEmpty`; creates `MealEntry` with `walletId` from prop
- Recipe: requires `name.isNotEmpty`; creates minimal `RecipeModel` (cuisine=indian, suitableFor=[lunch, dinner])
- Basket: requires `name.isNotEmpty`; `inStock = intent.addToStock`, `toBuy = !intent.addToStock`

**"Full Form" button**: pops sheet then calls `onOpenMealForm` / `onOpenRecipeForm` / `onOpenBasketForm` — opens the respective detailed sheet.

---

### Bill Scan — Full Technical Flow

**Phase state machine**: `'pick'` → `'loading'` → `'confirm'`

**Limit enforcement** (two-step):

```
Step 1 — On sheet open (informational):
  SELECT count(*) FROM feature_usage WHERE user_id=uid AND feature='bill_scan'
  SELECT monthly_limit FROM feature_limits WHERE feature='bill_scan'
  → if count >= limit: show banner "X of Y scans used"

Step 2 — Right before API call (enforcement):
  RPC: check_feature_limit(p_user_id, 'bill_scan')
  → increments usage counter in DB atomically
  → returns bool: true=allowed, false=limit exceeded
  → if false: show SnackBar, stay on 'pick' phase
```

Free tier default: **3 scans/month** (configurable via `feature_limits` table).

**API call**:
```dart
AIParser.parseImage(
  feature: 'pantry',
  subFeature: 'bill_scan',
  imageBytes: Uint8List,
  mimeType: String,           // 'image/jpeg' or 'image/png'
)
```

**Expected response structure**:
```json
{
  "items": [
    { "name": "Tomatoes", "quantity": 2, "unit": "kg", "category": "vegetables", "price": 40.0, "confidence": 0.92 }
  ]
}
```

**Confirm phase** (`_ScannedItemTile`):
- Each item rendered with inline `TextEditingController` for name, qty, unit, price
- Checkbox to include/exclude item
- `confidence` field drives a subtle indicator but is not shown to user

**Wallet push toggle**:
```dart
// If "Also push to Wallet?" is ON:
WalletService.addTransaction(
  walletId: walletId,
  type: 'expense',
  category: 'groceries',
  amount: sum(price * qty for all accepted items),
  payMode: 'cash',
  date: today,
)
```

---

### Conversational Meal Flow (`lib/features/pantry/sheets/meal_conversation_flow.dart`)

Step sequence: `mealTime → mealName → emoji → confirm`

- Step `emoji` is **skipped** when a recipe was selected in `mealName` step (recipe already has an emoji)
- Bot questions delivered with 520 ms typing delay + animated chat bubbles
- Progress bar at top: `AnimatedFractionallySizedBox` that fills as steps complete
- If the chosen time slot is already occupied: `onUpdate` is called instead of `onSave`
- Done card offers "Log Another" (restarts all steps) or "Done" (closes sheet)
- Shares `ChatBubble` widget with the Wallet tab's conversation flow

---

## 3b.6 Screens and Widgets — Complete Reference

### PantryScreen (`lib/features/pantry/pantry_screen.dart`)

**State**:
| Field | Type | Purpose |
|---|---|---|
| `_sectionTab` | `TabController(length:3)` | MealMap / Basket / RecipeBox switching |
| `_meals` | `List<MealEntry>` | All meal entries for current week + scope |
| `_recipes` | `List<RecipeModel>` | All recipes for current walletId |
| `_groceries` | `List<GroceryItem>` | All grocery items for current walletId |
| `_foodPrefs` | `List<MemberFoodPrefs>` | Per-member food preferences |
| `_clipboardMeals` | `List<MealEntry>` | Copied meals awaiting paste |
| `_clipboardLabel` | `String` | Human-readable clipboard description |
| `_clipboardIsWeek` | `bool` | True → full-week clipboard |
| `_clipboardSourceWeekStart` | `DateTime?` | Source week for offset calculation |

**Members building**:
```dart
List<PantryMember> _buildMembers() {
  if (isPersonal) return [PantryMember(id: currentUserId, name: firstName, emoji: '👤')];
  return activeFamily.members.map(m => PantryMember(id: m.userId, name: m.name, emoji: m.emoji)).toList();
}
```

**Wallet switch**: `didUpdateWidget` detects `oldWidget.walletId != widget.walletId` → re-fetches all three data sets + food prefs.

**`mealChangeSignal` listener**: `PantryService.mealChangeSignal` is a `ValueNotifier<int>` incremented after every mutation; `PantryScreen` adds a listener to re-fetch meals, enabling cross-screen reactivity without rebuild coupling.

---

### MealMapSection (`lib/features/pantry/widgets/meal_map_section.dart`)

| Prop | Type | Purpose |
|---|---|---|
| `meals` | `List<MealEntry>` | All meals, filtered locally by date |
| `recipes` | `List<RecipeModel>` | Passed to `AddMealSheet` for recipe picker |
| `walletId` | `String` | Scope for new meals |
| `members` | `List<PantryMember>` | For reaction badge member lookup |
| `weekStart` | `DateTime` | Monday of the displayed week |
| `clipboardMeals` | `List<MealEntry>` | Drives clipboard banner visibility |
| `clipboardLabel` | `String` | Text shown in clipboard banner |
| `onCopyMeal` | `Function(MealEntry)` | Single meal copy |
| `onCopyDay` | `Function(DateTime)` | Day copy |
| `onCopyWeek` | `VoidCallback` | Full week copy |
| `onPasteToDay` | `Function(DateTime)` | Paste to target day |
| `onMealSaved` | `Function(MealEntry)` | Bubble new meal up to screen state |
| `onMealUpdated` | `Function(MealEntry)` | Bubble updated meal up |
| `onMealDeleted` | `Function(String)` | Bubble delete up |
| `onWeekChange` | `Function(DateTime)` | Week navigation |

---

### ShoppingBasketSection (`lib/features/pantry/widgets/shopping_basket_section.dart`)

| Prop | Type | Purpose |
|---|---|---|
| `items` | `List<GroceryItem>` | All grocery items for current scope |
| `walletId` | `String` | Scope for new items |
| `onItemAdded` | `Function(GroceryItem)` | Bubble add up |
| `onItemUpdated` | `Function(GroceryItem)` | Bubble update up |
| `onItemDeleted` | `Function(String)` | Bubble delete up |
| `onBillScanned` | `Function(List<GroceryItem>)` | Bulk add from scan |
| `onPushToWallet` | `Function(double)` | Wallet expense push from scan |

---

### RecipeBoxSection (`lib/features/pantry/widgets/recipe_box_section.dart`)

| Prop | Type | Purpose |
|---|---|---|
| `recipes` | `List<RecipeModel>` | Full recipe list, filtered locally |
| `onRecipeTapped` | `Function(RecipeModel)` | Opens `RecipeDetailSheet` |
| `onRecipeAdded` | `Function(RecipeModel)` | Bubble add up |
| `onUntagRecipe` | `Function(RecipeModel)?` | Remove library recipe from box |

---

### AddMealSheet (`lib/features/pantry/sheets/add_meal_sheet.dart`)

| Prop | Type | Purpose |
|---|---|---|
| `date` | `DateTime` | Initial date (from tapped day) |
| `walletId` | `String` | Scope |
| `recipes` | `List<RecipeModel>` | Recipe picker population |
| `onSave` | `Function(MealEntry)` | New meal callback |
| `existing` | `MealEntry?` | Non-null = edit mode (opens Manual tab) |
| `onUpdate` | `Function(MealEntry)?` | Update callback (edit mode) |
| `dayMeals` | `List<MealEntry>` | Current day meals — occupied slot detection |

**Occupation dot**: a small dot badge on the meal-time button when that slot already has a meal.

---

### AddRecipeSheet (`lib/features/pantry/sheets/add_recipe_sheet.dart`)

| Prop | Type | Purpose |
|---|---|---|
| `onSave` | `Function(RecipeModel)` | Add new recipe |
| `existing` | `RecipeModel?` | Edit mode |
| `onUpdate` | `Function(RecipeModel)?` | Update callback |

`DraggableScrollableSheet` with `initialChildSize: 0.92`. In edit mode, tab switcher is hidden (always custom form).

**`_parseIng(String raw)`** helper (used in `RecipeDetailSheet`):
- Parses ingredient strings into `(name, qtyUnit)` pairs
- Supports: `"Chicken 500g"`, `"Tomato (3 Pcs)"`, `"Rice 2 cups"`, `"Garlic"`

---

### FamilyFoodPrefsCard (`lib/features/pantry/widgets/family_food_prefs_card.dart`)

| Prop | Type | Purpose |
|---|---|---|
| `members` | `List<PantryMember>` | Family members to show as chips |
| `foodPrefs` | `List<MemberFoodPrefs>` | Existing prefs (matched by memberId) |
| `currentUserId` | `String` | Determines own-vs-others edit permission |
| `walletId` | `String` | For upsert scope |
| `isAdmin` | `bool` | Admins can edit all members |
| `onSave` | `Future<void> Function(MemberFoodPrefs)` | Async save callback |

`MemberFoodPrefs.copyWith()` used for partial updates — only changed lists are replaced.

---

### PantryFlowSelector (`lib/features/pantry/flows/pantry_flow_selector.dart`)

Shown when user taps **+** in the Pantry AI input bar while the text field is empty.

Row 1: `🗺️ Meal Map` · `📖 Recipe Box` · `🧺 Basket`  
Row 2: `🧾 Scan Bill` · `📋 Create List` · _(spacer)_

Each tile is `Expanded` within a `Row`. Tapping pops this sheet first, then calls the matching callback on `PantryScreen`.

---

## 3b.7 Repository — PantryService (`lib/data/services/pantry_service.dart`)

All methods are instance methods on `PantryService.instance` (singleton).

### Recipe Methods

| Method | Parameters | Return | Supabase table |
|---|---|---|---|
| `fetchRecipes(walletId)` | `String walletId` | `Future<List<Map>>` | `recipes` |
| `addRecipe({walletId, name, emoji, cuisine, suitableFor, ingredients, socialLink, note, cookTimeMin, isFavourite, libraryRecipeId})` | — | `Future<Map>` | `recipes` |
| `updateRecipe(id, {...fields})` | `String id`, same fields | `Future<void>` | `recipes` |
| `toggleFavourite(id, isFavourite)` | `String id, bool` | `Future<void>` | `recipes` |
| `deleteRecipe(id)` | `String id` | `Future<void>` | `recipes` |
| `searchMasterRecipes(query)` | `String query` | `Future<List<Map>>` | `master_recipes` — OR filter on `name.ilike + cuisine.ilike` |

### Meal Entry Methods

| Method | Parameters | Return | Supabase table |
|---|---|---|---|
| `fetchMealEntries(walletId)` | `String walletId` | `Future<List<Map>>` | `meal_entries` |
| `fetchMealEntriesForWeek(walletId, weekStart)` | `String, DateTime` | `Future<List<Map>>` | `meal_entries` — date range `weekStart` to `weekStart + 6 days` |
| `fetchMealEntriesForDay(walletId, day)` | `String, DateTime` | `Future<List<Map>>` | `meal_entries` |
| `addMealEntry({walletId, name, emoji, mealTime, date, recipeIds, note, ingredients})` | — | `Future<Map>` | `meal_entries` |
| `updateMealStatus(id, {status, servingsCount})` | `String id` | `Future<void>` | `meal_entries` |
| `updateMealEntry(id, {...fields})` | — | `Future<void>` | `meal_entries` |
| `deleteMealEntry(id)` | `String id` | `Future<void>` | `meal_entries` |

### Meal Copy Methods

| Method | Behaviour |
|---|---|
| `copyDayMeals({walletId, sourceDay, targetDay})` | Deletes all target-day entries first, then re-inserts copies with new date |
| `copyWeekMeals({walletId, sourceWeekStart, targetWeekStart})` | Deletes entire target week, then re-inserts preserving day-of-week offsets (`entry.date.weekday == source.weekday`) |

### Reaction Methods

| Method | Parameters |
|---|---|
| `addReaction({mealId, memberName, reactionEmoji, comment, replyTo})` | Inserts to `meal_reactions` |
| `updateReaction(id, {emoji, comment})` | Updates specific reaction |
| `deleteReaction(id)` | Deletes reaction |

### Grocery Methods

| Method | Parameters | Return | Supabase table |
|---|---|---|---|
| `fetchGroceryItems(walletId)` | `String walletId` | `Future<List<Map>>` | `grocery_items` |
| `fetchShoppingList(walletId)` | `String walletId` | `Future<List<Map>>` | `grocery_items` — filters `to_buy = true` |
| `addGroceryItem({walletId, name, category, quantity, unit, inStock, toBuy, note, expiryDate})` | — | `Future<Map>` | `grocery_items` |
| `updateGroceryItem(id, {...fields})` | — | `Future<void>` | `grocery_items` |
| `toggleInStock(id, value)` | `String id, bool` | `Future<void>` | `grocery_items` |
| `toggleToBuy(id, value)` | `String id, bool` | `Future<void>` | `grocery_items` |
| `deleteGroceryItem(id)` | `String id` | `Future<void>` | `grocery_items` |

### Food Prefs Methods

| Method | Parameters | Supabase table |
|---|---|---|
| `upsertFoodPrefs({walletId, memberId, allergies, likes, dislikes, mandatoryFoods})` | — | `member_food_prefs` — conflict target: `wallet_id, member_id` |

### Signals

```dart
static final mealChangeSignal = ValueNotifier<int>(0);
// Incremented after every mutation that should trigger a UI refresh
// Listened to in PantryScreen to re-fetch meals without rebuilding the full widget
```

---

## 3b.8 GroceryController (Legacy)

`lib/features/pantry/groceries/grocerycontroller.dart` — a `ChangeNotifier`-based controller registered in `MultiProvider` at app root. **This is NOT the primary grocery management layer.** Actual CRUD goes through `PantryService` + `PantryScreen` state.

`GroceryController` uses its own older `GroceryItem` model from `lib/data/models/pantry/groceryitem.dart` (different from `pantry_models.dart`), which has a `StorageType` field (pantry / fridge / freezer) and `isOut / isLow` computed properties.

Methods:
- `markAsBought(item)` — merges quantity if item name already exists, otherwise adds new
- `consumeItem(item, amountUsed)` — decrements quantity, clamps to 0

---

## 3b.9 Business Rules

### Personal vs Family Scope
- All data is `wallet_id`-scoped; switching wallets in `AppStateScope` re-fetches all pantry data
- Members for meal reactions / food prefs are derived from the **active wallet's family members** (not the user's full friend list)
- Personal wallet: single member = current logged-in user

### Duplicate Prevention
- Paste skips meals with the same `name + mealTime` already in the target day
- `copyDayMeals` / `copyWeekMeals` delete first, then insert — no duplicate check needed on the server side

### Recipe Ownership
- Recipes in `recipes` table belong to a wallet (not a user directly)
- Family wallet: all members share the recipe box; any member can add/edit
- `libraryRecipeId` creates a soft link to `master_recipes` but is cosmetic only — changes to `master_recipes` do NOT cascade

### Scan Limit Enforcement
- `feature_limits` table stores per-feature monthly limits (default 3 for `bill_scan`)
- `feature_usage` tracks per-user per-feature monthly usage
- The RPC `check_feature_limit` is the authoritative gate — client-side pre-check is informational only

### Ingredient Stock Check
- Matching is fuzzy: `g.name.toLowerCase().contains(name) || name.contains(g.name.toLowerCase())`
- No normalisation — "Tomato" and "Cherry Tomatoes" will match if either contains the other
- Missing ingredients default to selected in `_IngredientCheckSheet`; already-in-To-Buy items are shown dimmed and not selectable

---

*Next: **Section 3c — PlanIt Tab Documentation***
