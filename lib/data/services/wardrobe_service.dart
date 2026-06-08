import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WardrobeService {
  WardrobeService._();
  static final WardrobeService instance = WardrobeService._();

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  static const _bucket = 'wardrobe-photos';

  // ── Photo Storage ────────────────────────────────────────────────────────────

  /// Uploads [localPath] to Supabase Storage under `{uid}/{memberId}/` and returns the public URL.
  Future<String> uploadPhoto(String localPath, {String memberId = 'me'}) async {
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    final ext = localPath.contains('.') ? localPath.split('.').last.toLowerCase() : 'jpg';
    final storagePath = '$_uid/$memberId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _db.storage.from(_bucket).uploadBinary(
      storagePath,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
    );

    return _db.storage.from(_bucket).getPublicUrl(storagePath);
  }

  /// Deletes the file at [photoUrl] from Supabase Storage (no-op if not a storage URL).
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
    } catch (e) {
      debugPrint('[Wardrobe] deletePhoto error: $e');
    }
  }

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
