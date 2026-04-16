import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InviteService — family invite send / accept / decline / join-by-token
// ─────────────────────────────────────────────────────────────────────────────

class InviteService {
  InviteService._();
  static final InviteService instance = InviteService._();

  SupabaseClient get _db => Supabase.instance.client;

  // ── Send a phone-based invite ─────────────────────────────────────────────
  /// Creates an invite record and, if the phone belongs to an existing WAI
  /// user, pushes an in-app notification to them.
  /// Returns a map with keys: invite_id, token, user_found (bool).
  Future<Map<String, dynamic>> sendInvite({
    required String familyId,
    required String phone,
    String role = 'member',
  }) async {
    final result = await _db.rpc('send_family_invite', params: {
      'p_family_id': familyId,
      'p_phone':     phone,
      'p_role':      role,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  // ── Generate a shareable invite link / token ──────────────────────────────
  /// Creates an open-ended invite (no specific phone). Returns invite_id and
  /// token so the caller can share the token string.
  Future<Map<String, dynamic>> createInviteLink({
    required String familyId,
    String role = 'member',
  }) async {
    final result = await _db.rpc('create_invite_link', params: {
      'p_family_id': familyId,
      'p_role':      role,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  // ── Accept ────────────────────────────────────────────────────────────────
  Future<bool> acceptInvite(String inviteId) async {
    final result = await _db.rpc('accept_family_invite', params: {
      'p_invite_id': inviteId,
    });
    return result as bool? ?? false;
  }

  // ── Decline ───────────────────────────────────────────────────────────────
  Future<void> declineInvite(String inviteId) async {
    await _db.rpc('decline_family_invite', params: {
      'p_invite_id': inviteId,
    });
  }

  // ── Join by token (invite code) ───────────────────────────────────────────
  Future<Map<String, dynamic>> joinByToken(String token) async {
    final result = await _db.rpc('join_family_by_token', params: {
      'p_token': token.trim().toUpperCase(),
    });
    return Map<String, dynamic>.from(result as Map);
  }
}
