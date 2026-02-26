import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:flutter/services.dart';

class FamilySwitcherSheet extends StatefulWidget {
  final String currentWalletId;
  final void Function(String walletId) onSelect;
  final bool isDashboard;

  const FamilySwitcherSheet({
    super.key,
    required this.currentWalletId,
    required this.onSelect,
    this.isDashboard = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentWalletId,
    required void Function(String) onSelect,
    bool isDashboard = false,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FamilySwitcherSheet(
        currentWalletId: currentWalletId,
        onSelect: onSelect,
        isDashboard: isDashboard,
      ),
    );
  }

  @override
  State<FamilySwitcherSheet> createState() => _FamilySwitcherSheetState();
}

class _FamilySwitcherSheetState extends State<FamilySwitcherSheet> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final all = [personalWallet, ...familyWallets];

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Switch View',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                  ),
                ),
                Text(
                  'Choose personal or a family/group',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WalletTile(
                    wallet: personalWallet,
                    family: null,
                    isSelected: widget.currentWalletId == 'personal',
                    isDark: isDark,
                    surfBg: surfBg,
                    tc: tc,
                    sub: sub,
                    onTap: () {
                      widget.onSelect('personal');
                      Navigator.pop(context);
                    },
                    onEdit: null,
                  ),
                  const SizedBox(height: 8),
                  ...familyWallets.asMap().entries.map((entry) {
                    final w = entry.value;
                    final family = mockFamilies.firstWhere(
                      (f) => f.id == w.id,
                      orElse: () => FamilyModel(
                        id: w.id,
                        name: w.name,
                        emoji: w.emoji,
                        colorIndex: 0,
                      ),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _WalletTile(
                        wallet: w,
                        family: family,
                        isSelected: widget.currentWalletId == w.id,
                        isDark: isDark,
                        surfBg: surfBg,
                        tc: tc,
                        sub: sub,
                        onTap: () {
                          widget.onSelect(w.id);
                          Navigator.pop(context);
                        },
                        onEdit: () async {
                          Navigator.pop(context);
                          await _showEditFamily(context, family, w, isDark);
                          setState(() {});
                        },
                      ),
                    );
                  }).toList(),
                  if (!widget.isDashboard) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        final newId = await _showAddFamily(context, isDark);
                        if (newId != null) widget.onSelect(newId);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.4),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_add_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Add New Family / Group',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                fontFamily: 'Nunito',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  final WalletModel wallet;
  final FamilyModel? family;
  final bool isSelected, isDark;
  final Color surfBg, tc, sub;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  const _WalletTile({
    required this.wallet,
    required this.family,
    required this.isSelected,
    required this.isDark,
    required this.surfBg,
    required this.tc,
    required this.sub,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final memberCount = family?.members.length ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: wallet.gradient) : null,
          color: isSelected ? null : surfBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : wallet.gradient[0].withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Text(wallet.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: isSelected ? Colors.white : tc,
                    ),
                  ),
                  Text(
                    wallet.isPersonal
                        ? 'Your personal view'
                        : '$memberCount member${memberCount != 1 ? "s" : ""}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      color: isSelected ? Colors.white70 : sub,
                    ),
                  ),
                ],
              ),
            ),
            if (!wallet.isPersonal && family != null && !isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _MemberAvatarStack(family!.members),
              ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 22,
              )
            else if (onEdit != null)
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: wallet.gradient[0].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: wallet.gradient[0],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberAvatarStack extends StatelessWidget {
  final List<FamilyMember> members;
  const _MemberAvatarStack(this.members);
  @override
  Widget build(BuildContext context) {
    final shown = members.take(3).toList();
    final extra = members.length - shown.length;
    return SizedBox(
      width: shown.length * 20.0 + (extra > 0 ? 22 : 0),
      height: 26,
      child: Stack(
        children: [
          ...shown.asMap().entries.map(
            (e) => Positioned(
              left: e.key * 18.0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  e.value.emoji,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          if (extra > 0)
            Positioned(
              left: shown.length * 18.0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.subLight.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$extra',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: AppColors.subLight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<String?> _showAddFamily(BuildContext context, bool isDark) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _FamilyFormSheet(isDark: isDark, existing: null),
  );
}

Future<void> _showEditFamily(
  BuildContext context,
  FamilyModel family,
  WalletModel wallet,
  bool isDark,
) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) =>
        _FamilyFormSheet(isDark: isDark, existing: family, wallet: wallet),
  );
}

class _FamilyFormSheet extends StatefulWidget {
  final bool isDark;
  final FamilyModel? existing;
  final WalletModel? wallet;
  const _FamilyFormSheet({
    required this.isDark,
    required this.existing,
    this.wallet,
  });
  @override
  State<_FamilyFormSheet> createState() => _FamilyFormSheetState();
}

class _FamilyFormSheetState extends State<_FamilyFormSheet> {
  final _nameCtrl = TextEditingController();
  String _selectedEmoji = '👨\u200d👩\u200d👧';
  final List<FamilyMember> _members = [];

  static const _groupEmojis = [
    '👨\u200d👩\u200d👧',
    '👨\u200d👩\u200d👦',
    '👪',
    '👥',
    '🏠',
    '💼',
    '🎓',
    '❤️',
    '🌟',
    '🤝',
    '⚽',
    '🎵',
    '🏋️',
    '🍕',
    '🎮',
  ];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.existing!.name;
      _selectedEmoji = widget.existing!.emoji;
      _members.addAll(
        widget.existing!.members.map(
          (m) => FamilyMember(
            id: m.id,
            name: m.name,
            emoji: m.emoji,
            role: m.role,
            phone: m.phone,
            relation: m.relation,
          ),
        ),
      );
    } else {
      _members.add(
        FamilyMember(
          id: 'me_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Me',
          emoji: '🧑',
          role: MemberRole.admin,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, sc) => Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEdit ? 'Edit Family / Group' : 'New Family / Group',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                    if (_isEdit)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.expense,
                          size: 20,
                        ),
                        onPressed: () => _confirmDelete(context),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    // Emoji picker
                    _Label('GROUP ICON', sub),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _groupEmojis
                          .map(
                            (e) => GestureDetector(
                              onTap: () => setState(() => _selectedEmoji = e),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _selectedEmoji == e
                                      ? AppColors.primary.withOpacity(0.15)
                                      : surfBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedEmoji == e
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  e,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),

                    // Name
                    _Label('GROUP NAME', sub),
                    _Field(
                      controller: _nameCtrl,
                      hint: 'e.g. Singh Family, Office Team…',
                      surfBg: surfBg,
                      tc: tc,
                    ),
                    const SizedBox(height: 18),

                    // Members header
                    Row(
                      children: [
                        Expanded(child: _Label('MEMBERS', sub)),
                        Text(
                          '${_members.length} member${_members.length != 1 ? "s" : ""}',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    ..._members
                        .asMap()
                        .entries
                        .map(
                          (entry) => _MemberRow(
                            member: entry.value,
                            isDark: isDark,
                            surfBg: surfBg,
                            tc: tc,
                            sub: sub,
                            onEdit: () => _editMember(
                              context,
                              entry.value,
                              isDark,
                              surfBg,
                            ),
                            onRemove:
                                entry.value.role == MemberRole.admin &&
                                    _members
                                            .where(
                                              (m) => m.role == MemberRole.admin,
                                            )
                                            .length ==
                                        1
                                ? null
                                : () => setState(
                                    () => _members.remove(entry.value),
                                  ),
                          ),
                        )
                        .toList(),

                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _addMember(context, isDark, surfBg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.income.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.income.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_add_alt_1_rounded,
                              color: AppColors.income,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Add New Member',
                              style: TextStyle(
                                color: AppColors.income,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                fontFamily: 'Nunito',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _isEdit ? 'Save Changes' : 'Create Group',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    if (_isEdit) {
      widget.existing!.name = _nameCtrl.text.trim();
      widget.existing!.emoji = _selectedEmoji;
      widget.existing!.members
        ..clear()
        ..addAll(_members);
      final idx = familyWallets.indexWhere((w) => w.id == widget.existing!.id);
      if (idx >= 0) {
        final old = familyWallets[idx];
        familyWallets[idx] = WalletModel(
          id: old.id,
          name: _nameCtrl.text.trim(),
          emoji: _selectedEmoji,
          isPersonal: false,
          cashIn: old.cashIn,
          cashOut: old.cashOut,
          onlineIn: old.onlineIn,
          onlineOut: old.onlineOut,
          gradient: old.gradient,
        );
      }
      Navigator.pop(context);
    } else {
      final newId = 'f${DateTime.now().millisecondsSinceEpoch}';
      final ci = familyWallets.length % AppColors.familyGradients.length;
      mockFamilies.add(
        FamilyModel(
          id: newId,
          name: _nameCtrl.text.trim(),
          emoji: _selectedEmoji,
          colorIndex: ci,
          members: List.from(_members),
        ),
      );
      familyWallets.add(
        WalletModel(
          id: newId,
          name: _nameCtrl.text.trim(),
          emoji: _selectedEmoji,
          isPersonal: false,
          cashIn: 0,
          cashOut: 0,
          onlineIn: 0,
          onlineOut: 0,
          gradient: AppColors.familyGradients[ci],
        ),
      );
      Navigator.pop(context, newId);
    }
  }

  void _confirmDelete(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text(
          'Remove Group?',
          style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Nunito'),
        ),
        content: Text(
          'Remove "${widget.existing!.name}"? All data will be lost.',
          style: const TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              mockFamilies.removeWhere((f) => f.id == widget.existing!.id);
              familyWallets.removeWhere((w) => w.id == widget.existing!.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.expense),
            ),
          ),
        ],
      ),
    );
  }

  void _addMember(BuildContext ctx, bool isDark, Color surfBg) =>
      _memberForm(ctx, isDark, surfBg, null);
  void _editMember(
    BuildContext ctx,
    FamilyMember m,
    bool isDark,
    Color surfBg,
  ) => _memberForm(ctx, isDark, surfBg, m);

  void _memberForm(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    FamilyMember? editing,
  ) {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final phoneCtrl = TextEditingController(text: editing?.phone ?? '');
    final relationCtrl = TextEditingController(text: editing?.relation ?? '');
    var role = editing?.role ?? MemberRole.member;
    var emoji = editing?.emoji ?? '👤';
    const avatars = [
      '👤',
      '🧑',
      '👨',
      '👩',
      '👦',
      '👧',
      '🧒',
      '👴',
      '👵',
      '🧑\u200d💼',
      '👨\u200d💼',
      '👩\u200d💼',
      '🧑\u200d🎓',
      '👮',
      '🧑\u200d🔧',
    ];

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (ctx2, ss) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      editing == null ? 'Add Member' : 'Edit Member',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    const SizedBox(height: 14),

                    _Label(
                      'AVATAR',
                      isDark ? AppColors.subDark : AppColors.subLight,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: avatars
                          .map(
                            (e) => GestureDetector(
                              onTap: () => ss(() => emoji = e),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: emoji == e
                                      ? AppColors.primary.withOpacity(0.15)
                                      : surfBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: emoji == e
                                        ? AppColors.primary
                                        : Colors.transparent,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  e,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),

                    _Field(
                      controller: nameCtrl,
                      hint: 'Full name *',
                      surfBg: surfBg,
                      tc: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            controller: phoneCtrl,
                            hint: 'Phone (optional)',
                            surfBg: surfBg,
                            tc: isDark
                                ? AppColors.textDark
                                : AppColors.textLight,
                            inputType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Field(
                            controller: relationCtrl,
                            hint: 'Relation (e.g. Wife)',
                            surfBg: surfBg,
                            tc: isDark
                                ? AppColors.textDark
                                : AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _Label(
                      'ROLE',
                      isDark ? AppColors.subDark : AppColors.subLight,
                    ),
                    Row(
                      children: MemberRole.values
                          .map(
                            (r) => Expanded(
                              child: GestureDetector(
                                onTap: () => ss(() => role = r),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  margin: EdgeInsets.only(
                                    right: r != MemberRole.viewer ? 8 : 0,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: role == r
                                        ? _rc(r).withOpacity(0.12)
                                        : surfBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: role == r
                                          ? _rc(r)
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        r.emoji,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        r.label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'Nunito',
                                          color: role == r
                                              ? _rc(r)
                                              : (isDark
                                                    ? AppColors.subDark
                                                    : AppColors.subLight),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _rd(r),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontFamily: 'Nunito',
                                          color: isDark
                                              ? AppColors.subDark
                                              : AppColors.subLight,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setState(() {
                            if (editing != null) {
                              editing.name = nameCtrl.text.trim();
                              editing.emoji = emoji;
                              editing.role = role;
                              editing.phone = phoneCtrl.text.trim().isEmpty
                                  ? null
                                  : phoneCtrl.text.trim();
                              editing.relation =
                                  relationCtrl.text.trim().isEmpty
                                  ? null
                                  : relationCtrl.text.trim();
                            } else {
                              _members.add(
                                FamilyMember(
                                  id: DateTime.now().millisecondsSinceEpoch
                                      .toString(),
                                  name: nameCtrl.text.trim(),
                                  emoji: emoji,
                                  role: role,
                                  phone: phoneCtrl.text.trim().isEmpty
                                      ? null
                                      : phoneCtrl.text.trim(),
                                  relation: relationCtrl.text.trim().isEmpty
                                      ? null
                                      : relationCtrl.text.trim(),
                                ),
                              );
                            }
                          });
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _rc(role),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          editing == null ? 'Add Member' : 'Save',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _rc(MemberRole r) {
    switch (r) {
      case MemberRole.admin:
        return AppColors.lend;
      case MemberRole.member:
        return AppColors.primary;
      case MemberRole.viewer:
        return AppColors.split;
    }
  }

  String _rd(MemberRole r) {
    switch (r) {
      case MemberRole.admin:
        return 'Full access';
      case MemberRole.member:
        return 'Can add & edit';
      case MemberRole.viewer:
        return 'Read only';
    }
  }
}

class _MemberRow extends StatelessWidget {
  final FamilyMember member;
  final bool isDark;
  final Color surfBg, tc, sub;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;
  const _MemberRow({
    required this.member,
    required this.isDark,
    required this.surfBg,
    required this.tc,
    required this.sub,
    required this.onEdit,
    required this.onRemove,
  });

  Color _rc(MemberRole r) {
    switch (r) {
      case MemberRole.admin:
        return AppColors.lend;
      case MemberRole.member:
        return AppColors.primary;
      case MemberRole.viewer:
        return AppColors.split;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _rc(member.role);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: roleColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(member.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            member.role.emoji,
                            style: const TextStyle(fontSize: 9),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            member.role.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: roleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (member.relation != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        member.relation!,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person_remove_rounded,
                      size: 15,
                      color: AppColors.expense,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final Color color;
  const _Label(this.text, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        fontFamily: 'Nunito',
        color: color,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color surfBg, tc;
  final TextInputType? inputType;
  const _Field({
    required this.controller,
    required this.hint,
    required this.surfBg,
    required this.tc,
    this.inputType,
  });
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: inputType,
    style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: tc),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 12,
        color: AppColors.subLight,
      ),
      filled: true,
      fillColor: surfBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

// class FamilySwitcherSheet extends StatefulWidget {
//   final String currentWalletId;
//   final void Function(String walletId) onSelect;

//   const FamilySwitcherSheet({
//     super.key,
//     required this.currentWalletId,
//     required this.onSelect,
//   });

//   static Future<void> show(
//     BuildContext context, {
//     required String currentWalletId,
//     required void Function(String) onSelect,
//   }) {
//     return showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       isScrollControlled: true,
//       builder: (_) => FamilySwitcherSheet(
//         currentWalletId: currentWalletId,
//         onSelect: onSelect,
//       ),
//     );
//   }

//   @override
//   State<FamilySwitcherSheet> createState() => _FamilySwitcherSheetState();
// }

// class _FamilySwitcherSheetState extends State<FamilySwitcherSheet> {
//   final _nameCtrl = TextEditingController();
//   bool _showAddForm = false;
//   String _selectedEmoji = '👨‍👩‍👧';

//   final _emojis = ['👨‍👩‍👧', '👨‍👩‍👦', '👥', '🏠', '💼', '🎓', '❤️', '🌟'];

//   @override
//   void dispose() {
//     _nameCtrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final bg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
//     final all = [personalWallet, ...familyWallets];

//     return Container(
//       padding: EdgeInsets.only(
//         bottom: MediaQuery.of(context).viewInsets.bottom,
//       ),
//       decoration: BoxDecoration(
//         color: bg,
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // Handle
//           Container(
//             width: 40,
//             height: 4,
//             margin: const EdgeInsets.only(top: 12, bottom: 20),
//             decoration: BoxDecoration(
//               color: Colors.grey.withOpacity(0.3),
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),

//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 24),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Switch Wallet',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.w800,
//                     fontFamily: 'Nunito',
//                   ),
//                 ),
//                 const SizedBox(height: 16),

//                 // Wallet list
//                 ...all.map((w) {
//                   final isSel = w.id == widget.currentWalletId;
//                   return GestureDetector(
//                     onTap: () {
//                       widget.onSelect(w.id);
//                       Navigator.pop(context);
//                     },
//                     child: AnimatedContainer(
//                       duration: const Duration(milliseconds: 200),
//                       margin: const EdgeInsets.only(bottom: 10),
//                       padding: const EdgeInsets.all(14),
//                       decoration: BoxDecoration(
//                         gradient: isSel
//                             ? LinearGradient(colors: w.gradient)
//                             : null,
//                         color: isSel
//                             ? null
//                             : (isDark
//                                   ? const Color(0xFF16213E)
//                                   : const Color(0xFFF5F6FA)),
//                         borderRadius: BorderRadius.circular(16),
//                         border: Border.all(
//                           color: isSel
//                               ? Colors.transparent
//                               : Colors.transparent,
//                         ),
//                       ),
//                       child: Row(
//                         children: [
//                           Text(w.emoji, style: const TextStyle(fontSize: 24)),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   w.name,
//                                   style: TextStyle(
//                                     fontWeight: FontWeight.w700,
//                                     fontSize: 15,
//                                     fontFamily: 'Nunito',
//                                     color: isSel
//                                         ? Colors.white
//                                         : (isDark
//                                               ? Colors.white
//                                               : const Color(0xFF1A1A2E)),
//                                   ),
//                                 ),
//                                 Text(
//                                   'Balance: ₹${w.balance >= 1000 ? "${(w.balance / 1000).toStringAsFixed(1)}K" : w.balance.toStringAsFixed(0)}',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: isSel
//                                         ? Colors.white70
//                                         : const Color(0xFF8E8EA0),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           if (isSel)
//                             const Icon(
//                               Icons.check_circle_rounded,
//                               color: Colors.white,
//                               size: 22,
//                             ),
//                         ],
//                       ),
//                     ),
//                   );
//                 }),

//                 const SizedBox(height: 8),

//                 // Add family toggle
//                 if (!_showAddForm)
//                   GestureDetector(
//                     onTap: () => setState(() => _showAddForm = true),
//                     child: Container(
//                       padding: const EdgeInsets.all(14),
//                       decoration: BoxDecoration(
//                         border: Border.all(
//                           color: AppColors.primary.withOpacity(0.4),
//                           width: 1.5,
//                           style: BorderStyle.solid,
//                         ),
//                         borderRadius: BorderRadius.circular(16),
//                       ),
//                       child: const Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.add_rounded,
//                             color: AppColors.primary,
//                             size: 20,
//                           ),
//                           SizedBox(width: 8),
//                           Text(
//                             'Add New Family / Group',
//                             style: TextStyle(
//                               color: AppColors.primary,
//                               fontWeight: FontWeight.w700,
//                               fontSize: 14,
//                               fontFamily: 'Nunito',
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   )
//                 else
//                   _AddFamilyForm(
//                     nameCtrl: _nameCtrl,
//                     selectedEmoji: _selectedEmoji,
//                     emojis: _emojis,
//                     onEmojiSelect: (e) => setState(() => _selectedEmoji = e),
//                     onCancel: () => setState(() {
//                       _showAddForm = false;
//                       _nameCtrl.clear();
//                     }),
//                     onAdd: () {
//                       if (_nameCtrl.text.trim().isEmpty) return;
//                       final newId = 'f${familyWallets.length + 1}';
//                       final ci =
//                           familyWallets.length %
//                           AppColors.familyGradients.length;
//                       familyWallets.add(
//                         WalletModel(
//                           id: newId,
//                           name: _nameCtrl.text.trim(),
//                           emoji: _selectedEmoji,
//                           isPersonal: false,
//                           cashIn: 0,
//                           cashOut: 0,
//                           onlineIn: 0,
//                           onlineOut: 0,
//                           gradient: AppColors.familyGradients[ci],
//                         ),
//                       );
//                       widget.onSelect(newId);
//                       Navigator.pop(context);
//                     },
//                   ),
//                 const SizedBox(height: 24),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _AddFamilyForm extends StatelessWidget {
//   final TextEditingController nameCtrl;
//   final String selectedEmoji;
//   final List<String> emojis;
//   final void Function(String) onEmojiSelect;
//   final VoidCallback onCancel, onAdd;

//   const _AddFamilyForm({
//     required this.nameCtrl,
//     required this.selectedEmoji,
//     required this.emojis,
//     required this.onEmojiSelect,
//     required this.onCancel,
//     required this.onAdd,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: isDark ? const Color(0xFF16213E) : const Color(0xFFF5F6FA),
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'New Family / Group',
//             style: TextStyle(
//               fontWeight: FontWeight.w800,
//               fontSize: 15,
//               fontFamily: 'Nunito',
//             ),
//           ),
//           const SizedBox(height: 12),

//           // Emoji picker
//           Wrap(
//             spacing: 8,
//             children: emojis
//                 .map(
//                   (e) => GestureDetector(
//                     onTap: () => onEmojiSelect(e),
//                     child: AnimatedContainer(
//                       duration: const Duration(milliseconds: 150),
//                       width: 40,
//                       height: 40,
//                       decoration: BoxDecoration(
//                         color: selectedEmoji == e
//                             ? AppColors.primary.withOpacity(0.15)
//                             : Colors.transparent,
//                         borderRadius: BorderRadius.circular(10),
//                         border: Border.all(
//                           color: selectedEmoji == e
//                               ? AppColors.primary
//                               : Colors.transparent,
//                         ),
//                       ),
//                       alignment: Alignment.center,
//                       child: Text(e, style: const TextStyle(fontSize: 22)),
//                     ),
//                   ),
//                 )
//                 .toList(),
//           ),
//           const SizedBox(height: 12),

//           // Name field
//           TextField(
//             controller: nameCtrl,
//             autofocus: true,
//             style: const TextStyle(fontFamily: 'Nunito'),
//             decoration: InputDecoration(
//               hintText: 'Name (e.g. Singh Family)',
//               hintStyle: const TextStyle(fontFamily: 'Nunito'),
//               filled: true,
//               fillColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(14),
//                 borderSide: BorderSide.none,
//               ),
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 16,
//                 vertical: 12,
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),

//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton(
//                   onPressed: onCancel,
//                   style: OutlinedButton.styleFrom(
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(14),
//                     ),
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                   ),
//                   child: const Text(
//                     'Cancel',
//                     style: TextStyle(fontFamily: 'Nunito'),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: onAdd,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.primary,
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(14),
//                     ),
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                   ),
//                   child: const Text(
//                     'Add',
//                     style: TextStyle(
//                       fontWeight: FontWeight.w800,
//                       fontFamily: 'Nunito',
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
