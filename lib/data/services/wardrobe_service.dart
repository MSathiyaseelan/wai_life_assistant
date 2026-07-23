import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/constants/api_endpoints.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';

/// Thrown by [WardrobeService.addItem] when the caller's standing wardrobe
/// item count cap (personal or shared family pool) is exhausted — deleting
/// an existing item frees up a slot for another.
class WardrobeLimitExceededException implements Exception {
  final int limit;
  const WardrobeLimitExceededException(this.limit);
  @override
  String toString() =>
      "You've reached the $limit wardrobe items on your plan. Remove one or upgrade to add more.";
}

class WardrobeService {
  WardrobeService._();
  static final WardrobeService instance = WardrobeService._();

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');
    return uid;
  }

  static const _bucket = 'wardrobe-photos';

  // ── Photo Storage ────────────────────────────────────────────────────────────

  Future<String> uploadPhoto(String localPath, {String memberId = 'me'}) async {
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    final ext = localPath.contains('.') ? localPath.split('.').last.toLowerCase() : 'jpg';
    final mime = switch (ext) {
      'png'  => 'image/png',
      'webp' => 'image/webp',
      'gif'  => 'image/gif',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _      => 'image/jpeg',
    };
    final storagePath = '$_uid/$memberId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _db.storage.from(_bucket).uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: false),
    );

    return _db.storage.from(_bucket).getPublicUrl(storagePath);
  }

  Future<void> deletePhoto(String? photoUrl) async {
    if (photoUrl == null || !photoUrl.contains(_bucket)) return;
    try {
      final uri = Uri.parse(photoUrl);
      final segments = uri.pathSegments;
      final bucketIdx = segments.indexOf(_bucket);
      if (bucketIdx >= 0 && bucketIdx < segments.length - 1) {
        final filePath = segments.sublist(bucketIdx + 1).join('/');
        await _db.storage.from(_bucket).remove([filePath]);
      }
    } catch (e, stack) {
      debugPrint('[Wardrobe] deletePhoto error: $e');
      ErrorLogger.log(e, stackTrace: stack, action: 'delete_wardrobe_photo');
    }
  }

  // ── Clothing Items ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchItems(String walletId) async {
    final rows = await _db
        .from('wardrobe_items')
        .select()
        .eq('wallet_id', walletId)
        .isFilter('deleted_at', null)
        .order('added_on', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> addItem(Map<String, dynamic> data) async {
    final limit = await _db.rpc(AppRpc.getEffectiveFeatureLimit, params: {
      'p_user_id': _uid,
      'p_feature': 'wardrobe_item',
    }) as int? ?? 30;
    if (limit != -1) {
      final walletId = data['wallet_id'] as String;
      final existing = await _db
          .from('wardrobe_items')
          .select('id')
          .eq('wallet_id', walletId)
          .isFilter('deleted_at', null);
      if ((existing as List).length >= limit) {
        throw WardrobeLimitExceededException(limit);
      }
    }
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
    await _db.from('wardrobe_items').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> restore(String table, String id) async {
    await _db.from(table).update({'deleted_at': null}).eq('id', id);
  }

  // ── Outfit Logs ─────────────────────────────────────────────────────────────

  /// Logging today's outfit always works regardless of plan — this only
  /// limits how far back history is *viewable*; older entries stay in the
  /// DB untouched and become visible again on upgrade.
  Future<List<Map<String, dynamic>>> fetchOutfitLogs(String walletId) async {
    final months = await _db.rpc(AppRpc.getEffectiveFeatureLimit, params: {
      'p_user_id': _uid,
      'p_feature': 'wardrobe_outfit_history',
    }) as int? ?? 1;

    var query = _db
        .from('wardrobe_outfit_logs')
        .select()
        .eq('wallet_id', walletId);
    if (months != -1) {
      final now = DateTime.now();
      final cutoff = DateTime(now.year, now.month - months, now.day);
      query = query.gte('date', cutoff.toIso8601String().split('T')[0]);
    }
    final rows = await query.order('date', ascending: false);
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
