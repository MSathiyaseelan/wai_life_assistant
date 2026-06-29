import 'package:supabase_flutter/supabase_flutter.dart';

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
        .isFilter('deleted_at', null)
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
    await _db.from('functions_my').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  // ── Upcoming Functions ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchUpcoming(String walletId, {bool onlyMine = false}) async {
    var query = _db
        .from('functions_upcoming')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null);
    if (onlyMine) query = query.eq('user_id', _uid);
    final rows = await query.order('created_at', ascending: false);
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
    await _db.from('functions_upcoming').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  // ── Attended Functions ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAttended(String walletId) async {
    final rows = await _db
        .from('functions_attended')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
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
    await _db.from('functions_attended').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  // ── Participants ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchParticipants(String functionId) async {
    final rows = await _db
        .from('function_participants')
        .select()
        .eq('function_id', functionId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addParticipant(Map<String, dynamic> data) async {
    final row = await _db
        .from('function_participants')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateParticipant(String id, Map<String, dynamic> updates) async {
    await _db.from('function_participants').update(updates).eq('id', id);
  }

  Future<void> deleteParticipant(String id) async {
    await _db.from('function_participants').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  // ── Clothing Families ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchClothingFamilies(String functionId) async {
    final rows = await _db
        .from('function_clothing_families')
        .select()
        .eq('function_id', functionId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addClothingFamily(Map<String, dynamic> data) async {
    final row = await _db
        .from('function_clothing_families')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateClothingFamily(String id, Map<String, dynamic> updates) async {
    await _db.from('function_clothing_families').update(updates).eq('id', id);
  }

  Future<void> deleteClothingFamily(String id) async {
    await _db.from('function_clothing_families').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  // ── Bridal Essentials ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchBridalEssentials(String functionId) async {
    final rows = await _db
        .from('function_bridal_essentials')
        .select()
        .eq('function_id', functionId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addBridalEssential(Map<String, dynamic> data) async {
    final row = await _db
        .from('function_bridal_essentials')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateBridalEssential(String id, Map<String, dynamic> updates) async {
    await _db.from('function_bridal_essentials').update(updates).eq('id', id);
  }

  Future<void> deleteBridalEssential(String id) async {
    await _db.from('function_bridal_essentials').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  // ── Return Gifts ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchReturnGifts(String functionId) async {
    final rows = await _db
        .from('function_return_gifts')
        .select()
        .eq('function_id', functionId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addReturnGift(Map<String, dynamic> data) async {
    final row = await _db
        .from('function_return_gifts')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateReturnGift(String id, Map<String, dynamic> updates) async {
    await _db.from('function_return_gifts').update(updates).eq('id', id);
  }

  Future<void> deleteReturnGift(String id) async {
    await _db.from('function_return_gifts').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  // ── Moi Entries ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchMoiEntries(String functionId) async {
    final rows = await _db
        .from('function_moi_entries')
        .select()
        .eq('function_id', functionId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addMoiEntry(Map<String, dynamic> data) async {
    final row = await _db
        .from('function_moi_entries')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> addMoiEntries(List<Map<String, dynamic>> rows) async {
    final withUid = rows.map((r) => {...r, 'user_id': _uid}).toList();
    await _db.from('function_moi_entries').insert(withUid);
  }

  Future<void> updateMoiEntry(String id, Map<String, dynamic> updates) async {
    await _db.from('function_moi_entries').update(updates).eq('id', id);
  }

  Future<void> deleteMoiEntry(String id) async {
    await _db.from('function_moi_entries').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> restore(String table, String id) async {
    await _db.from(table).update({'deleted_at': null}).eq('id', id);
  }
}
