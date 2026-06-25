import 'package:supabase_flutter/supabase_flutter.dart';

class WishService {
  WishService._();
  static final WishService instance = WishService._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchWishes(String walletId) async {
    final rows = await _db
        .from('wishes')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addWish(Map<String, dynamic> data) async {
    final row = await _db.from('wishes').insert(data).select().single();
    return row;
  }

  Future<void> updateWish(String id, Map<String, dynamic> updates) async {
    await _db.from('wishes').update(updates).eq('id', id);
  }

  Future<void> deleteWish(String id) async {
    await _db.from('wishes').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> restore(String table, String id) async {
    await _db.from(table).update({'deleted_at': null}).eq('id', id);
  }
}
