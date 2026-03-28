import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC MEAL DETAIL SHEET
// Extracted from pantry_screen.dart so it can be used from other screens
// (e.g. Dashboard Today's Plate).
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the meal detail bottom sheet with handle bar.
void showMealDetailSheet(
  BuildContext context, {
  required MealEntry meal,
  required bool isDark,
  required String currentUserName,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  required void Function(MealReaction reaction) onReactionAdded,
  required void Function(int index, MealReaction updated) onReactionUpdated,
  required void Function(int index) onReactionDeleted,
  void Function(MealStatus status, int servingsCount)? onStatusChanged,
  VoidCallback? onCheckStock,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final maxH = MediaQuery.of(ctx).size.height * 0.92;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
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
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: MealDetailSheet(
                  meal: meal,
                  isDark: isDark,
                  currentUserName: currentUserName,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  onReactionAdded: onReactionAdded,
                  onReactionUpdated: onReactionUpdated,
                  onReactionDeleted: onReactionDeleted,
                  onStatusChanged: onStatusChanged,
                  onCheckStock: onCheckStock,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class MealDetailSheet extends StatefulWidget {
  final MealEntry meal;
  final bool isDark;
  final String currentUserName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(MealReaction reaction) onReactionAdded;
  final void Function(int index, MealReaction updated) onReactionUpdated;
  final void Function(int index) onReactionDeleted;
  final void Function(MealStatus status, int servingsCount)? onStatusChanged;
  final VoidCallback? onCheckStock;

  const MealDetailSheet({
    super.key,
    required this.meal,
    required this.isDark,
    required this.currentUserName,
    required this.onEdit,
    required this.onDelete,
    required this.onReactionAdded,
    required this.onReactionUpdated,
    required this.onReactionDeleted,
    this.onStatusChanged,
    this.onCheckStock,
  });

  @override
  State<MealDetailSheet> createState() => _MealDetailSheetState();
}

class _MealDetailSheetState extends State<MealDetailSheet> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _reactionOptions = [
    ('👍', 'Love it'),
    ('😋', 'Yummy'),
    ('🤔', 'Not sure'),
    ('❌', "Don't want it"),
    ('🔄', 'Want alternative'),
  ];

  static const _replyOptions = [
    ('✅', 'Accepted'),
    ('❌', 'Rejected'),
    ('🤔', 'Let me think'),
    ('🔄', 'Suggest alternative'),
    ('💬', 'Noted'),
    ('🙏', 'Thanks for sharing'),
  ];

  late List<MealReaction> _reactions;
  bool _showForm = false;
  String _selectedEmoji = '👍';
  final _nameCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  late MealStatus _status;
  late int _servings;

  int? _editingIndex;
  String? _replyingTo;

  @override
  void initState() {
    super.initState();
    _reactions = List.from(widget.meal.reactions);
    _status = widget.meal.mealStatus;
    _servings = widget.meal.servingsCount;
    if (widget.currentUserName.isNotEmpty) {
      _nameCtrl.text = widget.currentUserName;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _startEdit(int index) {
    final r = _reactions[index];
    setState(() {
      _editingIndex = index;
      _replyingTo = r.replyTo;
      _nameCtrl.text = r.memberName;
      _commentCtrl.text = r.comment ?? '';
      _selectedEmoji = r.reactionEmoji;
      _showForm = true;
    });
  }

  void _startReply(int index) {
    final r = _reactions[index];
    setState(() {
      _editingIndex = null;
      _replyingTo = r.memberName;
      _nameCtrl.text = widget.currentUserName;
      _commentCtrl.clear();
      _selectedEmoji = '✅';
      _showForm = true;
    });
  }

  void _cancelForm() {
    setState(() {
      _showForm = false;
      _editingIndex = null;
      _replyingTo = null;
      _nameCtrl.text = widget.currentUserName;
      _commentCtrl.clear();
      _selectedEmoji = '👍';
    });
  }

  void _deleteReaction(int index) {
    setState(() => _reactions.removeAt(index));
    widget.onReactionDeleted(index);
  }

  void _submitReaction() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final comment = _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim();

    if (_editingIndex != null) {
      final idx = _editingIndex!;
      final updated = _reactions[idx].copyWith(
        memberName: name,
        reactionEmoji: _selectedEmoji,
        comment: comment,
      );
      setState(() {
        _reactions[idx] = updated;
        _showForm = false;
        _editingIndex = null;
        _nameCtrl.text = widget.currentUserName;
        _commentCtrl.clear();
        _selectedEmoji = '👍';
      });
      widget.onReactionUpdated(idx, updated);
    } else {
      final r = MealReaction(
        memberName: name,
        reactionEmoji: _selectedEmoji,
        comment: comment,
        replyTo: _replyingTo,
      );
      setState(() {
        _reactions = [..._reactions, r];
        _showForm = false;
        _replyingTo = null;
        _nameCtrl.text = widget.currentUserName;
        _commentCtrl.clear();
        _selectedEmoji = '👍';
      });
      widget.onReactionAdded(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;
    final surfBg = widget.isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final c = widget.meal.mealTime.color;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Meal header ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(widget.meal.emoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.meal.name,
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito', color: tc,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${widget.meal.mealTime.emoji} ${widget.meal.mealTime.label}',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800,
                                color: c, fontFamily: 'Nunito',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_months[widget.meal.date.month - 1]} ${widget.meal.date.day}',
                            style: TextStyle(fontSize: 12, color: sub, fontFamily: 'Nunito'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Edit / Delete ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.expense,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── Status picker ────────────────────────────────────────────────
            Text(
              '📍  Meal Status',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900,
                fontFamily: 'Nunito', color: tc,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: MealStatus.values.map((s) {
                final active = _status == s;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: s != MealStatus.values.last ? 8 : 0,
                    ),
                    child: GestureDetector(
                      onTap: () => setState(() => _status = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: active
                              ? s.color.withValues(alpha: 0.15)
                              : (widget.isDark ? AppColors.surfDark : AppColors.bgLight),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active ? s.color : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(s.emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 3),
                            Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: active ? s.color : sub,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_status == MealStatus.cooked || _status == MealStatus.ordered) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '👥  Serves',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito', color: tc,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _servings > 1 ? () => setState(() => _servings--) : null,
                    child: Icon(Icons.remove_circle_outline,
                        size: 22,
                        color: _servings > 1 ? AppColors.primary : sub),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '$_servings',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito', color: tc,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _servings++),
                    child: const Icon(Icons.add_circle_outline,
                        size: 22, color: AppColors.primary),
                  ),
                ],
              ),
            ],
            if (_status != widget.meal.mealStatus ||
                _servings != widget.meal.servingsCount) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onStatusChanged?.call(_status, _servings);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _status.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    '${_status.emoji}  Save Status',
                    style: const TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 22),

            // ── Check Stock ──────────────────────────────────────────────────
            if (widget.onCheckStock != null) ...[
              GestureDetector(
                onTap: widget.onCheckStock,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('🧺', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Check Ingredients in Stock',
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito', color: AppColors.primary,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
            ],

            // ── Opinions section ─────────────────────────────────────────────
            Row(
              children: [
                Text(
                  '💬  Family Opinions',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito', color: tc,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showForm ? _cancelForm() : setState(() => _showForm = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _showForm ? 'Cancel' : '+ Add Opinion',
                      style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito', color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_reactions.isEmpty && !_showForm)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No opinions yet. Be the first to share!',
                  style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
                ),
              )
            else
              ...List.generate(_reactions.length, (i) {
                final r = _reactions[i];
                final isReply = r.replyTo != null;
                return Container(
                  margin: EdgeInsets.only(bottom: 8, left: isReply ? 16 : 0),
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(12),
                    border: isReply
                        ? Border(left: BorderSide(color: AppColors.primary.withValues(alpha: 0.4), width: 3))
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isReply)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Text(
                            '↩ replying to ${r.replyTo}',
                            style: TextStyle(fontSize: 10, fontFamily: 'Nunito',
                                color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.reactionEmoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.memberName,
                                    style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w800,
                                      fontFamily: 'Nunito', color: tc,
                                    ),
                                  ),
                                  Text(
                                    ([..._reactionOptions, ..._replyOptions].firstWhere(
                                      (o) => o.$1 == r.reactionEmoji,
                                      orElse: () => (r.reactionEmoji, r.reactionEmoji),
                                    )).$2,
                                    style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
                                  ),
                                  if (r.comment != null && r.comment!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        '"${r.comment}"',
                                        style: TextStyle(
                                          fontSize: 11, fontFamily: 'Nunito',
                                          fontStyle: FontStyle.italic, color: sub,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MealReactionActionBtn(
                                  icon: Icons.reply_rounded,
                                  color: AppColors.primary,
                                  onTap: () => _startReply(i),
                                  tooltip: 'Reply',
                                ),
                                MealReactionActionBtn(
                                  icon: Icons.edit_rounded,
                                  color: sub,
                                  onTap: () => _startEdit(i),
                                  tooltip: 'Edit',
                                ),
                                MealReactionActionBtn(
                                  icon: Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                  onTap: () => _deleteReaction(i),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

            if (_showForm) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_replyingTo != null) ...[
                      Row(
                        children: [
                          Icon(Icons.reply_rounded, size: 13, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Replying to $_replyingTo',
                            style: const TextStyle(
                              fontSize: 11, fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700, color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ] else if (_editingIndex != null) ...[
                      Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 13, color: sub),
                          const SizedBox(width: 4),
                          Text(
                            'Editing opinion',
                            style: TextStyle(
                              fontSize: 11, fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700, color: sub,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: _nameCtrl,
                      readOnly: widget.currentUserName.isNotEmpty && _editingIndex == null,
                      style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: tc),
                      decoration: InputDecoration(
                        hintText: 'Your name (e.g. Mom, Dad)',
                        hintStyle: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
                        prefixIcon: widget.currentUserName.isNotEmpty && _editingIndex == null
                            ? Icon(Icons.person_rounded, size: 16, color: AppColors.primary)
                            : null,
                        filled: true,
                        fillColor: widget.currentUserName.isNotEmpty && _editingIndex == null
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : (widget.isDark ? AppColors.cardDark : Colors.white),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (_replyingTo != null ? _replyOptions : _reactionOptions).map((opt) {
                        final selected = _selectedEmoji == opt.$1;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedEmoji = opt.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : (widget.isDark ? AppColors.cardDark : Colors.white),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected ? AppColors.primary : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(opt.$1, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 5),
                                Text(
                                  opt.$2,
                                  style: TextStyle(
                                    fontSize: 11, fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w700,
                                    color: selected ? AppColors.primary : sub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _commentCtrl,
                      style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: tc),
                      decoration: InputDecoration(
                        hintText: 'Add a comment or suggestion (optional)',
                        hintStyle: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
                        filled: true,
                        fillColor: widget.isDark ? AppColors.cardDark : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitReaction,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _editingIndex != null ? 'Update Opinion' : _replyingTo != null ? 'Post Reply' : 'Share Opinion',
                          style: const TextStyle(
                            fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REACTION ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class MealReactionActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  const MealReactionActionBtn({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
