import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin Supabase layer for PlanIt tasks.
class TaskService {
  TaskService._();
  static final TaskService instance = TaskService._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchTasks(String walletId) async {
    final rows = await _db
        .from('tasks')
        .select()
        .eq('wallet_id', walletId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addTask(Map<String, dynamic> data) async {
    final row = await _db.from('tasks').insert(data).select().single();
    return row;
  }

  Future<void> updateTask(String id, Map<String, dynamic> updates) async {
    await _db.from('tasks').update(updates).eq('id', id);
  }

  Future<void> deleteTask(String id) async {
    await _db.from('tasks').delete().eq('id', id);
  }
}
