import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin Supabase layer for PlanIt special days.
class SpecialDayService {
  SpecialDayService._();
  static final SpecialDayService instance = SpecialDayService._();

  /// Fires whenever a special day is added, updated, or deleted — lets any
  /// screen (PlanIt, Dashboard) know its cached list is stale.
  static final changeSignal = ValueNotifier<int>(0);

  SupabaseClient get _db => Supabase.instance.client;

  /// Per-wallet cache — whichever screen (PlanIt or Dashboard) asks first
  /// does the real query; the other reuses this instead of re-fetching.
  final Map<String, List<Map<String, dynamic>>> _cache = {};

  Future<List<Map<String, dynamic>>> fetchDays(
    String walletId, {
    bool force = false,
  }) async {
    if (!force) {
      final cached = _cache[walletId];
      if (cached != null) return cached;
    }
    final rows = await _db
        .from('special_days')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('date');
    final result = List<Map<String, dynamic>>.from(rows);
    _cache[walletId] = result;
    return result;
  }

  Future<Map<String, dynamic>> addDay(Map<String, dynamic> data) async {
    final row = await _db.from('special_days').insert(data).select().single();
    _invalidate();
    return row;
  }

  Future<void> updateDay(String id, Map<String, dynamic> updates) async {
    await _db.from('special_days').update(updates).eq('id', id);
    _invalidate();
  }

  Future<void> deleteDay(String id) async {
    await _db.from('special_days').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
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
