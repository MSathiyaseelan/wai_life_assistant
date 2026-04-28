# PlanIt Feature

---

## Overview

PlanIt is the planning hub tab. It renders a scrollable list of module cards — each card shows a count badge, 2-line summary preview, and a quick-add button. Tapping a card navigates to the full module screen.

**V1 modules (visible):**

| Module | Purpose |
|---|---|
| Functions | Functions Tracker + MOI system (see [functions.md](functions.md)) |
| Special Days | Birthdays, anniversaries, festivals with yearly recurrence |
| Alert Me | Scheduled reminders with snooze and local notifications |
| My Tasks | To-do items with subtasks, priority, and project tagging |
| Wish List | Savings goals with progress tracking |
| Notes | Sticky notes with types (text/list/link/secret) and pin support |

**V2 modules (defined but hidden):** TravelBoard, PlanParty, MySchedule, HealthVault.

---

## Screen Architecture

`PlanItScreen` (`lib/features/planit/planit_screen.dart`) is a stateful hub. Key design decisions:

### Personal vs Family View

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
Map<String, String> _familyWalletNames    // walletId → label, EMPTY when in family wallet view
Map<String, String> _allFamilyWalletNames // always populated — used by edit sheets
String _personalWalletId                  // always set
```

When `familyWalletNames` is non-empty, items from family wallets display a `FamilyBadge` and are **read-only** (no edit, delete, or action buttons).

### Navigation Transition

```dart
Navigator.push(
  context,
  PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (ctx, anim, _, child) =>
      FadeTransition(opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.05), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
  ),
);
```

Quick-add passes `openAdd: true`. Functions also passes `initialTab: 2` (Attended tab, since quick-add from PlanIt hub = logging an attended function).

---

## My Tasks

### Data Model

```dart
Task {
  status:      'todo' | 'inProgress' | 'done'
  priority:    'low' | 'medium' | 'high' | 'urgent'
  subtasks:    JSONB array — [{ id, title, done }]
  project:     String? — free-text project label
  tags:        List<String>
  assigned_to: String — 'me' or a member name
  due_date:    Date?
}
```

### State Management

`TodoController` (Provider) owns the in-memory task list. Mutations call `TaskService` then `notifyListeners()`.

**Drag-and-drop:** Tasks support drag-to-reorder within a status column (Kanban-style). The order is visual only — there is no `sort_order` column in the DB. Drag-and-drop order does not persist across sessions.

---

## Alert Me (Reminders)

Reminders are stored in Supabase and also scheduled as **local notifications** via `NotificationService`.

```
User saves reminder → ReminderService.addReminder()
        │
        ▼
Supabase reminders table (source of truth)
        │
        ▼
NotificationService.scheduleReminder(reminder)
  └── flutter_local_notifications.zonedSchedule()
      channel: wai_alarms (MAX importance)
```

**Snooze:** cancels current notification, reschedules 10 min later, updates `reminders.snoozed = true`.

**Notification actions** (Android):
- **Snooze** — reschedule 10 min later
- **Stop** — cancel notification (no DB change)

**Reboot persistence:** `RECEIVE_BOOT_COMPLETED` permission in AndroidManifest. `BootReceiver` re-schedules all non-done, non-snoozed reminders on device restart.

---

## Special Days

Special days support **yearly recurrence** (`yearly_recur = TRUE`). The app computes the next occurrence client-side when displaying the upcoming events list.

`SpecialDaysController` (Provider) fetches all special days for active wallets on app start and whenever the wallet scope changes.

**Alert days before:** each special day has `alert_days_before` (default: 1). `NotificationService.scheduleSpecialDayAlert()` is called when a special day is saved.

---

## Wish List

```dart
Wish {
  target_price:    Numeric?
  saved_amount:    Numeric (default 0)
  purchased:       Boolean
  savings_history: JSONB — [{ date, amount, note }]
  priority:        'low' | 'medium' | 'high' | 'urgent'
  category:        'electronics' | 'fashion' | 'home' | 'travel' | 'food' | 'experience' | 'other'
  target_date:     Date?
}
```

Progress percentage: `saved_amount / target_price * 100`. When `purchased = true`, the wish is moved to a separate "Achieved" section.

---

## Notes

```dart
Note {
  note_type: 'text' | 'list' | 'link' | 'secret'
  color:     'yellow' | 'green' | 'blue' | 'pink' | 'purple' | 'orange'
  is_pinned: Boolean
}
```

- `list` type: content is newline-separated checklist items
- `secret` type: content is displayed blurred; tap-to-reveal
- Pinned notes float to the top of the list

---

## Folder Structure

```
lib/features/planit/
├── data/
│   └── services/
│       ├── task_service.dart
│       ├── reminder_service.dart
│       ├── special_days_service.dart
│       ├── wish_service.dart
│       └── note_service.dart
├── models/
│   ├── task.dart
│   ├── reminder.dart
│   ├── special_day.dart
│   ├── wish.dart
│   └── note.dart
├── screens/
│   ├── planit_screen.dart          ← hub screen
│   ├── my_tasks_screen.dart
│   ├── reminders_screen.dart
│   ├── special_days_screen.dart
│   ├── wish_list_screen.dart
│   └── notes_screen.dart
└── widgets/
    └── ...
```

---

## AI Prompts Used

| sub_feature | What it parses |
|---|---|
| `reminder` | Free-text → title, date, time, repeat interval |
| `task` | Free-text → title, priority, project, subtasks, due_date |
| `special_day` | Free-text → title, date, type, members |
| `wish` | Free-text → title, category, target_price, target_date |
| `note` | Free-text → title, content, note_type |
| `event` | Free-text → event details for special days |

---

## Common Issues

**Drag-and-drop order not persisted:** Task reorder via drag is UI-only. There is no `sort_order` column. After refresh, tasks return to their creation order.

**Reminder not firing after reboot:** Check that `RECEIVE_BOOT_COMPLETED` is declared in AndroidManifest and that the `BootReceiver` calls `NotificationService.rescheduleAll()`. If reminders were scheduled before the user upgraded and the boot receiver was added in that upgrade, old reminders will not be re-scheduled.

**Personal view loads family data:** In personal view, PlanIt intentionally loads from all wallet IDs (personal + all families). This is by design — it gives a merged household view. Family items are read-only and badged.

---

## Related Documentation

- [Functions Tracker](functions.md) — MOI system (lives in PlanIt)
- [Database Schema](../database.md) — `tasks`, `reminders`, `special_days`, `wishes`, `notes`
- [AI Smart Parser](../ai/smart-parser.md) — NLP + Gemini pipeline
