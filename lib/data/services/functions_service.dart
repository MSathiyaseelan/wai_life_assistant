import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/constants/api_endpoints.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/data/services/wallet_service.dart';

/// Thrown by [FunctionsService]'s add methods when the caller's standing
/// count cap for that Functions list (personal or shared family pool) is
/// exhausted — deleting an existing entry frees up a slot for another.
class FunctionLimitExceededException implements Exception {
  final int limit;
  final String label;
  const FunctionLimitExceededException(this.limit, this.label);
  @override
  String toString() =>
      "You've reached the $limit $label on your plan. Remove one or upgrade to add more.";
}

class FunctionsService {
  FunctionsService._();
  static final FunctionsService instance = FunctionsService._();

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
      throw FunctionLimitExceededException(limit, label);
    }
  }

  /// Sum of `amount` across a function's `gifts` JSONB list (same shape as
  /// PlannedGiftItem.toJson — gifts without an amount contribute 0).
  double _giftsTotal(dynamic gifts) {
    if (gifts is! List) return 0;
    return gifts.fold<double>(0, (sum, g) {
      final amount = (g as Map?)?['amount'];
      return sum + ((amount is num) ? amount.toDouble() : 0);
    });
  }

  /// Creates the matching Personal-wallet expense for an attended function's
  /// gift, the first time it has a recorded amount — fire-and-forget aside
  /// from returning the new transaction id to store on the function row, so
  /// this never runs twice for the same function.
  Future<String?> _syncGiftToWallet({
    required String personalWalletId,
    required dynamic gifts,
    required String functionName,
    String? personName,
    String? familyName,
    String? functionDate,
  }) async {
    final total = _giftsTotal(gifts);
    if (total <= 0) return null;
    try {
      final who = personName ?? familyName;
      final row = await WalletService.instance.addTransaction(
        walletId: personalWalletId,
        type: 'expense',
        amount: total,
        category: '🎁 Gifts',
        title: functionName,
        note: who != null ? 'Gift given at $functionName for $who' : 'Gift given at $functionName',
        date: functionDate != null ? DateTime.tryParse(functionDate) : null,
      );
      return row['id'] as String?;
    } catch (e) {
      // Never let the wallet sync block saving the attended function itself.
      if (e is! TransactionLimitExceededException) {
        ErrorLogger.warning(e, action: 'sync_attended_gift_to_wallet');
      }
      return null;
    }
  }

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
    await _enforceCountLimit(
      table: 'functions_my',
      walletId: data['wallet_id'] as String,
      feature: 'my_function',
      label: 'My Functions',
    );
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
    await _enforceCountLimit(
      table: 'functions_upcoming',
      walletId: data['wallet_id'] as String,
      feature: 'upcoming_function',
      label: 'Upcoming Functions',
    );
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

  /// [personalWalletId] enables auto-logging the gift as a Personal-wallet
  /// expense — pass it whenever the caller has it (my_functions_screen.dart
  /// always does). Omitted only for callers that don't want the sync.
  Future<Map<String, dynamic>> addAttended(
    Map<String, dynamic> data, {
    String? personalWalletId,
  }) async {
    await _enforceCountLimit(
      table: 'functions_attended',
      walletId: data['wallet_id'] as String,
      feature: 'attended_function',
      label: 'Attended Functions',
    );
    var row = await _db
        .from('functions_attended')
        .insert({...data, 'user_id': _uid})
        .select()
        .single();

    if (personalWalletId != null) {
      final txId = await _syncGiftToWallet(
        personalWalletId: personalWalletId,
        gifts: row['gifts'],
        functionName: row['function_name'] as String? ?? '',
        personName: row['person_name'] as String?,
        familyName: row['family_name'] as String?,
        functionDate: row['date'] as String?,
      );
      if (txId != null) {
        row = await _db
            .from('functions_attended')
            .update({'wallet_tx_id': txId})
            .eq('id', row['id'] as String)
            .select()
            .single();
      }
    }
    return row;
  }

  /// Same [personalWalletId] contract as [addAttended] — only touches the
  /// wallet when [updates] touches `gifts`. If this function has no linked
  /// transaction yet, one is created (as before). If it's already linked,
  /// the existing transaction's amount is kept in sync with the edited gift
  /// total instead of going stale — and if every gift is removed, the
  /// now-pointless transaction is deleted and unlinked.
  Future<void> updateAttended(
    String id,
    Map<String, dynamic> updates, {
    String? personalWalletId,
  }) async {
    if (personalWalletId != null && updates.containsKey('gifts')) {
      final existing = await _db
          .from('functions_attended')
          .select('wallet_tx_id, function_name, person_name, family_name, date')
          .eq('id', id)
          .maybeSingle();
      final existingTxId = existing?['wallet_tx_id'] as String?;
      if (existing != null && existingTxId == null) {
        final txId = await _syncGiftToWallet(
          personalWalletId: personalWalletId,
          gifts: updates['gifts'],
          functionName: (existing['function_name'] as String?) ?? '',
          personName: existing['person_name'] as String?,
          familyName: existing['family_name'] as String?,
          functionDate: existing['date'] as String?,
        );
        if (txId != null) updates = {...updates, 'wallet_tx_id': txId};
      } else if (existingTxId != null) {
        final newTotal = _giftsTotal(updates['gifts']);
        try {
          if (newTotal > 0) {
            await WalletService.instance.updateTransaction(existingTxId, {'amount': newTotal});
          } else {
            // All gifts removed — the linked expense no longer applies.
            await WalletService.instance.deleteTransaction(existingTxId);
            updates = {...updates, 'wallet_tx_id': null};
          }
        } catch (e) {
          ErrorLogger.warning(e, action: 'sync_attended_gift_to_wallet_update');
        }
      }
    }
    await _db.from('functions_attended').update(updates).eq('id', id);
  }

  Future<void> deleteAttended(String id) async {
    await _db.from('functions_attended').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  // ── Attended Function Groups ─────────────────────────────────────────────

  /// Fetch all attended_function_groups for a wallet.
  Future<List<Map<String, dynamic>>> fetchAttendedGroups(String walletId) async {
    final rows = await _db
        .from('attended_function_groups')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Create a new attended-function group.
  Future<Map<String, dynamic>> createAttendedGroup({
    required String walletId,
    required String name,
    String emoji = '👨‍👩‍👧',
  }) async {
    final row = await _db.from('attended_function_groups').insert({
      'wallet_id': walletId,
      'user_id': _uid,
      'name': name,
      'emoji': emoji,
    }).select().single();
    return row;
  }

  /// Rename / re-emoji a group.
  Future<void> updateAttendedGroup(String groupId, {String? name, String? emoji}) async {
    final fields = <String, dynamic>{};
    if (name != null) fields['name'] = name;
    if (emoji != null) fields['emoji'] = emoji;
    if (fields.isNotEmpty) {
      await _db.from('attended_function_groups').update(fields).eq('id', groupId);
    }
  }

  /// Delete a group (soft). Member functions stay but their group_id is set to NULL.
  Future<void> deleteAttendedGroup(String groupId) async {
    await _db.from('attended_function_groups').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', groupId);
  }

  /// Assign or remove an attended function from a group (groupId = null to ungroup).
  Future<void> setAttendedGroup(String functionId, String? groupId) async {
    await _db.from('functions_attended').update({'group_id': groupId}).eq('id', functionId);
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
