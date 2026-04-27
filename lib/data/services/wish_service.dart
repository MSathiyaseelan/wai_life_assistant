import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin Supabase layer for PlanIt wish list.
class WishService {
  WishService._();
  static final WishService instance = WishService._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchWishes(String walletId) async {
    final rows = await _db
        .from('wishes')
        .select()
        .eq('wallet_id', walletId)
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
    await _db.from('wishes').delete().eq('id', id);
  }
}
