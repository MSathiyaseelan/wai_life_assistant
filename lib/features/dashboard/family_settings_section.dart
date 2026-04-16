import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/supabase/profile_service.dart';
import 'package:wai_life_assistant/core/supabase/invite_service.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/AppStateNotifier.dart';
import 'package:wai_life_assistant/features/wallet/widgets/family_switcher_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FAMILY SETTINGS SECTION
// Shown in Dashboard Settings between Account and Preferences.
// ─────────────────────────────────────────────────────────────────────────────

class FamilySettingsSection extends StatefulWidget {
  final AppStateNotifier appState;
  final bool isDark;

  const FamilySettingsSection({
    super.key,
    required this.appState,
    required this.isDark,
  });

  @override
  State<FamilySettingsSection> createState() => _FamilySettingsSectionState();
}

class _FamilySettingsSectionState extends State<FamilySettingsSection> {
  bool _sectionExpanded = false;
  bool _myFamilyExpanded = false;
  bool _permissionsExpanded = false;
  bool _savingPerms = false;

  final _inviteCtrl = TextEditingController();

  // Permission state — initialised from FamilyModel, persisted to DB on change.
  String _invitePerm = 'admin_only';
  String _editPerm   = 'any_member';
  String _deletePerm = 'admin_only';

  // DB values → display labels
  static const _dbToLabel = {
    'admin_only': 'Admin only',
    'any_member': 'Any member',
  };
  static const _labelToDb = {
    'Admin only': 'admin_only',
    'Any member': 'any_member',
  };

  @override
  void initState() {
    super.initState();
    _syncPermsFromModel();
  }

  @override
  void didUpdateWidget(FamilySettingsSection old) {
    super.didUpdateWidget(old);
    if (old.appState.families != widget.appState.families) {
      _syncPermsFromModel();
    }
  }

  void _syncPermsFromModel() {
    final f = _family;
    if (f == null) return;
    _invitePerm = f.permInvite;
    _editPerm   = f.permEdit;
    _deletePerm = f.permDelete;
  }

  Future<void> _savePermission(
    String field,
    String dbValue,
  ) async {
    final f = _family;
    if (f == null) return;
    // Update in-memory model immediately so UI stays in sync
    if (field == 'perm_invite') f.permInvite = dbValue;
    if (field == 'perm_edit')   f.permEdit   = dbValue;
    if (field == 'perm_delete') f.permDelete = dbValue;
    // Persist to Supabase (admin-only via RLS)
    if (_savingPerms) return;
    setState(() => _savingPerms = true);
    try {
      await ProfileService.instance.updateFamilyPermissions(
        familyId:    f.id,
        permInvite:  f.permInvite,
        permEdit:    f.permEdit,
        permDelete:  f.permDelete,
      );
    } catch (_) {
      // Revert on failure
      _syncPermsFromModel();
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _savingPerms = false);
    }
  }

  @override
  void dispose() {
    _inviteCtrl.dispose();
    super.dispose();
  }

  FamilyModel? get _family =>
      widget.appState.families.isEmpty ? null : widget.appState.families.first;

  // ── Invite actions ────────────────────────────────────────────────────────────

  bool _sendingInvite = false;

  Future<void> _sendPhoneInvite(FamilyModel family) async {
    final phone = _inviteCtrl.text.trim();
    if (phone.isEmpty || _sendingInvite) return;
    HapticFeedback.lightImpact();
    setState(() => _sendingInvite = true);
    try {
      final result = await InviteService.instance.sendInvite(
        familyId: family.id,
        phone:    phone,
      );
      if (!mounted) return;
      _inviteCtrl.clear();
      final userFound = result['user_found'] as bool? ?? false;
      final msg = userFound
          ? 'Invite sent! They\'ll see it in their notifications.'
          : 'Invite created. Share the link so they can join once they sign up.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to send invite: $e'),
        backgroundColor: AppColors.expense,
      ));
    } finally {
      if (mounted) setState(() => _sendingInvite = false);
    }
  }

  Future<void> _shareInviteLink(FamilyModel family) async {
    HapticFeedback.lightImpact();
    try {
      final result = await InviteService.instance.createInviteLink(
        familyId: family.id,
      );
      final token = result['token'] as String? ?? '';
      if (!mounted) return;
      await Share.share(
        'Join "${family.name}" on WAI Life Assistant!\n'
        'Use invite code: $token\n'
        '(Code expires in 7 days)',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to generate invite link: $e'),
        backgroundColor: AppColors.expense,
      ));
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Color get _surfBg =>
      widget.isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
  Color get _sub =>
      widget.isDark ? AppColors.subDark : AppColors.subLight;
  Color get _tc =>
      widget.isDark ? AppColors.textDark : AppColors.textLight;

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final family = _family;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ────────────────────────────────────────────────────
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _sectionExpanded = !_sectionExpanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Text(
                  'FAMILY',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    fontFamily: 'Nunito',
                    color: _sub,
                  ),
                ),
                const Spacer(),
                Icon(
                  _sectionExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: _sub,
                ),
              ],
            ),
          ),
        ),

        if (_sectionExpanded) ...[
          // ── My Family card (only when family exists) ──────────────────────
          if (family != null) ...[
            _buildMyFamilyCard(context, family),
            const SizedBox(height: 8),
            _buildPermissionsCard(context),
            const SizedBox(height: 8),
          ],

          // ── Create Family (enabled only when below maxFamilyGroups) ─────────
          _buildCreateFamilyTile(context),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MY FAMILY CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMyFamilyCard(BuildContext context, FamilyModel family) {
    final sub = _sub;
    final tc = _tc;

    return Container(
      decoration: BoxDecoration(
        color: _surfBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Sub-section header
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDD5),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(family.emoji,
                  style: const TextStyle(fontSize: 20)),
            ),
            title: const Text(
              'My Family',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
              ),
            ),
            subtitle: Text(
              family.name,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Nunito',
                color: sub,
              ),
            ),
            trailing: Icon(
              _myFamilyExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: sub,
            ),
            onTap: () =>
                setState(() => _myFamilyExpanded = !_myFamilyExpanded),
          ),

          if (_myFamilyExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                    height: 1,
                    color: widget.isDark
                        ? Colors.white12
                        : Colors.black12,
                  ),
                  const SizedBox(height: 14),

                  // ── Family name ──────────────────────────────────────────
                  Row(
                    children: [
                      _sectionLabel('Family Name'),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          final wallet = widget.appState.wallets.firstWhere(
                            (w) => w.id == family.walletId,
                            orElse: () => personalWallet,
                          );
                          _showEditFamily(context, family, wallet);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      family.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Family photo ─────────────────────────────────────────
                  _sectionLabel('Family Photo'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      // Photo picker — handled in edit form
                      final wallet = widget.appState.wallets.firstWhere(
                        (w) => w.id == family.walletId,
                        orElse: () => personalWallet,
                      );
                      _showEditFamily(context, family, wallet);
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: family.photoPath != null &&
                                  family.photoPath!.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    family.photoPath!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Text(
                                  family.emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Tap to change family photo',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Nunito',
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Members list ─────────────────────────────────────────
                  Row(
                    children: [
                      _sectionLabel('Members'),
                      const Spacer(),
                      Text(
                        '${family.members.length} member${family.members.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...family.members.asMap().entries.map((entry) {
                    final i = entry.key;
                    final m = entry.value;
                    return _buildMemberRow(context, m, i, family);
                  }),
                  const SizedBox(height: 14),

                  // ── Invite Member (gated by perm_invite) ─────────────────
                  _sectionLabel('Invite Member'),
                  const SizedBox(height: 8),
                  if (family.canInvite) ...[
                    // By phone
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            child: TextField(
                              controller: _inviteCtrl,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'Nunito',
                                color: tc,
                              ),
                              decoration: InputDecoration.collapsed(
                                hintText: '+91 phone number',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Nunito',
                                  color: sub,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _sendPhoneInvite(family),
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Invite',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Share invite link
                    GestureDetector(
                      onTap: () => _shareInviteLink(family),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.link_rounded,
                                size: 16,
                                color: AppColors.primary),
                            const SizedBox(width: 6),
                            const Text(
                              'Share Invite Link',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 13, color: sub),
                          const SizedBox(width: 8),
                          Text(
                            'Only admins can invite members',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // ── Leave Family ─────────────────────────────────────────
                  GestureDetector(
                    onTap: () =>
                        _confirmLeaveFamily(context, family),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.exit_to_app_rounded,
                              size: 16, color: Colors.red),
                          SizedBox(width: 6),
                          Text(
                            'Leave Family',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Delete Family (admin only) ─────────────────────────────
                  if (family.isAdmin) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () =>
                          _confirmDeleteFamily(context, family),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_forever_rounded,
                                size: 16, color: Colors.red),
                            SizedBox(width: 6),
                            Text(
                              'Delete Family',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Member row ───────────────────────────────────────────────────────────────

  Widget _buildMemberRow(
    BuildContext context,
    FamilyMember m,
    int index,
    FamilyModel family,
  ) {
    final sub = _sub;
    final isFirst = index == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: m.photoPath != null && m.photoPath!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(m.photoPath!,
                          width: 36, height: 36, fit: BoxFit.cover),
                    )
                  : Text(m.emoji,
                      style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            // Name + role
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: _tc,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        m.role.emoji,
                        style: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        m.role.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Nunito',
                          color: m.role == MemberRole.admin
                              ? AppColors.primary
                              : sub,
                          fontWeight: m.role == MemberRole.admin
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Admin actions (not on self = first member)
            if (!isFirst) ...[
              GestureDetector(
                onTap: () =>
                    _showChangeRoleDialog(context, m, family),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Role',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () =>
                    _confirmRemoveMember(context, m, family),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Remove',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FAMILY PERMISSIONS CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPermissionsCard(BuildContext context) {
    final sub = _sub;
    final isAdmin = _family?.isAdmin ?? false;

    return Container(
      decoration: BoxDecoration(
        color: _surfBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E0FF),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text('🔐',
                  style: TextStyle(fontSize: 18)),
            ),
            title: const Text(
              'Family Permissions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
              ),
            ),
            subtitle: Text(
              isAdmin
                  ? 'Control what members can do'
                  : 'Only admins can change permissions',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Nunito',
                color: sub,
              ),
            ),
            trailing: Icon(
              _permissionsExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: sub,
            ),
            onTap: () => setState(
                () => _permissionsExpanded = !_permissionsExpanded),
          ),
          if (_permissionsExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                children: [
                  Divider(
                    height: 1,
                    color: widget.isDark
                        ? Colors.white12
                        : Colors.black12,
                  ),
                  const SizedBox(height: 12),
                  _buildPermissionRow(
                    icon: '👥',
                    label: 'Who can invite members',
                    currentDb: _invitePerm,
                    isEditable: isAdmin,
                    onChanged: (db) {
                      setState(() => _invitePerm = db);
                      _savePermission('perm_invite', db);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildPermissionRow(
                    icon: '✏️',
                    label: 'Who can edit entries',
                    currentDb: _editPerm,
                    isEditable: isAdmin,
                    onChanged: (db) {
                      setState(() => _editPerm = db);
                      _savePermission('perm_edit', db);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildPermissionRow(
                    icon: '🗑️',
                    label: 'Who can delete entries',
                    currentDb: _deletePerm,
                    isEditable: isAdmin,
                    onChanged: (db) {
                      setState(() => _deletePerm = db);
                      _savePermission('perm_delete', db);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// [currentDb] is a DB value ('admin_only' | 'any_member').
  /// [onChanged] receives the new DB value.
  Widget _buildPermissionRow({
    required String icon,
    required String label,
    required String currentDb,
    required bool isEditable,
    required void Function(String db) onChanged,
  }) {
    const options = <String, String>{
      'Admin only': 'admin_only',
      'Any member': 'any_member',
    };
    final sub = _sub;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  color: _tc,
                ),
              ),
            ),
            if (!isEditable)
              Icon(Icons.lock_outline_rounded, size: 12, color: sub),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: options.entries.map((entry) {
            final displayLabel = entry.key;
            final dbValue = entry.value;
            final selected = dbValue == currentDb;
            final isFirst = entry.key == options.keys.first;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: isFirst ? 5 : 0,
                  left: isFirst ? 0 : 5,
                ),
                child: GestureDetector(
                  onTap: isEditable && !_savingPerms
                      ? () {
                          HapticFeedback.lightImpact();
                          onChanged(dbValue);
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? (isEditable
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.45))
                          : (widget.isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      displayLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: selected ? Colors.white : sub,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CREATE FAMILY TILE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCreateFamilyTile(BuildContext context) {
    final currentCount = widget.appState.families.length;
    final maxAllowed  = widget.appState.maxFamilyGroups;
    final isEnabled   = currentCount < maxAllowed;

    final tileColor  = isEnabled
        ? AppColors.primary.withValues(alpha: 0.06)
        : (widget.isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03));
    final borderColor = isEnabled
        ? AppColors.primary.withValues(alpha: 0.18)
        : (widget.isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08));
    final iconBg = isEnabled
        ? AppColors.primary.withValues(alpha: 0.12)
        : (widget.isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06));
    final iconColor  = isEnabled ? AppColors.primary : _sub;
    final titleColor = isEnabled ? AppColors.primary : _sub;
    final subtitle   = isEnabled
        ? 'Add a new family or group'
        : 'Limit reached ($currentCount/$maxAllowed families)';

    return GestureDetector(
      onTap: isEnabled
          ? () async {
              HapticFeedback.lightImpact();
              final newId = await showAddFamilySheet(
                context,
                widget.isDark,
                widget.appState,
              );
              if (newId != null && mounted) {
                widget.appState.switchWallet(newId);
                setState(() {});
              }
            }
          : () => HapticFeedback.heavyImpact(),
      child: Container(
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEnabled
                  ? Icons.group_add_rounded
                  : Icons.lock_outline_rounded,
              size: 18,
              color: iconColor,
            ),
          ),
          title: Text(
            'Create Family',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: 'Nunito',
              color: titleColor,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'Nunito',
              color: _sub,
            ),
          ),
          trailing: Icon(
            isEnabled
                ? Icons.arrow_forward_ios_rounded
                : Icons.block_rounded,
            size: 13,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOGS & SHEETS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showEditFamily(
    BuildContext context,
    FamilyModel family,
    WalletModel wallet,
  ) {
    showEditFamilySheet(
      context,
      family,
      wallet,
      widget.isDark,
      widget.appState,
    ).then((_) => setState(() {}));
  }

  void _showChangeRoleDialog(
    BuildContext context,
    FamilyMember member,
    FamilyModel family,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          'Change Role — ${member.name}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: MemberRole.values.map((role) {
            final selected = role == member.role;
            return ListTile(
              leading: Text(role.emoji,
                  style: const TextStyle(fontSize: 20)),
              title: Text(
                role.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: selected
                  ? const Icon(Icons.check_rounded,
                      color: AppColors.primary)
                  : null,
              onTap: () {
                Navigator.pop(dialogCtx);
                setState(() => member.role = role);
                // TODO: persist role change to backend
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _confirmRemoveMember(
    BuildContext context,
    FamilyMember member,
    FamilyModel family,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text(
          'Remove Member',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
        content: Text(
          'Remove ${member.name} from the family? They will lose access to shared data.',
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'Nunito',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Nunito')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              setState(() => family.members.remove(member));
              // TODO: persist removal to backend
            },
            child: const Text(
              'Remove',
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveFamily(BuildContext context, FamilyModel family) {
    // Check if user is the only admin
    final adminCount = family.members
        .where((m) => m.role == MemberRole.admin)
        .length;
    final isLastAdmin = adminCount == 1 &&
        family.members.isNotEmpty &&
        family.members.first.role == MemberRole.admin;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Leave Family',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
        content: Text(
          isLastAdmin
              ? 'You are the only admin. Please transfer admin to another member before leaving.'
              : 'Are you sure you want to leave "${family.name}"?',
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'Nunito',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Nunito')),
          ),
          if (!isLastAdmin)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.appState.switchWallet(
                    widget.appState.wallets
                        .firstWhere((w) => w.isPersonal,
                            orElse: () => personalWallet)
                        .id);
                // TODO: persist leave-family action to backend
                setState(() {});
              },
              child: const Text(
                'Leave',
                style: TextStyle(
                  color: Colors.red,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (isLastAdmin)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Show role assignment dialog first
                if (family.members.length > 1) {
                  _showTransferAdminDialog(
                      context, family);
                }
              },
              child: const Text(
                'Transfer Admin',
                style: TextStyle(
                  color: AppColors.primary,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDeleteFamily(BuildContext context, FamilyModel family) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Delete Family',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            color: Colors.red,
          ),
        ),
        content: Text(
          'Delete "${family.name}"? The family and all its transactions will be archived and hidden. This cannot be undone.',
          style: const TextStyle(fontSize: 13, fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Nunito')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ProfileService.instance.deleteFamily(family.id);
                if (mounted) {
                  // Switch to personal wallet and refresh
                  widget.appState.switchWallet(
                    widget.appState.wallets
                        .firstWhere((w) => w.isPersonal,
                            orElse: () => personalWallet)
                        .id,
                  );
                  await widget.appState.reload();
                  if (mounted) setState(() {});
                }
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete family. Try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransferAdminDialog(
      BuildContext context, FamilyModel family) {
    final others = family.members.skip(1).toList();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Transfer Admin',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select a member to become the new admin:',
              style: TextStyle(fontSize: 12, fontFamily: 'Nunito'),
            ),
            const SizedBox(height: 8),
            ...others.map((m) => ListTile(
                  leading: Text(m.emoji,
                      style: const TextStyle(fontSize: 18)),
                  title: Text(m.name,
                      style: const TextStyle(
                          fontSize: 13, fontFamily: 'Nunito')),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      family.members.first.role = MemberRole.member;
                      m.role = MemberRole.admin;
                    });
                    // TODO: persist transfer + leave to backend
                  },
                )),
          ],
        ),
      ),
    );
  }

  // ── Shared label widget ───────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        fontFamily: 'Nunito',
        color: _sub,
        letterSpacing: 0.2,
      ),
    );
  }
}

