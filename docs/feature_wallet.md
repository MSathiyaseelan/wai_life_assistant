# WAI Life Assistant — Technical Documentation
### Section 3a: Wallet Tab

---

## Overview

The Wallet tab is the financial core of WAI. It tracks personal and family money flows across seven transaction types, supports AI-driven natural-language entry, reads bank SMS automatically, and manages shared expense splits with per-participant settlement tracking.

**V1 tabs exposed in the tab bar:**

| Tab | Widget | Purpose |
|---|---|---|
| Wallet | `WalletScreen` inner tab 0 | Transactions, balance card, groups |
| Splits | `WalletScreen` inner tab 1 | Split expense groups and settlement |
| Bill Watch | *(enum defined, V2 hidden)* | Upcoming bill tracker |

---

## Transaction Types

```dart
enum TxType { income, expense, split, lend, borrow, request, returned }
enum PayMode { cash, online }
```

| TxType | Emoji | Direction | Has Person | Has DueDate |
|---|---|---|---|---|
| `expense` | 💸 | Out | No | No |
| `income` | 💰 | In | No | No |
| `split` | ⚖️ | Out (shared) | Multi | No |
| `lend` | 📤 | Out | Single | Yes |
| `borrow` | 📥 | In | Single | Yes |
| `request` | 🔔 | Pending | Single | No |
| `returned` | ↩️ | In (settlement) | Single | No |

`isPositive` is true for: `income`, `borrow`, `returned` — these increase the displayed balance.

---

## User Flows

### Flow 1 — Add Expense via AI (Spark Assistant)

```
User taps ✨ FAB on WalletScreen
        │
        ▼
showSparkBottomSheet(context, walletId, onSave, onOpenFlow)
        │
        ▼
SparkBottomSheet displayed (modal bottom sheet)
        │
        ├── User types text  OR  taps "Tap to speak" (STT)
        │   OR  taps "Paste bank SMS"
        │
        ▼  (for typed/spoken text)
AIParser.parseText(feature:'wallet', subFeature:'expense', text: input)
        │  — invokes Supabase Edge Function 'parse'
        │  — returns AIParseResult { success, data{}, confidence }
        │
        ▼
_mapToIntent(data) → ParsedIntent
        │  (flowType, amount, category, person, payMode, title, note, confidence)
        │
        ▼
Navigator.pop(SparkSheet)
IntentConfirmSheet.show(context, intent, walletId, onSave, onOpenFlow)
        │
        ▼
User reviews parsed fields inline (editable)
        │  — Amount (large rupee input)
        │  — FlowType chip selector (can change to Income/Lend/etc.)
        │  — Category chips
        │  — Person field (if lend/borrow/split/request)
        │  — PayMode toggle (Cash / Online)
        │  — Date picker
        │  — Title (optional)
        │  — Note (optional)
        │
        ├── Taps "Full Flow" → opens ConversationFlow (see Flow 2)
        │
        └── Taps "Save Expense"
                │
                ▼
        WalletService.instance.ensureCategory(category, txType)
        WalletService.instance.addTransaction(walletId, type, amount, ...)
                │  — INSERT into 'transactions' table
                │  — DB trigger: sync_wallet_balance() updates wallet balance cols
                │  — DB trigger: notify_family_on_transaction() inserts notifications
                │    for all other family wallet members
                │
                ▼
        TxModel.fromRow(row) returned to WalletScreen via onSave callback
        WalletScreen prepends new TxModel to _transactions list
        WalletService.txChangeSignal.value++ (notifies DashboardScreen)
```

---

### Flow 2 — Add Expense via Conversational Flow (Full Flow)

```
User taps "Full Flow" button  OR  taps a FlowType card in FlowSelectorSheet
        │
        ▼
ConversationScreen opened (push navigation)
  contains ConversationFlow(flowType, walletId, wallets, transactions, onComplete)
        │
        ▼
ConversationFlow.initState()
  → _steps = flowType.steps  (ordered list of FlowStep enum values)
  → CategoryDetector.ensureLoaded()   (loads learned mappings from SharedPrefs)
  → _pushBotQuestion(0)
        │
        ▼ ─── Step loop begins ───────────────────────────────────────────────────
        │
        │  For each FlowStep:
        │    1. Bot shows typing indicator (520ms)
        │    2. Bot message + input widget rendered in chat ListView
        │    3. User interacts with widget (tap chip / numpad / contact picker)
        │    4. _answer(step, displayText, applyData):
        │         - marks previous bot message widget as "done" (hidden)
        │         - adds user bubble to chat
        │         - increments _stepIdx
        │         - pushes next bot question
        │
        │  Special: FlowStep.title
        │    After user answers, _answerTitle() attempts auto-detect:
        │    CategoryDetector.detect(title, isIncome: ...) → checks learned map,
        │    then keyword map → if found, overrides category step question text
        │
        │  Special: FlowStep.person (for FlowType.returned)
        │    _validateReturnedPerson(name):
        │      - sums lentTotal + borrowedTotal - returnedTotal for that person
        │      - rejects if no record found OR outstanding ≤ 0
        │      - shows bot error message and does NOT advance step
        │
        ▼ ─── After FlowStep.confirm ─────────────────────────────────────────────
        │
        │  ConfirmStep widget shows summary card
        │  User taps "Save Transaction"
        │
        ▼
_save() → _data.toTxModel(flowType, walletId) → widget.onComplete(tx)
        │  (tx is a temporary TxModel with timestamp id, not yet persisted)
        │
        ▼
WalletScreen._onFlowComplete(tx):
  → WalletService.instance.addTransaction(...)  [persists to Supabase]
  → prepends to _transactions
  → shows SuccessStep card (elastic-out animation)
        │
        ▼
User taps "+ Add Another" → _restart() resets all state
```

**Step order by FlowType:**

| FlowType | Steps (in order) |
|---|---|
| expense | amount → title → owner → paymode → date → category → note → confirm |
| income | amount → title → owner → paymode → date → category → note → confirm |
| split | amount → persons → splitType → date → title → note → confirm |
| lend | amount → person → paymode → dueDate → title → note → confirm |
| borrow | amount → person → paymode → dueDate → title → note → confirm |
| request | amount → person → title → note → confirm |
| returned | amount → person → paymode → date → title → note → confirm |

---

### Flow 3 — Add a Split Group and Record Expenses

```
User taps "+" in Splits tab
        │
        ▼
SplitGroupSheet.show(context, walletId, onSave)
        │  Two inner tabs: "Contacts" / "Manual"
        │
        ├── Contacts tab: loads FlutterContacts, user taps to add participants
        │   Each participant gets name + emoji avatar
        │   "Me" participant is always added automatically (isMe: true)
        │
        └── Manual tab: user types name + picks avatar emoji
        │
        ▼
User fills group name + emoji, taps Save
        │
        ▼
WalletService.instance.createSplitGroup(
  walletId, name, emoji, participants: [{name, emoji, phone, isMe}])
  → INSERT into split_groups
  → INSERT batch into split_participants
  → returns group + participant rows with real UUIDs
        │
        ▼
SplitGroupDetailScreen pushed (3-tab full page)
  Tab 0: Overview — member balance summary, total spent
  Tab 1: Expenses — list of split_group_transactions + per-share status
  Tab 2: Chat — real-time group message thread

─── Adding an expense to the split group ─────────────────────────────────────

User taps "Add Expense" in Expenses tab
        │
        ▼
_showAddExpense() bottom sheet:
  - Title, Amount, Date, Split type (equal / unequal / percentage)
  - Participant checkboxes with individual amount fields if custom
        │
        ▼
WalletService.instance.addSplitTransaction(
  groupId, addedByParticipantId, title, totalAmount, splitType,
  shares: [{participantId, amount, percentage}], ...)
  → INSERT into split_group_transactions
  → INSERT batch into split_shares
    (payer's own share: status = 'settled' immediately)
    (others' shares: status = 'pending')

─── Settling a share ─────────────────────────────────────────────────────────

User taps a pending share tile → taps "Mark Settled"
        │
        ▼
WalletService.instance.updateShareStatus(
  shareId, status: 'settled', proofNote: ..., proofDate: ...)
  → UPDATE split_shares SET status = 'settled', ...

─── Proof image upload ───────────────────────────────────────────────────────

User taps camera icon → ImagePicker → selects image
        │
        ▼
WalletService.instance.uploadProofImage(groupId, imageBytes)
  → upload to Supabase Storage bucket 'split-proof'
  → path: 'proofs/{groupId}/{timestamp}.jpg'
  → returns public URL stored in split_shares.proof_image_path

─── Sending a reminder ───────────────────────────────────────────────────────

User taps "Send Reminder" on pending share
        │
        ▼
WalletService.instance.recordReminderSent(transactionId, participantId, sentBy)
  → RPC call: increment_split_reminder(p_transaction_id, p_participant_id, p_sent_by)
  → atomically increments split_shares.reminder_count
        │
        ▼
WhatsApp deep link opened via url_launcher:
  "https://wa.me/{phone}?text=Hey, reminder to settle ₹{amount} for {title}"
```

---

### Flow 4 — Lend / Borrow Tracking

```
User selects "Lend Money" or "Borrow" from FlowSelectorSheet
        │
        ▼
ConversationFlow(flowType: FlowType.lend / FlowType.borrow)
  Steps: amount → person (contact picker) → paymode → dueDate → title → note → confirm
        │
        ▼
WalletService.addTransaction(type: 'lend' or 'borrow', person: name, ...)
  → Saved to 'transactions' table with type = 'lend' / 'borrow'

─── Recording a return ───────────────────────────────────────────────────────

User selects "Returned Money" flow
  Steps: amount → person → paymode → date → title → note → confirm
        │
        ▼ (at the person step)
_validateReturnedPerson(name):
  lentTotal   = SUM of transactions WHERE type='lend' AND person=name
  borrowedTotal = SUM of transactions WHERE type='borrow' AND person=name
  returnedTotal = SUM of transactions WHERE type='returned' AND person=name
  outstanding  = lentTotal + borrowedTotal - returnedTotal
  → Rejects if outstanding ≤ 0 (all settled)
  → Proceeds if outstanding > 0
        │
        ▼
WalletService.addTransaction(type: 'returned', person: name, ...)
```

---

### Flow 5 — Family Expense (switching wallet context)

```
Any screen with wallet pill at top
        │
        ▼
User taps wallet pill → WalletSwitcherPill (or DefaultScopeSheet)
        │
        ▼
AppStateNotifier.switchWallet(newWalletId)
  → notifyListeners()
  → AppStateScope rebuilds
  → All tab screens receive new activeWalletId via prop
        │
        ▼
WalletScreen._loadAll():
  WalletService.fetchTransactions(newWalletId)
  WalletService.fetchTxGroups(newWalletId)
  WalletService.fetchSplitGroups(newWalletId)
        │
        ▼
All new transactions are posted with this walletId
RLS on 'transactions' validates:
  wallet_id IN (SELECT wallet_id FROM wallet_members WHERE user_id = auth.uid())
DB trigger notify_family_on_transaction():
  Inserts a notification row for EVERY OTHER member of the wallet
  (SECURITY DEFINER — runs as superuser to bypass member-only RLS)
```

---

## Technical Flows

### SmartParser Layer Sequence

The wallet uses a three-layer parsing strategy for natural language and SMS input:

```
User input (typed / spoken / pasted SMS)
        │
        ▼
Layer 1: SMSRegexParser.tryParse(text)       [free, instant, ~70% coverage]
        │  10 pattern matchers for Indian banks:
        │  HDFC debit/credit, SBI debit, ICICI debit, Axis debit,
        │  UPI paid, UPI received, Salary credit, Generic debit/credit
        │  Returns SMSTransaction with confidence 0.60–0.92
        │
        ├─ confidence ≥ isHighConfidence threshold → RETURN immediately
        │
        └─ low confidence or null
                │
                ▼
        Layer 2: AIParser.parseText(feature, subFeature, text)   [Gemini via Edge Fn]
                │  → POST to Supabase Edge Function 'parse'
                │  → body: { feature, sub_feature, input_type, text, context }
                │  → context includes: today's date, day_of_week, currency: INR
                │  → Edge Function calls Google Gemini AI
                │  → Returns AIParseResult { success, data{}, confidence, needsReview }
                │
                ├─ success=true → return AIParseResult.data
                │
                └─ failure → fall back to Layer 1 regex result (even if low confidence)
```

**For the conversational full flow, a separate local parser is also used:**

```
NlpParser.parse(rawText)   [pure Dart, no network call]
        │  1. Amount extraction: regex for "5k", "2.5L", plain numbers, word numbers
        │  2. Flow type detection: keyword lists (paid/spent = expense, received = income,
        │     lent/gave = lend, split/shared = split, etc.)
        │  3. Category detection: keyword map (50+ merchant/keyword → category)
        │  4. Person extraction: regex r'(?:to|from|with|for) ([A-Z][a-z]+)'
        │  5. PayMode detection: cash/online keyword lists
        │  6. Confidence = sum of: amount(+0.5) + intent(+0.25) + category(+0.15) + paymode(+0.10)
        │
        └─ Returns ParsedIntent { flowType, amount, category, person, payMode, note, confidence }
```

---

### Category Auto-Detection

```dart
CategoryDetector.detect(title, isIncome: bool)
```

**Detection priority (highest to lowest):**

1. **Learned mappings** (SharedPreferences key `wallet_cat_learned`) — exact match first, then substring match.  When a user manually picks a different category than auto-detected, `CategoryDetector.learn(title, category)` is called and the mapping is persisted.

2. **Keyword lists** — two sets (isIncome: true / false), each with ~10 categories and 5–10 trigger keywords per category. Examples:

   | Keywords (expense) | Category |
   |---|---|
   | food, eat, lunch, dinner, swiggy, zomato, biryani | 🍕 Food |
   | petrol, uber, ola, metro, bus, toll, namma | 🚗 Travel |
   | amazon, flipkart, meesho, myntra | 🛒 Shopping |
   | medicine, doctor, hospital, pharmacy, tablet | 💊 Health |
   | netflix, prime, hotstar, game, concert | 🎬 Entertainment |
   | salary, paycheck, wage | 💼 Salary |

3. **Returns null** if no match → UI shows all categories for manual selection.

---

### SMS Parsing Integration

There are two approaches running simultaneously:

**Approach 1 — Automatic scan on app open (Android only):**

```
SMSParserService.initialize()         [called in app_bootstrap.dart — DISABLED pending Play Store approval]
        │
        ▼
scanNewMessages():
  - Reads inbox via flutter_sms_inbox
  - Filters: newer than last scan AND isBankSMS(sender, body)
  - isBankSMS: checks sender against 16 bank codes (hdfcbk, icicib, sbiinb...)
               OR body contains: debited/credited/debit/credit/INR/₹
  - Enforces 5-minute cooldown (SharedPrefs: sms_last_scanned_ms)
  - Tracks seen IDs (SharedPrefs: sms_seen_ids, max 200)
  - Surfaces MOST RECENT unseen bank SMS only
        │
        ├─ Shows local notification via flutter_local_notifications (wai_sms_channel)
        └─ Sets SMSParserService.pendingSmsBody (ValueNotifier<String?>)
                │
                ▼
        AppShell listens to pendingSmsBody:
          SMSRegexParser.tryParse(body) → quick preview in notification title
          User taps notification → SparkBottomSheet(autoPasteSms: true)
```

**Approach 2 — Manual paste in Spark:**

```
User taps "Paste bank SMS" in SparkBottomSheet
        │
        ▼
Clipboard.getData('text/plain') → raw SMS text
        │
        ▼
SMSParserService.parseSMSText(text):
  Layer 1: SMSRegexParser.tryParse(text)
  if isHighConfidence → return directly
  else → Layer 2: AIParser.parseText(feature:'wallet', subFeature:'sms_parse', text)
        │
        ▼
SMSTransaction → .toParsedIntent() → ParsedIntent
        │
        ▼
IntentConfirmSheet.show(context, intent, walletId, ...)
```

**Approach 2b — Import past SMS (SmsHistoryImportScreen):**

```
User taps "Import past transactions" in Spark
        │
        ▼
SmsHistoryImportScreen.show(context, walletId, onImported)
        │
        ▼
SMSParserService.scanHistory(from: DateTime, to: DateTime):
  - Reads inbox for date range
  - Filters bank SMS only
  - Parses with SMSRegexParser (regex only, no AI for bulk)
  - Returns List<SmsHistoryItem> sorted newest-first
        │
        ▼
User reviews list, selects transactions to import
Each selected item → WalletService.addTransaction(...)
```

---

### Family Notifications

Family notifications are **server-triggered** — the client does not send them. The Supabase DB trigger `notify_family_on_transaction()` fires on every `INSERT` to the `transactions` table:

```sql
-- Pseudocode of what the trigger does:
FOR EACH other_member IN wallet_members WHERE wallet_id = NEW.wallet_id AND user_id != NEW.user_id:
    INSERT INTO notifications (user_id, type, title, body, data)
    VALUES (
        other_member.user_id,
        'new_transaction',
        'New transaction in ' || wallet_name,
        added_by_name || ' added ₹' || amount || ' ' || type,
        json_build_object('wallet_id', NEW.wallet_id, 'tx_id', NEW.id)
    );
```

The trigger runs as `SECURITY DEFINER` so it can read `wallet_members` and write `notifications` tables even though the inserting user's RLS would normally restrict cross-user writes.

The Flutter FCM listener (`FcmService`) picks up the resulting push notification and can route the user to the relevant wallet tab via `FcmService.pendingTab`.

---

## Business Rules

### Personal vs Family Scope

- Every transaction has a `wallet_id` foreign key (TEXT — known schema issue: no FK constraint).
- **Personal wallet** = `wallets.is_personal = true`. Created once per user on sign-up. Owned by `owner_id = auth.uid()`.
- **Family wallet** = `wallets.is_personal = false`. Linked to a `family_id`. Any `wallet_members` member can read/write it via RLS.
- The active wallet is determined by `AppStateNotifier.activeWalletId`. Users can switch mid-session — every subsequent query uses the new `walletId`.
- Per-tab scope preference (`AppPrefs.walletScope`) lets users default each tab to personal or family independently.

### Split Calculation Logic

```dart
// Equal split
shareAmount = totalAmount / participants.length
// e.g. ₹900 ÷ 3 people = ₹300 each

// Custom (unequal) split
// Each participant's amount is entered manually; must sum to totalAmount

// Percentage split
// Each participant gets a percentage; percentages must sum to 100
// shareAmount = totalAmount * percentage / 100
```

- The participant who adds the expense (`addedByParticipantId`) has their own share automatically marked as `settled`.
- Other shares start as `pending`.
- Settlement flow: `pending` → `settled` (direct mark) or `pending` → extension requested → `extended` → `settled`.
- Outstanding balance per member = Σ(pending shares where they owe) − Σ(pending shares where others owe them).

### Lend / Borrow Tracking Logic

Lend and borrow are not linked at the DB level — they are just transaction types. The outstanding balance is computed client-side at the time of recording a "Returned Money" transaction:

```dart
// In ConversationFlow._validateReturnedPerson(name)
final lentTotal    = transactions.where(type == lend && person == name).sum(amount);
final borrowedTotal = transactions.where(type == borrow && person == name).sum(amount);
final returnedTotal = transactions.where(type == returned && person == name).sum(amount);
final outstanding  = lentTotal + borrowedTotal - returnedTotal;
// Outstanding ≤ 0 → reject (all settled)
```

This approach does not distinguish direction (who owes whom) — it treats both lend and borrow as contributing to the outstanding total. This is a known simplification.

### Duplicate Transaction Prevention

There is **no server-side duplicate detection**. The app prevents accidental duplicates through UX only:

- The Spark sheet is dismissed before showing IntentConfirmSheet — the user must actively tap "Save".
- The ConversationFlow's Save button is only shown on the final ConfirmStep.
- `WalletService.addTransaction` does not check for duplicates before inserting.
- SMS seen-ID tracking (`sms_seen_ids` in SharedPrefs) prevents the **same SMS** from being surfaced twice, but does not prevent saving the same amount twice from different paths.

### Category Persistence

When any category is used (default or custom):

```dart
WalletService.ensureCategory(name, txTypeName)
→ UPSERT into user_tx_categories(user_id, name, tx_type)
  onConflict: 'user_id,name,tx_type'
→ Also updates in-memory cache immediately
```

On first login, all default categories are seeded into `user_tx_categories`.

---

## Screens and Widgets

### `WalletScreen` — [lib/features/wallet/wallet_screen.dart](../lib/features/wallet/wallet_screen.dart)

**Purpose:** Root screen for the Wallet tab. Manages the inner `TabBar` (Wallet / Splits), loads all data, coordinates wallet switching.

**Props:** `walletId: String`, `wallets: List<WalletModel>`, `onWalletChange: void Function(String)`

**State it manages:**
- `_transactions: List<TxModel>` — all transactions for active wallet, newest-first
- `_groups: List<TxGroup>` — grouping buckets for transactions
- `_splitGroups: List<SplitGroup>` — split expense groups
- `_loading: bool`
- `_tab: TabController` (Wallet / Splits)
- `_realtimeChannel: RealtimeChannel?` — live Supabase subscription

**Key behaviours:**
- Calls `_loadAll()` when `walletId` changes (via `didUpdateWidget`)
- Subscribes to `WalletService.subscribeToTransactions(walletId)` for live updates
- Fires `WalletService.txChangeSignal.value++` after every save (DashboardScreen listens)

---

### `ConversationScreen` — [lib/features/wallet/conversation_screen.dart](../lib/features/wallet/conversation_screen.dart)

**Purpose:** Full-page wrapper for `ConversationFlow`. Shown when user selects a flow type from `FlowSelectorSheet` or taps "Full Flow" in `IntentConfirmSheet`.

**Contains:** `ConversationFlow` as its body

---

### `ConversationFlow` — [lib/features/wallet/conversation_flow.dart](../lib/features/wallet/conversation_flow.dart)

**Purpose:** The conversational multi-step transaction entry UI. Drives through `FlowStep` sequence for any `FlowType`.

**Props:**
```dart
final FlowType flowType;
final String walletId;
final List<WalletModel> wallets;
final List<TxModel> transactions;       // for "returned" flow validation
final void Function(TxModel tx) onComplete;
```

**State:**
- `_messages: List<_Message>` — chat bubble history (bot + user)
- `_data: FlowData` — collected answers across all steps
- `_steps: List<FlowStep>` — ordered steps for this flowType
- `_stepIdx: int` — current step index
- `_showTyping: bool` — typing indicator visibility
- `_done: bool` — shows SuccessStep at end
- `_autoDetectedCategory: String` — pre-fill for category step

---

### `SparkBottomSheet` — [lib/features/wallet/AI/SparkBottomSheet.dart](../lib/features/wallet/AI/SparkBottomSheet.dart)

**Purpose:** The AI assistant entry point. Accepts text, voice, or clipboard SMS.

**Props:**
```dart
final String walletId;
final void Function(TxModel tx) onSave;
final VoidCallback onOpenFlow;
final bool embedded;        // strips chrome for embedding inside another sheet
final bool autoPasteSms;    // auto-triggers _pasteSms() on first frame
```

**State:**
- `_controller: TextEditingController` — text input
- `_speech: SpeechToText` — voice recognition
- `_isListening / _isLoading / _isSmsLoading: bool`
- `_spokenText: String` — real-time STT result
- `_errorMsg: String?`

**Input modes:**

| Mode | Trigger | Parser used |
|---|---|---|
| Typed text | User types + taps send | `AIParser.parseText(feature:'wallet', subFeature:'expense')` |
| Voice | Tap microphone | STT → same as typed after speech complete |
| Paste SMS | Tap "Paste bank SMS" | `SMSParserService.parseSMSText()` → Regex + AI |
| Import history | Tap "Import past transactions" | `SmsHistoryImportScreen` |

---

### `IntentConfirmSheet` — [lib/features/wallet/AI/IntentConfirmSheet.dart](../lib/features/wallet/AI/IntentConfirmSheet.dart)

**Purpose:** Post-parse confirmation sheet. Shows what AI understood and lets user edit before saving.

**Props:**
```dart
final ParsedIntent intent;
final String walletId;
final void Function(TxModel tx) onSave;
final VoidCallback onOpenFlow;
final String? existingId;     // set for edit mode
```

**State:**
- `_flowType: FlowType` — changeable via chip grid picker
- `_amountCtrl, _titleCtrl, _noteCtrl, _personCtrl: TextEditingController`
- `_category: String?`
- `_payMode: PayMode?`
- `_date: DateTime`
- `_saving: bool`

**Save validation:**
1. `Supabase.auth.currentUser` must not be null
2. `walletId` must not be empty or `'personal'`
3. `amount` must parse to a positive double

---

### `FlowSelectorSheet` — [lib/features/wallet/flow_selector_sheet.dart](../lib/features/wallet/flow_selector_sheet.dart)

**Purpose:** Grid of FlowType cards shown when user wants to pick a specific transaction type manually.

---

### `SplitGroupSheet` — [lib/features/wallet/splits/split_group_sheet.dart](../lib/features/wallet/splits/split_group_sheet.dart)

**Purpose:** Create or edit a split group. Two inner tabs: Contacts (reads phone contacts via `FlutterContacts`) and Manual (type name + pick emoji avatar).

**Props:**
```dart
final SplitGroup? existing;   // null = create mode
final String walletId;
final void Function(SplitGroup) onSave;
final VoidCallback? onDelete;
```

**State:**
- `_nameCtrl: TextEditingController`
- `_emoji: String` — group photo emoji
- `_groupPhotoPath: String?` — local path if photo picked from gallery
- `_participants: List<SplitParticipant>` — accumulated participant list
- `_pinned: bool` — whether to pin to dashboard
- `_contacts: List<(name, emoji, phone)>?` — cached contacts

---

### `SplitGroupDetailScreen` — [lib/features/wallet/splits/split_group_detail_screen.dart](../lib/features/wallet/splits/split_group_detail_screen.dart)

**Purpose:** Full-page split group management. Three tabs.

**Props:**
```dart
final SplitGroup group;
final void Function(SplitGroup) onGroupUpdated;
final bool autoOpenAddExpense;
```

**State:**
- `_group: SplitGroup` — mutable local copy
- `_tab: TabController` (3 tabs)
- `_chatCtrl: TextEditingController`
- `_chatChannel: RealtimeChannel?` — live Supabase channel for messages
- `_chatLoading: bool`

**Tabs:**

| Index | Name | Content |
|---|---|---|
| 0 | Overview | Group stats, per-member balance, quick settle nudge |
| 1 | Expenses | `split_group_transactions` list with `split_shares` breakdown |
| 2 | Chat | Real-time message thread via Supabase Realtime |

---

### `WalletCardWidget` — [lib/features/wallet/widgets/wallet_card_widget.dart](../lib/features/wallet/widgets/wallet_card_widget.dart)

**Purpose:** Large gradient card at the top of WalletScreen showing balance breakdown (cash-in, cash-out, online-in, online-out).

---

### `TxTile` — [lib/features/wallet/widgets/tx_tile.dart](../lib/features/wallet/widgets/tx_tile.dart)

**Purpose:** Single transaction row. Shows type emoji, category, title, amount, date.

---

### `TxDetailSheet` — [lib/features/wallet/widgets/tx_detail_sheet.dart](../lib/features/wallet/widgets/tx_detail_sheet.dart)

**Purpose:** Bottom sheet shown on tap of a transaction. Full detail view with edit / delete / move-to-wallet / add-to-group actions.

**Props:**
```dart
final TxModel tx;
final bool isDark;
final List<WalletModel> otherWallets;
final void Function(TxModel) onEdit;
final VoidCallback onDelete;
final void Function(WalletModel) onMove;
final List<TxGroup> groups;
final void Function(TxGroup group)? onAddToGroup;
final VoidCallback? onRemoveFromGroup;
```

---

### `TxGroupCard` — [lib/features/wallet/widgets/tx_group_card.dart](../lib/features/wallet/widgets/tx_group_card.dart)

**Purpose:** Collapsible card for a named transaction group. Shows grouped transactions with a total.

---

### `WalletReportsSheet` — [lib/features/wallet/wallet_reports_sheet.dart](../lib/features/wallet/wallet_reports_sheet.dart)

**Purpose:** Monthly/date-range spending breakdown with category totals. Shown via sheet from WalletScreen.

---

### `MonthYearPicker` — [lib/features/wallet/widgets/month_year_picker.dart](../lib/features/wallet/widgets/month_year_picker.dart)

**Purpose:** Custom month + year picker used by WalletReportsSheet for selecting report period.

---

### `ChatBubble` — [lib/features/wallet/chat_bubble.dart](../lib/features/wallet/chat_bubble.dart)

**Purpose:** Single message bubble for ConversationFlow. Differentiates bot (left, colored) vs user (right, primary).

---

### `ChatInputBar` — [lib/features/wallet/widgets/chat_input_bar.dart](../lib/features/wallet/widgets/chat_input_bar.dart)

**Purpose:** Text input bar at the bottom of the conversation screen. Shows send button.

---

### Step Widgets — [lib/features/wallet/flow_steps.dart](../lib/features/wallet/flow_steps.dart)

All step widgets live in a single file:

| Widget | Purpose | Key behaviour |
|---|---|---|
| `AmountStep` | Custom numpad | 9-digit limit, supports decimals, haptic on tap |
| `ChipStep` | Scrollable chip selector | Used for category picker |
| `ToggleStep` | Large card toggle | Used for personal/family, cash/online, equal/custom |
| `DateStep` | Quick date chips | Today / Yesterday / 2 days ago / Pick date |
| `PersonStep` | Contact picker (single or multi) | Loads + caches `FlutterContacts`, search by name/phone |
| `NoteStep` | Multi-line text + Skip | Optional, always has Skip button |
| `TitleStep` | Single-line text | Required text before Next is enabled |
| `DueDateStep` | Quick due date chips | In 1 week / In 2 weeks / In 1 month / No due date |
| `ConfirmStep` | Summary card | Shows all `FlowData.summaryRows`, Save + Edit buttons |
| `SuccessStep` | Celebration card | Elastic-out scale animation, amount display, Add Another |
| `TypingIndicator` | Animated dots | Shown for 520ms before each bot question |

---

### SMS Screens

| Screen | Path | Purpose |
|---|---|---|
| `SmsHistoryImportScreen` | [lib/features/wallet/screens/sms_history_import_screen.dart](../lib/features/wallet/screens/sms_history_import_screen.dart) | Date-range SMS bulk import |
| `SmsPermissionScreen` | [lib/features/wallet/screens/sms_permission_screen.dart](../lib/features/wallet/screens/sms_permission_screen.dart) | Permission request UI for SMS access |

---

## Data Models

### `TxModel` — `wallet_models.dart`

```dart
class TxModel {
  final String id;
  final TxType type;
  final double amount;
  final String category;
  final DateTime date;
  final String walletId;
  final PayMode payMode;
  final String? title;
  final String? note;
  final String? person;           // single person (lend/borrow/request/returned)
  final List<String>? persons;   // multi-person (split)
  final String? status;          // 'pending' / 'settled' for lend/request
  final String? dueDate;
  final String? groupId;         // TxGroup.id if grouped

  factory TxModel.fromRow(Map<String, dynamic> row) { ... }
}
```

### `FlowData` — `flow_models.dart`

In-memory accumulator for a single flow session. Builds a `TxModel` at the confirm step via `toTxModel(flowType, walletId)`. The resulting TxModel has a timestamp-based `id` (not a UUID) until it is persisted by `WalletService.addTransaction`.

### `ParsedIntent` — `AI/nlp_parser.dart`

```dart
class ParsedIntent {
  final FlowType flowType;
  final double? amount;
  final String? category;
  final String? title;
  final String? person;
  final PayMode? payMode;
  final String? note;
  final DateTime? date;
  final double confidence;   // 0.0–1.0
}
```

### `SMSTransaction` — `models/sms_transaction.dart`

```dart
class SMSTransaction {
  final bool isTransaction;
  final String transactionType;   // 'debit' | 'credit'
  final double amount;
  final String? merchant;
  final String? title;
  final String? accountLast4;
  final String? bankName;
  final String transactionDate;   // ISO date string YYYY-MM-DD
  final String? category;
  final String? paymentMode;
  final double confidence;
  
  bool get isExpense => transactionType == 'debit';
  bool get isHighConfidence => confidence >= 0.80;
  ParsedIntent toParsedIntent() { ... }
}
```

### `SplitGroup` — `data/models/wallet/split_group_models.dart`

```dart
class SplitGroup {
  final String id;
  final String walletId;
  final String name;
  final String emoji;
  final bool pinnedToDashboard;
  final List<SplitParticipant> participants;
  final List<SplitGroupTransaction> transactions;
  final List<ChatMessage> messages;
}

class SplitParticipant {
  final String id;
  final String name;
  final String emoji;
  final String? phone;
  final bool isMe;
  final String? userId;
}

class SplitGroupTransaction {
  final String id;
  final String title;
  final double totalAmount;
  final String splitType;   // 'equal' | 'unequal' | 'percentage' | 'custom'
  final String addedById;
  final List<SplitShare> shares;
}

class SplitShare {
  final String id;
  final String participantId;
  final double amount;
  final double? percentage;
  final String status;   // 'pending' | 'settled' | 'extended'
  final String? proofNote;
  final String? proofImagePath;
  final DateTime? proofDate;
  final int reminderCount;
}
```

---

## Service Methods — `WalletService`

File: [lib/data/services/wallet_service.dart](../lib/data/services/wallet_service.dart)

> All methods throw `PostgrestException` on failure. Callers must catch.

### Category Methods

| Method | Parameters | Returns | Tables |
|---|---|---|---|
| `loadCategories()` | — | `Future<void>` | `user_tx_categories` |
| `categoriesFor(txType)` | `String txType` | `List<String>` | in-memory cache |
| `ensureCategory(name, txTypeName)` | `String name, String txTypeName` | `Future<void>` | `user_tx_categories` UPSERT |

### Wallet Methods

| Method | Parameters | Returns | Tables |
|---|---|---|---|
| `fetchWallets()` | — | `Future<List<Map>>` | `wallets` SELECT |
| `createPersonalWallet({name, emoji})` | optional name+emoji | `Future<Map>` | `wallets` INSERT |
| `createFamilyWallet({familyId, name, emoji, gradientIndex})` | required familyId | `Future<Map>` | `wallets` INSERT |

### Family Methods

| Method | Parameters | Returns | Tables |
|---|---|---|---|
| `fetchFamilies()` | — | `Future<List<Map>>` | `families` + `family_members` |
| `createFamily({name, emoji, colorIndex})` | — | `Future<Map>` | `families` INSERT + `family_members` INSERT (creator as admin) + `profiles` SELECT |
| `addFamilyMember({familyId, name, emoji, role, relation, phone, userId})` | — | `Future<void>` | `family_members` INSERT |

### Transaction Methods

| Method | Parameters | Returns | Tables |
|---|---|---|---|
| `fetchTransactions(walletId)` | `String walletId` | `Future<List<Map>>` | `transactions` WHERE wallet_id, deleted_at IS NULL, ORDER date DESC |
| `addTransaction({walletId, type, amount, category, payMode, title, note, person, persons, status, dueDate, date, groupId})` | required: walletId, type, amount, category | `Future<Map>` | `transactions` INSERT → triggers: `sync_wallet_balance`, `notify_family_on_transaction` |
| `deleteTransaction(txId)` | `String txId` | `Future<void>` | `transactions` DELETE → triggers: `sync_wallet_balance` |
| `updateTransaction(txId, updates)` | `String txId, Map<String,dynamic> updates` | `Future<void>` | `transactions` UPDATE |

### Transaction Group Methods

| Method | Parameters | Returns | Tables |
|---|---|---|---|
| `fetchTxGroups(walletId)` | `String walletId` | `Future<List<Map>>` | `tx_groups` SELECT |
| `createTxGroup({walletId, name, emoji})` | required walletId, name | `Future<Map>` | `tx_groups` INSERT |
| `updateTxGroup(groupId, {name, emoji})` | `String groupId` | `Future<void>` | `tx_groups` UPDATE |
| `deleteTxGroup(groupId)` | `String groupId` | `Future<void>` | `tx_groups` DELETE (member transactions: group_id SET NULL) |
| `setTxGroup(txId, groupId)` | `String txId, String? groupId` | `Future<void>` | `transactions` UPDATE group_id (null = ungroup) |

### Split Group Methods

| Method | Parameters | Returns | Tables |
|---|---|---|---|
| `fetchSplitGroups(walletId)` | `String walletId` | `Future<List<Map>>` | `split_groups` + `split_participants` + `split_group_transactions` + `split_shares` |
| `fetchPinnedSplitGroups()` | — | `Future<List<SplitGroup>>` | same + filter pinned_to_dashboard=true |
| `createSplitGroup({walletId, name, emoji, participants})` | required all | `Future<Map>` | `split_groups` INSERT + `split_participants` batch INSERT |
| `updateSplitGroup(groupId, {name, emoji, pinned})` | required groupId | `Future<void>` | `split_groups` UPDATE |
| `updateSplitGroupPin(groupId, {pinned})` | required both | `Future<void>` | `split_groups` UPDATE |
| `addSplitTransaction({groupId, addedByParticipantId, title, totalAmount, splitType, shares, note, date})` | required all | `Future<Map>` | `split_group_transactions` INSERT + `split_shares` batch INSERT |
| `updateShareStatus({shareId, status, proofNote, proofImagePath, proofDate, extensionDate, extensionReason, ...})` | required shareId or (txId + participantId) | `Future<void>` | `split_shares` UPDATE |
| `uploadProofImage({groupId, imageBytes, extension})` | required groupId, imageBytes | `Future<String>` | Supabase Storage `split-proof` bucket |
| `recordReminderSent({transactionId, participantId, sentBy})` | required all | `Future<void>` | RPC `increment_split_reminder` |

### Chat Methods

| Method | Parameters | Returns | Tables |
|---|---|---|---|
| `fetchMessages(groupId)` | `String groupId` | `Future<List<Map>>` | `split_group_messages` ORDER created_at ASC |
| `postMessage({groupId, senderId, senderName, senderEmoji, text, type})` | required all | `Future<Map>` | `split_group_messages` INSERT |

### Bill Methods

| Method | Parameters | Returns | Tables |
|---|---|---|---|
| `fetchBills(walletId)` | `String walletId` | `Future<List<Map>>` | `bills` ORDER due_date |
| `addBill({walletId, name, category, amount, dueDate, repeat, provider, accountNumber, note})` | required: walletId, name, category, amount, dueDate, repeat | `Future<Map>` | `bills` INSERT |
| `updateBill(billId, updates)` | `String billId, Map` | `Future<void>` | `bills` UPDATE |
| `deleteBill(billId)` | `String billId` | `Future<void>` | `bills` DELETE |

### Realtime Subscriptions

```dart
// Subscribe to live transaction changes for a wallet
RealtimeChannel subscribeToTransactions(
  String walletId,
  void Function(Map<String, dynamic> payload) onEvent,
)
// Channel key: 'transactions:{walletId}'
// Filter: wallet_id = walletId (all events: INSERT / UPDATE / DELETE)

// Subscribe to live chat messages in a split group
RealtimeChannel subscribeToMessages(
  String groupId,
  void Function(Map<String, dynamic> msg) onMessage,
)
// Channel key: 'messages:{groupId}'
// Filter: group_id = groupId (INSERT only)
```

### Static Signals

```dart
// Fires whenever a transaction is added, updated, or deleted.
// Value is an incrementing counter — listeners just react to any change.
static final txChangeSignal = ValueNotifier<int>(0);
```

DashboardScreen subscribes to `WalletService.txChangeSignal` to refresh its transaction summary card without needing to know which specific transaction changed.

---

## AIParser Service — `lib/core/services/ai_parser.dart`

Thin wrapper around the Supabase Edge Function `parse`. Stateless — all methods are static.

```dart
// For text input (natural language / SMS)
static Future<AIParseResult> parseText({
  required String feature,      // e.g. 'wallet'
  required String subFeature,   // e.g. 'expense', 'sms_parse'
  required String text,
  Map<String, dynamic>? context,
})

// For image input (receipt scan, pantry scan)
static Future<AIParseResult> parseImage({
  required String feature,
  required String subFeature,
  required List<int> imageBytes,
  String mimeType = 'image/jpeg',
  Map<String, dynamic>? context,
})
```

**Context injected automatically:**

```dart
{
  'today': '2026-04-27',          // ISO date
  'day_of_week': 'Sunday',
  'current_month': 'April',
  'currency': 'INR',
  ...?extra,                       // caller-supplied extras
}
```

**Response:**

```dart
class AIParseResult {
  final bool success;
  final Map<String, dynamic>? data;   // parsed fields
  final double? confidence;           // 0.0–1.0
  final bool needsReview;
  final String? error;
  final Map<String, dynamic>? meta;
}
```

The edge function returns different `data` shapes per `feature/subFeature`:

| feature | subFeature | data keys |
|---|---|---|
| wallet | expense | type, amount, category, person, payment_mode, title, note, confidence |
| wallet | sms_parse | is_transaction, transaction_type, amount, merchant, category, payment_mode, account_last4, bank_name, transaction_date, confidence |

---

## Known Issues / Gaps

| Issue | Impact | Location |
|---|---|---|
| `wallet_id` is TEXT not UUID FK in several tables | No referential integrity — orphan rows possible if wallet deleted | `transactions`, `tx_groups`, `split_groups` schema |
| No server-side duplicate prevention | Users can save the same amount twice | `WalletService.addTransaction` |
| SMS scan disabled pending Play Store approval | Approach 1 (auto-scan) is commented out in bootstrap | `app_bootstrap.dart`, `SMSParserService.initialize()` |
| `handleAiIntent.dart` is a stub | `AiIntentType` cases are all commented out — function does nothing | `lib/features/wallet/AI/handleAiIntent.dart` |
| `SplitSparkBottomSheet` is not integrated | The class exists and was the V0 split NLP approach but is not shown anywhere in V1 | `lib/features/wallet/AI/SplitSparkBottomSheet.dart` |
| Lend/borrow outstanding calculation ignores direction | `returned` is counted against both lend+borrow total — mixing personal loans with family debts | `ConversationFlow._validateReturnedPerson` |
| `WalletTab.billWatch` is hidden | Bill Watch tab exists in enum and service but not shown in nav | `wallet_models.dart`, `wallet_screen.dart` |
| `NlpParser` is not used for AI path | It exists and is accurate for simple cases but `AIParser` (Gemini) is called instead — the local parser is a dead code path in the current Spark flow | `AI/nlp_parser.dart` |
