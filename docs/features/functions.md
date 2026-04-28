# Functions Tracker (MOI System)

---

## Overview

The **Functions Tracker** is WAI's system for tracking South Indian social obligation gifts — specifically **Moi** (மொய்), the tradition of giving cash at functions (weddings, housewarming, naming ceremonies, etc.) and tracking what you owe in return.

It lives under the **PlanIt tab** → Functions module.

---

## The MOI Concept

In South Indian culture, when you receive money at your function, social obligation dictates you return a similar or greater amount when the gift-giver hosts their own function. WAI tracks:

- **How much you received** at your own functions and from whom
- **Which of those givers** have hosted their own functions since (you now owe them)
- **How much you've returned** (or still owe)

This creates a social ledger that spans years and generations.

---

## Three Sections

The Functions screen has three tabs:

| Tab | Table | Purpose |
|---|---|---|
| **My Functions** | `functions_my` | Functions you hosted — weddings, housewarmings, etc. |
| **Upcoming** | `functions_upcoming` | Functions you plan to attend (with planned gift amounts) |
| **Attended** | `functions_attended` | Functions you've already attended (with actual gift given) |

MOI entries (`function_moi_entries`) are attached to **My Functions** — they record who gave what at your function.

---

## Data Models

### `functions_my` (Functions You Hosted)

```sql
CREATE TABLE functions_my (
  id            UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id     TEXT  NOT NULL,   -- TEXT, not UUID (known schema issue)
  user_id       UUID  NOT NULL REFERENCES auth.users(id),
  type          TEXT  NOT NULL DEFAULT 'other',
  title         TEXT  NOT NULL,
  who_function  TEXT  NOT NULL DEFAULT '',   -- whose function is this
  custom_type   TEXT,                         -- if type = 'custom'
  function_date DATE,
  venue         TEXT,
  address       TEXT,
  notes         TEXT,
  family_name   TEXT,
  icon          TEXT  NOT NULL DEFAULT '🎊'
);
```

### `function_moi_entries` (MOI Received at Your Function)

```dart
MOIEntry {
  person_name:           String    // who gave
  family_name:           String?   // their family
  place:                 String?   // their city/area
  phone:                 String?
  relation:              String?   // 'Uncle', 'Neighbour', etc.
  amount:                Decimal   // amount given
  kind:                  'newMoi' | 'returnMoi'
  notes:                 String?
  returned:              Boolean   // have you returned this?
  returned_amount:       Decimal?
  returned_on:           Date?
  returned_for_function: String?   // which function you returned it at
}
```

### `functions_upcoming` (Functions You Plan to Attend)

```dart
UpcomingFunction {
  type:          String     // 'wedding', 'housewarming', etc.
  person_name:   String     // whose function
  function_title: String
  date:          Date?
  venue:         String?
  planned_gifts: JSONB      // [{ item, amount, note }]
}
```

### `functions_attended` (Functions Already Attended)

```dart
AttendedFunction {
  type:          String
  function_name: String
  date:          Date?
  venue:         String?
  gifts:         JSONB      // [{ item, amount, note }]
}
```

---

## Key User Flows

### Flow 1 — Add a Function I Hosted

1. PlanIt → Functions → My Functions → **+**
2. Select function type (Wedding, Housewarming, Naming, Birthday, Custom)
3. Enter title, who, date, venue, family name
4. Save → creates `functions_my` row

### Flow 2 — Add MOI Entry (Who Gave at My Function)

1. Open a My Function → **Add MOI Entry**
2. Enter: person name, family, relation, amount, kind (`newMoi` / `returnMoi`)
3. Optional: phone, place, notes
4. Save → creates `function_moi_entries` row attached to that function

**Bulk MOI Entry** (`MyFunctionBulkMoiSheet`) — allows adding multiple MOI entries at once from a list, optimized for entering many names quickly at the function itself.

### Flow 3 — Mark MOI as Returned

1. Open MOI entry → **Mark Returned**
2. Enter: returned amount, date, which function it was returned at
3. Sets `returned = TRUE`, `returned_amount`, `returned_on`, `returned_for_function`

### Flow 4 — Add an Upcoming Function

1. Functions → Upcoming → **+**
2. Enter: person name, function title, type, date, venue
3. Optional: add planned gifts (cash amount + item)

---

## MOI Analytics

The screen shows summary cards per My Function:
- Total MOI received
- Number of givers
- Amount still to be returned (sum of unreturned `newMoi` entries)
- Amount returned

Cross-function views:
- **Pending Returns:** all `newMoi` entries where `returned = FALSE`, sorted by oldest first (longest outstanding obligation)
- **Person History:** all entries for a specific person across all your functions — shows the full relationship ledger

---

## AI Prompts Used

| sub_feature | What it parses |
|---|---|
| `my_function` | Free-text → function type, title, date, venue |
| `upcoming_function` | Free-text → person name, function type, date |
| `received_gift` | Free-text → amount, person, kind (newMoi/returnMoi) |
| `attended_function` | Free-text → function name, date, gift given |
| `bulk_moi` | Multi-line text → list of MOI entries |
| `moi_return` | Free-text → return details |
| `function_search` | Query → search within existing functions/entries |

---

## Folder Structure

```
lib/features/planit/       (Functions lives under PlanIt)
├── functions/
│   ├── my_functions_screen.dart      ← large file (~369KB)
│   ├── upcoming_functions_screen.dart
│   ├── attended_functions_screen.dart
│   ├── widgets/
│   │   ├── moi_entry_card.dart
│   │   ├── bulk_moi_sheet.dart
│   │   └── ...
│   └── services/
│       └── functions_service.dart
```

Note: `my_functions_screen.dart` is very large. Read it in chunks (e.g. `Read` with `limit` and `offset` parameters).

---

## Known Schema Issues

| Issue | Impact |
|---|---|
| `wallet_id TEXT` (not UUID) | No FK enforcement — bad wallet IDs won't be caught at DB level |
| `function_id TEXT` in `function_moi_entries` | No referential integrity to `functions_my.id` |
| All Functions tables are personal-scoped | Cannot be shared with family wallet — MOI data is always personal |

---

## Related Documentation

- [PlanIt Feature](planit.md) — parent module
- [Database Schema](../database.md) — `functions_my`, `function_moi_entries` tables
- [AI Prompts Reference](../ai/prompts-reference.md) — all 7 functions prompts
