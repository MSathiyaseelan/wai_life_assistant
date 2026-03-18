import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin Supabase layer for PlanIt reminders.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  SupabaseClient get _db => Supabase.instance.client;

  /// Fetch all reminders for a wallet, ordered by due_date.
  Future<List<Map<String, dynamic>>> fetchReminders(String walletId) async {
    final rows = await _db
        .from('reminders')
        .select()
        .eq('wallet_id', walletId)
        .order('due_date');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Insert a new reminder and return the saved row (with real UUID).
  Future<Map<String, dynamic>> addReminder({
    required String walletId,
    required String title,
    required String emoji,
    required DateTime dueDate,
    required String dueTime,   // "HH:MM"
    required String repeat,    // RepeatMode.name
    required String priority,  // Priority.name
    required String assignedTo,
    String? note,
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
    }).select().single();
    return row;
  }

  /// Update mutable fields on a reminder.
  Future<void> updateReminder(String id, Map<String, dynamic> updates) async {
    await _db.from('reminders').update(updates).eq('id', id);
  }

  /// Delete a reminder.
  Future<void> deleteReminder(String id) async {
    await _db.from('reminders').delete().eq('id', id);
  }
}
