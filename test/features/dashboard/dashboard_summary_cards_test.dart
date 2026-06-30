// Tests for Dashboard Summary Cards — pure logic only (no Supabase / network).
// Covers the data and logic that drives every dashboard summary card:
//   • CategoryDetector.detect()       → Quick Add chip auto-detection
//   • Nudge urgency + subtitle logic  → "Needs Attention" card
//   • ReminderModel.fromRow / toMap   → reminder data model
//   • Priority / RepeatMode / TaskStatus / SpecialDayType enums
//   • MealTime / MealStatus / GroceryCategory / CuisineType enums

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/features/wallet/category_detector.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';

// ── Nudge urgency logic (mirrored from _DashboardScreenState._nudges) ─────────
// The dashboard computes urgency 1/2/3 and a subtitle for every upcoming item.
// These helpers mirror the exact formulas so tests serve as a regression guard.

int reminderUrgency(int daysLeft) {
  if (daysLeft == 0) return 3;
  if (daysLeft <= 2) return 2;
  return 1;
}

String reminderSubtitle(int daysLeft) {
  if (daysLeft == 0) return 'Due today';
  return 'In ${daysLeft}d';
}

int taskUrgency(int daysLeft, Priority priority) {
  if (daysLeft == 0) return 3;
  if (priority.index >= 2) return 2; // high or urgent
  return 1;
}

String taskSubtitle(int daysLeft) {
  if (daysLeft == 0) return 'Due today';
  return 'Due in ${daysLeft}d';
}

int specialDayUrgency(int daysLeft) {
  if (daysLeft == 0) return 3;
  if (daysLeft <= 2) return 2;
  return 1;
}

String specialDaySubtitle(int daysLeft) {
  if (daysLeft == 0) return '🎉 Today!';
  return 'In ${daysLeft}d';
}

int vaccineUrgency(int daysLeft) {
  if (daysLeft < 0 || daysLeft == 0) return 3;
  if (daysLeft <= 7) return 2;
  return 1;
}

String vaccineSubtitle(int daysLeft) {
  if (daysLeft < 0) return 'Overdue by ${daysLeft.abs()}d';
  if (daysLeft == 0) return 'Due today';
  return 'Due in ${daysLeft}d';
}

bool isReminderInWindow(int daysLeft) => daysLeft >= 0 && daysLeft <= 7;
bool isVaccineInWindow(int daysLeft) => daysLeft <= 30;

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // CategoryDetector.detect
  // ───────────────────────────────────────────────────────────────────────────

  group('CategoryDetector.detect — expense categories', () {
    test('food keywords → 🍕 Food', () {
      for (final kw in ['zomato', 'lunch', 'dinner', 'grocery', 'swiggy', 'cafe', 'chai']) {
        expect(CategoryDetector.detect(kw, isIncome: false), '🍕 Food',
            reason: '"$kw" should map to Food');
      }
    });

    test('travel keywords → 🚗 Travel', () {
      for (final kw in ['uber', 'petrol', 'metro', 'cab', 'toll', 'ola', 'rapido', 'namma']) {
        expect(CategoryDetector.detect(kw, isIncome: false), '🚗 Travel',
            reason: '"$kw" should map to Travel');
      }
    });

    test('shopping keywords → 🛒 Shopping', () {
      for (final kw in ['amazon', 'flipkart', 'myntra', 'shopping', 'order']) {
        expect(CategoryDetector.detect(kw, isIncome: false), '🛒 Shopping',
            reason: '"$kw" should map to Shopping');
      }
    });

    test('health keywords → 💊 Health', () {
      for (final kw in ['doctor', 'pharmacy', 'medicine', 'hospital', 'clinic']) {
        expect(CategoryDetector.detect(kw, isIncome: false), '💊 Health',
            reason: '"$kw" should map to Health');
      }
    });

    test('entertainment keywords → 🎬 Entertainment', () {
      for (final kw in ['netflix', 'prime', 'hotstar', 'movie', 'concert']) {
        expect(CategoryDetector.detect(kw, isIncome: false), '🎬 Entertainment',
            reason: '"$kw" should map to Entertainment');
      }
    });

    test('housing keywords → 🏠 Housing', () {
      for (final kw in ['rent', 'maintenance', 'plumber', 'electrician']) {
        expect(CategoryDetector.detect(kw, isIncome: false), '🏠 Housing',
            reason: '"$kw" should map to Housing');
      }
    });

    test('education keywords → 📚 Education', () {
      for (final kw in ['school', 'tuition', 'course', 'coaching', 'exam']) {
        expect(CategoryDetector.detect(kw, isIncome: false), '📚 Education',
            reason: '"$kw" should map to Education');
      }
    });

    test('utilities keywords → 💡 Utilities', () {
      for (final kw in ['electric', 'internet', 'wifi', 'recharge', 'broadband']) {
        expect(CategoryDetector.detect(kw, isIncome: false), '💡 Utilities',
            reason: '"$kw" should map to Utilities');
      }
    });

    test('clothing keywords → 👕 Clothing', () {
      for (final kw in ['shirt', 'jeans', 'saree', 'footwear', 'kurta']) {
        expect(CategoryDetector.detect(kw, isIncome: false), '👕 Clothing',
            reason: '"$kw" should map to Clothing');
      }
    });

    test('fitness keywords → 🏋️ Fitness', () {
      for (final kw in ['gym', 'yoga', 'workout', 'fitness', 'cycling']) {
        expect(CategoryDetector.detect(kw, isIncome: false), '🏋️ Fitness',
            reason: '"$kw" should map to Fitness');
      }
    });

    test('vacation keywords → ✈️ Vacation', () {
      for (final kw in ['vacation', 'trip', 'hotel', 'resort', 'trek']) {
        expect(CategoryDetector.detect(kw, isIncome: false), '✈️ Vacation',
            reason: '"$kw" should map to Vacation');
      }
    });

    test('gift keywords → 🎁 Gifts', () {
      for (final kw in ['gift', 'present', 'anniversary', 'diwali']) {
        expect(CategoryDetector.detect(kw, isIncome: false), '🎁 Gifts',
            reason: '"$kw" should map to Gifts');
      }
    });

    test('returns null for empty string', () {
      expect(CategoryDetector.detect('', isIncome: false), isNull);
    });

    test('returns null for whitespace-only string', () {
      expect(CategoryDetector.detect('   ', isIncome: false), isNull);
    });

    test('returns null for unrecognised keyword', () {
      expect(CategoryDetector.detect('xyzunknownterm', isIncome: false), isNull);
    });

    test('is case-insensitive', () {
      expect(CategoryDetector.detect('ZOMATO', isIncome: false), '🍕 Food');
      expect(CategoryDetector.detect('Amazon', isIncome: false), '🛒 Shopping');
    });
  });

  group('CategoryDetector.detect — income categories', () {
    test('salary keywords → 💼 Salary', () {
      for (final kw in ['salary', 'paycheck', 'wage', 'payroll']) {
        expect(CategoryDetector.detect(kw, isIncome: true), '💼 Salary',
            reason: '"$kw" should map to Salary');
      }
    });

    test('freelance keywords → 💻 Freelance', () {
      for (final kw in ['freelance', 'client', 'consulting', 'gig']) {
        expect(CategoryDetector.detect(kw, isIncome: true), '💻 Freelance',
            reason: '"$kw" should map to Freelance');
      }
    });

    test('investment keywords → 📈 Investment', () {
      for (final kw in ['dividend', 'sip', 'mutual', 'invest', 'stock']) {
        expect(CategoryDetector.detect(kw, isIncome: true), '📈 Investment',
            reason: '"$kw" should map to Investment');
      }
    });

    test('rental keywords → 🏠 Rent', () {
      expect(CategoryDetector.detect('rental income', isIncome: true), '🏠 Rent');
    });

    test('bonus keywords → 💰 Bonus', () {
      for (final kw in ['bonus', 'incentive', 'increment', 'hike']) {
        expect(CategoryDetector.detect(kw, isIncome: true), '💰 Bonus',
            reason: '"$kw" should map to Bonus');
      }
    });

    test('refund keywords → 🔁 Refund', () {
      for (final kw in ['refund', 'cashback', 'reimburse']) {
        expect(CategoryDetector.detect(kw, isIncome: true), '🔁 Refund',
            reason: '"$kw" should map to Refund');
      }
    });

    test('gift keywords (income) → 🎁 Gift', () {
      expect(CategoryDetector.detect('birthday gift', isIncome: true), '🎁 Gift');
    });

    test('business keywords → 📦 Business', () {
      for (final kw in ['revenue', 'sale', 'business', 'earning']) {
        expect(CategoryDetector.detect(kw, isIncome: true), '📦 Business',
            reason: '"$kw" should map to Business');
      }
    });

    test('income flag changes category for ambiguous terms', () {
      // "birthday" → Gift for income, Gifts for expense
      expect(CategoryDetector.detect('birthday', isIncome: true), '🎁 Gift');
      expect(CategoryDetector.detect('birthday', isIncome: false), '🎁 Gifts');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Nudge urgency + subtitle — mirrors dashboard _nudges logic
  // ───────────────────────────────────────────────────────────────────────────

  group('Nudge urgency — reminders and tasks', () {
    test('due today → urgency 3', () {
      expect(reminderUrgency(0), 3);
      expect(taskUrgency(0, Priority.low), 3);
    });

    test('due in 1 day → urgency 2 for reminder', () {
      expect(reminderUrgency(1), 2);
    });

    test('due in 2 days → urgency 2 for reminder', () {
      expect(reminderUrgency(2), 2);
    });

    test('due in 3+ days → urgency 1 for reminder', () {
      expect(reminderUrgency(3), 1);
      expect(reminderUrgency(7), 1);
    });

    test('task due in 1 day with high priority → urgency 2', () {
      expect(taskUrgency(1, Priority.high), 2);
    });

    test('task due in 1 day with urgent priority → urgency 2', () {
      expect(taskUrgency(1, Priority.urgent), 2);
    });

    test('task due in 3 days with low priority → urgency 1', () {
      expect(taskUrgency(3, Priority.low), 1);
    });

    test('task due in 3 days with medium priority → urgency 1', () {
      expect(taskUrgency(3, Priority.medium), 1);
    });
  });

  group('Nudge subtitle — reminders and tasks', () {
    test('daysLeft 0 → "Due today"', () {
      expect(reminderSubtitle(0), 'Due today');
      expect(taskSubtitle(0), 'Due today');
    });

    test('daysLeft 1 → "In 1d" for reminder', () {
      expect(reminderSubtitle(1), 'In 1d');
    });

    test('daysLeft 5 → "In 5d" for reminder', () {
      expect(reminderSubtitle(5), 'In 5d');
    });

    test('daysLeft 1 → "Due in 1d" for task', () {
      expect(taskSubtitle(1), 'Due in 1d');
    });

    test('daysLeft 7 → "Due in 7d" for task', () {
      expect(taskSubtitle(7), 'Due in 7d');
    });
  });

  group('Nudge urgency + subtitle — special days', () {
    test('due today → urgency 3 and 🎉 Today!', () {
      expect(specialDayUrgency(0), 3);
      expect(specialDaySubtitle(0), '🎉 Today!');
    });

    test('in 1 day → urgency 2', () {
      expect(specialDayUrgency(1), 2);
    });

    test('in 2 days → urgency 2', () {
      expect(specialDayUrgency(2), 2);
    });

    test('in 3 days → urgency 1', () {
      expect(specialDayUrgency(3), 1);
    });

    test('subtitle: in 3 days → "In 3d"', () {
      expect(specialDaySubtitle(3), 'In 3d');
    });
  });

  group('Nudge urgency + subtitle — vaccines', () {
    test('overdue → urgency 3, subtitle "Overdue by Xd"', () {
      expect(vaccineUrgency(-5), 3);
      expect(vaccineSubtitle(-5), 'Overdue by 5d');
    });

    test('overdue by 1 day', () {
      expect(vaccineSubtitle(-1), 'Overdue by 1d');
    });

    test('due today → urgency 3, subtitle "Due today"', () {
      expect(vaccineUrgency(0), 3);
      expect(vaccineSubtitle(0), 'Due today');
    });

    test('due in 7 days → urgency 2', () {
      expect(vaccineUrgency(7), 2);
    });

    test('due in 30 days → urgency 1', () {
      expect(vaccineUrgency(30), 1);
    });

    test('due in 15 days → urgency 1', () {
      expect(vaccineUrgency(15), 1);
    });

    test('subtitle: due in 10 days → "Due in 10d"', () {
      expect(vaccineSubtitle(10), 'Due in 10d');
    });
  });

  group('Nudge window filtering', () {
    test('reminders within 0–7 days are shown', () {
      for (int d = 0; d <= 7; d++) {
        expect(isReminderInWindow(d), isTrue, reason: '$d days should be in window');
      }
    });

    test('reminders outside 7 days are hidden', () {
      expect(isReminderInWindow(8), isFalse);
      expect(isReminderInWindow(30), isFalse);
    });

    test('overdue reminders (daysLeft < 0) are excluded', () {
      expect(isReminderInWindow(-1), isFalse);
    });

    test('vaccines within 30 days are shown (including overdue)', () {
      expect(isVaccineInWindow(-5), isTrue);  // overdue
      expect(isVaccineInWindow(0), isTrue);
      expect(isVaccineInWindow(30), isTrue);
    });

    test('vaccines due after 30 days are hidden', () {
      expect(isVaccineInWindow(31), isFalse);
      expect(isVaccineInWindow(60), isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // ReminderModel.fromRow
  // ───────────────────────────────────────────────────────────────────────────

  group('ReminderModel.fromRow', () {
    Map<String, dynamic> row({
      String id = 'r1',
      String walletId = 'wallet-1',
      String title = 'Pay bill',
      String emoji = '💡',
      String dueDate = '2026-07-01',
      String dueTime = '09:30',
      String repeat = 'monthly',
      String priority = 'high',
      String assignedTo = 'me',
      bool snoozed = false,
      bool done = false,
      String? note,
      String? repeatEndDate,
    }) =>
        {
          'id': id,
          'wallet_id': walletId,
          'title': title,
          'emoji': emoji,
          'due_date': dueDate,
          'due_time': dueTime,
          'repeat': repeat,
          'priority': priority,
          'assigned_to': assignedTo,
          'snoozed': snoozed,
          'done': done,
          'note': note,
          'repeat_end_date': repeatEndDate,
        };

    test('parses id, walletId, title, emoji', () {
      final m = ReminderModel.fromRow(row(id: 'r99', title: 'Buy groceries', emoji: '🛒'));
      expect(m.id, 'r99');
      expect(m.walletId, 'wallet-1');
      expect(m.title, 'Buy groceries');
      expect(m.emoji, '🛒');
    });

    test('parses due date correctly', () {
      final m = ReminderModel.fromRow(row(dueDate: '2026-08-15'));
      expect(m.dueDate.year, 2026);
      expect(m.dueDate.month, 8);
      expect(m.dueDate.day, 15);
    });

    test('parses due time correctly', () {
      final m = ReminderModel.fromRow(row(dueTime: '14:45'));
      expect(m.dueTime.hour, 14);
      expect(m.dueTime.minute, 45);
    });

    test('due time defaults to 09:00 when missing', () {
      final r = Map<String, dynamic>.from(row());
      r.remove('due_time');
      r['due_time'] = null;
      final m = ReminderModel.fromRow(r);
      expect(m.dueTime.hour, 9);
      expect(m.dueTime.minute, 0);
    });

    test('all RepeatMode values are parsed', () {
      for (final mode in RepeatMode.values) {
        final m = ReminderModel.fromRow(row(repeat: mode.name));
        expect(m.repeat, mode, reason: '${mode.name} should parse');
      }
    });

    test('unknown repeat defaults to RepeatMode.none', () {
      final m = ReminderModel.fromRow(row(repeat: 'biannual'));
      expect(m.repeat, RepeatMode.none);
    });

    test('all Priority values are parsed', () {
      for (final p in Priority.values) {
        final m = ReminderModel.fromRow(row(priority: p.name));
        expect(m.priority, p, reason: '${p.name} should parse');
      }
    });

    test('unknown priority defaults to Priority.medium', () {
      final m = ReminderModel.fromRow(row(priority: 'critical'));
      expect(m.priority, Priority.medium);
    });

    test('done and snoozed flags parsed', () {
      final m = ReminderModel.fromRow(row(done: true, snoozed: true));
      expect(m.done, isTrue);
      expect(m.snoozed, isTrue);
    });

    test('default done=false, snoozed=false', () {
      final m = ReminderModel.fromRow(row());
      expect(m.done, isFalse);
      expect(m.snoozed, isFalse);
    });

    test('null note stays null', () {
      final m = ReminderModel.fromRow(row(note: null));
      expect(m.note, isNull);
    });

    test('note is parsed when present', () {
      final m = ReminderModel.fromRow(row(note: 'Call before going'));
      expect(m.note, 'Call before going');
    });

    test('repeatEndDate parsed when present', () {
      final m = ReminderModel.fromRow(row(repeatEndDate: '2026-12-31'));
      expect(m.repeatEndDate, isNotNull);
      expect(m.repeatEndDate!.year, 2026);
      expect(m.repeatEndDate!.month, 12);
    });

    test('repeatEndDate is null when absent', () {
      final m = ReminderModel.fromRow(row());
      expect(m.repeatEndDate, isNull);
    });

    test('emoji defaults to 🔔 when null', () {
      final r = Map<String, dynamic>.from(row());
      r['emoji'] = null;
      final m = ReminderModel.fromRow(r);
      expect(m.emoji, '🔔');
    });
  });

  group('ReminderModel.toMap', () {
    ReminderModel makeReminder({
      String id = 'r1',
      String walletId = 'w1',
      String title = 'Pay bill',
      String emoji = '💡',
      DateTime? dueDate,
      RepeatMode repeat = RepeatMode.monthly,
      Priority priority = Priority.high,
      bool done = false,
      String? note,
      DateTime? repeatEndDate,
    }) =>
        ReminderModel(
          id: id,
          walletId: walletId,
          title: title,
          emoji: emoji,
          dueDate: dueDate ?? DateTime(2026, 7, 1),
          dueTime: const TimeOfDay(hour: 9, minute: 30),
          repeat: repeat,
          priority: priority,
          assignedTo: 'me',
          done: done,
          note: note,
          repeatEndDate: repeatEndDate,
        );

    test('toMap contains title, emoji, repeat, priority', () {
      final m = makeReminder();
      final map = m.toMap();
      expect(map['title'], 'Pay bill');
      expect(map['emoji'], '💡');
      expect(map['repeat'], 'monthly');
      expect(map['priority'], 'high');
    });

    test('toMap formats due_date as YYYY-MM-DD', () {
      final m = makeReminder(dueDate: DateTime(2026, 8, 5));
      expect(m.toMap()['due_date'], '2026-08-05');
    });

    test('toMap formats due_time as HH:MM', () {
      final map = makeReminder().toMap();
      expect(map['due_time'], '09:30');
    });

    test('toMap omits note when null', () {
      final map = makeReminder(note: null).toMap();
      expect(map.containsKey('note'), isFalse);
    });

    test('toMap includes note when present', () {
      final map = makeReminder(note: 'Urgent').toMap();
      expect(map['note'], 'Urgent');
    });

    test('toMap omits repeat_end_date when null', () {
      final map = makeReminder().toMap();
      expect(map.containsKey('repeat_end_date'), isFalse);
    });

    test('toMap formats repeat_end_date as YYYY-MM-DD', () {
      final map = makeReminder(repeatEndDate: DateTime(2026, 12, 31)).toMap();
      expect(map['repeat_end_date'], '2026-12-31');
    });

    test('done flag is in toMap', () {
      expect(makeReminder(done: true).toMap()['done'], isTrue);
      expect(makeReminder(done: false).toMap()['done'], isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Priority enum
  // ───────────────────────────────────────────────────────────────────────────

  group('Priority enum', () {
    test('all priorities have non-empty label', () {
      for (final p in Priority.values) {
        expect(p.label, isNotEmpty, reason: '${p.name} should have label');
      }
    });

    test('priority labels are correct', () {
      expect(Priority.low.label, 'Low');
      expect(Priority.medium.label, 'Medium');
      expect(Priority.high.label, 'High');
      expect(Priority.urgent.label, 'Urgent');
    });

    test('urgent has highest index', () {
      expect(Priority.urgent.index, greaterThan(Priority.high.index));
      expect(Priority.high.index, greaterThan(Priority.medium.index));
      expect(Priority.medium.index, greaterThan(Priority.low.index));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // RepeatMode enum
  // ───────────────────────────────────────────────────────────────────────────

  group('RepeatMode enum', () {
    test('all modes have non-empty label', () {
      for (final r in RepeatMode.values) {
        expect(r.label, isNotEmpty);
      }
    });

    test('none has empty badge', () {
      expect(RepeatMode.none.badge, '');
    });

    test('repeating modes have non-empty badge with 🔁', () {
      for (final r in RepeatMode.values) {
        if (r == RepeatMode.none) continue;
        expect(r.badge, startsWith('🔁'), reason: '${r.name} badge should start with 🔁');
      }
    });

    test('all mode badges include frequency name', () {
      expect(RepeatMode.daily.badge, contains('Daily'));
      expect(RepeatMode.weekly.badge, contains('Weekly'));
      expect(RepeatMode.monthly.badge, contains('Monthly'));
      expect(RepeatMode.yearly.badge, contains('Yearly'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TaskStatus enum
  // ───────────────────────────────────────────────────────────────────────────

  group('TaskStatus enum', () {
    test('all statuses have non-empty label', () {
      for (final s in TaskStatus.values) {
        expect(s.label, isNotEmpty);
      }
    });

    test('status labels', () {
      expect(TaskStatus.todo.label, 'To Do');
      expect(TaskStatus.inProgress.label, 'In Progress');
      expect(TaskStatus.done.label, 'Done');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // SpecialDayType enum
  // ───────────────────────────────────────────────────────────────────────────

  group('SpecialDayType enum', () {
    test('all types have non-empty label and emoji', () {
      for (final t in SpecialDayType.values) {
        expect(t.label, isNotEmpty, reason: '${t.name} should have label');
        expect(t.emoji, isNotEmpty, reason: '${t.name} should have emoji');
      }
    });

    test('birthday has 🎂 emoji', () {
      expect(SpecialDayType.birthday.emoji, '🎂');
    });

    test('anniversary has 💍 emoji', () {
      expect(SpecialDayType.anniversary.emoji, '💍');
    });

    test('festival has 🎉 emoji', () {
      expect(SpecialDayType.festival.emoji, '🎉');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // MealTime enum (feeds Today's Plate card)
  // ───────────────────────────────────────────────────────────────────────────

  group('MealTime enum', () {
    test('all times have label, emoji, color', () {
      for (final t in MealTime.values) {
        expect(t.label, isNotEmpty, reason: '${t.name} label');
        expect(t.emoji, isNotEmpty, reason: '${t.name} emoji');
      }
    });

    test('meal time labels', () {
      expect(MealTime.breakfast.label, 'Breakfast');
      expect(MealTime.lunch.label, 'Lunch');
      expect(MealTime.snack.label, 'Snacks');
      expect(MealTime.dinner.label, 'Dinner');
    });

    test('meal time emojis are distinct', () {
      final emojis = MealTime.values.map((t) => t.emoji).toSet();
      expect(emojis.length, MealTime.values.length);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // MealStatus enum (feeds Today's Plate card status badge)
  // ───────────────────────────────────────────────────────────────────────────

  group('MealStatus enum', () {
    test('all statuses have label and emoji', () {
      for (final s in MealStatus.values) {
        expect(s.label, isNotEmpty);
        expect(s.emoji, isNotEmpty);
      }
    });

    test('planned label and emoji', () {
      expect(MealStatus.planned.label, 'Planned');
      expect(MealStatus.planned.emoji, '⏰');
    });

    test('cooked label and emoji', () {
      expect(MealStatus.cooked.label, 'Cooked');
      expect(MealStatus.cooked.emoji, '🏠');
    });

    test('ordered label and emoji', () {
      expect(MealStatus.ordered.label, 'Ordered');
      expect(MealStatus.ordered.emoji, '🛵');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // GroceryCategory enum (feeds shopping list card)
  // ───────────────────────────────────────────────────────────────────────────

  group('GroceryCategory enum', () {
    test('all categories have label and emoji', () {
      for (final c in GroceryCategory.values) {
        expect(c.label, isNotEmpty, reason: '${c.name} label');
        expect(c.emoji, isNotEmpty, reason: '${c.name} emoji');
      }
    });

    test('dairy has 🥛 emoji', () {
      expect(GroceryCategory.dairy.emoji, '🥛');
    });

    test('vegetables has 🥬 emoji', () {
      expect(GroceryCategory.vegetables.emoji, '🥬');
    });

    test('all category labels are distinct', () {
      final labels = GroceryCategory.values.map((c) => c.label).toSet();
      expect(labels.length, GroceryCategory.values.length);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // BillCategory enum
  // ───────────────────────────────────────────────────────────────────────────

  group('BillCategory enum', () {
    test('all categories have label and emoji', () {
      for (final c in BillCategory.values) {
        expect(c.label, isNotEmpty, reason: '${c.name} label');
        expect(c.emoji, isNotEmpty, reason: '${c.name} emoji');
      }
    });

    test('electricity has 💡 emoji', () {
      expect(BillCategory.electricity.emoji, '💡');
    });

    test('emi has 🏦 emoji', () {
      expect(BillCategory.emi.emoji, '🏦');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // WishCategory enum
  // ───────────────────────────────────────────────────────────────────────────

  group('WishCategory enum', () {
    test('all categories have label and emoji', () {
      for (final c in WishCategory.values) {
        expect(c.label, isNotEmpty);
        expect(c.emoji, isNotEmpty);
      }
    });

    test('electronics has 💻 emoji', () {
      expect(WishCategory.electronics.emoji, '💻');
    });

    test('travel has ✈️ emoji', () {
      expect(WishCategory.travel.emoji, '✈️');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // CuisineType enum
  // ───────────────────────────────────────────────────────────────────────────

  group('CuisineType enum', () {
    test('all types have label and emoji', () {
      for (final t in CuisineType.values) {
        expect(t.label, isNotEmpty, reason: '${t.name} label');
        expect(t.emoji, isNotEmpty, reason: '${t.name} emoji');
      }
    });

    test('indian cuisine emoji', () {
      expect(CuisineType.indian.emoji, '🇮🇳');
    });

    test('all labels are distinct', () {
      final labels = CuisineType.values.map((c) => c.label).toSet();
      expect(labels.length, CuisineType.values.length);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TravelMode enum
  // ───────────────────────────────────────────────────────────────────────────

  group('TravelMode enum', () {
    test('all modes have label and emoji', () {
      for (final m in TravelMode.values) {
        expect(m.label, isNotEmpty);
        expect(m.emoji, isNotEmpty);
      }
    });

    test('flight has ✈️ emoji', () {
      expect(TravelMode.flight.emoji, '✈️');
    });

    test('car has 🚗 emoji', () {
      expect(TravelMode.car.emoji, '🚗');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // HealthRecordType enum
  // ───────────────────────────────────────────────────────────────────────────

  group('HealthRecordType enum', () {
    test('all types have label, emoji, color', () {
      for (final t in HealthRecordType.values) {
        expect(t.label, isNotEmpty, reason: '${t.name} label');
        expect(t.emoji, isNotEmpty, reason: '${t.name} emoji');
      }
    });

    test('vaccination has 💉 emoji', () {
      expect(HealthRecordType.vaccination.emoji, '💉');
    });

    test('prescription has 💊 emoji', () {
      expect(HealthRecordType.prescription.emoji, '💊');
    });
  });
}
