import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';

class FamilyFoodPrefsCard extends StatelessWidget {
  final List<PantryMember> members;
  final List<MemberFoodPrefs> foodPrefs;
  final String currentUserId;
  final bool isAdmin;
  final void Function(MemberFoodPrefs) onSave;

  const FamilyFoodPrefsCard({
    super.key,
    required this.members,
    required this.foodPrefs,
    required this.currentUserId,
    required this.isAdmin,
    required this.onSave,
  });

  MemberFoodPrefs _prefsFor(PantryMember m, String walletId) =>
      foodPrefs.firstWhere(
        (p) => p.memberId == m.id,
        orElse: () => MemberFoodPrefs(
          id: 'fp_${m.id}_new',
          memberId: m.id,
          memberName: m.name,
          memberEmoji: m.emoji,
          walletId: walletId,
        ),
      );

  String _summary(MemberFoodPrefs p) {
    final parts = <String>[];
    if (p.likes.isNotEmpty) parts.add('❤️ ${p.likes.length}');
    if (p.dislikes.isNotEmpty) parts.add('😑 ${p.dislikes.length}');
    if (p.mandatoryFoods.isNotEmpty) parts.add('📌 ${p.mandatoryFoods.length}');
    return parts.isEmpty ? 'Tap to add' : parts.join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final walletId = foodPrefs.isNotEmpty ? foodPrefs.first.walletId : 'personal';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family Food Guide',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      Text(
                        'Allergies · Likes & Dislikes · Mandatory',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Member chips — single scrollable row
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              primary: false,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final m = members[i];
                final prefs = _prefsFor(m, walletId);
                final hasAllergy = prefs.allergies.isNotEmpty;
                final canEdit = isAdmin || m.id == currentUserId;
                return GestureDetector(
                  onTap: () => _showMemberSheet(context, m, prefs, canEdit),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasAllergy
                          ? AppColors.expense.withValues(alpha: 0.07)
                          : AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasAllergy
                            ? AppColors.expense.withValues(alpha: 0.25)
                            : AppColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(m.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 7),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: tc,
                              ),
                            ),
                            if (hasAllergy)
                              Text(
                                '⚠️ ${prefs.allergies.length} allerg${prefs.allergies.length == 1 ? 'y' : 'ies'}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'Nunito',
                                  color: AppColors.expense,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            else
                              Text(
                                _summary(prefs),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'Nunito',
                                  color: sub,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showMemberSheet(
    BuildContext context,
    PantryMember m,
    MemberFoodPrefs prefs,
    bool canEdit,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MemberPrefsSheet(
        member: m,
        prefs: prefs,
        canEdit: canEdit,
        onSave: (updated) {
          Navigator.pop(ctx);
          onSave(updated);
        },
      ),
    );
  }
}

// ── Member prefs bottom sheet ──────────────────────────────────────────────────

class _MemberPrefsSheet extends StatefulWidget {
  final PantryMember member;
  final MemberFoodPrefs prefs;
  final bool canEdit;
  final void Function(MemberFoodPrefs) onSave;

  const _MemberPrefsSheet({
    required this.member,
    required this.prefs,
    required this.canEdit,
    required this.onSave,
  });

  @override
  State<_MemberPrefsSheet> createState() => _MemberPrefsSheetState();
}

class _MemberPrefsSheetState extends State<_MemberPrefsSheet> {
  late List<String> _allergies;
  late List<String> _likes;
  late List<String> _dislikes;
  late List<String> _mandatory;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _allergies = List.from(widget.prefs.allergies);
    _likes = List.from(widget.prefs.likes);
    _dislikes = List.from(widget.prefs.dislikes);
    _mandatory = List.from(widget.prefs.mandatoryFoods);
  }

  void _save() {
    widget.onSave(widget.prefs.copyWith(
      allergies: _allergies,
      likes: _likes,
      dislikes: _dislikes,
      mandatoryFoods: _mandatory,
    ));
  }

  Future<void> _addItem(List<String> list, String hint) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Add $hint',
          style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        list.add(result);
        _hasChanges = true;
      });
    }
  }

  void _removeItem(List<String> list, String item) {
    setState(() {
      list.remove(item);
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : Colors.white;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Member header
            Row(
              children: [
                Text(
                  widget.member.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.member.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    if (!widget.canEdit)
                      Text(
                        'View only',
                        style: TextStyle(
                          fontSize: 11,
                          color: sub,
                          fontFamily: 'Nunito',
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                if (_hasChanges)
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            _PrefsSection(
              title: '🚫 Allergies',
              subtitle: 'Foods this member must avoid',
              items: _allergies,
              canEdit: widget.canEdit,
              accentColor: AppColors.expense,
              onAdd: () => _addItem(_allergies, 'Allergy / intolerance'),
              onRemove: (item) => _removeItem(_allergies, item),
            ),
            const SizedBox(height: 16),
            _PrefsSection(
              title: '❤️ Likes',
              subtitle: 'Favourite foods',
              items: _likes,
              canEdit: widget.canEdit,
              accentColor: const Color(0xFFE53935),
              onAdd: () => _addItem(_likes, 'Favourite food'),
              onRemove: (item) => _removeItem(_likes, item),
            ),
            const SizedBox(height: 16),
            _PrefsSection(
              title: '😑 Dislikes',
              subtitle: 'Foods to avoid if possible',
              items: _dislikes,
              canEdit: widget.canEdit,
              accentColor: Colors.orange,
              onAdd: () => _addItem(_dislikes, 'Disliked food'),
              onRemove: (item) => _removeItem(_dislikes, item),
            ),
            const SizedBox(height: 16),
            _PrefsSection(
              title: '📌 Mandatory',
              subtitle: 'Must include in meals',
              items: _mandatory,
              canEdit: widget.canEdit,
              accentColor: AppColors.primary,
              onAdd: () => _addItem(_mandatory, 'e.g. Milk (morning)'),
              onRemove: (item) => _removeItem(_mandatory, item),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Prefs section with chips ───────────────────────────────────────────────────

class _PrefsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> items;
  final bool canEdit;
  final Color accentColor;
  final VoidCallback onAdd;
  final void Function(String) onRemove;

  const _PrefsSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.canEdit,
    required this.accentColor,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFF5F5F8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: accentColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                ],
              ),
            ),
            if (canEdit)
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 13, color: accentColor),
                      const SizedBox(width: 3),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              canEdit ? 'None added — tap + Add' : 'None',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Nunito',
                color: sub,
              ),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map((item) => _ItemChip(
                      item: item,
                      canDelete: canEdit,
                      accentColor: accentColor,
                      onDelete: () => onRemove(item),
                    ))
                .toList(),
          ),
      ],
    );
  }
}

class _ItemChip extends StatelessWidget {
  final String item;
  final bool canDelete;
  final Color accentColor;
  final VoidCallback onDelete;

  const _ItemChip({
    required this.item,
    required this.canDelete,
    required this.accentColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(10, 5, canDelete ? 4 : 10, 5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
              color: isDark ? AppColors.textDark : AppColors.textLight,
            ),
          ),
          if (canDelete) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.close_rounded, size: 14, color: accentColor),
            ),
          ],
        ],
      ),
    );
  }
}
