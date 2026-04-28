# WAI Life Assistant — Technical Documentation
### Section 3c: PlanIt Tab

---

## 3c.1 PlanIt Screen Architecture

**File:** `lib/features/planit/planit_screen.dart`

`PlanItScreen` is a stateful widget that acts as a hub for all planning modules. It renders a scrollable list of module cards — each card shows a summary preview and a quick-add button.

### Module Roster

```
_kV1Modules = {Functions, SpecialDays, AlertMe, MyTasks, WishList, Notes}
_kV2Modules = {TravelBoard, PlanParty, MySchedule, HealthVault}  ← hidden
```

V2 modules are defined but excluded from `_kV1Modules`, so they are never rendered.

### Personal vs Family View

The `PlanItScreen` receives `walletId` from `AppShell`. The **key design decision** is:

- **Personal view:** loads data from `[personalWalletId, ...allFamilyWalletIds]` simultaneously — all modules show merged personal + family data.
- **Family wallet view:** loads only that wallet's data.

**Redundant-fetch prevention:**

```dart
String _loadedKey = '';
// Computed from active wallet IDs:
_loadedKey = walletIds.join('|');
// Load only when key changes.
```

### Family Badge Logic

```dart
// Passed to each module screen:
Map<String, String> _familyWalletNames  // walletId → label, EMPTY when in family wallet view
Map<String, String> _allFamilyWalletNames  // always populated — used by edit sheets ("Move to Group")
String _personalWalletId  // always set — used by edit sheets ("Move to Personal")
```

When `familyWalletNames` is non-empty, items from family wallets display a `FamilyBadge` and are **read-only** (no edit, delete, or action buttons).

### Module Card Layout

Each module card is full-width with:
- Left colored bar (module-specific color)
- Icon + title
- Count badge (number of records in that module)
- 2-line preview summary (e.g. upcoming reminders, task titles)
- Quick-add FAB button

### Navigation Transition

```dart
Navigator.push(
  context,
  PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (ctx, anim, _, child) =>
      FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.05), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
  ),
);
```

Quick-add passes `openAdd: true`. Functions also passes `initialTab: 2` (Attended tab, since quick-add from the PlanIt hub means logging an attended function).

---

## 3c.2 Alert Me (Reminders)

**File:** `lib/features/planit/modules/alert_me/alert_me_screen.dart`

### Data Model — `ReminderModel`

| Field | Type | Description |
|---|---|---|
| `id` | `String` | DB primary key |
| `walletId` | `String` | Scope |
| `title` | `String` | Reminder text |
| `emoji` | `String` | Display icon |
| `dueDate` | `DateTime` | Date component |
| `dueTime` | `TimeOfDay` | Time component |
| `repeat` | `RepeatMode` | none / daily / weekly / monthly / yearly |
| `priority` | `Priority` | low / medium / high / urgent |
| `assignedTo` | `String` | Member ID |
| `snoozed` | `bool` | Whether currently snoozed |
| `done` | `bool` | Completion flag |
| `note` | `String?` | Optional extra text |

**DB columns:** `due_date` (YYYY-MM-DD), `due_time` (HH:MM), `repeat` (enum `.name`), `priority` (enum `.name`), `assigned_to`, `snoozed`, `done`.

### Two-Tab Display

```
Upcoming  |  Done
```

- **Upcoming** = `!done && !_isPast`
- **Done** = `done == true`
- **Overdue** = `!done && _isPast` — shown in Upcoming tab with red/orange tint

`_isPast` logic: combines `dueDate` + `dueTime` into a full `DateTime` and compares to `DateTime.now()`.

### Snooze

Snooze adds exactly **10 minutes** to the current due datetime, updates the DB record, and reschedules the local notification via `NotificationService.instance.schedule(r)`.

### Notification Lifecycle

```
_loadReminders()
  └─ NotificationService.instance.rescheduleAll(loaded)
       // cancels all old alarms, schedules all active ones

onAdd(reminder)
  └─ NotificationService.instance.schedule(r)

onUpdate(reminder)
  └─ NotificationService.instance.schedule(r)

onDelete(reminder)
  └─ NotificationService.instance.cancel(r)

onSnooze(reminder)
  └─ mutate dueDate/dueTime + 10 min
     → NotificationService.instance.schedule(r)
```

### Family Items

Family wallet reminders appear in the list with a `FamilyBadge`. They have no done/snooze/delete actions. The `SwipeTile` wrapper (swipe-to-delete) is only applied to own items.

### Add/Edit Sheet — Two Tabs

| Tab | Description |
|---|---|
| ✨ AI Parse | Free-text entry → Claude AI parses intent |
| Manual | Full form: title, emoji, date, time, priority, repeat, assign to, note |

Edit mode always opens on the Manual tab.

### AI Parse Flow

```
User types free text
  │
  ▼
_ClaudeParser.parse(text)
  │
  ├─ AIParser.parseText(feature:'planit', subFeature:'reminder')
  │      → success: returns _ParsedReminder
  │
  └─ FAIL → _NlpParser.parse(text)  [local fallback]
              → returns _ParsedReminder
```

**Claude AI response fields:**

| Field | Type | Notes |
|---|---|---|
| `title` | `String` | Cleaned reminder title |
| `emoji` | `String` | Suggested emoji |
| `date` | `String` | ISO date string |
| `time` | `String` | `HH:MM` format |
| `priority` | `String` | `low` / `medium` / `high` / `urgent` |
| `repeat` | `String` | `none` / `daily` / `weekly` / `monthly` / `yearly` |
| `assigned_to` | `String` | Member ID |
| `note` | `String?` | Extra note |

### Local NLP Parser (`_NlpParser`)

Fallback when Claude AI is unavailable.

**Date patterns:**
- `today`, `tomorrow`, `day after tomorrow`
- `next week` (+7 days), `next month` (+30 days)
- `in N days`, `in N weeks`, `on [the] Nth`
- Weekday names: `monday` → `tuesday` → ... → `sunday`

**Time patterns:**
- `HH:MM am/pm`
- Named times: `morning`=9:00, `afternoon`=14:00, `evening`=18:00, `night`=21:00, `noon`/`lunch`=12:00

**Priority keywords:**
- `urgent` / `asap` → urgent
- `high` / `important` → high
- `low` / `someday` → low
- Default: medium

**Repeat patterns:**
- `daily` / `every day` → daily
- `weekly` / `every week` / `every [mon-sun]` → weekly
- `monthly` / `every month` → monthly
- `yearly` / `every year` / `annually` → yearly

**Emoji inference (12 categories):**

| Keywords | Emoji |
|---|---|
| bill / electricity / payment | 💡 |
| doctor / hospital | 🏥 |
| medicine / pill | 💊 |
| car / vehicle / insurance | 🚗 |
| birthday / anniversary | 🎂 |
| school / class / study | 📚 |
| meeting / appointment | 📅 |
| call / phone | 📞 |
| dentist | 🦷 |
| gym / workout | 🏋️ |
| travel / flight / trip | ✈️ |
| shopping / grocery | 🛒 |

**Title cleaning:** strips "remind me to", "don't forget to", "please", "set a reminder", "alert me about", then removes extracted date/time/priority/repeat words.

### Emoji Palette

25 emojis available in the manual form:
`🔔 ⏰ 📅 💊 🏥 💉 🦷 💼 📞 🎂 🚗 ✈️ 🎓 📚 🏋️ 🛒 💰 🧾 🏦 ⚠️ 🏠 👨‍👩‍👧 🌡️ 💸 🗓️`

### Example Prompts

- "Pay electricity bill on the 5th at 10am, monthly"
- "Doctor appointment tomorrow at 11:30, high priority"
- "Mom's medicine refill every Friday evening"
- "Car insurance renewal in 2 weeks, urgent"
- "Remind me to call school every Monday morning"

---

## 3c.3 My Tasks

**File:** `lib/features/planit/modules/my_tasks/my_tasks_screen.dart`

### Data Model — `TaskModel`

| Field | Type | Description |
|---|---|---|
| `id` | `String` | DB primary key |
| `title` | `String` | Task name |
| `description` | `String?` | Optional description |
| `emoji` | `String` | Display icon (default ✅) |
| `status` | `TaskStatus` | `todo` / `inProgress` / `done` |
| `priority` | `Priority` | `low` / `medium` / `high` / `urgent` |
| `dueDate` | `DateTime?` | Optional deadline |
| `project` | `String?` | Project bucket |
| `tags` | `List<String>` | Tag labels |
| `assignedTo` | `String` | Member ID (default `'me'`) |
| `walletId` | `String` | Scope |
| `subtasks` | `List<SubTask>` | Checklist items |
| `createdAt` | `DateTime` | Creation timestamp |

**`SubTask`:** `{id, title, done}` — stored as JSONB array in `subtasks` column.

### Status Colors

| Status | Color | Hex |
|---|---|---|
| `todo` | Purple | `#6C63FF` |
| `inProgress` | Orange | `#FFAA2C` |
| `done` | Green | `#00C897` |

### Priority Colors

| Priority | Color | Hex |
|---|---|---|
| `low` | Green | `#00C897` |
| `medium` | Blue | `#4A9EFF` |
| `high` | Orange | `#FFAA2C` |
| `urgent` | Red-pink | `#FF5C7A` |

### 3-Tab Kanban

```
To Do  |  Doing  |  Done
```

Counts shown in each tab header. Tasks are filtered by `TaskStatus` value.

**Project filter:** Horizontal scrollable chip row appears above tabs when any tasks have a `project` assigned. Selecting a project chip filters all three columns simultaneously.

### Task Card

- Status icon (tappable to cycle: todo → inProgress → done → todo)
- Title (strikethrough when done)
- Priority badge, family badge (if family item), due date badge
- Subtask progress bar (`doneCount / total`) + count display
- `SwipeTile` wrapper for swipe-to-delete (own items only)

### Subtask Handling

Toggling a subtask in the detail sheet:
1. Mutates the in-memory `SubTask.done` flag
2. Calls `_toggleSubtask(SubTask)` which persists the **full subtask array** to the DB

```dart
void _toggleSubtask(SubTask st) {
  st.done = !st.done;
  TaskService.instance.updateTask(st.taskId, {
    'subtasks': task.subtasks.map((s) => s.toJson()).toList(),
  });
}
```

### Due Date Display

Two helper functions used on cards:
- `daysUntil(date)` → "Today", "Tomorrow", "In N days", "N days ago"
- `daysUntilColor(date)` → green if future, orange if ≤3 days, red if past

### Add/Edit Sheet

Two-tab modal: ✨ AI Parse | ✏️ Manual

Edit mode opens on Manual tab with pre-filled values.

**AI parse:** `AIParser.parseText(feature:'planit', subFeature:'task')`

**Claude AI response fields:** `{title, description?, emoji, priority, dueDate (ISO string), project?, subtasks (List<String>), assignedTo}`

**Local NLP fallback:** `_TaskNlpParser.parse(text, walletId)` — basic keyword extraction.

**Example prompt hint:** `"Build landing page by Friday, high priority, subtasks: design, code, deploy"`

**Available task emojis:** `✅ 📊 🎯 🔧 🎒 🚀 💡 📝 🏃 🎨 💼 🏠 🛒 📞 🏥 📚 ✈️ 🎉 🔑 💰`

### Detail Sheet

Tapping a task card opens a bottom sheet showing:
- Full title, description, priority badge
- Project chip, due date badge
- Subtask checklist with animated completion
- Progress bar (done / total subtasks)
- "Edit Task" button → opens edit sheet
- Status change buttons (→ Doing, → Done; excludes current status)
- Delete button

---

## 3c.4 Special Days

**File:** `lib/features/planit/modules/special_days/special_days_screen.dart`

### Data Model — `SpecialDayModel`

| Field | Type | Default |
|---|---|---|
| `id` | `String` | — |
| `walletId` | `String` | — |
| `title` | `String` | — |
| `emoji` | `String` | — |
| `type` | `SpecialDayType` | — |
| `date` | `DateTime` | — (month + day only meaningful) |
| `yearlyRecur` | `bool` | `true` |
| `members` | `List<String>` | Member IDs |
| `note` | `String?` | — |
| `alertDaysBefore` | `int` | `1` |

### `SpecialDayType` Enum

| Type | Emoji | Color |
|---|---|---|
| `birthday` | 🎂 | `#FF5C7A` |
| `anniversary` | 💍 | `#FFAA2C` |
| `festival` | 🎉 | `#6C63FF` |
| `govtHoliday` | 🏛️ | `#1A8FE3` |
| `holiday` | 🌟 | `#00C897` |
| `custom` | 📅 | `#4A9EFF` |

### Two-Tab Display

```
Upcoming (N)  |  Past (N)
```

**Upcoming:** yearly-recur events always appear (next occurrence may be next year); one-off events appear only if this year's date hasn't passed.

**Past:** all events whose current-year date has already passed.

Both lists are sorted by `_nextOccurrence(date)`.

### Countdown Logic

```dart
DateTime _nextOccurrence(DateTime date) {
  final ty = DateTime(now.year, date.month, date.day);
  return ty.isBefore(today)
      ? DateTime(now.year + 1, date.month, date.day)
      : ty;
}
```

**Countdown display colors:**
- 🎉 Today! → green (`AppColors.income`)
- ≤7 days → orange (`AppColors.expense`)
- 8–30 days → yellow (`AppColors.lend`)
- >30 days → "N months away" → subtitle color

### Type Filter Chips

Horizontal chip row above the tab bar. Selecting a type filters both Upcoming and Past tabs. "All" chip resets filter.

### Day Card Layout

- Left color strip (type color)
- Date badge: mini calendar tile showing month abbreviation + day number (avoids 📅 emoji rendering as July 17)
- Title, type label chip, date string
- Family badge (if from a family wallet)
- Note preview (1 line)
- Countdown label + alert days badge

### Region Presets

The add sheet offers an "Add from Region Presets" flow with 8 country presets + universal holidays.

**India preset:**
- 5 Govt Holidays: Republic Day (Jan 26), Independence Day (Aug 15), Gandhi Jayanti (Oct 2), Ambedkar Jayanti (Apr 14), Christmas (Dec 25)
- 16 Festivals: Diwali, Holi, Eid ul-Fitr, Navratri, Dussehra, Raksha Bandhan, Janmashtami, Ganesh Chaturthi, Pongal, Onam, Baisakhi, Guru Nanak Jayanti, Mahavir Jayanti, Buddha Purnima, Christmas, New Year

Other presets: US (11 govt + 7 festivals), UK (8 + 6), Australia, Germany, Japan, UAE, Singapore.

**Universal preset:** New Year (Jan 1), Valentine's Day (Feb 14), Women's Day (Mar 8), Earth Day (Apr 22), Halloween (Oct 31), Christmas (Dec 25), New Year's Eve (Dec 31), Black Friday (Nov, varies).

### Connection to PlanIt Hub Summary

`PlanItScreen` shows Special Days within **90 days** of today sorted by next occurrence. The module badge count shows events within **30 days** absolute.

### AI Parse

`AIParser.parseText(feature:'planit', subFeature:'special_day')` — extracts `{title, emoji, type, date (ISO), yearlyRecur, note, alertDaysBefore}`.

Local NLP fallback: keyword-based type detection (birthday/anniversary/festival/holiday keywords).

---

## 3c.5 Sticky Notes

**File:** `lib/features/planit/modules/notes/notes_screen.dart`

### Data Model — `NoteModel`

| Field | Type | Default |
|---|---|---|
| `id` | `String` | — |
| `walletId` | `String` | — |
| `title` | `String` | `''` |
| `content` | `String` | `''` |
| `color` | `NoteColor` | `yellow` |
| `type` | `NoteType` | `text` |
| `isPinned` | `bool` | `false` |
| `createdAt` | `DateTime` | — |
| `updatedAt` | `DateTime` | — |

**DB columns:** `wallet_id`, `title`, `content`, `color` (name string), `note_type` (name string), `is_pinned`.

### Four Note Types

| Type | Icon | Content Hint | Rendering |
|---|---|---|---|
| `text` | `text_fields` | "Write your note here..." | Plain text, up to 8 lines |
| `list` | `checklist` | "One item per line..." | Bulleted preview (up to 5 items) |
| `link` | `link` | "Paste a URL here..." | Plain text with URL keyboard |
| `secret` | `lock_outline` | "Your secret content..." | `••••••••••••` in card preview; `obscureText: true` in editor |

**Secret type note:** The content field uses `obscureText: true` when `!_secretVisible`. A visibility toggle button appears in the field corner. The card preview always shows `🔒 ••••••••••••` — content is never exposed in the list view.

### Eight Color Options

| Color | Light BG | Dark BG | Accent |
|---|---|---|---|
| `yellow` | `#FFF9C4` | `#3D3000` | `#F9A825` |
| `pink` | `#FFE4EC` | `#3D0019` | `#E91E8C` |
| `blue` | `#DCEEFF` | `#002040` | `#1565C0` |
| `green` | `#D6F5E3` | `#002210` | `#2E7D32` |
| `purple` | `#EBDCFF` | `#200035` | `#6A1B9A` |
| `orange` | `#FFE6CC` | `#3D1500` | `#E65100` |
| `mint` | `#CCF5EE` | `#00302A` | `#00796B` |
| `white` | `#FFFFFF` | `#232323` | `#607D8B` |

### Pin Behavior

- Pinned notes appear in a "📌 Pinned" section above the "🗒️ Notes" section.
- Toggle pin: long-press → context menu → Pin/Unpin.
- Immediately updates DB with `{'is_pinned': !isPinned}`.
- **No explicit pin limit** in the current implementation (the summary mentioned max 3 in context but the code does not enforce this).

### Grid Layout

2-column `SliverGrid`, aspect ratio 0.85. Each card shows:
- Type icon + pin icon + relative timestamp + color dot (top row)
- Family badge (if from family wallet)
- Title (bold, 2 lines max)
- Content preview (type-dependent rendering, see table above)

### Family Notes

Family wallet notes appear in Personal view with a `FamilyBadge`. They are **read-only** — tapping does nothing (`onTap: () {}`), long-press does nothing. Only personal notes open the edit sheet or context menu.

### Context Menu (Long-Press)

- **Edit** → opens `_NoteSheet` in edit mode
- **Pin / Unpin** → toggles `isPinned`
- **Delete** → removes from list + DB

### Add/Edit Sheet — Two Tabs

| Tab | Description |
|---|---|
| ✨ AI Parse | Free-text → Claude AI or NLP parser |
| ✏️ Manual | Type selector, title, content, color picker, pin toggle |

- New note: opens on AI Parse tab.
- Edit mode: opens on Manual tab with pre-filled values.
- Sheet background color matches the selected `NoteColor`.

### AI Parse Flow

```
User types free text
  │
  ▼
AIParser.parseText(feature:'planit', subFeature:'note')
  │
  ├─ success → _ParsedNote from AI {title, content, color, note_type, is_pinned}
  │
  └─ FAIL → _NoteNlpParser.parse(text, walletId)
```

**Local NLP (`_NoteNlpParser`) rules:**

| Trigger | Result |
|---|---|
| `http://`, `https://`, `www.` | `NoteType.link` + blue color |
| `password`, `secret`, ` pin `, `credential` | `NoteType.secret` + purple color |
| Multi-line text with `- ` / `* ` / numbered list | `NoteType.list` + green color |
| First line < 60 chars + multi-line | First line → title, rest → content |
| `important`, `pin this`, `don't forget` | `isPinned = true` |
| Default | `NoteType.text` + yellow color |

### AI Parse Example Prompts

- `"Team meeting today — action items: update landing page, call vendor, send report"` → list note
- `"Groceries: milk, eggs, bread, tomatoes, onions, coriander"` → list note
- `"https://github.com/flutter/flutter — good reference for animations"` → link note
- `"Password for bank account login PIN important"` → secret note (pinned)

### Search

Full-text search across `title` and `content`. Clear button appears when search is active.

---

## 3c.6 Functions Tracker

**Files:**
- `lib/features/lifestyle/modules/my_functions/my_functions_screen.dart`
- `lib/data/models/lifestyle/lifestyle_models.dart`

### Concept: MOI (Indian Monetary Gift Obligation System)

**MOI** (Moi / Madurai-style gift exchange) is a traditional South Indian practice where guests give cash at family functions. Each entry creates a **social obligation** — when you attend a guest's future function, you are expected to return approximately the same amount.

The WAI app tracks this cycle:

```
Family holds a function (e.g. wedding)
  │
  ▼
Guests give cash/gold/gifts → recorded as GiftEntry or MoiEntry
  │
  ▼
Each MoiEntry tracks:
  - amount received
  - kind: newMoi (fresh gift) | returnMoi (returning what they gave us)
  - returned: bool — have we returned this?
  - returnedAmount, returnedOn, returnedForFunction
  │
  ▼
When attending their function:
  - Create AttendedFunction record + gift given (PlannedGiftItem)
  - Mark original MoiEntry.returned = true
  │
  ▼
Net obligation = totalMoiReceived - totalMoiReturned
```

### FunctionModel

| Field | Type | Description |
|---|---|---|
| `id` | `String` | DB primary key |
| `walletId` | `String` | Scope |
| `type` | `FunctionType` | Function category |
| `title` | `String` | Function name |
| `whoFunction` | `String` | Who is the function for |
| `customType` | `String?` | Custom label if type = other |
| `functionDate` | `DateTime?` | Date of event |
| `venue` | `String?` | Location |
| `address` | `String?` | Full address |
| `notes` | `String?` | Extra notes |
| `isPlanned` | `bool` | true = upcoming/in-planning, false = completed |
| `icon` | `String` | Emoji or image path |
| `gifts` | `List<GiftEntry>` | Received physical gifts |
| `moi` | `List<MoiEntry>` | Monetary gift entries |
| `vendors` | `List<FunctionVendor>` | Service providers |
| `chat` | `List<FunctionChatMessage>` | Internal chat messages |
| `memberIds` | `List<String>` | Participating family member IDs |

**Computed properties:**

```dart
double get totalCash => moi.fold(0.0, (s, m) => s + m.amount);
double get totalGold => gifts.where((g) => g.giftType == GiftType.gold).fold(0, (s, g) => s + (g.goldGrams ?? 0));
double get totalMoiReceived => moi.fold(0.0, (s, m) => s + m.amount);
double get totalMoiReturned => moi.where((m) => m.returned).fold(0.0, (s, m) => s + (m.returnedAmount ?? m.amount));
int get moiPending => moi.where((m) => !m.returned).length;
```

### FunctionType Enum (10 types)

| Type | Emoji | Label |
|---|---|---|
| `wedding` | 💒 | Wedding |
| `naming` | 👶 | Naming Ceremony |
| `earPiercing` | 👂 | Ear Piercing |
| `engagement` | 💍 | Engagement |
| `houseWarming` | 🏠 | Housewarming |
| `birthday` | 🎂 | Birthday |
| `anniversary` | 💑 | Anniversary |
| `graduation` | 🎓 | Graduation |
| `puberty` | 🌸 | Puberty Ceremony |
| `other` | 🎊 | Others (+ `customType` field) |

### GiftType Enum (7 types)

| Type | Emoji | Label |
|---|---|---|
| `gold` | 🥇 | Gold (tracked in grams) |
| `silver` | 🥈 | Silver (tracked in grams) |
| `household` | 🏠 | Household item |
| `clothing` | 👗 | Clothing |
| `giftItem` | 🎁 | General gift |
| `giftCard` | 🎴 | Gift card (value field) |
| `other` | ✨ | Others |

**GiftEntry.summary computed:**

```dart
String get summary {
  // gold: "Xg Gold"
  // silver: "Xg Silver"
  // giftCard: "₹X Card"
  // others: itemDescription ?? giftType.label
}
```

### MoiEntry

| Field | Type | Description |
|---|---|---|
| `id` | `String` | — |
| `personName` | `String` | Guest name |
| `familyName` | `String?` | Family/household name |
| `place` | `String?` | Guest's hometown |
| `phone` | `String?` | Contact |
| `relation` | `String?` | Relationship |
| `amount` | `double` | Cash received |
| `kind` | `MoiKind` | `newMoi` or `returnMoi` |
| `returned` | `bool` | Whether we've returned this moi |
| `returnedAmount` | `double?` | Amount returned |
| `returnedOn` | `DateTime?` | Date returned |
| `returnedForFunction` | `String?` | Which function we returned at |
| `notes` | `String?` | — |

**MoiKind:**
- `newMoi` 🆕 (blue `#4A9EFF`) — a fresh gift (first time giving)
- `returnMoi` 🔁 (green `#00C897`) — returning a previous obligation

### Three-Tab Screen

```
Our Functions (N)  |  Upcoming (N)  |  Attended (N)
```

#### Tab 0: Our Functions

Shows all `FunctionModel` records grouped into two sections:
- **PLANNED** (green header) — `isPlanned == true`
- **COMPLETED** (primary color header) — `isPlanned == false`

Tapping a **completed** function → `_FunctionDetail` screen.
Tapping a **planned** function → `_PlannedFunctionDetail` screen (7-tab detail view).

#### Tab 1: Upcoming

Shows `UpcomingFunction` records — events you know you'll attend in the future.

**UpcomingFunction model:**
```
id, walletId, personName, familyName?, functionTitle, memberId,
type, date?, venue?, notes?,
plannedGifts: List<PlannedGiftItem>,
chat: List<FunctionChatMessage>,
votes: Map<memberId, giftCategoryLabel>
```

The Upcoming detail screen allows family members to **vote** on what to give, and records `plannedGifts` (category + notes).

#### Tab 2: Attended

Shows `AttendedFunction` records — events already attended. Includes a live search bar (searches name, venue, type, gift category).

**AttendedFunction model:**
```
id, walletId, functionName, personName?, familyName?,
type, date?, venue?, notes?,
gifts: List<PlannedGiftItem>  // what was actually given
```

### Planned Function Detail — 7 Tabs

When `isPlanned == true`, the function detail screen has 7 tabs for comprehensive planning:

| Tab | Content |
|---|---|
| **Info** | Basic details + summary stats (participants, clothing, return gifts count) |
| **Participants** | Guest list with family member breakdown; `totalCount = 1 + familyMembers.length` |
| **Clothing Gifts** | `ClothingFamily` entries — who gets what clothing: gender, dress type, size, brand, budget, purchased flag |
| **Bridal Essentials** | `BridalEssential` checklist items |
| **Return Gift** | `FunctionReturnGift` records |
| **Vendors** | Service providers: catering, venue, decoration, photography, entertainment, clothing, makeup, jewelry, accessories, ritual services, accommodation, invitations, return gifts, support services — each with cost, advance paid, balance |
| **Messages** | In-app chat thread (reuses shared `ChatWidget`) |

### VendorCategory (14 types)

Catering, Venue, Decoration, Photography & Videography, Entertainment, Clothing, Makeup, Jewelry, Accessories, Ritual Services, Accommodation, Invitations, Return Gifts, Support Services.

**FunctionVendor computed:** `double get balance => (totalCost ?? 0) - (advancePaid ?? 0)`

### Gift Recording (Upcoming Tab)

Gift categories available when planning/recording gifts given:

The `_upcomingGiftCategories` list provides `(emoji, categoryLabel)` pairs including: Cash, Gold, Silver, Saree, Dress, Household, Gift Item, Gift Card. When editing an attended function, the same category chips are shown.

**PlannedGiftItem:** `{category: String, notes: String?}` — stored as JSONB array.

### MOI Bulk Entry

The "Bulk MOI Entry" feature (from commit history: `MyFunction - Bulk Moi Entry implemented`) allows recording multiple MOI entries in a single flow — useful at large functions where dozens of guests give cash.

### Personal vs Family View

In Personal view, `fetchMyFunctions` is called for **all wallet IDs** (personal + family) simultaneously using `Future.wait`. Upcoming and Attended are fetched only from the **personal wallet** (not merged).

---

## 3c.7 AI Integration

### Architecture

All AI parsing goes through a single edge function `parse` via `AIParser`:

```dart
static Future<AIParseResult> parseText({
  required String feature,    // e.g. 'planit', 'functions'
  required String subFeature, // e.g. 'reminder', 'task'
  required String text,
  Map<String, dynamic>? context,
}) async { ... }
```

**Context injected automatically:**
```dart
{
  'today': 'YYYY-MM-DD',
  'day_of_week': 'Monday',
  'current_month': 'January',
  'currency': 'INR',
  ...?extra
}
```

**Response structure:**
```dart
class AIParseResult {
  final bool success;
  final Map<String, dynamic>? data;
  final double? confidence;
  final bool needsReview;
  final String? error;
  final Map<String, dynamic>? meta;
}
```

### Fallback Pattern (All Modules)

Every AI parse call follows the same two-layer pattern:

```
Claude AI (edge function)
  ├─ success → use result
  └─ failure → local NLP parser (deterministic regex/keyword fallback)
                ├─ success → use result (labeled "Local NLP" in UI)
                └─ failure → show error banner, keep manual tab open
```

### All 8 PlanIt + Functions AI Prompts

| # | Feature | Sub-feature | Module | What it Extracts |
|---|---|---|---|---|
| 1 | `planit` | `reminder` | Alert Me | `{title, emoji, date (ISO), time (HH:MM), priority, repeat, assigned_to, note}` |
| 2 | `planit` | `task` | My Tasks | `{title, description, emoji, priority, dueDate (ISO), project, subtasks (List<String>), assignedTo}` |
| 3 | `planit` | `note` | Sticky Notes | `{title, content, color, note_type, is_pinned}` |
| 4 | `planit` | `wishlist` | Wish List | Wish item details (name, category, price, link, targetDate) |
| 5 | `planit` | `special_day` | Special Days | `{title, emoji, type, date (ISO), yearlyRecur, note, alertDaysBefore}` |
| 6 | `functions` | `my_function` | Our Functions (Tab 0) | `{title, type, function_date, venue}` |
| 7 | `functions` | `upcoming_function` | Upcoming (Tab 1) | `{title, function_type, date, venue, person_name, family_name}` |
| 8 | `functions` | `attended_function` | Attended (Tab 2) | `{title, type, date, venue, person_name, family_name}` |

### Intent Detection / Routing

There is no single intent router that detects which module to route to. Instead, each module screen has its own dedicated "AI Parse" tab within its add/edit sheet. The user navigates to the relevant module, taps the AI Parse tab, types, and the module's specific sub-feature prompt is used.

**Tab-level routing for Functions:** the `_FunctionAIParser` uses `tabIdx` to pick the correct sub-feature:

```dart
final subFeature = tabIdx == 0 ? 'my_function'
    : tabIdx == 1              ? 'upcoming_function'
    :                            'attended_function';
```

**Date sanity check (Functions parser):**

```dart
// Rejects hallucinated years outside current year ±1/+10 range
if (parsed.year >= now.year - 1 && parsed.year <= now.year + 10) {
  date = parsed;
} else {
  // Fix 2-digit year misparse: adjust to current year or next year
  final fixed = DateTime(now.year, parsed.month, parsed.day);
  date = fixed.isBefore(now)
      ? DateTime(now.year + 1, parsed.month, parsed.day)
      : fixed;
}
```

**Type mapping (Functions parser):**

```dart
const typeMap = {
  'wedding': FunctionType.wedding,
  'birthday': FunctionType.birthday,
  'housewarming': FunctionType.houseWarming,
  'house_warming': FunctionType.houseWarming,
  'naming': FunctionType.naming,
  'naming_ceremony': FunctionType.naming,
  'ear_piercing': FunctionType.earPiercing,
  'engagement': FunctionType.engagement,
  'graduation': FunctionType.graduation,
  'anniversary': FunctionType.anniversary,
  'puberty': FunctionType.puberty,
};
// upcoming_function uses 'function_type' key; others use 'type'
final rawType = (data['type'] ?? data['function_type']).toString().toLowerCase();
```

### UI Indicators

Each module's AI parse result preview shows a badge:
- **"✨ Claude AI"** (purple) — result from the edge function
- **"🔍 Local NLP"** (orange) — result from the deterministic fallback parser

An "Edit" link on the preview card switches to the Manual tab so the user can adjust any field before saving.

---

## 3c.8 Shared PlanIt Widgets

**File:** `lib/features/planit/widgets/plan_widgets.dart`

| Widget | Purpose |
|---|---|
| `SwipeTile` | Swipe-to-delete wrapper for list items |
| `PlanEmptyState` | Empty list placeholder with emoji + title + subtitle |
| `FamilyBadge` | Small colored chip showing family wallet label |
| `PriorityBadge` | Priority color chip (low/medium/high/urgent) |
| `MemberAvatar` | Circular avatar with member emoji |
| `SaveButton` | Styled full-width CTA button |
| `SheetLabel` | Small section label for bottom sheets |
| `PlanInputField` | Styled text input for plan forms |
| `showPlanSheet` | Helper to show a modal bottom sheet with standard styling |
| `fmtDate(DateTime)` | "Jan 26, 2025" formatted date |
| `fmtDateShort(DateTime)` | "26 Jan" short format |
| `daysUntil(DateTime)` | Relative countdown string |
| `daysUntilColor(DateTime)` | Countdown color (green/orange/red) |

---

## 3c.9 Shared Enums and Models

**File:** `lib/data/models/planit/planit_models.dart`

### `Priority`

```
low (green #00C897) | medium (blue #4A9EFF) | high (orange #FFAA2C) | urgent (red-pink #FF5C7A)
```

### `RepeatMode`

```
none | daily | weekly | monthly | yearly
```
Each has `.label` ("Every Day", etc.) and `.badge` (short display like "Daily").

### `TaskStatus`

```
todo (purple #6C63FF, ☐) | inProgress (orange #FFAA2C, ⏳) | done (green #00C897, ✓)
```

### `SpecialDayType`

6 types: birthday / anniversary / festival / govtHoliday / holiday / custom — each with `.label`, `.emoji`, `.color`.

### `WishCategory`

7 types: electronics / fashion / home / travel / food / experience / other — each with `.label` and `.emoji`.

### `BillCategory`

12 types for bill tracking in Wish List / other billing modules.

### `PlanMember`

```dart
class PlanMember {
  final String id, name, emoji;
  final String? phone;
}
```

**mockMembers** (used in development/preview):
- `me` 👤, `arjun` 👨, `priya` 👩, `rahul` 🧑, `sneha` 👧, `dad` 👴, `mom` 👵

---

*Next: **Section 3d — Dashboard Tab Documentation***
