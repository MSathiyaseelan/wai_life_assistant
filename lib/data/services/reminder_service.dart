import 'package:supabase_flutter/supabase_flutter.dart';

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchReminders(String walletId) async {
    final rows = await _db
        .from('reminders')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('due_date');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addReminder({
    required String walletId,
    required String title,
    required String emoji,
    required DateTime dueDate,
    required String dueTime,
    required String repeat,
    required String priority,
    required String assignedTo,
    String? note,
    DateTime? repeatEndDate,
  }) async {
    final row = await _db.from('reminders').insert({
      'wallet_id':   walletId,
      'title':       title,
      'emoji':       emoji,
      'due_date':    dueDate.toIso8601String().split('T').first,
      'due_time':    dueTime,
      'repeat':      repeat,
      'priority':    priority,
      'assigned_to': assignedTo,
      if (note != null) 'note': note,
      if (repeatEndDate != null)
        'repeat_end_date': repeatEndDate.toIso8601String().split('T').first,
    }).select().single();
    return row;
  }

  Future<void> updateReminder(String id, Map<String, dynamic> updates) async {
    await _db.from('reminders').update(updates).eq('id', id);
  }

  Future<void> deleteReminder(String id) async {
    await _db.from('reminders').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> restore(String table, String id) async {
    await _db.from(table).update({'deleted_at': null}).eq('id', id);
  }
}
