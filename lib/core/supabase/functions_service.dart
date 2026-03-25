import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin Supabase layer for the Functions module.
/// All methods throw [PostgrestException] on failure — callers should catch.
class FunctionsService {
  FunctionsService._();
  static final FunctionsService instance = FunctionsService._();

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  // ── Our Functions ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchMyFunctions(String walletId) async {
    final rows = await _db
        .from('functions_my')
        .select()
        .eq('wallet_id', walletId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addMyFunction(Map<String, dynamic> data) async {
    final row = await _db
        .from('functions_my')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateMyFunction(String id, Map<String, dynamic> updates) async {
    await _db.from('functions_my').update(updates).eq('id', id);
  }

  Future<void> deleteMyFunction(String id) async {
    await _db.from('functions_my').delete().eq('id', id);
  }

  // ── Upcoming Functions ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchUpcoming(String walletId) async {
    final rows = await _db
        .from('functions_upcoming')
        .select()
        .eq('wallet_id', walletId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addUpcoming(Map<String, dynamic> data) async {
    final row = await _db
        .from('functions_upcoming')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateUpcoming(String id, Map<String, dynamic> updates) async {
    await _db.from('functions_upcoming').update(updates).eq('id', id);
  }

  Future<void> deleteUpcoming(String id) async {
    await _db.from('functions_upcoming').delete().eq('id', id);
  }

  // ── Attended Functions ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAttended(String walletId) async {
    final rows = await _db
        .from('functions_attended')
        .select()
        .eq('wallet_id', walletId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addAttended(Map<String, dynamic> data) async {
    final row = await _db
        .from('functions_attended')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateAttended(String id, Map<String, dynamic> updates) async {
    await _db.from('functions_attended').update(updates).eq('id', id);
  }

  Future<void> deleteAttended(String id) async {
    await _db.from('functions_attended').delete().eq('id', id);
  }
}
