import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import '../../widgets/plan_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  c. SPECIAL DAYS
// ═══════════════════════════════════════════════════════════════════════════════

class SpecialDaysScreen extends StatefulWidget {
  final String walletId;
  const SpecialDaysScreen({super.key, required this.walletId});
  @override
  State<SpecialDaysScreen> createState() => _SpecialDaysScreenState();
}

class _SpecialDaysScreenState extends State<SpecialDaysScreen> {
  final List<SpecialDayModel> _days = List.from(mockSpecialDays);
  SpecialDayType? _filter;

  List<SpecialDayModel> get _filtered {
    var list = _days.where((d) => d.walletId == widget.walletId).toList();
    if (_filter != null) list = list.where((d) => d.type == _filter).toList();
    list.sort((a, b) {
      final an = _nextDate(a.date), bn = _nextDate(b.date);
      return an.compareTo(bn);
    });
    return list;
  }

  DateTime _nextDate(DateTime d) {
    final now = DateTime.now();
    var next = DateTime(now.year, d.month, d.day);
    if (next.isBefore(now)) next = DateTime(now.year + 1, d.month, d.day);
    return next;
  }

  int _daysUntil(DateTime d) => _nextDate(d).difference(DateTime.now()).inDays;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('🎂', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Special Days',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, isDark, surfBg),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Day',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type filter
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              children: [
                _TypeChip(
                  label: 'All',
                  emoji: '🗓️',
                  selected: _filter == null,
                  color: AppColors.primary,
                  onTap: () => setState(() => _filter = null),
                ),
                ...SpecialDayType.values.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _TypeChip(
                      label: t.label,
                      emoji: t.emoji,
                      selected: _filter == t,
                      color: t.color,
                      onTap: () =>
                          setState(() => _filter = _filter == t ? null : t),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _filtered.isEmpty
                ? const PlanEmptyState(
                    emoji: '🎂',
                    title: 'No special days yet',
                    subtitle: 'Add birthdays, anniversaries and more',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final d = _filtered[i];
                      final days = _daysUntil(d.date);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SwipeTile(
                          onDelete: () => setState(() => _days.remove(d)),
                          child: _SpecialDayCard(
                            day: d,
                            isDark: isDark,
                            daysUntil: days,
                            onTap: () => _showDetailSheet(context, d, isDark),
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

  void _showAddSheet(BuildContext context, bool isDark, Color surfBg) {
    showPlanSheet(
      context,
      child: _AddSpecialDaySheet(
        isDark: isDark,
        surfBg: surfBg,
        walletId: widget.walletId,
        onSave: (d) {
          setState(() => _days.add(d));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDetailSheet(BuildContext context, SpecialDayModel d, bool isDark) {
    showPlanSheet(
      context,
      child: _SpecialDayDetailSheet(
        day: d,
        isDark: isDark,
        daysUntil: _daysUntil(d.date),
        onDelete: () {
          setState(() => _days.remove(d));
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label, emoji;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? color
              : Theme.of(context).brightness == Brightness.dark
              ? AppColors.surfDark
              : const Color(0xFFE0E0EC),
        ),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
          color: selected
              ? color
              : Theme.of(context).brightness == Brightness.dark
              ? AppColors.subDark
              : AppColors.subLight,
        ),
      ),
    ),
  );
}

class _SpecialDayCard extends StatelessWidget {
  final SpecialDayModel day;
  final bool isDark;
  final int daysUntil;
  final VoidCallback onTap;
  const _SpecialDayCard({
    required this.day,
    required this.isDark,
    required this.daysUntil,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final c = day.type.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c, c.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(day.emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          day.type.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: c,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '📅 ${_monthName(day.date.month)} ${day.date.day}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: isDark
                              ? AppColors.subDark
                              : AppColors.subLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Countdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  daysUntil == 0 ? '🎉 Today!' : '$daysUntil',
                  style: TextStyle(
                    fontSize: daysUntil == 0 ? 14 : 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: daysUntil <= 7
                        ? AppColors.expense
                        : AppColors.income,
                  ),
                ),
                if (daysUntil > 0)
                  Text(
                    'days',
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'Nunito',
                      color: isDark ? AppColors.subDark : AppColors.subLight,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialDayDetailSheet extends StatelessWidget {
  final SpecialDayModel day;
  final bool isDark;
  final int daysUntil;
  final VoidCallback onDelete;
  const _SpecialDayDetailSheet({
    required this.day,
    required this.isDark,
    required this.daysUntil,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final c = day.type.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c, c.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(day.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    Text(
                      day.type.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: c,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                daysUntil == 0 ? '🎉' : '$daysUntil days',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                  color: daysUntil <= 7 ? AppColors.expense : AppColors.income,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InfoRow(
            icon: Icons.calendar_today_rounded,
            label:
                '${_monthName(day.date.month)} ${day.date.day} • ${day.yearlyRecur ? "Repeats yearly" : "One-time"}',
          ),
          InfoRow(
            icon: Icons.notifications_rounded,
            label:
                'Alert ${day.alertDaysBefore} day${day.alertDaysBefore > 1 ? "s" : ""} before',
          ),
          if (day.members.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: day.members
                  .map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: MemberAvatar(memberId: m, size: 32),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (day.note != null) ...[
            const SizedBox(height: 8),
            InfoRow(icon: Icons.notes_rounded, label: day.note!),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '✏️ Edit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.expense.withOpacity(0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.expense,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _monthName(int m) => const [
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
][m];

class _AddSpecialDaySheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final void Function(SpecialDayModel) onSave;
  const _AddSpecialDaySheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    required this.onSave,
  });
  @override
  State<_AddSpecialDaySheet> createState() => _AddSpecialDaySheetState();
}

class _AddSpecialDaySheetState extends State<_AddSpecialDaySheet> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  SpecialDayType _type = SpecialDayType.birthday;
  DateTime _date = DateTime.now().add(const Duration(days: 30));
  bool _yearly = true;
  int _alertDays = 1;
  List<String> _members = ['me'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Add Special Day',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 16),
          PlanInputField(
            controller: _titleCtrl,
            hint: 'Title (e.g. Mom\'s Birthday) *',
          ),
          const SizedBox(height: 10),
          PlanInputField(controller: _noteCtrl, hint: 'Notes (optional)'),
          const SizedBox(height: 16),

          const SheetLabel(text: 'TYPE'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SpecialDayType.values
                .map(
                  (t) => GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _type == t ? t.color : t.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _type == t ? t.color : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '${t.emoji} ${t.label}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: _type == t ? Colors.white : t.color,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),

          // Date
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _date = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: widget.surfBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_monthName(_date.month)} ${_date.day}, ${_date.year}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Yearly toggle + alert days
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _yearly = !_yearly),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 40,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _yearly
                              ? AppColors.primary
                              : (widget.isDark
                                    ? AppColors.surfDark
                                    : const Color(0xFFE0E0EC)),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        padding: const EdgeInsets.all(2),
                        alignment: _yearly
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: const CircleAvatar(
                          radius: 9,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Repeat yearly',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'Alert ${_alertDays}d before',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Nunito',
                  color: sub,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  if (_alertDays > 1) _alertDays--;
                }),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.surfBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.remove_rounded, size: 16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$_alertDays',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _alertDays++),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.surfBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.add_rounded, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const SheetLabel(text: 'TAG MEMBERS'),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: mockMembers
                  .map(
                    (m) => GestureDetector(
                      onTap: () => setState(
                        () => _members.contains(m.id)
                            ? _members.remove(m.id)
                            : _members.add(m.id),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _members.contains(m.id)
                              ? AppColors.primary.withOpacity(0.15)
                              : widget.surfBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _members.contains(m.id)
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(m.emoji, style: const TextStyle(fontSize: 18)),
                            Text(
                              m.name.split(' ')[0],
                              style: TextStyle(
                                fontSize: 8,
                                fontFamily: 'Nunito',
                                color: sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),

          SaveButton(
            label: 'Save Special Day',
            color: AppColors.primary,
            onTap: () {
              if (_titleCtrl.text.trim().isEmpty) return;
              widget.onSave(
                SpecialDayModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: _titleCtrl.text.trim(),
                  emoji: _type.emoji,
                  type: _type,
                  date: _date,
                  yearlyRecur: _yearly,
                  members: _members,
                  walletId: widget.walletId,
                  note: _noteCtrl.text.trim().isEmpty
                      ? null
                      : _noteCtrl.text.trim(),
                  alertDaysBefore: _alertDays,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
