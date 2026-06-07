import 'package:supabase_flutter/supabase_flutter.dart';

class WardrobeService {
  WardrobeService._();
  static final WardrobeService instance = WardrobeService._();

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  // ── Clothing Items ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchItems(String walletId) async {
    final rows = await _db
        .from('wardrobe_items')
        .select()
        .eq('wallet_id', walletId)
        .order('added_on', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addItem(Map<String, dynamic> data) async {
    final row = await _db
        .from('wardrobe_items')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateItem(String id, Map<String, dynamic> updates) async {
    await _db.from('wardrobe_items').update(updates).eq('id', id);
  }

  Future<void> deleteItem(String id) async {
    await _db.from('wardrobe_items').delete().eq('id', id);
  }

  // ── Outfit Logs ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchOutfitLogs(String walletId) async {
    final rows = await _db
        .from('wardrobe_outfit_logs')
        .select()
        .eq('wallet_id', walletId)
        .order('date', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addOutfitLog(Map<String, dynamic> data) async {
    final row = await _db
        .from('wardrobe_outfit_logs')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateOutfitLog(String id, Map<String, dynamic> updates) async {
    await _db.from('wardrobe_outfit_logs').update(updates).eq('id', id);
  }
}
