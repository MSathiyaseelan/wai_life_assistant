import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/constants/api_endpoints.dart';

/// Thrown by [WishService.addWish] when the caller's standing wish-list
/// count cap (personal or shared family pool) is exhausted — deleting one
/// frees up a slot for another.
class WishLimitExceededException implements Exception {
  final int limit;
  const WishLimitExceededException(this.limit);
  @override
  String toString() =>
      "You've reached the $limit wish list items on your plan. Remove one or upgrade to add more.";
}

class WishService {
  WishService._();
  static final WishService instance = WishService._();

  /// Fires whenever a wish is added, updated, or deleted — lets any screen
  /// (PlanIt, Dashboard) know its cached list is stale.
  static final changeSignal = ValueNotifier<int>(0);

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');
    return uid;
  }

  /// Per-wallet cache — whichever screen (PlanIt or Dashboard) asks first
  /// does the real query; the other reuses this instead of re-fetching.
  final Map<String, List<Map<String, dynamic>>> _cache = {};

  Future<List<Map<String, dynamic>>> fetchWishes(
    String walletId, {
    bool force = false,
  }) async {
    if (!force) {
      final cached = _cache[walletId];
      if (cached != null) return cached;
    }
    final rows = await _db
        .from('wishes')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('created_at');
    final result = List<Map<String, dynamic>>.from(rows);
    _cache[walletId] = result;
    return result;
  }

  Future<Map<String, dynamic>> addWish(Map<String, dynamic> data) async {
    final limit = await _db.rpc(AppRpc.getEffectiveFeatureLimit, params: {
      'p_user_id': _uid,
      'p_feature': 'planit_wishlist',
    }) as int? ?? 25;
    if (limit != -1) {
      final walletId = data['wallet_id'] as String;
      final existing = await _db
          .from('wishes')
          .select('id')
          .eq('wallet_id', walletId)
          .isFilter('deleted_at', null);
      if ((existing as List).length >= limit) {
        throw WishLimitExceededException(limit);
      }
    }
    final row = await _db.from('wishes').insert(data).select().single();
    _invalidate();
    return row;
  }

  Future<void> updateWish(String id, Map<String, dynamic> updates) async {
    await _db.from('wishes').update(updates).eq('id', id);
    _invalidate();
  }

  Future<void> deleteWish(String id) async {
    await _db.from('wishes').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    _invalidate();
  }

  Future<void> restore(String table, String id) async {
    await _db.from(table).update({'deleted_at': null}).eq('id', id);
    _invalidate();
  }

  /// Mutations don't know which wallet an id belongs to, so the whole cache
  /// is cleared rather than tracking id→walletId — mutations are far rarer
  /// than reads, so this is cheap.
  void _invalidate() {
    _cache.clear();
    changeSignal.value++;
  }
}
