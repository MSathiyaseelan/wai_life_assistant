import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wai_life_assistant/core/constants/api_endpoints.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/wallet/wallet_models.dart';
import '../models/subscription/subscription_models.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';

/// Handles profile setup, personal vs family selection, and family management.
/// All methods throw [PostgrestException] / [Exception] on failure.
class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');
    return uid;
  }

  // ── Onboarding ────────────────────────────────────────────────────────────

  /// Call once after OTP verification completes.
  /// Creates profile row + personal wallet atomically via DB function.
  /// Returns { profile_id, wallet_id }.
  Future<Map<String, dynamic>> bootstrapNewUser({
    String name = '',
    String emoji = '👤',
  }) async {
    final result = await _db.rpc(AppRpc.bootstrapNewUser, params: {
      'p_name': name,
      'p_emoji': emoji,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  /// Dev-bypass: find any existing profile mapped to [phone] and migrate all
  /// its data (wallets, transactions, families, etc.) to the current user.
  /// Returns true if a migration happened, false if no old profile was found.
  Future<bool> linkProfileByPhone(String phone) async {
    final result = await _db.rpc(AppRpc.devLinkProfileByPhone, params: {
      'p_phone': phone,
    });
    return result as bool? ?? false;
  }

  /// Returns true if the current user has already been onboarded.
  Future<bool> isOnboarded() async {
    final row = await _db
        .from('profiles')
        .select('onboarded')
        .eq('id', _uid)
        .maybeSingle();
    return row?['onboarded'] == true;
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  /// Fetch the current user's profile row.
  Future<Map<String, dynamic>?> fetchProfile() async {
    return await _db
        .from('profiles')
        .select()
        .eq('id', _uid)
        .maybeSingle();
  }

  /// Update display name, emoji, date of birth, and/or photo URL.
  Future<void> updateProfile({
    String? name,
    String? emoji,
    String? dob,
    String? photoUrl,
  }) async {
    await _db.from('profiles').update({
      if (name != null)     'name': name,
      if (emoji != null)    'emoji': emoji,
      if (dob != null)      'dob': dob,
      if (photoUrl != null) 'photo_url': photoUrl,
    }).eq('id', _uid);
  }

  /// Persist default scope preferences (Personal / Family) for each tab.
  Future<void> updateDefaultScopes({
    required String walletScope,
    required String pantryScope,
    required String planItScope,
  }) async {
    await _db.from('profiles').update({
      'wallet_scope': walletScope,
      'pantry_scope': pantryScope,
      'planit_scope': planItScope,
    }).eq('id', _uid);
  }

  // ── FamilySwitcher seed data ──────────────────────────────────────────────

  /// Loads everything the FamilySwitcherSheet needs in a single round-trip:
  /// profile + personal wallet balance + all families with members + wallet ids.
  ///
  /// Returns the row from the `my_profile_with_families` view.
  Future<Map<String, dynamic>?> fetchSwitcherData() async {
    final row = await _db
        .from('my_profile_with_families')
        .select()
        .maybeSingle();
    return row;
  }

  /// Convert the raw Supabase row from [fetchSwitcherData] into app models.
  ({WalletModel personal, List<FamilyModel> families, List<WalletModel> familyWallets})
      parseSwitcherData(Map<String, dynamic> row) {
    // Personal wallet
    final personal = WalletModel(
      id: row['personal_wallet_id'] as String,
      name: 'Personal',
      emoji: row['emoji'] as String? ?? '👤',
      isPersonal: true,
      cashIn:    (row['cash_in']    as num?)?.toDouble() ?? 0,
      cashOut:   (row['cash_out']   as num?)?.toDouble() ?? 0,
      onlineIn:  (row['online_in']  as num?)?.toDouble() ?? 0,
      onlineOut: (row['online_out'] as num?)?.toDouble() ?? 0,
      gradient: AppColors.personalGrad,
    );

    // Families + their wallets
    final rawFamilies = (row['families'] as List<dynamic>?) ?? [];
    final families = <FamilyModel>[];
    final familyWallets = <WalletModel>[];

    for (final f in rawFamilies) {
      final fm = Map<String, dynamic>.from(f as Map);
      final colorIdx = (fm['color_index'] as int?) ?? 0;

      // Members
      final rawMembers = (fm['members'] as List<dynamic>?) ?? [];
      final members = rawMembers.map((m) {
        final mm = Map<String, dynamic>.from(m as Map);
        return FamilyMember(
          id:       mm['id'] as String,
          userId:   mm['user_id'] as String?,
          name:     mm['name'] as String,
          emoji:    mm['emoji'] as String? ?? '👤',
          role:     _parseRole(mm['role'] as String?),
          phone:    mm['phone'] as String?,
          relation: mm['relation'] as String?,
        );
      }).toList();

      families.add(FamilyModel(
        id:         fm['family_id'] as String,
        name:       fm['name'] as String,
        emoji:      fm['emoji'] as String? ?? '👥',
        colorIndex: colorIdx,
        members:    members,
        walletId:   fm['wallet_id'] as String?,
        myRole:     _parseRole(fm['my_role'] as String?),
        permInvite: fm['perm_invite'] as String? ?? 'admin_only',
        permEdit:   fm['perm_edit']   as String? ?? 'any_member',
        permDelete: fm['perm_delete'] as String? ?? 'admin_only',
      ));

      if (fm['wallet_id'] != null) {
        final gradients = AppColors.familyGradients;
        familyWallets.add(WalletModel(
          id:        fm['wallet_id'] as String,
          name:      fm['name'] as String,
          emoji:     fm['emoji'] as String? ?? '👥',
          isPersonal: false,
          cashIn:    0, cashOut: 0,
          onlineIn:  0, onlineOut: 0,
          gradient: gradients[colorIdx % gradients.length],
        ));
      }
    }

    return (personal: personal, families: families, familyWallets: familyWallets);
  }

  MemberRole _parseRole(String? r) {
    switch (r) {
      case 'admin':  return MemberRole.admin;
      case 'viewer': return MemberRole.viewer;
      default:       return MemberRole.member;
    }
  }

  // ── Family CRUD ───────────────────────────────────────────────────────────

  /// Create a family, add creator as admin, and create its linked wallet.
  /// Returns { family_id, wallet_id }.
  Future<Map<String, dynamic>> createFamily({
    required String name,
    required String emoji,
    int colorIndex = 0,
    String? description,
  }) async {
    final result = await _db.rpc(AppRpc.createFamilyWithWallet, params: {
      'p_name':        name,
      'p_emoji':       emoji,
      'p_color_index': colorIndex,
      'p_description': description,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  /// Update family name/emoji/color. Also syncs the linked wallet.
  Future<void> updateFamily({
    required String familyId,
    required String name,
    required String emoji,
    int colorIndex = 0,
    String? description,
  }) async {
    await _db.rpc(AppRpc.updateFamily, params: {
      'p_family_id':   familyId,
      'p_name':        name,
      'p_emoji':       emoji,
      'p_color_index': colorIndex,
      'p_description': description,
    });
  }

  /// Delete a family (admin only). Cascades wallets, transactions, splits.
  Future<void> deleteFamily(String familyId) async {
    await _db.rpc(AppRpc.deleteFamily, params: {'p_family_id': familyId});
  }

  // ── Member CRUD ───────────────────────────────────────────────────────────

  /// Add a member to a family via RPC (SECURITY DEFINER bypasses RLS).
  Future<void> addMember({
    required String familyId,
    required String name,
    required String emoji,
    String role = 'member',
    String? relation,
    String? phone,
  }) async {
    await _db.rpc(AppRpc.addFamilyMember, params: {
      'p_family_id': familyId,
      'p_name':      name,
      'p_emoji':     emoji,
      'p_role':      role,
      'p_relation':  relation,
      'p_phone':     phone,
    });
  }

  /// Update a member's editable fields via SECURITY DEFINER RPC (bypasses RLS).
  Future<void> updateMember(
    String memberId,
    Map<String, dynamic> updates,
  ) async {
    await _db.rpc(AppRpc.updateFamilyMember, params: {
      'p_member_id': memberId,
      'p_name':      updates['name'],
      'p_emoji':     updates['emoji'],
      'p_role':      updates['role'],
      'p_phone':     updates['phone'],
      'p_relation':  updates['relation'],
    });
  }

  /// Remove a member from a family (soft delete).
  Future<void> removeMember(String memberId) async {
    await _db.from('family_members').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', memberId);
  }

  Future<void> restore(String table, String id) async {
    await _db.from(table).update({'deleted_at': null}).eq('id', id);
  }

  /// Update family permission settings (admin only — enforced by RLS).
  Future<void> updateFamilyPermissions({
    required String familyId,
    required String permInvite,
    required String permEdit,
    required String permDelete,
  }) async {
    await _db.from('families').update({
      'perm_invite': permInvite,
      'perm_edit':   permEdit,
      'perm_delete': permDelete,
    }).eq('id', familyId);
  }

  /// Fetch members of a specific family.
  Future<List<Map<String, dynamic>>> fetchMembers(String familyId) async {
    final rows = await _db
        .from('family_members')
        .select()
        .eq('family_id', familyId)
        .isFilter('deleted_at', null)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Same as [fetchMembers] but includes soft-deleted members — used to keep
  /// past transaction "added by" labels visible after a member leaves.
  Future<List<Map<String, dynamic>>> fetchAllMembers(String familyId) async {
    final rows = await _db
        .from('family_members')
        .select()
        .eq('family_id', familyId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  // ── Photo Upload ──────────────────────────────────────────────────────────

  /// Upload a local image file to Supabase Storage and return its public URL.
  /// [folder] is either 'families' or 'members'.
  /// [name] is a unique identifier (e.g. family_id or member_id).
  Future<String> uploadPhoto({
    required String localPath,
    required String folder,
    required String name,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) throw Exception('Photo file not found: $localPath');
    final ext = localPath.contains('.')
        ? localPath.split('.').last.toLowerCase().replaceAll(RegExp(r'\?.*'), '')
        : 'jpg';
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    // Sanitise name to avoid path issues
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final filename = '$folder/${_uid}_$safeName.$ext';
    debugPrint('[Storage] uploading to wai-photos/$filename');
    await _db.storage.from('wai-photos').upload(
      filename,
      file,
      fileOptions: FileOptions(upsert: true, contentType: contentType),
    );
    final url = _db.storage.from('wai-photos').getPublicUrl(filename);
    debugPrint('[Storage] uploaded → $url');
    return url;
  }

  // ── Subscription plans ────────────────────────────────────────────────────

  /// Fetches all active subscription plans with their limits.
  /// Returns plans ordered by sort_order (personal_free → family_plus → family_pro).
  Future<List<SubscriptionPlanData>> fetchSubscriptionPlans() async {
    final rows = await _db
        .from('subscription_plans')
        .select('plan_key, name, price_monthly, price_yearly, plan_limits(*)')
        .eq('is_active', true)
        .order('sort_order');
    return (rows as List)
        .map((r) => SubscriptionPlanData.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Returns the maximum number of family members allowed by the user's current plan.
  /// Returns 0 for personal_free (no family groups allowed).
  Future<int> fetchMaxFamilyMembers() async {
    try {
      final profile = await _db
          .from('profiles')
          .select('plan')
          .eq('id', _uid)
          .maybeSingle();
      final planKey = (profile?['plan'] as String?) ?? 'personal_free';
      final planRow = await _db
          .from('subscription_plans')
          .select('plan_limits!inner(family_max_members)')
          .eq('plan_key', planKey)
          .maybeSingle();
      return (planRow?['plan_limits']?['family_max_members'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
