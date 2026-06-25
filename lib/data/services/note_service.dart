import 'package:supabase_flutter/supabase_flutter.dart';

class NoteService {
  NoteService._();
  static final NoteService instance = NoteService._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchNotes(String walletId) async {
    final rows = await _db
        .from('notes')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('is_pinned', ascending: false)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addNote(Map<String, dynamic> data) async {
    final row = await _db.from('notes').insert(data).select().single();
    return row;
  }

  Future<void> updateNote(String id, Map<String, dynamic> updates) async {
    await _db.from('notes').update(updates).eq('id', id);
  }

  Future<void> deleteNote(String id) async {
    await _db.from('notes').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> restore(String table, String id) async {
    await _db.from(table).update({'deleted_at': null}).eq('id', id);
  }
}
