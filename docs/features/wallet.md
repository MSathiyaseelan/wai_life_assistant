# Wallet Feature

> See also: [lib/features/wallet/README.md](../../lib/features/wallet/README.md) for developer-focused guide.

---

## Overview

The Wallet tab is the financial core of WAI. It tracks personal and family money flows across seven transaction types, supports AI-driven natural-language entry, reads bank SMS automatically, and manages shared expense splits with per-participant settlement tracking.

**V1 tabs exposed in the tab bar:**

| Tab | Widget | Purpose |
|---|---|---|
| Wallet | `WalletScreen` inner tab 0 | Transactions, balance card, groups |
| Splits | `WalletScreen` inner tab 1 | Split expense groups and settlement |
| Bill Watch | *(V2 hidden)* | Upcoming bill tracker |

---

## Transaction Types

```dart
enum TxType { income, expense, split, lend, borrow, request, returned }
enum PayMode { cash, online }
```

| TxType | Direction | Has Person | Has DueDate |
|---|---|---|---|
| `expense` | Out | No | No |
| `income` | In | No | No |
| `split` | Out (shared) | Multi | No |
| `lend` | Out | Single | Yes |
| `borrow` | In | Single | Yes |
| `request` | Pending | Single | No |
| `returned` | In (settlement) | Single | No |

`isPositive` = true for `income`, `borrow`, `returned` — these increase the displayed balance.

---

## User Flows

### Flow 1 — Add Expense via AI (Spark Assistant)

```
User taps FAB → SparkBottomSheet
        │
        ├── types text  OR  taps "Tap to speak" (STT)
        │   OR  taps "Paste bank SMS"
        │
        ▼  (for typed/spoken text)
AIParser.parseText(feature:'wallet', subFeature:'expense', text: input)
        │  invokes Supabase Edge Function 'parse'
        │  returns AIParseResult { success, data{}, confidence }
        │
        ▼
_mapToIntent(data) → ParsedIntent
        │
        ▼
IntentConfirmSheet.show(context, intent, walletId, onSave, onOpenFlow)
        │
User reviews parsed fields (editable):
  Amount · FlowType · Category · Person · PayMode · Date · Title · Note
        │
        ▼
WalletService.addTransaction(walletId, type, amount, ...)
        │
Supabase INSERT → trg_notify_family_on_tx fires
        │
WalletScreen refreshes transaction list
```

### Flow 2 — Manual Entry

```
User taps "Add Manually" → WalletFlowSelector
        │
        ▼
TransactionFormSheet (per txType)
  ← Amount, Category, Person, PayMode, Note, Date
        │
        ▼
WalletService.addTransaction(...)
```

### Flow 3 — SMS Auto-Import (disabled) / Manual Paste (active)

```
User copies bank SMS → SparkBottomSheet → "Paste bank SMS"
        │
Layer 1: SMSRegexParser.tryParse()
        │  confidence ≥ 0.80 → return (free, <1ms)
        │  confidence < 0.80 → Layer 2
        │
Layer 2: AIParser.parseText(feature:'wallet', subFeature:'sms_parse')
        │
IntentConfirmSheet.show(context, intent)
```

See [integrations/supabase.md](../integrations/supabase.md) for SMS parsing details.

---

## Data Flow Diagram

```
User Input (text/voice/SMS)
        │
        ▼
┌────────────────────────────┐
│ Layer 1: Local NLP         │  NlpParser.parse() — confidence ≥ 0.75
│  or SMS Regex Parser       │  SMSRegexParser — confidence ≥ 0.80
└────────────────────────────┘
        │ fails / low confidence
        ▼
┌────────────────────────────┐
│ Layer 2: Gemini AI         │  AIParser → /parse edge function
│  (gemini-2.5-flash)        │  reads prompt from ai_prompts table
└────────────────────────────┘
        │
        ▼
AIParseResult { success, data, confidence }
        │
IntentConfirmSheet (user review + edit)
        │
        ▼
WalletService.addTransaction()
        │
Supabase transactions table
```

---

## NLP Parser

`NlpParser` (`lib/features/wallet/AI/nlp_parser.dart`) — deterministic, zero-cost, runs entirely on-device.

**7-step pipeline:**
1. Amount extraction — handles `₹500`, `5k`, `2.5L`, `five hundred`
2. Flow type detection — priority order: lend → borrow → split → request → income → expense
3. Category detection — `CategoryDetector.detectCategory(text)` (must call `ensureLoaded()` first)
4. Person extraction — after/before keywords: "to Ravi", "from Priya", "with Kumar"
5. Pay mode detection — `cash`, `online`, `upi`, `gpay`, `phonepe` keywords
6. Note extraction — sentence fragment after all above are stripped
7. Confidence scoring — weighted sum of matched fields (0.0–1.0)

---

## Folder Structure

```
lib/features/wallet/
├── AI/
│   ├── nlp_parser.dart          ← local NLP (primary)
│   ├── category_detector.dart   ← keyword-based category matching
│   ├── sms_regex_parser.dart    ← bank SMS pattern matching
│   ├── SparkBottomSheet.dart    ← AI entry sheet (voice/text/SMS)
│   ├── IntentConfirmSheet.dart  ← user review before save
│   └── handleAiIntent.dart      ← stub (superseded by IntentConfirmSheet)
├── data/
│   └── services/
│       └── wallet_service.dart  ← Supabase CRUD for transactions
├── models/
│   ├── wallet_transaction.dart
│   └── parsed_intent.dart
├── screens/
│   └── wallet_screen.dart       ← main screen (inner tab controller)
├── services/
│   └── sms_parser_service.dart  ← SMS scan coordination, cooldown, dedup
└── widgets/
    └── ...                      ← transaction cards, balance card, etc.
```

---

## Split Groups

Splits are tracked separately from regular transactions:

| Table | Purpose |
|---|---|
| `split_groups` | Named group (e.g. "Goa Trip") |
| `split_participants` | Members — may or may not have WAI accounts |
| `split_group_transactions` | Individual expenses within the group |
| `split_shares` | Each member's portion + settlement status |

Settlement statuses: `pending` → `proof_submitted` → `settled` (or `extension_requested` → `extension_granted`).

The `SplitSparkBottomSheet` class (`lib/features/wallet/AI/SplitSparkBottomSheet.dart`) is currently a stub — logic is commented out.

---

## Common Issues

**Category not detected:** `CategoryDetector.ensureLoaded()` must be called before any `NlpParser.parse()`. If called from a cold start without this, category always returns the default.

**SMS cooldown:** `SMSParserService` enforces a 5-minute cooldown between scans (`_kScanCooldownMs = 5 * 60 * 1000`). Manual paste is not subject to this.

**NLP priority order matters:** `lend` keywords are checked before `income`. "I lent 500 to Ravi and got income from work" parses as `lend` because lend is tested first. Adjust `_detectFlowType()` keyword order only after understanding all downstream effects.

**Balance columns are triggers, not computed:** `wallets.cash_in`, `cash_out`, `online_in`, `online_out` are maintained by the `trg_sync_wallet_balance` trigger. Do not try to UPDATE them directly.

---

## Related Documentation

- [AI Smart Parser](../ai/smart-parser.md) — two-layer parsing architecture
- [Database Schema](../database.md) — `transactions`, `split_groups` tables
- [SMS Parsing (Section 5.6)](../integrations/supabase.md) — bank SMS detection details
- [lib/features/wallet/README.md](../../lib/features/wallet/README.md) — developer guide (add new tx type, gotchas)
