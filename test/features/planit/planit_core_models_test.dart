import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';

// ─── helpers ─────────────────────────────────────────────────────────────────

Map<String, dynamic> _baseReminder({
  String id = 'r1',
  String walletId = 'w1',
  String title = 'Test Reminder',
  String? emoji,
  String dueDate = '2025-06-15',
  String? dueTime,
  String? repeat,
  String? priority,
  String? assignedTo,
  bool? snoozed,
  bool? done,
  String? note,
  String? repeatEndDate,
}) {
  return {
    'id': id,
    'wallet_id': walletId,
    'title': title,
    if (emoji != null) 'emoji': emoji,
    'due_date': dueDate,
    if (dueTime != null) 'due_time': dueTime,
    if (repeat != null) 'repeat': repeat,
    if (priority != null) 'priority': priority,
    if (assignedTo != null) 'assigned_to': assignedTo,
    if (snoozed != null) 'snoozed': snoozed,
    if (done != null) 'done': done,
    if (note != null) 'note': note,
    if (repeatEndDate != null) 'repeat_end_date': repeatEndDate,
  };
}

Map<String, dynamic> _baseTask({
  String id = 't1',
  String walletId = 'w1',
  String title = 'Test Task',
  String? emoji,
  String? status,
  String? priority,
  String? description,
  String? dueDate,
  String? project,
  List? tags,
  String? assignedTo,
  List? subtasks,
  String? createdAt,
}) {
  return {
    'id': id,
    'wallet_id': walletId,
    'title': title,
    if (emoji != null) 'emoji': emoji,
    if (status != null) 'status': status,
    if (priority != null) 'priority': priority,
    if (description != null) 'description': description,
    if (dueDate != null) 'due_date': dueDate,
    if (project != null) 'project': project,
    if (tags != null) 'tags': tags,
    if (assignedTo != null) 'assigned_to': assignedTo,
    if (subtasks != null) 'subtasks': subtasks,
    if (createdAt != null) 'created_at': createdAt,
  };
}

Map<String, dynamic> _baseSpecialDay({
  String id = 'sd1',
  String walletId = 'w1',
  String title = 'Test Day',
  String? emoji,
  String? type,
  String date = '2025-03-15',
  bool? yearlyRecur,
  List? members,
  String? note,
  int? alertDaysBefore,
}) {
  return {
    'id': id,
    'wallet_id': walletId,
    'title': title,
    if (emoji != null) 'emoji': emoji,
    if (type != null) 'type': type,
    'date': date,
    if (yearlyRecur != null) 'yearly_recur': yearlyRecur,
    if (members != null) 'members': members,
    if (note != null) 'note': note,
    if (alertDaysBefore != null) 'alert_days_before': alertDaysBefore,
  };
}

Map<String, dynamic> _baseWish({
  String id = 'w1',
  String walletId = 'wlt1',
  String title = 'Test Wish',
  String? emoji,
  String? category,
  String? priority,
  dynamic targetPrice,
  dynamic savedAmount,
  String? link,
  String? note,
  bool? purchased,
  String? targetDate,
  List? savingsHistory,
}) {
  return {
    'id': id,
    'wallet_id': walletId,
    'title': title,
    if (emoji != null) 'emoji': emoji,
    if (category != null) 'category': category,
    if (priority != null) 'priority': priority,
    if (targetPrice != null) 'target_price': targetPrice,
    if (savedAmount != null) 'saved_amount': savedAmount,
    if (link != null) 'link': link,
    if (note != null) 'note': note,
    if (purchased != null) 'purchased': purchased,
    if (targetDate != null) 'target_date': targetDate,
    if (savingsHistory != null) 'savings_history': savingsHistory,
  };
}

BillModel _makeBill({
  required DateTime dueDate,
  bool paid = false,
}) =>
    BillModel(
      id: 'b1',
      name: 'Test Bill',
      category: BillCategory.electricity,
      amount: 500,
      dueDate: dueDate,
      repeat: RepeatMode.monthly,
      walletId: 'w1',
      paid: paid,
    );

TripDestination _dest(String name, {int order = 0}) =>
    TripDestination(name: name, orderIndex: order);

TripModel _makeTrip({
  List<TripDestination>? destinations,
  List<TripExpense>? expenses,
  List<TripTask>? tasks,
}) =>
    TripModel(
      id: 'tr1',
      title: 'Test Trip',
      emoji: '✈️',
      destinations: destinations ?? [],
      travelMode: TravelMode.flight,
      walletId: 'w1',
      createdBy: 'me',
      expenses: expenses ?? [],
      tasks: tasks ?? [],
    );

// ─── tests ───────────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. ReminderModel.fromRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('ReminderModel.fromRow — scalar fields', () {
    test('parses id, walletId, title correctly', () {
      final r = ReminderModel.fromRow(_baseReminder(
        id: 'rem-1', walletId: 'wlt', title: 'Buy groceries',
      ));
      expect(r.id, 'rem-1');
      expect(r.walletId, 'wlt');
      expect(r.title, 'Buy groceries');
    });

    test('parses dueDate from ISO string', () {
      final r = ReminderModel.fromRow(_baseReminder(dueDate: '2025-08-20'));
      expect(r.dueDate, DateTime.parse('2025-08-20'));
    });

    test('emoji defaults to "🔔" when absent', () {
      final r = ReminderModel.fromRow(_baseReminder());
      expect(r.emoji, '🔔');
    });

    test('emoji set when provided', () {
      final r = ReminderModel.fromRow(_baseReminder(emoji: '💊'));
      expect(r.emoji, '💊');
    });

    test('snoozed defaults to false', () {
      expect(ReminderModel.fromRow(_baseReminder()).snoozed, false);
    });

    test('done defaults to false', () {
      expect(ReminderModel.fromRow(_baseReminder()).done, false);
    });

    test('snoozed and done set when provided', () {
      final r = ReminderModel.fromRow(_baseReminder(snoozed: true, done: true));
      expect(r.snoozed, true);
      expect(r.done, true);
    });

    test('note is null when absent', () {
      expect(ReminderModel.fromRow(_baseReminder()).note, isNull);
    });

    test('note populated when provided', () {
      final r = ReminderModel.fromRow(_baseReminder(note: 'Bring docs'));
      expect(r.note, 'Bring docs');
    });

    test('assignedTo defaults to "me" when absent', () {
      expect(ReminderModel.fromRow(_baseReminder()).assignedTo, 'me');
    });

    test('assignedTo set when provided', () {
      final r = ReminderModel.fromRow(_baseReminder(assignedTo: 'arjun'));
      expect(r.assignedTo, 'arjun');
    });

    test('repeatEndDate is null when absent', () {
      expect(ReminderModel.fromRow(_baseReminder()).repeatEndDate, isNull);
    });

    test('repeatEndDate parsed when provided', () {
      final r = ReminderModel.fromRow(
          _baseReminder(repeatEndDate: '2025-12-31'));
      expect(r.repeatEndDate, DateTime.parse('2025-12-31'));
    });
  });

  group('ReminderModel.fromRow — dueTime parsing', () {
    test('"10:30" → hour:10 minute:30', () {
      final r = ReminderModel.fromRow(_baseReminder(dueTime: '10:30'));
      expect(r.dueTime.hour, 10);
      expect(r.dueTime.minute, 30);
    });

    test('"09:05" → hour:9 minute:5', () {
      final r = ReminderModel.fromRow(_baseReminder(dueTime: '09:05'));
      expect(r.dueTime.hour, 9);
      expect(r.dueTime.minute, 5);
    });

    test('absent due_time defaults to 09:00', () {
      final r = ReminderModel.fromRow(_baseReminder());
      expect(r.dueTime.hour, 9);
      expect(r.dueTime.minute, 0);
    });
  });

  group('ReminderModel.fromRow — repeat and priority', () {
    test('repeat "daily" → RepeatMode.daily', () {
      final r = ReminderModel.fromRow(_baseReminder(repeat: 'daily'));
      expect(r.repeat, RepeatMode.daily);
    });

    test('repeat "weekly" → RepeatMode.weekly', () {
      expect(
          ReminderModel.fromRow(_baseReminder(repeat: 'weekly')).repeat,
          RepeatMode.weekly);
    });

    test('repeat "monthly" → RepeatMode.monthly', () {
      expect(
          ReminderModel.fromRow(_baseReminder(repeat: 'monthly')).repeat,
          RepeatMode.monthly);
    });

    test('repeat "yearly" → RepeatMode.yearly', () {
      expect(
          ReminderModel.fromRow(_baseReminder(repeat: 'yearly')).repeat,
          RepeatMode.yearly);
    });

    test('repeat absent → RepeatMode.none', () {
      expect(ReminderModel.fromRow(_baseReminder()).repeat, RepeatMode.none);
    });

    test('unknown repeat → RepeatMode.none', () {
      expect(
          ReminderModel.fromRow(_baseReminder(repeat: 'biweekly')).repeat,
          RepeatMode.none);
    });

    test('priority "low" → Priority.low', () {
      expect(
          ReminderModel.fromRow(_baseReminder(priority: 'low')).priority,
          Priority.low);
    });

    test('priority "urgent" → Priority.urgent', () {
      expect(
          ReminderModel.fromRow(_baseReminder(priority: 'urgent')).priority,
          Priority.urgent);
    });

    test('priority absent → Priority.medium', () {
      expect(ReminderModel.fromRow(_baseReminder()).priority, Priority.medium);
    });

    test('unknown priority → Priority.medium', () {
      expect(
          ReminderModel.fromRow(_baseReminder(priority: 'critical')).priority,
          Priority.medium);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. ReminderModel.toMap
  // ═══════════════════════════════════════════════════════════════════════════
  group('ReminderModel.toMap', () {
    late ReminderModel reminder;
    setUp(() {
      reminder = ReminderModel.fromRow(_baseReminder(
        dueDate: '2025-09-10',
        dueTime: '10:30',
        repeat: 'weekly',
        priority: 'high',
        assignedTo: 'priya',
        note: 'Take meds',
        repeatEndDate: '2025-12-31',
      ));
    });

    test('due_date is date-only (no time component)', () {
      final m = reminder.toMap();
      expect(m['due_date'], '2025-09-10');
      expect((m['due_date'] as String).contains('T'), false);
    });

    test('due_time zero-pads hour and minute', () {
      final r = ReminderModel.fromRow(_baseReminder(dueTime: '09:05'));
      expect(r.toMap()['due_time'], '09:05');
    });

    test('due_time "10:30" serialised as "10:30"', () {
      expect(reminder.toMap()['due_time'], '10:30');
    });

    test('repeat serialised as enum name', () {
      expect(reminder.toMap()['repeat'], 'weekly');
    });

    test('priority serialised as enum name', () {
      expect(reminder.toMap()['priority'], 'high');
    });

    test('note included when non-null', () {
      expect(reminder.toMap().containsKey('note'), true);
      expect(reminder.toMap()['note'], 'Take meds');
    });

    test('note absent when null', () {
      final r = ReminderModel.fromRow(_baseReminder());
      expect(r.toMap().containsKey('note'), false);
    });

    test('repeat_end_date included when non-null', () {
      expect(reminder.toMap().containsKey('repeat_end_date'), true);
      expect(reminder.toMap()['repeat_end_date'], '2025-12-31');
    });

    test('repeat_end_date absent when null', () {
      final r = ReminderModel.fromRow(_baseReminder());
      expect(r.toMap().containsKey('repeat_end_date'), false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. TaskModel.fromRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('TaskModel.fromRow — scalar fields', () {
    test('parses id, walletId, title', () {
      final t = TaskModel.fromRow(
          _baseTask(id: 'tsk-1', walletId: 'wlt', title: 'Buy milk'));
      expect(t.id, 'tsk-1');
      expect(t.walletId, 'wlt');
      expect(t.title, 'Buy milk');
    });

    test('emoji defaults to "✅" when absent', () {
      expect(TaskModel.fromRow(_baseTask()).emoji, '✅');
    });

    test('emoji set when provided', () {
      expect(TaskModel.fromRow(_baseTask(emoji: '📊')).emoji, '📊');
    });

    test('description is null when absent', () {
      expect(TaskModel.fromRow(_baseTask()).description, isNull);
    });

    test('description populated when provided', () {
      final t = TaskModel.fromRow(_baseTask(description: 'Do it'));
      expect(t.description, 'Do it');
    });

    test('assignedTo defaults to "me"', () {
      expect(TaskModel.fromRow(_baseTask()).assignedTo, 'me');
    });

    test('dueDate is null when absent', () {
      expect(TaskModel.fromRow(_baseTask()).dueDate, isNull);
    });

    test('dueDate parsed when provided', () {
      final t = TaskModel.fromRow(_baseTask(dueDate: '2025-07-01'));
      expect(t.dueDate, DateTime.parse('2025-07-01'));
    });

    test('project is null when absent', () {
      expect(TaskModel.fromRow(_baseTask()).project, isNull);
    });

    test('tags is empty list by default', () {
      expect(TaskModel.fromRow(_baseTask()).tags, isEmpty);
    });

    test('tags populated from list', () {
      final t = TaskModel.fromRow(_baseTask(tags: ['work', 'urgent']));
      expect(t.tags, ['work', 'urgent']);
    });

    test('createdAt parsed from string', () {
      final t = TaskModel.fromRow(
          _baseTask(createdAt: '2025-01-01T00:00:00.000Z'));
      expect(t.createdAt, DateTime.parse('2025-01-01T00:00:00.000Z'));
    });
  });

  group('TaskModel.fromRow — status and priority via const map', () {
    test('"todo" → TaskStatus.todo', () {
      expect(
          TaskModel.fromRow(_baseTask(status: 'todo')).status,
          TaskStatus.todo);
    });

    test('"inProgress" → TaskStatus.inProgress', () {
      expect(
          TaskModel.fromRow(_baseTask(status: 'inProgress')).status,
          TaskStatus.inProgress);
    });

    test('"done" → TaskStatus.done', () {
      expect(
          TaskModel.fromRow(_baseTask(status: 'done')).status,
          TaskStatus.done);
    });

    test('absent status → TaskStatus.todo (default)', () {
      expect(TaskModel.fromRow(_baseTask()).status, TaskStatus.todo);
    });

    test('unknown status → TaskStatus.todo (default)', () {
      expect(
          TaskModel.fromRow(_baseTask(status: 'blocked')).status,
          TaskStatus.todo);
    });

    test('"high" priority → Priority.high', () {
      expect(
          TaskModel.fromRow(_baseTask(priority: 'high')).priority,
          Priority.high);
    });

    test('absent priority → Priority.medium', () {
      expect(TaskModel.fromRow(_baseTask()).priority, Priority.medium);
    });

    test('unknown priority → Priority.medium', () {
      expect(
          TaskModel.fromRow(_baseTask(priority: 'extreme')).priority,
          Priority.medium);
    });
  });

  group('TaskModel.fromRow — subtasks', () {
    test('subtasks empty when absent', () {
      expect(TaskModel.fromRow(_baseTask()).subtasks, isEmpty);
    });

    test('subtasks parsed correctly', () {
      final t = TaskModel.fromRow(_baseTask(subtasks: [
        {'id': 'st1', 'title': 'Step 1', 'done': false},
        {'id': 'st2', 'title': 'Step 2', 'done': true},
      ]));
      expect(t.subtasks.length, 2);
      expect(t.subtasks[0].id, 'st1');
      expect(t.subtasks[0].title, 'Step 1');
      expect(t.subtasks[0].done, false);
      expect(t.subtasks[1].done, true);
    });

    test('subtask done defaults to false when absent', () {
      final t = TaskModel.fromRow(_baseTask(subtasks: [
        {'id': 'st1', 'title': 'Step 1'},
      ]));
      expect(t.subtasks[0].done, false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. TaskModel.toRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('TaskModel.toRow', () {
    test('status serialised as enum name "inProgress"', () {
      final t = TaskModel.fromRow(_baseTask(status: 'inProgress'));
      expect(t.toRow()['status'], 'inProgress');
    });

    test('priority serialised as enum name', () {
      final t = TaskModel.fromRow(_baseTask(priority: 'urgent'));
      expect(t.toRow()['priority'], 'urgent');
    });

    test('description absent when null', () {
      expect(TaskModel.fromRow(_baseTask()).toRow().containsKey('description'),
          false);
    });

    test('description present when non-null', () {
      final t = TaskModel.fromRow(_baseTask(description: 'desc'));
      expect(t.toRow()['description'], 'desc');
    });

    test('due_date is date-only when set', () {
      final t = TaskModel.fromRow(_baseTask(dueDate: '2025-11-20'));
      expect(t.toRow()['due_date'], '2025-11-20');
    });

    test('due_date absent when null', () {
      expect(TaskModel.fromRow(_baseTask()).toRow().containsKey('due_date'),
          false);
    });

    test('project absent when null', () {
      expect(TaskModel.fromRow(_baseTask()).toRow().containsKey('project'),
          false);
    });

    test('project present when set', () {
      final t = TaskModel.fromRow(_baseTask(project: 'Work'));
      expect(t.toRow()['project'], 'Work');
    });

    test('subtasks serialised as list of maps', () {
      final t = TaskModel.fromRow(_baseTask(subtasks: [
        {'id': 'st1', 'title': 'Step 1', 'done': true},
      ]));
      final rows = t.toRow()['subtasks'] as List;
      expect(rows.length, 1);
      expect(rows[0], {'id': 'st1', 'title': 'Step 1', 'done': true});
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. SubTask.toMap
  // ═══════════════════════════════════════════════════════════════════════════
  group('SubTask.toMap', () {
    test('done=false round-trips', () {
      final s = SubTask(id: 's1', title: 'Check', done: false);
      expect(s.toMap(), {'id': 's1', 'title': 'Check', 'done': false});
    });

    test('done=true round-trips', () {
      final s = SubTask(id: 's2', title: 'Done item', done: true);
      expect(s.toMap(), {'id': 's2', 'title': 'Done item', 'done': true});
    });

    test('done defaults to false in constructor', () {
      final s = SubTask(id: 's3', title: 'New');
      expect(s.done, false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. SpecialDayModel.fromRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('SpecialDayModel.fromRow — type parsing', () {
    test('"birthday" → SpecialDayType.birthday', () {
      final d = SpecialDayModel.fromRow(_baseSpecialDay(type: 'birthday'));
      expect(d.type, SpecialDayType.birthday);
    });

    test('"anniversary" → SpecialDayType.anniversary', () {
      expect(
          SpecialDayModel.fromRow(_baseSpecialDay(type: 'anniversary')).type,
          SpecialDayType.anniversary);
    });

    test('"govtHoliday" → SpecialDayType.govtHoliday', () {
      expect(
          SpecialDayModel.fromRow(_baseSpecialDay(type: 'govtHoliday')).type,
          SpecialDayType.govtHoliday);
    });

    test('absent type → SpecialDayType.custom', () {
      expect(SpecialDayModel.fromRow(_baseSpecialDay()).type,
          SpecialDayType.custom);
    });

    test('unknown type → SpecialDayType.custom', () {
      expect(
          SpecialDayModel.fromRow(_baseSpecialDay(type: 'reunion')).type,
          SpecialDayType.custom);
    });
  });

  group('SpecialDayModel.fromRow — defaults', () {
    test('emoji defaults to "📅" when absent', () {
      expect(SpecialDayModel.fromRow(_baseSpecialDay()).emoji, '📅');
    });

    test('emoji set when provided', () {
      final d = SpecialDayModel.fromRow(_baseSpecialDay(emoji: '🎂'));
      expect(d.emoji, '🎂');
    });

    test('yearlyRecur defaults to true', () {
      expect(SpecialDayModel.fromRow(_baseSpecialDay()).yearlyRecur, true);
    });

    test('yearlyRecur=false preserved', () {
      final d = SpecialDayModel.fromRow(_baseSpecialDay(yearlyRecur: false));
      expect(d.yearlyRecur, false);
    });

    test('members defaults to []', () {
      expect(SpecialDayModel.fromRow(_baseSpecialDay()).members, isEmpty);
    });

    test('members populated from list', () {
      final d = SpecialDayModel.fromRow(
          _baseSpecialDay(members: ['me', 'priya']));
      expect(d.members, ['me', 'priya']);
    });

    test('note is null when absent', () {
      expect(SpecialDayModel.fromRow(_baseSpecialDay()).note, isNull);
    });

    test('alertDaysBefore defaults to 1', () {
      expect(SpecialDayModel.fromRow(_baseSpecialDay()).alertDaysBefore, 1);
    });

    test('alertDaysBefore set when provided', () {
      final d = SpecialDayModel.fromRow(_baseSpecialDay(alertDaysBefore: 7));
      expect(d.alertDaysBefore, 7);
    });

    test('date parsed from string', () {
      final d = SpecialDayModel.fromRow(_baseSpecialDay(date: '2025-08-10'));
      expect(d.date, DateTime.parse('2025-08-10'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. SpecialDayModel.toRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('SpecialDayModel.toRow', () {
    test('date is zero-padded YYYY-MM-DD (single-digit month and day)', () {
      final d = SpecialDayModel.fromRow(
          _baseSpecialDay(type: 'birthday', date: '2025-03-05'));
      expect(d.toRow()['date'], '2025-03-05');
    });

    test('date with double-digit parts preserved', () {
      final d = SpecialDayModel.fromRow(_baseSpecialDay(date: '2025-12-31'));
      expect(d.toRow()['date'], '2025-12-31');
    });

    test('type serialised as enum name', () {
      final d = SpecialDayModel.fromRow(_baseSpecialDay(type: 'festival'));
      expect(d.toRow()['type'], 'festival');
    });

    test('note absent when null', () {
      expect(SpecialDayModel.fromRow(_baseSpecialDay()).toRow()
          .containsKey('note'), false);
    });

    test('note present when non-null', () {
      final d = SpecialDayModel.fromRow(_baseSpecialDay(note: 'Buy gift'));
      expect(d.toRow()['note'], 'Buy gift');
    });

    test('yearlyRecur and alertDaysBefore preserved', () {
      final d = SpecialDayModel.fromRow(
          _baseSpecialDay(yearlyRecur: false, alertDaysBefore: 5));
      final row = d.toRow();
      expect(row['yearly_recur'], false);
      expect(row['alert_days_before'], 5);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. WishModel.progress
  // ═══════════════════════════════════════════════════════════════════════════
  group('WishModel.progress', () {
    WishModel makeWish({double? targetPrice, double savedAmount = 0}) =>
        WishModel(
          id: 'w1',
          title: 'T',
          emoji: '🎁',
          category: WishCategory.other,
          priority: Priority.medium,
          walletId: 'wlt',
          targetPrice: targetPrice,
          savedAmount: savedAmount,
        );

    test('null targetPrice → 0.0', () {
      expect(makeWish(targetPrice: null).progress, 0.0);
    });

    test('zero targetPrice → 0.0 (guard against divide-by-zero)', () {
      expect(makeWish(targetPrice: 0, savedAmount: 500).progress, 0.0);
    });

    test('no savings → 0.0', () {
      expect(makeWish(targetPrice: 1000, savedAmount: 0).progress, 0.0);
    });

    test('half saved → 0.5', () {
      expect(makeWish(targetPrice: 1000, savedAmount: 500).progress, 0.5);
    });

    test('fully saved → 1.0', () {
      expect(makeWish(targetPrice: 1000, savedAmount: 1000).progress, 1.0);
    });

    test('over-saved → clamped to 1.0', () {
      expect(makeWish(targetPrice: 1000, savedAmount: 1500).progress, 1.0);
    });

    test('progress never below 0', () {
      expect(makeWish(targetPrice: 1000, savedAmount: -100).progress,
          greaterThanOrEqualTo(0.0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. WishModel.fromRow — parseNum
  // ═══════════════════════════════════════════════════════════════════════════
  group('WishModel.fromRow — parseNum handles Supabase NUMERIC types', () {
    test('num target_price → double', () {
      final w = WishModel.fromRow(_baseWish(targetPrice: 50000));
      expect(w.targetPrice, 50000.0);
      expect(w.targetPrice, isA<double>());
    });

    test('String target_price → parsed double', () {
      final w = WishModel.fromRow(_baseWish(targetPrice: '28000.5'));
      expect(w.targetPrice, 28000.5);
    });

    test('null target_price → targetPrice is null', () {
      final w = WishModel.fromRow(_baseWish());
      expect(w.targetPrice, isNull);
    });

    test('num saved_amount → double', () {
      final w = WishModel.fromRow(_baseWish(savedAmount: 15000));
      expect(w.savedAmount, 15000.0);
    });

    test('String saved_amount → parsed double', () {
      final w = WishModel.fromRow(_baseWish(savedAmount: '7500'));
      expect(w.savedAmount, 7500.0);
    });

    test('absent saved_amount → defaults to 0', () {
      final w = WishModel.fromRow(_baseWish());
      expect(w.savedAmount, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. WishModel.fromRow — other fields
  // ═══════════════════════════════════════════════════════════════════════════
  group('WishModel.fromRow — scalar fields and defaults', () {
    test('emoji defaults to "🎁" when absent', () {
      expect(WishModel.fromRow(_baseWish()).emoji, '🎁');
    });

    test('emoji set when provided', () {
      expect(WishModel.fromRow(_baseWish(emoji: '💻')).emoji, '💻');
    });

    test('purchased defaults to false', () {
      expect(WishModel.fromRow(_baseWish()).purchased, false);
    });

    test('purchased=true preserved', () {
      expect(WishModel.fromRow(_baseWish(purchased: true)).purchased, true);
    });

    test('link is null when absent', () {
      expect(WishModel.fromRow(_baseWish()).link, isNull);
    });

    test('note is null when absent', () {
      expect(WishModel.fromRow(_baseWish()).note, isNull);
    });

    test('targetDate parsed when provided', () {
      final w = WishModel.fromRow(_baseWish(targetDate: '2025-12-25'));
      expect(w.targetDate, DateTime.parse('2025-12-25'));
    });

    test('targetDate is null when absent', () {
      expect(WishModel.fromRow(_baseWish()).targetDate, isNull);
    });

    test('unknown category → WishCategory.other', () {
      final w = WishModel.fromRow(_baseWish(category: 'gadgets'));
      expect(w.category, WishCategory.other);
    });

    test('"electronics" category parsed correctly', () {
      final w = WishModel.fromRow(_baseWish(category: 'electronics'));
      expect(w.category, WishCategory.electronics);
    });

    test('unknown priority → Priority.medium', () {
      final w = WishModel.fromRow(_baseWish(priority: 'extreme'));
      expect(w.priority, Priority.medium);
    });
  });

  group('WishModel.fromRow — savingsHistory', () {
    test('empty savingsHistory when absent', () {
      expect(WishModel.fromRow(_baseWish()).savingsHistory, isEmpty);
    });

    test('savingsHistory entries parsed', () {
      final w = WishModel.fromRow(_baseWish(savingsHistory: [
        {'amount': 5000, 'date': '2025-01-10T00:00:00.000', 'note': 'Bonus'},
        {'amount': 3000.0, 'date': '2025-02-10T00:00:00.000'},
      ]));
      expect(w.savingsHistory.length, 2);
      expect(w.savingsHistory[0].amount, 5000.0);
      expect(w.savingsHistory[0].date, DateTime.parse('2025-01-10T00:00:00.000'));
      expect(w.savingsHistory[0].note, 'Bonus');
      expect(w.savingsHistory[1].note, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 11. WishModel.toRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('WishModel.toRow', () {
    test('category serialised as enum name', () {
      final w = WishModel.fromRow(_baseWish(category: 'fashion'));
      expect(w.toRow()['category'], 'fashion');
    });

    test('priority serialised as enum name', () {
      final w = WishModel.fromRow(_baseWish(priority: 'high'));
      expect(w.toRow()['priority'], 'high');
    });

    test('targetPrice absent when null', () {
      expect(WishModel.fromRow(_baseWish()).toRow().containsKey('target_price'),
          false);
    });

    test('targetPrice present when set', () {
      final w = WishModel.fromRow(_baseWish(targetPrice: 45000));
      expect(w.toRow()['target_price'], 45000.0);
    });

    test('targetDate zero-padded YYYY-MM-DD', () {
      final w = WishModel.fromRow(_baseWish(targetDate: '2025-03-05'));
      expect(w.toRow()['target_date'], '2025-03-05');
    });

    test('targetDate absent when null', () {
      expect(
          WishModel.fromRow(_baseWish()).toRow().containsKey('target_date'),
          false);
    });

    test('link absent when null', () {
      expect(WishModel.fromRow(_baseWish()).toRow().containsKey('link'), false);
    });

    test('savings_history serialised with amount and date', () {
      final w = WishModel.fromRow(_baseWish(savingsHistory: [
        {'amount': 1000, 'date': '2025-01-01T00:00:00.000'},
      ]));
      final hist = w.toRow()['savings_history'] as List;
      expect(hist.length, 1);
      expect(hist[0]['amount'], 1000.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 12. BillModel.isOverdue
  // ═══════════════════════════════════════════════════════════════════════════
  group('BillModel.isOverdue', () {
    test('unpaid past due → true', () {
      final b = _makeBill(
          dueDate: DateTime.now().subtract(const Duration(hours: 1)));
      expect(b.isOverdue, true);
    });

    test('paid past due → false (paid bills are never overdue)', () {
      final b = _makeBill(
          dueDate: DateTime.now().subtract(const Duration(hours: 1)),
          paid: true);
      expect(b.isOverdue, false);
    });

    test('unpaid future due → false', () {
      final b = _makeBill(
          dueDate: DateTime.now().add(const Duration(days: 3)));
      expect(b.isOverdue, false);
    });

    test('paid future due → false', () {
      final b = _makeBill(
          dueDate: DateTime.now().add(const Duration(days: 3)),
          paid: true);
      expect(b.isOverdue, false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 13. BillModel.isDueSoon
  // ═══════════════════════════════════════════════════════════════════════════
  group('BillModel.isDueSoon', () {
    test('unpaid, not overdue, due in 3 days → true', () {
      final b = _makeBill(
          dueDate: DateTime.now().add(const Duration(days: 3)));
      expect(b.isDueSoon, true);
    });

    test('boundary: exactly 5 days → true (inDays == 5 ≤ 5)', () {
      final b = _makeBill(
          dueDate: DateTime.now().add(const Duration(days: 5, hours: 1)));
      expect(b.isDueSoon, true);
    });

    test('6 days away → false (inDays == 6 > 5)', () {
      final b = _makeBill(
          dueDate: DateTime.now().add(const Duration(days: 6, hours: 1)));
      expect(b.isDueSoon, false);
    });

    test('paid, due in 2 days → false (paid bills are never due-soon)', () {
      final b = _makeBill(
          dueDate: DateTime.now().add(const Duration(days: 2)),
          paid: true);
      expect(b.isDueSoon, false);
    });

    test('overdue bill → isDueSoon is false even though unpaid', () {
      final b = _makeBill(
          dueDate: DateTime.now().subtract(const Duration(hours: 1)));
      expect(b.isOverdue, true);
      expect(b.isDueSoon, false);
    });

    test('far-future bill → false', () {
      final b = _makeBill(
          dueDate: DateTime.now().add(const Duration(days: 30)));
      expect(b.isDueSoon, false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 14. TripModel.destinationLabel
  // ═══════════════════════════════════════════════════════════════════════════
  group('TripModel.destinationLabel', () {
    test('empty destinations → "—"', () {
      expect(_makeTrip(destinations: []).destinationLabel, '—');
    });

    test('single destination → name only', () {
      final t = _makeTrip(destinations: [_dest('Goa')]);
      expect(t.destinationLabel, 'Goa');
    });

    test('two destinations → joined with " → "', () {
      final t = _makeTrip(destinations: [_dest('Delhi'), _dest('Mumbai')]);
      expect(t.destinationLabel, 'Delhi → Mumbai');
    });

    test('three destinations → all joined', () {
      final t = _makeTrip(destinations: [
        _dest('Delhi'), _dest('Agra'), _dest('Jaipur')
      ]);
      expect(t.destinationLabel, 'Delhi → Agra → Jaipur');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 15. TripModel.totalSpent
  // ═══════════════════════════════════════════════════════════════════════════
  group('TripModel.totalSpent', () {
    TripExpense _expense(double amount) => TripExpense(
        id: 'e1', paidBy: 'me', description: 'x', amount: amount,
        at: DateTime.now());

    test('no expenses → 0.0', () {
      expect(_makeTrip().totalSpent, 0.0);
    });

    test('single expense → that amount', () {
      expect(_makeTrip(expenses: [_expense(1500)]).totalSpent, 1500.0);
    });

    test('multiple expenses summed', () {
      expect(
          _makeTrip(expenses: [_expense(1000), _expense(500), _expense(250)])
              .totalSpent,
          1750.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 16. TripModel.tasksDone and tasksTotal
  // ═══════════════════════════════════════════════════════════════════════════
  group('TripModel.tasksDone / tasksTotal', () {
    TripTask _tripTask(bool done) => TripTask(
        id: 'tk1', title: 'Task', assignedTo: 'me', addedBy: 'me', done: done);

    test('no tasks → tasksDone=0, tasksTotal=0', () {
      final t = _makeTrip();
      expect(t.tasksDone, 0);
      expect(t.tasksTotal, 0);
    });

    test('all pending → tasksDone=0, tasksTotal=N', () {
      final t = _makeTrip(
          tasks: [_tripTask(false), _tripTask(false), _tripTask(false)]);
      expect(t.tasksDone, 0);
      expect(t.tasksTotal, 3);
    });

    test('all done → tasksDone=N', () {
      final t = _makeTrip(tasks: [_tripTask(true), _tripTask(true)]);
      expect(t.tasksDone, 2);
      expect(t.tasksTotal, 2);
    });

    test('mixed done/pending counted correctly', () {
      final t = _makeTrip(
          tasks: [_tripTask(true), _tripTask(false), _tripTask(true)]);
      expect(t.tasksDone, 2);
      expect(t.tasksTotal, 3);
    });
  });
}
