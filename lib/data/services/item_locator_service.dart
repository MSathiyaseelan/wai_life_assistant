import 'package:supabase_flutter/supabase_flutter.dart';

class ItemLocatorService {
  ItemLocatorService._();
  static final ItemLocatorService instance = ItemLocatorService._();

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  // ── Containers ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchContainers(String walletId) async {
    final rows = await _db
        .from('item_locator_containers')
        .select()
        .eq('wallet_id', walletId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addContainer(Map<String, dynamic> data) async {
    final row = await _db
        .from('item_locator_containers')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateContainer(String id, Map<String, dynamic> updates) async {
    await _db.from('item_locator_containers').update(updates).eq('id', id);
  }

  Future<void> deleteContainer(String id) async {
    await _db.from('item_locator_containers').delete().eq('id', id);
  }

  // ── Items ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchItems(String walletId) async {
    final rows = await _db
        .from('item_locator_items')
        .select()
        .eq('wallet_id', walletId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addItem(Map<String, dynamic> data) async {
    final row = await _db
        .from('item_locator_items')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();
    return row;
  }

  Future<void> updateItem(String id, Map<String, dynamic> updates) async {
    await _db.from('item_locator_items').update(updates).eq('id', id);
  }

  Future<void> deleteItem(String id) async {
    await _db.from('item_locator_items').delete().eq('id', id);
  }
}
