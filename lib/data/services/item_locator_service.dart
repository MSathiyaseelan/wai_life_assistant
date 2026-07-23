import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/constants/api_endpoints.dart';

/// Thrown by [ItemLocatorService]'s add methods when the caller's standing
/// count cap (personal or shared family pool) is exhausted — deleting an
/// existing container/item frees up a slot for another.
class ItemLocatorLimitExceededException implements Exception {
  final int limit;
  final String label;
  const ItemLocatorLimitExceededException(this.limit, this.label);
  @override
  String toString() =>
      "You've reached the $limit $label on your plan. Remove one or upgrade to add more.";
}

class ItemLocatorService {
  ItemLocatorService._();
  static final ItemLocatorService instance = ItemLocatorService._();

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');
    return uid;
  }

  Future<void> _enforceCountLimit({
    required String table,
    required String walletId,
    required String feature,
    required String label,
  }) async {
    final limit = await _db.rpc(AppRpc.getEffectiveFeatureLimit, params: {
      'p_user_id': _uid,
      'p_feature': feature,
    }) as int? ?? 10;
    if (limit == -1) return;
    final rows = await _db
        .from(table)
        .select('id')
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null);
    if ((rows as List).length >= limit) {
      throw ItemLocatorLimitExceededException(limit, label);
    }
  }

  // ── Containers ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchContainers(String walletId) async {
    final rows = await _db
        .from('item_locator_containers')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addContainer(Map<String, dynamic> data) async {
    await _enforceCountLimit(
      table: 'item_locator_containers',
      walletId: data['wallet_id'] as String,
      feature: 'item_locator_container',
      label: 'Item Locator containers',
    );
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
    await _db.from('item_locator_containers').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  // ── Items ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchItems(String walletId) async {
    final rows = await _db
        .from('item_locator_items')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addItem(Map<String, dynamic> data) async {
    await _enforceCountLimit(
      table: 'item_locator_items',
      walletId: data['wallet_id'] as String,
      feature: 'item_locator_item',
      label: 'Item Locator items',
    );
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
    await _db.from('item_locator_items').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> restore(String table, String id) async {
    await _db.from(table).update({'deleted_at': null}).eq('id', id);
  }
}
