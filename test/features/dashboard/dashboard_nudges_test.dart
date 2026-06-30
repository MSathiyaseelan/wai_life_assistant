import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';

// ─── Nudge sort helper (mirrors dashboard _nudges sort) ───────────────────────
List<T> sortedByUrgency<T>(List<T> items, int Function(T) urgency) {
  final copy = List<T>.from(items);
  copy.sort((a, b) => urgency(b).compareTo(urgency(a)));
  return copy;
}

// ─── Task urgency mirror ──────────────────────────────────────────────────────
int taskUrgency(int? daysLeft, Priority priority) {
  if (daysLeft == null) return 1;
  if (daysLeft == 0) return 3;
  if (priority.index >= 2) return 2; // high or urgent
  return 1;
}

// ─── Special day urgency mirror ───────────────────────────────────────────────
int specialDayUrgency(int daysLeft) {
  if (daysLeft == 0) return 3;
  if (daysLeft <= 3) return 2;
  return 1;
}

String specialDaySubtitle(int daysLeft) {
  if (daysLeft == 0) return 'Today!';
  if (daysLeft == 1) return 'Tomorrow';
  return 'In ${daysLeft}d';
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. TaskModel.fromRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('TaskModel.fromRow', () {
    test('parses all fields', () {
      final row = {
        'id': 'task1',
        'wallet_id': 'personal',
        'title': 'Buy groceries',
        'emoji': '🛒',
        'description': 'Weekly shop',
        'status': 'inProgress',
        'priority': 'high',
        'due_date': '2025-08-10',
        'project': 'Home',
        'tags': ['shopping', 'weekly'],
        'assigned_to': 'me',
        'subtasks': [
          {'id': 'st1', 'title': 'Milk', 'done': false},
          {'id': 'st2', 'title': 'Eggs', 'done': true},
        ],
        'created_at': '2025-07-01T08:00:00.000Z',
      };
      final task = TaskModel.fromRow(row);
      expect(task.id, 'task1');
      expect(task.walletId, 'personal');
      expect(task.title, 'Buy groceries');
      expect(task.emoji, '🛒');
      expect(task.description, 'Weekly shop');
      expect(task.status, TaskStatus.inProgress);
      expect(task.priority, Priority.high);
      expect(task.dueDate, DateTime(2025, 8, 10));
      expect(task.project, 'Home');
      expect(task.tags, ['shopping', 'weekly']);
      expect(task.assignedTo, 'me');
      expect(task.subtasks.length, 2);
      expect(task.subtasks[0].id, 'st1');
      expect(task.subtasks[0].title, 'Milk');
      expect(task.subtasks[0].done, false);
      expect(task.subtasks[1].done, true);
    });

    test('defaults: emoji=✅, status=todo, priority=medium, assignedTo=me', () {
      final task = TaskModel.fromRow({
        'id': 't2',
        'wallet_id': 'w1',
        'title': 'Task',
      });
      expect(task.emoji, '✅');
      expect(task.status, TaskStatus.todo);
      expect(task.priority, Priority.medium);
      expect(task.assignedTo, 'me');
      expect(task.dueDate, isNull);
      expect(task.project, isNull);
      expect(task.description, isNull);
      expect(task.tags, isEmpty);
      expect(task.subtasks, isEmpty);
    });

    test('unknown status defaults to todo', () {
      final task = TaskModel.fromRow({
        'id': 't3',
        'wallet_id': 'w1',
        'title': 'T',
        'status': 'archived',
      });
      expect(task.status, TaskStatus.todo);
    });

    test('unknown priority defaults to medium', () {
      final task = TaskModel.fromRow({
        'id': 't4',
        'wallet_id': 'w1',
        'title': 'T',
        'priority': 'critical',
      });
      expect(task.priority, Priority.medium);
    });

    test('all status values parse correctly', () {
      for (final s in TaskStatus.values) {
        final task = TaskModel.fromRow({
          'id': 'tx',
          'wallet_id': 'w',
          'title': 'T',
          'status': s.name,
        });
        expect(task.status, s);
      }
    });

    test('all priority values parse correctly', () {
      for (final p in Priority.values) {
        final task = TaskModel.fromRow({
          'id': 'tx',
          'wallet_id': 'w',
          'title': 'T',
          'priority': p.name,
        });
        expect(task.priority, p);
      }
    });

    test('invalid due_date returns null (tryParse)', () {
      final task = TaskModel.fromRow({
        'id': 'tx',
        'wallet_id': 'w',
        'title': 'T',
        'due_date': 'not-a-date',
      });
      expect(task.dueDate, isNull);
    });

    test('subtasks default to empty list when absent', () {
      final task = TaskModel.fromRow({
        'id': 'tx',
        'wallet_id': 'w',
        'title': 'T',
      });
      expect(task.subtasks, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. TaskModel.toRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('TaskModel.toRow', () {
    test('round-trips through fromRow→toRow', () {
      final original = TaskModel.fromRow({
        'id': 't1',
        'wallet_id': 'w1',
        'title': 'Write tests',
        'emoji': '🧪',
        'status': 'inProgress',
        'priority': 'urgent',
        'due_date': '2025-09-15',
        'project': 'Dev',
        'tags': ['flutter', 'test'],
        'assigned_to': 'arjun',
        'subtasks': [
          {'id': 's1', 'title': 'Step 1', 'done': true},
        ],
      });
      final row = original.toRow();
      expect(row['title'], 'Write tests');
      expect(row['emoji'], '🧪');
      expect(row['status'], 'inProgress');
      expect(row['priority'], 'urgent');
      expect(row['due_date'], '2025-09-15');
      expect(row['project'], 'Dev');
      expect(row['tags'], ['flutter', 'test']);
      expect(row['assigned_to'], 'arjun');
      expect((row['subtasks'] as List).length, 1);
    });

    test('omits due_date and project when null', () {
      final task = TaskModel.fromRow({
        'id': 't1',
        'wallet_id': 'w1',
        'title': 'T',
      });
      final row = task.toRow();
      expect(row.containsKey('due_date'), false);
      expect(row.containsKey('project'), false);
    });

    test('omits description when null', () {
      final task = TaskModel.fromRow({
        'id': 't1',
        'wallet_id': 'w1',
        'title': 'T',
      });
      final row = task.toRow();
      expect(row.containsKey('description'), false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. SubTask
  // ═══════════════════════════════════════════════════════════════════════════
  group('SubTask', () {
    test('toMap round-trips', () {
      final sub = SubTask(id: 's1', title: 'Do thing', done: true);
      final m = sub.toMap();
      expect(m['id'], 's1');
      expect(m['title'], 'Do thing');
      expect(m['done'], true);
    });

    test('done defaults to false', () {
      final sub = SubTask(id: 's2', title: 'Pending');
      expect(sub.done, false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. SpecialDayModel.fromRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('SpecialDayModel.fromRow', () {
    test('parses all fields', () {
      final row = {
        'id': 'sd1',
        'wallet_id': 'personal',
        'title': "Mom's Birthday",
        'emoji': '🎂',
        'type': 'birthday',
        'date': '2025-10-05',
        'yearly_recur': false,
        'members': ['mom', 'me'],
        'note': 'Surprise party',
        'alert_days_before': 5,
      };
      final sd = SpecialDayModel.fromRow(row);
      expect(sd.id, 'sd1');
      expect(sd.walletId, 'personal');
      expect(sd.title, "Mom's Birthday");
      expect(sd.emoji, '🎂');
      expect(sd.type, SpecialDayType.birthday);
      expect(sd.date, DateTime(2025, 10, 5));
      expect(sd.yearlyRecur, false);
      expect(sd.members, ['mom', 'me']);
      expect(sd.note, 'Surprise party');
      expect(sd.alertDaysBefore, 5);
    });

    test('defaults: emoji=📅, yearlyRecur=true, alertDaysBefore=1, members=[]', () {
      final sd = SpecialDayModel.fromRow({
        'id': 'sd2',
        'wallet_id': 'w1',
        'title': 'Holiday',
        'type': 'holiday',
        'date': '2025-12-25',
      });
      expect(sd.emoji, '📅');
      expect(sd.yearlyRecur, true);
      expect(sd.alertDaysBefore, 1);
      expect(sd.members, isEmpty);
      expect(sd.note, isNull);
    });

    test('unknown type defaults to custom', () {
      final sd = SpecialDayModel.fromRow({
        'id': 'sd3',
        'wallet_id': 'w1',
        'title': 'X',
        'type': 'puja',
        'date': '2025-01-01',
      });
      expect(sd.type, SpecialDayType.custom);
    });

    test('all SpecialDayType values parse correctly', () {
      const types = {
        'birthday': SpecialDayType.birthday,
        'anniversary': SpecialDayType.anniversary,
        'festival': SpecialDayType.festival,
        'govtHoliday': SpecialDayType.govtHoliday,
        'holiday': SpecialDayType.holiday,
        'custom': SpecialDayType.custom,
      };
      for (final entry in types.entries) {
        final sd = SpecialDayModel.fromRow({
          'id': 'x',
          'wallet_id': 'w',
          'title': 'X',
          'type': entry.key,
          'date': '2025-06-01',
        });
        expect(sd.type, entry.value, reason: 'type: ${entry.key}');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. SpecialDayModel.toRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('SpecialDayModel.toRow', () {
    test('formats date as YYYY-MM-DD', () {
      final sd = SpecialDayModel.fromRow({
        'id': 'sd1',
        'wallet_id': 'w1',
        'title': 'Test Day',
        'type': 'custom',
        'date': '2025-03-07',
      });
      final row = sd.toRow();
      expect(row['date'], '2025-03-07');
    });

    test('includes note when present, omits when null', () {
      final withNote = SpecialDayModel.fromRow({
        'id': 'sd1',
        'wallet_id': 'w1',
        'title': 'T',
        'type': 'custom',
        'date': '2025-01-01',
        'note': 'Hello',
      });
      expect(withNote.toRow().containsKey('note'), true);

      final noNote = SpecialDayModel.fromRow({
        'id': 'sd2',
        'wallet_id': 'w1',
        'title': 'T',
        'type': 'custom',
        'date': '2025-01-01',
      });
      expect(noNote.toRow().containsKey('note'), false);
    });

    test('type serialises as name string', () {
      final sd = SpecialDayModel.fromRow({
        'id': 'sd1',
        'wallet_id': 'w1',
        'title': 'T',
        'type': 'festival',
        'date': '2025-11-01',
      });
      expect(sd.toRow()['type'], 'festival');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. WishModel.fromRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('WishModel.fromRow', () {
    test('parses all fields including savings history', () {
      final row = {
        'id': 'w1',
        'wallet_id': 'personal',
        'title': 'MacBook Pro',
        'emoji': '💻',
        'category': 'electronics',
        'priority': 'high',
        'target_price': 180000.0,
        'saved_amount': 45000.0,
        'link': 'https://apple.com',
        'note': 'M3 chip',
        'purchased': false,
        'target_date': '2025-12-01',
        'savings_history': [
          {'amount': 10000.0, 'date': '2025-01-15', 'note': 'First save'},
          {'amount': 35000.0, 'date': '2025-03-01'},
        ],
      };
      final wish = WishModel.fromRow(row);
      expect(wish.id, 'w1');
      expect(wish.walletId, 'personal');
      expect(wish.title, 'MacBook Pro');
      expect(wish.emoji, '💻');
      expect(wish.category, WishCategory.electronics);
      expect(wish.priority, Priority.high);
      expect(wish.targetPrice, 180000.0);
      expect(wish.savedAmount, 45000.0);
      expect(wish.link, 'https://apple.com');
      expect(wish.note, 'M3 chip');
      expect(wish.purchased, false);
      expect(wish.targetDate, DateTime(2025, 12, 1));
      expect(wish.savingsHistory.length, 2);
      expect(wish.savingsHistory[0].amount, 10000.0);
      expect(wish.savingsHistory[0].note, 'First save');
      expect(wish.savingsHistory[1].note, isNull);
    });

    test('defaults: emoji=🎁, category=other, priority=medium, purchased=false', () {
      final wish = WishModel.fromRow({
        'id': 'w2',
        'wallet_id': 'w1',
        'title': 'Something',
      });
      expect(wish.emoji, '🎁');
      expect(wish.category, WishCategory.other);
      expect(wish.priority, Priority.medium);
      expect(wish.purchased, false);
      expect(wish.savedAmount, 0.0);
      expect(wish.targetPrice, isNull);
      expect(wish.targetDate, isNull);
      expect(wish.savingsHistory, isEmpty);
    });

    test('all WishCategory values parse', () {
      const cats = {
        'electronics': WishCategory.electronics,
        'fashion': WishCategory.fashion,
        'home': WishCategory.home,
        'travel': WishCategory.travel,
        'food': WishCategory.food,
        'experience': WishCategory.experience,
        'other': WishCategory.other,
      };
      for (final entry in cats.entries) {
        final w = WishModel.fromRow({
          'id': 'x',
          'wallet_id': 'w',
          'title': 'T',
          'category': entry.key,
        });
        expect(w.category, entry.value, reason: entry.key);
      }
    });

    test('numeric target_price as int is cast to double', () {
      final wish = WishModel.fromRow({
        'id': 'w3',
        'wallet_id': 'w1',
        'title': 'Phone',
        'target_price': 50000, // int, not double
        'saved_amount': 10000,
      });
      expect(wish.targetPrice, 50000.0);
      expect(wish.savedAmount, 10000.0);
    });

    test('numeric fields as String are parsed', () {
      final wish = WishModel.fromRow({
        'id': 'w4',
        'wallet_id': 'w1',
        'title': 'Watch',
        'target_price': '25000.50',
        'saved_amount': '5000.0',
      });
      expect(wish.targetPrice, 25000.50);
      expect(wish.savedAmount, 5000.0);
    });

    test('progress is 0 when targetPrice is null', () {
      final wish = WishModel.fromRow({
        'id': 'w5',
        'wallet_id': 'w1',
        'title': 'X',
      });
      expect(wish.progress, 0.0);
    });

    test('progress is clamped to 0..1', () {
      final wish = WishModel.fromRow({
        'id': 'w6',
        'wallet_id': 'w1',
        'title': 'X',
        'target_price': 100.0,
        'saved_amount': 150.0, // over-saved
      });
      expect(wish.progress, 1.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. WishModel.toRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('WishModel.toRow', () {
    test('serialises target_date as YYYY-MM-DD', () {
      final wish = WishModel.fromRow({
        'id': 'w1',
        'wallet_id': 'personal',
        'title': 'Laptop',
        'category': 'electronics',
        'priority': 'high',
        'target_date': '2025-11-20',
      });
      expect(wish.toRow()['target_date'], '2025-11-20');
    });

    test('omits optional fields when null', () {
      final wish = WishModel.fromRow({
        'id': 'w1',
        'wallet_id': 'personal',
        'title': 'X',
      });
      final row = wish.toRow();
      expect(row.containsKey('target_price'), false);
      expect(row.containsKey('link'), false);
      expect(row.containsKey('note'), false);
      expect(row.containsKey('target_date'), false);
    });

    test('savings_history serialises correctly', () {
      final wish = WishModel.fromRow({
        'id': 'w1',
        'wallet_id': 'personal',
        'title': 'X',
        'savings_history': [
          {'amount': 5000.0, 'date': '2025-02-01', 'note': 'Birthday money'},
        ],
      });
      final row = wish.toRow();
      final history = row['savings_history'] as List;
      expect(history.length, 1);
      expect((history[0] as Map)['amount'], 5000.0);
      expect((history[0] as Map).containsKey('note'), true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. FunctionModel.fromJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('FunctionModel.fromJson', () {
    test('parses all fields', () {
      final json = {
        'id': 'fn1',
        'wallet_id': 'personal',
        'type': 'wedding',
        'title': 'Raj Wedding',
        'who_function': 'Cousin Raj',
        'custom_type': null,
        'function_date': '2025-11-12',
        'venue': 'Grand Hall',
        'address': '123 Main St',
        'notes': 'Black tie',
        'is_planned': true,
        'icon': '💒',
      };
      final fn = FunctionModel.fromJson(json);
      expect(fn.id, 'fn1');
      expect(fn.walletId, 'personal');
      expect(fn.type, FunctionType.wedding);
      expect(fn.title, 'Raj Wedding');
      expect(fn.whoFunction, 'Cousin Raj');
      expect(fn.functionDate, DateTime(2025, 11, 12));
      expect(fn.venue, 'Grand Hall');
      expect(fn.address, '123 Main St');
      expect(fn.notes, 'Black tie');
      expect(fn.isPlanned, true);
      expect(fn.icon, '💒');
    });

    test('defaults: title="", whoFunction="", isPlanned=false, icon=🎊', () {
      final fn = FunctionModel.fromJson({
        'id': 'fn2',
        'wallet_id': 'w1',
        'type': 'birthday',
      });
      expect(fn.title, '');
      expect(fn.whoFunction, '');
      expect(fn.isPlanned, false);
      expect(fn.icon, '🎊');
      expect(fn.functionDate, isNull);
      expect(fn.venue, isNull);
    });

    test('unknown type defaults to other', () {
      final fn = FunctionModel.fromJson({
        'id': 'fn3',
        'wallet_id': 'w1',
        'type': 'concert',
      });
      expect(fn.type, FunctionType.other);
    });

    test('all FunctionType values parse', () {
      for (final ft in FunctionType.values) {
        final fn = FunctionModel.fromJson({
          'id': 'x',
          'wallet_id': 'w',
          'type': ft.name,
        });
        expect(fn.type, ft, reason: ft.name);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. UpcomingFunction.fromJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('UpcomingFunction.fromJson', () {
    test('parses all fields including planned_gifts', () {
      final json = {
        'id': 'uf1',
        'wallet_id': 'personal',
        'person_name': 'Priya',
        'family_name': 'Sharma family',
        'function_title': 'Baby Shower',
        'type': 'naming',
        'date': '2025-09-20',
        'venue': 'Priya Home',
        'notes': 'Bring gift',
        'planned_gifts': [
          {'category': 'Cash', 'notes': '₹500'},
          {'category': 'Gold'},
        ],
      };
      final uf = UpcomingFunction.fromJson(json);
      expect(uf.id, 'uf1');
      expect(uf.walletId, 'personal');
      expect(uf.personName, 'Priya');
      expect(uf.familyName, 'Sharma family');
      expect(uf.functionTitle, 'Baby Shower');
      expect(uf.type, FunctionType.naming);
      expect(uf.date, DateTime(2025, 9, 20));
      expect(uf.venue, 'Priya Home');
      expect(uf.notes, 'Bring gift');
      expect(uf.plannedGifts.length, 2);
      expect(uf.plannedGifts[0].category, 'Cash');
      expect(uf.plannedGifts[0].notes, '₹500');
      expect(uf.plannedGifts[1].category, 'Gold');
      expect(uf.plannedGifts[1].notes, isNull);
      expect(uf.memberId, 'me'); // hardcoded
    });

    test('defaults: personName="", functionTitle="", date=null', () {
      final uf = UpcomingFunction.fromJson({
        'id': 'uf2',
        'wallet_id': 'w1',
        'type': 'other',
      });
      expect(uf.personName, '');
      expect(uf.functionTitle, '');
      expect(uf.date, isNull);
      expect(uf.familyName, isNull);
      expect(uf.venue, isNull);
      expect(uf.plannedGifts, isEmpty);
    });

    test('unknown type defaults to other', () {
      final uf = UpcomingFunction.fromJson({
        'id': 'uf3',
        'wallet_id': 'w1',
        'type': 'ritual',
      });
      expect(uf.type, FunctionType.other);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. PlannedGiftItem.fromJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('PlannedGiftItem.fromJson / toJson', () {
    test('round-trips with notes', () {
      final item = PlannedGiftItem.fromJson({'category': 'Silver', 'notes': 'Bracelet'});
      expect(item.category, 'Silver');
      expect(item.notes, 'Bracelet');
      final j = item.toJson();
      expect(j['category'], 'Silver');
      expect(j['notes'], 'Bracelet');
    });

    test('omits notes when null', () {
      final item = PlannedGiftItem.fromJson({'category': 'Cash'});
      expect(item.notes, isNull);
      expect(item.toJson().containsKey('notes'), false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 11. Nudge urgency sort ordering
  // ═══════════════════════════════════════════════════════════════════════════
  group('Nudge sort ordering', () {
    test('higher urgency appears first', () {
      final items = [
        {'title': 'low', 'urgency': 1},
        {'title': 'high', 'urgency': 3},
        {'title': 'med', 'urgency': 2},
      ];
      final sorted = sortedByUrgency(items, (x) => x['urgency'] as int);
      expect(sorted[0]['title'], 'high');
      expect(sorted[1]['title'], 'med');
      expect(sorted[2]['title'], 'low');
    });

    test('items with same urgency preserve relative order (stable)', () {
      final items = [
        {'title': 'A', 'urgency': 2},
        {'title': 'B', 'urgency': 2},
        {'title': 'C', 'urgency': 2},
      ];
      final sorted = sortedByUrgency(items, (x) => x['urgency'] as int);
      expect(sorted.map((x) => x['title']).toList(), ['A', 'B', 'C']);
    });

    test('urgency=3 always before urgency=1', () {
      final items = [
        {'title': 'urgent', 'urgency': 3},
        {'title': 'normal', 'urgency': 1},
      ];
      final sorted = sortedByUrgency(items, (x) => x['urgency'] as int);
      expect(sorted.first['title'], 'urgent');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 12. Task nudge urgency logic
  // ═══════════════════════════════════════════════════════════════════════════
  group('Task nudge urgency', () {
    test('daysLeft=0 → urgency 3 regardless of priority', () {
      expect(taskUrgency(0, Priority.low), 3);
      expect(taskUrgency(0, Priority.urgent), 3);
    });

    test('daysLeft>0 + high priority → urgency 2', () {
      expect(taskUrgency(3, Priority.high), 2);
      expect(taskUrgency(5, Priority.urgent), 2);
    });

    test('daysLeft>0 + low/medium priority → urgency 1', () {
      expect(taskUrgency(3, Priority.low), 1);
      expect(taskUrgency(7, Priority.medium), 1);
    });

    test('null daysLeft → urgency 1', () {
      expect(taskUrgency(null, Priority.urgent), 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 13. Special day nudge urgency + subtitle logic
  // ═══════════════════════════════════════════════════════════════════════════
  group('Special day nudge urgency', () {
    test('daysLeft=0 → urgency 3', () => expect(specialDayUrgency(0), 3));
    test('daysLeft=1 → urgency 2', () => expect(specialDayUrgency(1), 2));
    test('daysLeft=3 → urgency 2', () => expect(specialDayUrgency(3), 2));
    test('daysLeft=4 → urgency 1', () => expect(specialDayUrgency(4), 1));
    test('daysLeft=30 → urgency 1', () => expect(specialDayUrgency(30), 1));
  });

  group('Special day nudge subtitle', () {
    test('daysLeft=0 → "Today!"', () => expect(specialDaySubtitle(0), 'Today!'));
    test('daysLeft=1 → "Tomorrow"', () => expect(specialDaySubtitle(1), 'Tomorrow'));
    test('daysLeft=5 → "In 5d"', () => expect(specialDaySubtitle(5), 'In 5d'));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 14. FunctionType enum
  // ═══════════════════════════════════════════════════════════════════════════
  group('FunctionType enum', () {
    test('all values have non-empty emoji and label', () {
      for (final ft in FunctionType.values) {
        expect(ft.emoji, isNotEmpty, reason: ft.name);
        expect(ft.label, isNotEmpty, reason: ft.name);
      }
    });

    test('specific emoji/label spot checks', () {
      expect(FunctionType.wedding.emoji, '💒');
      expect(FunctionType.wedding.label, 'Wedding');
      expect(FunctionType.birthday.emoji, '🎂');
      expect(FunctionType.other.emoji, '🎊');
      expect(FunctionType.other.label, 'Others');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 15. WishCategory enum extensions
  // ═══════════════════════════════════════════════════════════════════════════
  group('WishCategoryExt', () {
    test('all values have non-empty label and emoji', () {
      for (final wc in WishCategory.values) {
        expect(wc.label, isNotEmpty, reason: wc.name);
        expect(wc.emoji, isNotEmpty, reason: wc.name);
      }
    });

    test('spot checks', () {
      expect(WishCategory.electronics.label, 'Electronics');
      expect(WishCategory.electronics.emoji, '💻');
      expect(WishCategory.other.emoji, '🎁');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 16. SpecialDayType enum extensions
  // ═══════════════════════════════════════════════════════════════════════════
  group('SpecialDayTypeExt', () {
    test('all values have non-empty label, emoji, and a color', () {
      for (final sdt in SpecialDayType.values) {
        expect(sdt.label, isNotEmpty, reason: sdt.name);
        expect(sdt.emoji, isNotEmpty, reason: sdt.name);
        expect(sdt.color, isA<Color>());
      }
    });

    test('specific values', () {
      expect(SpecialDayType.birthday.emoji, '🎂');
      expect(SpecialDayType.anniversary.emoji, '💍');
      expect(SpecialDayType.festival.emoji, '🎉');
      expect(SpecialDayType.govtHoliday.label, 'Govt Holiday');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 17. TaskStatus enum extensions
  // ═══════════════════════════════════════════════════════════════════════════
  group('TaskStatusExt', () {
    test('all values have non-empty label and an IconData', () {
      for (final ts in TaskStatus.values) {
        expect(ts.label, isNotEmpty, reason: ts.name);
        expect(ts.color, isA<Color>());
        expect(ts.icon, isA<IconData>());
      }
    });

    test('specific labels', () {
      expect(TaskStatus.todo.label, 'To Do');
      expect(TaskStatus.inProgress.label, 'In Progress');
      expect(TaskStatus.done.label, 'Done');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 18. Priority enum extensions
  // ═══════════════════════════════════════════════════════════════════════════
  group('PriorityExt', () {
    test('all values have non-empty label and a color', () {
      for (final p in Priority.values) {
        expect(p.label, isNotEmpty, reason: p.name);
        expect(p.color, isA<Color>());
      }
    });

    test('index ordering: low < medium < high < urgent', () {
      expect(Priority.low.index, lessThan(Priority.medium.index));
      expect(Priority.medium.index, lessThan(Priority.high.index));
      expect(Priority.high.index, lessThan(Priority.urgent.index));
    });

    test('high.index >= 2 and urgent.index >= 2 (used in task urgency)', () {
      expect(Priority.high.index >= 2, true);
      expect(Priority.urgent.index >= 2, true);
      expect(Priority.low.index >= 2, false);
      expect(Priority.medium.index >= 2, false);
    });
  });
}
