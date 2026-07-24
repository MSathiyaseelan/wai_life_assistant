import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/constants/api_endpoints.dart';

/// Thrown by [ReminderService.addReminder] when the caller's standing
/// reminder count cap (personal or shared family pool) is exhausted —
/// deleting a reminder frees up a slot for another.
class ReminderLimitExceededException implements Exception {
  final int limit;
  const ReminderLimitExceededException(this.limit);
  @override
  String toString() =>
      "You've reached the $limit reminders on your plan. Remove one or upgrade to add more.";
}

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  /// Fires whenever a reminder is added, updated, or deleted — lets any
  /// screen (PlanIt, Dashboard) know its cached list is stale.
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

  Future<List<Map<String, dynamic>>> fetchReminders(
    String walletId, {
    bool force = false,
  }) async {
    if (!force) {
      final cached = _cache[walletId];
      if (cached != null) return cached;
    }
    final rows = await _db
        .from('reminders')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('due_date');
    final result = List<Map<String, dynamic>>.from(rows);
    _cache[walletId] = result;
    return result;
  }

  Future<Map<String, dynamic>> addReminder({
    required String walletId,
    required String title,
    required String emoji,
    required DateTime dueDate,
    required String dueTime,
    required String repeat,
    required String priority,
    required String assignedTo,
    String? note,
    DateTime? repeatEndDate,
  }) async {
    final limit = await _db.rpc(AppRpc.getEffectiveFeatureLimit, params: {
      'p_user_id': _uid,
      'p_feature': 'planit_reminder',
    }) as int? ?? 30;
    if (limit != -1) {
      final existing = await _db
          .from('reminders')
          .select('id')
          .eq('wallet_id', walletId)
          .isFilter('deleted_at', null);
      if ((existing as List).length >= limit) {
        throw ReminderLimitExceededException(limit);
      }
    }
    final row = await _db.from('reminders').insert({
      'wallet_id':   walletId,
      'created_by':  _uid,
      'title':       title,
      'emoji':       emoji,
      'due_date':    dueDate.toIso8601String().split('T').first,
      'due_time':    dueTime,
      'repeat':      repeat,
      'priority':    priority,
      'assigned_to': assignedTo,
      if (note != null) 'note': note,
      if (repeatEndDate != null)
        'repeat_end_date': repeatEndDate.toIso8601String().split('T').first,
    }).select().single();
    _invalidate();
    return row;
  }

  Future<void> updateReminder(String id, Map<String, dynamic> updates) async {
    await _db.from('reminders').update(updates).eq('id', id);
    _invalidate();
  }

  Future<void> deleteReminder(String id) async {
    await _db.from('reminders').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
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
