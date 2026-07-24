import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/constants/api_endpoints.dart';

/// Thrown by [NoteService.addNote] when the caller's standing note count cap
/// (personal or shared family pool) is exhausted — deleting a note frees up
/// a slot for another.
class NoteLimitExceededException implements Exception {
  final int limit;
  const NoteLimitExceededException(this.limit);
  @override
  String toString() =>
      "You've reached the $limit notes on your plan. Remove one or upgrade to add more.";
}

class NoteService {
  NoteService._();
  static final NoteService instance = NoteService._();

  /// Fires whenever a note is added, updated, or deleted — lets any screen
  /// (PlanIt, Dashboard) know its cached list is stale.
  static final changeSignal = ValueNotifier<int>(0);

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');
    return uid;
  }

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
    final limit = await _db.rpc(AppRpc.getEffectiveFeatureLimit, params: {
      'p_user_id': _uid,
      'p_feature': 'planit_note',
    }) as int? ?? 20;
    if (limit != -1) {
      final walletId = data['wallet_id'] as String;
      final existing = await _db
          .from('notes')
          .select('id')
          .eq('wallet_id', walletId)
          .isFilter('deleted_at', null);
      if ((existing as List).length >= limit) {
        throw NoteLimitExceededException(limit);
      }
    }
    final row = await _db.from('notes').insert({...data, 'created_by': _uid}).select().single();
    changeSignal.value++;
    return row;
  }

  Future<void> updateNote(String id, Map<String, dynamic> updates) async {
    await _db.from('notes').update(updates).eq('id', id);
    changeSignal.value++;
  }

  Future<void> deleteNote(String id) async {
    await _db.from('notes').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    changeSignal.value++;
  }

  Future<void> restore(String table, String id) async {
    await _db.from(table).update({'deleted_at': null}).eq('id', id);
  }
}
