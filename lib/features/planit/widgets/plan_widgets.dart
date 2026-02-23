import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';

// ── Reusable bottom-sheet launcher ────────────────────────────────────────────

void showPlanSheet(
  BuildContext context, {
  required Widget child,
  bool isScrollControlled = true,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(child: SingleChildScrollView(child: child)),
          ],
        ),
      ),
    ),
  );
}

// ── Section header ────────────────────────────────────────────────────────────

class PlanSectionHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const PlanSectionHeader({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      color: isDark ? AppColors.subDark : AppColors.subLight,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Priority badge ────────────────────────────────────────────────────────────

class PriorityBadge extends StatelessWidget {
  final Priority priority;
  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: priority.color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: priority.color.withOpacity(0.3)),
    ),
    child: Text(
      priority.label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        fontFamily: 'Nunito',
        color: priority.color,
      ),
    ),
  );
}

// ── Repeat badge ──────────────────────────────────────────────────────────────

class RepeatBadge extends StatelessWidget {
  final RepeatMode repeat;
  const RepeatBadge({super.key, required this.repeat});

  @override
  Widget build(BuildContext context) {
    if (repeat == RepeatMode.none) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(
        repeat.badge,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ── Member avatar chip ────────────────────────────────────────────────────────

class MemberAvatar extends StatelessWidget {
  final String memberId;
  final double size;
  const MemberAvatar({super.key, required this.memberId, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final member = mockMembers.firstWhere(
      (m) => m.id == memberId,
      orElse: () => const PlanMember(id: '?', name: '?', emoji: '👤'),
    );
    return Tooltip(
      message: member.name,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        alignment: Alignment.center,
        child: Text(member.emoji, style: TextStyle(fontSize: size * 0.5)),
      ),
    );
  }
}

// ── Generic info field row ────────────────────────────────────────────────────

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color:
                iconColor ?? (isDark ? AppColors.subDark : AppColors.subLight),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Nunito',
                color: isDark ? AppColors.subDark : AppColors.subLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class PlanEmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;
  const PlanEmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Nunito',
                color: AppColors.subDark,
              ),
            ),
            if (buttonLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onButton,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  buttonLabel!,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Input field ───────────────────────────────────────────────────────────────

class PlanInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? inputType;
  final TextCapitalization capitalization;

  const PlanInputField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.inputType,
    this.capitalization = TextCapitalization.sentences,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Container(
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: 1,
        keyboardType: inputType,
        textCapitalization: capitalization,
        style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: sub, fontFamily: 'Nunito'),
        ),
      ),
    );
  }
}

// ── Sheet label ───────────────────────────────────────────────────────────────

class SheetLabel extends StatelessWidget {
  final String text;
  const SheetLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'Nunito',
          color: isDark ? AppColors.subDark : AppColors.subLight,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Date / time helpers ───────────────────────────────────────────────────────

const _months = [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String fmtDate(DateTime d) => '${d.day} ${_months[d.month]} ${d.year}';

String fmtDateShort(DateTime d) => '${d.day} ${_months[d.month]}';

String fmtTime(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.period == DayPeriod.am ? "AM" : "PM"}';
}

String daysUntil(DateTime d) {
  final diff = d.difference(DateTime.now()).inDays;
  if (diff < 0) return '${diff.abs()}d overdue';
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return 'in $diff days';
}

Color daysUntilColor(DateTime d) {
  final diff = d.difference(DateTime.now()).inDays;
  if (diff < 0) return AppColors.expense;
  if (diff <= 2) return AppColors.lend;
  return AppColors.income;
}

// ── Save button ───────────────────────────────────────────────────────────────

class SaveButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const SaveButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
          ),
        ),
      ),
    ),
  );
}

// ── Swipe-to-delete list tile wrapper ─────────────────────────────────────────

class SwipeTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onDelete;
  const SwipeTile({super.key, required this.child, required this.onDelete});

  @override
  Widget build(BuildContext context) => Dismissible(
    key: UniqueKey(),
    direction: DismissDirection.endToStart,
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: AppColors.expense.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: AppColors.expense,
        size: 24,
      ),
    ),
    onDismissed: (_) => onDelete(),
    child: child,
  );
}
