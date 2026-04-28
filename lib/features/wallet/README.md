# Wallet Feature

## Overview

The Wallet feature is WAI's personal finance module. It tracks income, expenses, lends, borrows, split expenses, and money requests across one or more wallets per household. Transactions can be entered in three ways — a guided conversational flow (step-by-step bot), a natural-language/voice quick-add sheet (Spark), or by pasting/auto-detecting bank SMS messages. The screen also hosts Split Groups (shared expense tracking with member balances), a Bill Watch tab for upcoming recurring bills, a Family tab to view transactions across linked wallets, and a Reports sheet with daily/weekly/monthly breakdowns.

---

## Folder Structure

```
lib/features/wallet/
│
├── wallet_screen.dart          # Root screen — tabs, state, entry points
│
├── AI/                         # Natural-language and voice entry
│   ├── SparkBottomSheet.dart       # Primary quick-add sheet (type/speak/paste SMS)
│   ├── IntentConfirmSheet.dart     # Review + edit parsed result before saving
│   ├── nlp_parser.dart             # Local regex NLP (Layer 1, zero cost)
│   ├── handleAiIntent.dart         # Legacy stub — dispatch on AI intent type
│   ├── SplitSparkBottomSheet.dart  # WIP: AI split creation (currently stubbed)
│   ├── showSparkBottomSheet.dart   # Helper to show SparkBottomSheet as a sheet
│   └── showSplitSparkBottomSheet.dart  # Helper for SplitSparkBottomSheet
│
├── models/
│   └── sms_transaction.dart    # Parsed SMS result + toParsedIntent() bridge
│
├── services/
│   ├── sms_parser_service.dart # Auto-scan + manual-paste pipeline (Android)
│   └── sms_regex_parser.dart   # Layer 1 regex parser for Indian bank SMS
│
├── screens/
│   ├── sms_permission_screen.dart      # Permission onboarding for READ_SMS
│   └── sms_history_import_screen.dart  # Bulk date-range SMS import sheet
│
├── splits/
│   ├── split_group_sheet.dart          # Create/edit a split group
│   └── split_group_detail_screen.dart  # Group detail: Overview / Expenses / Chat
│
└── widgets/
    ├── wallet_card_widget.dart     # Balance card with cash/online period breakdown
    ├── tx_tile.dart                # Single transaction row (list item)
    ├── tx_group_card.dart          # Grouped transaction card (named bundle)
    ├── tx_detail_sheet.dart        # Bottom sheet: view/edit/delete/move a tx
    ├── chat_input_bar.dart         # Bottom input bar (type, voice mic, Spark button)
    ├── month_year_picker.dart      # Date range filter chip
    └── family_switcher_sheet.dart  # Sheet to switch the active family wallet

├── category_detector.dart      # Keyword + learned category detection (shared)
├── flow_selector_sheet.dart    # Bottom sheet: choose a transaction type
├── flow_steps.dart             # Individual form widgets for each flow step
├── conversation_flow.dart      # Conversational bot UI (step-by-step)
├── conversation_screen.dart    # Screen wrapper around ConversationFlow
├── chat_bubble.dart            # Chat message bubble widget
└── wallet_reports_sheet.dart   # Daily/Weekly/Monthly/Yearly/Category reports
```

**Folders at a glance:**

| Folder | What belongs here |
|---|---|
| `AI/` | Anything that parses natural language or images — sheets, parsers, handlers |
| `models/` | Wallet-specific data classes not shared across features |
| `services/` | Non-UI logic that touches device hardware (SMS inbox) |
| `screens/` | Full-page screens pushed onto the navigator |
| `splits/` | Everything for split/shared expense groups |
| `widgets/` | Reusable UI components used by `wallet_screen.dart` |

Data models shared with other features (`TxModel`, `WalletModel`, `FlowType`, `SplitGroup`, etc.) live in `lib/data/models/wallet/`, not here.

---

## Key Files

### `wallet_screen.dart`
The root stateful widget. Owns: tab state (`WalletTab` enum), the active `MonthRange` filter, the loaded `_transactions` list, `_splitGroups`, `_txGroups`, and the lifted `_bills` state for BillWatch. It also initialises `SpeechToText` and handles drag-and-drop of transactions into groups. Every other file in this folder is opened from here.

### `AI/SparkBottomSheet.dart`
The main quick-add entry point. Three input modes in one sheet:
1. **Type** — free-form text fed to `NlpParser`, then to Gemini if NLP confidence is low
2. **Voice** — `SpeechToText.listen(localeId: 'en_IN')` feeds transcribed text to the same pipeline
3. **Paste SMS** — copies from clipboard, runs through `SMSParserService.parseSMSText()`

After parsing, opens `IntentConfirmSheet`. Has an `autoPasteSms` flag that triggers the paste path automatically on open (used by the `paste_bank_sms` home screen quick action).

### `AI/IntentConfirmSheet.dart`
Review step between parsing and saving. Shows the detected type, amount, category, and person as editable chips. Has an "Edit in full flow" escape hatch that opens `ConversationFlow` with pre-filled values. Calls `WalletService.instance.addTransaction()` on confirm.

### `AI/nlp_parser.dart`
Pure Dart, zero-cost local NLP. `NlpParser.parse(text)` returns a `ParsedIntent`. Extracts:
- **Amount** — handles `₹500`, `5k`, `2.5L`, `five hundred`
- **Flow type** — keyword sets for expense/income/lend/borrow/split/request
- **Category** — ~40 keyword mappings
- **Person** — regex for names after `to/from/with/for`
- **PayMode** — cash vs online keyword sets
- **Confidence** — 0–1 score based on what was successfully extracted

Returns confidence < 0.75 → caller falls back to Gemini (`AIParser.parseText`).

### `category_detector.dart`
Keyword-based category detection with a **learning layer**. When a user manually corrects a category, `CategoryDetector.learn(title, category)` persists the correction to `SharedPreferences`. Future detections for the same title return the learned value first. Used by both `NlpParser` and `SMSRegexParser`.

### `models/sms_transaction.dart`
`SMSTransaction` — the parsed result from either the regex or AI SMS parser. The key bridge method is `toParsedIntent()`, which converts it to a `ParsedIntent` so `IntentConfirmSheet` can pre-fill the form without knowing the source.

### `services/sms_regex_parser.dart`
Ten bank-specific regex patterns for Indian SMS formats (HDFC debit/credit, SBI, ICICI, Axis, UPI paid/received, salary, generic). Each returns an `SMSTransaction` with a confidence score. Handles three Indian date formats (`17-03-26`, `17/03/2026`, `17-Mar-26`). Returns `null` when no pattern matches — caller falls back to AI.

### `services/sms_parser_service.dart`
Orchestrates SMS scanning. Approach 1 (auto-scan on open, Android, currently disabled — see Known Issues) and Approach 2 (manual paste). The two-layer pipeline: regex first → AI fallback. Maintains a deduplication set of seen SMS IDs and a 5-minute scan cooldown in `SharedPreferences`.

### `conversation_flow.dart`
Step-by-step conversational UI rendered as a chat thread. Each step (`FlowStep`) is an inline widget that captures one piece of data (amount, category, person, pay mode, note, date). On completion, assembles a `TxModel` and calls `WalletService.instance.addTransaction()` directly.

### `flow_steps.dart`
All individual step widgets: `AmountStep` (custom numpad), `CategoryStep`, `PersonStep` (contacts picker), `PayModeStep`, `NoteStep`, `DateStep`. Each widget calls `onConfirm(value)` when the user submits.

### `splits/split_group_detail_screen.dart`
Full-page screen with three tabs: Overview (member balances), Expenses (transactions with per-person shares), Chat (group thread via Supabase Realtime). Handles its own Realtime subscription independently from the main wallet screen.

### `wallet_reports_sheet.dart`
Pure computation — takes the already-loaded `List<TxModel>` and slices it into daily/weekly/monthly/yearly and category breakdowns. No new DB call. Uses `dart:math` for chart bar normalization.

---

## Data Flow

```
User input
    │
    ├── Type/Voice ──► NlpParser.parse()
    │                       │
    │                       ├── confidence ≥ 0.75 ──► ParsedIntent
    │                       │
    │                       └── confidence < 0.75 ──► AIParser.parseText()
    │                                                  (Gemini via /parse edge fn)
    │                                                       │
    │                                                       └── ParsedIntent
    │
    ├── Paste/Scan SMS ──► SMSRegexParser.tryParse()
    │                           │
    │                           ├── confidence ≥ 0.80 ──► SMSTransaction
    │                           │                              │
    │                           └── no match or low ──► AIParser.parseText()
    │                                                    (wallet/sms_parse prompt)
    │                                                         │
    │                                                         └── SMSTransaction
    │                                                              │
    │                                                    SMSTransaction.toParsedIntent()
    │                                                              │
    │                                                         ParsedIntent
    │
    └── Manual flow ──► ConversationFlow (step by step)
                                │
                                └── TxModel assembled in memory
                                         │
                                         ▼
                              IntentConfirmSheet
                              (user reviews, edits inline)
                                         │
                                         ▼
                              WalletService.addTransaction(walletId, tx)
                                         │
                                         ▼
                              Supabase: INSERT INTO transactions
                                         │
                                         ▼
                              onSave(tx) callback
                                         │
                                         ▼
                              WalletScreen._transactions.insert(0, tx)
                              (optimistic local update — no reload)
```

**Key data models:**

| Model | Location | Purpose |
|---|---|---|
| `TxModel` | `lib/data/models/wallet/wallet_models.dart` | A saved transaction in the DB |
| `WalletModel` | `lib/data/models/wallet/wallet_models.dart` | A wallet (personal or family) |
| `FlowType` | `lib/data/models/wallet/flow_models.dart` | `expense/income/lend/borrow/split/request` |
| `PayMode` | `lib/data/models/wallet/flow_models.dart` | `cash/online` |
| `ParsedIntent` | `lib/features/wallet/AI/nlp_parser.dart` | NLP parse result (pre-save) |
| `SMSTransaction` | `lib/features/wallet/models/sms_transaction.dart` | SMS parse result (pre-confirm) |
| `SplitGroup` | `lib/data/models/wallet/split_group_models.dart` | A shared expense group |
| `TxGroup` | `lib/data/models/wallet/wallet_models.dart` | A named bundle of transactions |

**WalletService** (`lib/data/services/wallet_service.dart`) owns all DB calls for the wallet feature. Never call `Supabase.instance.client` directly from wallet UI code — go through the service.

---

## Adding a New Transaction Type

Say you want to add a `subscription` type (recurring monthly charge with a service name field).

### Step 1 — Add the enum value

```dart
// lib/data/models/wallet/flow_models.dart
enum FlowType {
  expense, income, lend, borrow, split, request,
  subscription,  // ← add here
}
```

### Step 2 — Add it to the flow selector UI

```dart
// lib/features/wallet/flow_selector_sheet.dart
// In the _flowOptions list (or equivalent), add:
_FlowOption(
  type:  FlowType.subscription,
  emoji: '🔁',
  label: 'Subscription',
  color: const Color(0xFF7C3AED),
),
```

### Step 3 — Add a conversation flow script

Open `conversation_flow.dart` and add a case in the `_buildScript()` method (or equivalent step list builder):

```dart
case FlowType.subscription:
  return [
    _Step(FlowStep.amount,    'How much is the subscription? 💳'),
    _Step(FlowStep.person,    'Which service? (Netflix, Spotify…)'),
    _Step(FlowStep.payMode,   'Paid by cash or online?'),
    _Step(FlowStep.note,      'Any note? (optional)'),
    _Step(FlowStep.date,      'When was it charged?'),
  ];
```

### Step 4 — Map it to a DB transaction type

In `WalletService.addTransaction()`, make sure the `type` field written to Supabase is correct. If `subscription` needs to be stored as `expense` with a tag:

```dart
// lib/data/services/wallet_service.dart
final dbType = flowType == FlowType.subscription ? 'expense' : flowType.name;
```

Or add `subscription` as a native DB type if you want to filter/report on it separately (requires a migration).

### Step 5 — Add NLP keywords

```dart
// lib/features/wallet/AI/nlp_parser.dart
static const _intentSubscription = [
  'subscription', 'subscribe', 'renew', 'renewal', 'monthly plan',
];

// In parse(), add before the income/expense tryMatch calls:
tryMatch(_intentSubscription, FlowType.subscription);
```

### Step 6 — Add category keywords

```dart
// lib/features/wallet/category_detector.dart  (expense section)
if (has(['netflix', 'spotify', 'youtube premium', 'hotstar', 'prime',
          'icloud', 'subscription'])) return '🔁 Subscription';
```

### Step 7 — Update the AI prompt

Run the SQL below in Supabase Dashboard → SQL Editor to add subscription recognition to the expense prompt. Or bump the version and add new `sub_feature: 'subscription'` if it needs distinct handling:

```sql
-- If reusing the expense prompt, just update the notes.
-- If it needs its own prompt:
INSERT INTO ai_prompts (feature, sub_feature, input_type, version, prompt)
VALUES ('wallet', 'subscription', 'text', 1, $$
  ... your prompt ...
$$);
```

### Step 8 — Handle in reports

Open `wallet_reports_sheet.dart` and ensure the category breakdown picks up the new type. If `FlowType.subscription` is stored as `expense`, it will already appear under its category. If it's a new top-level type, add it to the summary row computation.

---

## Common Issues and Solutions

### "No transactions appear after saving"

The screen does an optimistic local insert: `_transactions.insert(0, tx)`. If the screen was rebuilt between the `addTransaction` call and the callback, the insert may have been dropped. Call `_loadTransactions()` inside `setState` in `onSave` as a fallback:

```dart
onSave: (tx) {
  setState(() => _transactions.insert(0, tx));
  // If the list still looks stale, force reload:
  _loadTransactions();
},
```

### NLP returns wrong flow type

`NlpParser` checks intent keywords in a fixed priority order: lend → borrow → split → request → income → expense. If a phrase matches two types (e.g. "gave salary to employee" matches both lend and income), the first match wins. Add a more specific keyword to the higher-priority list, or move your new type earlier in the `tryMatch` chain.

### AI parse returns `needs_review: true` but confidence looks fine

The `needs_review` flag is set by the edge function when `parsed.confidence < 0.7`. The NLP confidence and the AI confidence are different scales — NLP confidence is computed locally from how many fields were extracted, while AI confidence is the value Gemini returned in its JSON. They are not comparable. Check `meta.confidence` in the `AIParseResult`, not the local `ParsedIntent.confidence`.

### SMS scan finds nothing after enabling READ_SMS

Two likely causes:
1. `_kScanCooldownMs` (5 minutes) is still active from a previous run. Clear `SharedPreferences` or wait 5 minutes.
2. The seen-IDs set (`sms_seen_ids`) already contains the message IDs from a previous scan. Clear it via:
   ```dart
   final prefs = await SharedPreferences.getInstance();
   await prefs.remove('sms_seen_ids');
   ```

### `IntentConfirmSheet` opens with empty fields

`ParsedIntent` is immutable — all fields are optional except `flowType` and `confidence`. If NLP returned `amount: null`, the confirm sheet shows an empty amount field. This is by design — the user fills in whatever is missing. If this happens too often for a common phrase, add the pattern to `NlpParser._catMap` or the intent keyword lists.

### `SplitSparkBottomSheet` does nothing

This file is currently stubbed out. The entire constructor body and the `show()` helper are commented out at the top of the file. Split creation goes through `SplitGroupSheet` directly, not via this sheet. Do not use `SplitSparkBottomSheet` until it is implemented.

### `CategoryDetector.detect()` returns null after learning

`CategoryDetector.ensureLoaded()` must be called before `detect()` on cold app start. It loads the learned map from `SharedPreferences` into the in-memory cache. If you skip it, `_loaded` is `false` and the learned map is empty. Add `await CategoryDetector.ensureLoaded()` to your service's `init()` if you're using it outside the conversational flow.

### `conversation_flow.dart` imports use `../../../../../core/` (five levels up)

This is a known path depth issue. The file is nested at `lib/features/wallet/`, so the relative path to `lib/core/` needs five `../`. If you move any file, update these manually — the project does not use path aliases or barrel files for this feature.

### Drag-and-drop assignment to `TxGroup` doesn't persist

Drag state is managed in `wallet_screen.dart` via `_draggingTx`. The drop target calls `WalletService.instance.assignGroup(tx.id, group.id)`. If that call succeeds but the UI doesn't update, check that the `onGroupUpdated` callback triggers a `setState` that rebuilds `_transactions` with the new `groupId` set.

---

## Related Documentation

- **[docs/ai_integration.md](../../../docs/ai_integration.md)** — All 28 AI prompts, the `/parse` edge function, context injection, cost analysis. Read this before modifying any AI parse behaviour.
- **[docs/third_party_integrations.md](../../../docs/third_party_integrations.md)** — Section 5.2 (Gemini), Section 5.6 (SMS parsing) — setup, secrets, rate limits.
- **[docs/error_tracking.md](../../../docs/error_tracking.md)** — How to wrap wallet service calls in `SafeExecutor`, severity levels, SQL queries for wallet errors.
- **`lib/data/services/wallet_service.dart`** — All Supabase DB calls for the wallet. This is the canonical source of truth for what columns exist and what constraints apply.
- **`lib/data/models/wallet/`** — `wallet_models.dart` (`TxModel`, `WalletModel`, `TxGroup`), `flow_models.dart` (`FlowType`, `PayMode`, `FlowStep`), `split_group_models.dart` (`SplitGroup`).
- **`supabase/migrations/`** — Look for migration files prefixed `0XX_wallet_` or containing `transactions` for the DB schema. The `ai_prompts` table seeds are in `037_sms_parse_prompt.sql` and `018_split_expense_ai_prompt.sql`.
