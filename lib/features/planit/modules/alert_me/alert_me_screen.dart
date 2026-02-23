import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import '../../widgets/plan_widgets.dart';

class AlertMeScreen extends StatefulWidget {
  final String walletId;
  const AlertMeScreen({super.key, required this.walletId});
  @override
  State<AlertMeScreen> createState() => _AlertMeScreenState();
}

class _AlertMeScreenState extends State<AlertMeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final List<ReminderModel> _reminders = List.from(mockReminders);

  List<ReminderModel> get _active =>
      _reminders.where((r) => r.walletId == widget.walletId && !r.done).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  List<ReminderModel> get _done =>
      _reminders.where((r) => r.walletId == widget.walletId && r.done).toList();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _add(ReminderModel r) => setState(() => _reminders.add(r));
  void _delete(ReminderModel r) => setState(() => _reminders.remove(r));
  void _markDone(ReminderModel r) => setState(() => r.done = true);
  void _snooze(ReminderModel r) => setState(() {
    r.dueDate = r.dueDate.add(const Duration(hours: 1));
    r.snoozed = true;
  });

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
            Text('🔔', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Alert Me',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
          indicatorColor: AppColors.expense,
          labelColor: AppColors.expense,
          unselectedLabelColor: subColor,
          tabs: [
            Tab(text: 'Active (${_active.length})'),
            Tab(text: 'Done (${_done.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, isDark, surfBg),
        backgroundColor: AppColors.expense,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Reminder',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ReminderList(
            reminders: _active,
            isDark: isDark,
            onDone: _markDone,
            onSnooze: _snooze,
            onDelete: _delete,
            onTap: (r) => _showDetailSheet(context, r, isDark, surfBg),
          ),
          _ReminderList(
            reminders: _done,
            isDark: isDark,
            onDone: null,
            onSnooze: null,
            onDelete: _delete,
            onTap: null,
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, bool isDark, Color surfBg) {
    showPlanSheet(
      context,
      child: _AddReminderSheet(
        isDark: isDark,
        surfBg: surfBg,
        walletId: widget.walletId,
        onSave: (r) {
          _add(r);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context,
    ReminderModel r,
    bool isDark,
    Color surfBg,
  ) {
    showPlanSheet(
      context,
      child: _ReminderDetailSheet(
        reminder: r,
        isDark: isDark,
        surfBg: surfBg,
        onSnooze: () {
          _snooze(r);
          Navigator.pop(context);
        },
        onDone: () {
          _markDone(r);
          Navigator.pop(context);
        },
        onDelete: () {
          _delete(r);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ── Reminder list ─────────────────────────────────────────────────────────────

class _ReminderList extends StatelessWidget {
  final List<ReminderModel> reminders;
  final bool isDark;
  final void Function(ReminderModel)? onDone;
  final void Function(ReminderModel)? onSnooze;
  final void Function(ReminderModel) onDelete;
  final void Function(ReminderModel)? onTap;

  const _ReminderList({
    required this.reminders,
    required this.isDark,
    required this.onDone,
    required this.onSnooze,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return const PlanEmptyState(
        emoji: '🔔',
        title: 'No reminders',
        subtitle: 'Tap + to add your first reminder',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: reminders.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SwipeTile(
          onDelete: () => onDelete(reminders[i]),
          child: _ReminderCard(
            reminder: reminders[i],
            isDark: isDark,
            onDone: onDone != null ? () => onDone!(reminders[i]) : null,
            onSnooze: onSnooze != null ? () => onSnooze!(reminders[i]) : null,
            onTap: onTap != null ? () => onTap!(reminders[i]) : null,
          ),
        ),
      ),
    );
  }
}

// ── Reminder card ─────────────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  final ReminderModel reminder;
  final bool isDark;
  final VoidCallback? onDone, onSnooze, onTap;
  const _ReminderCard({
    required this.reminder,
    required this.isDark,
    this.onDone,
    this.onSnooze,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final p = reminder.priority;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Priority strip
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: p.color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Text(
                          reminder.emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reminder.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: tc,
                              decoration: reminder.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        MemberAvatar(memberId: reminder.assignedTo, size: 26),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Date + badges row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Due date chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: daysUntilColor(
                              reminder.dueDate,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 11,
                                color: daysUntilColor(reminder.dueDate),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${fmtDateShort(reminder.dueDate)} • ${fmtTime(reminder.dueTime)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                  color: daysUntilColor(reminder.dueDate),
                                ),
                              ),
                            ],
                          ),
                        ),
                        PriorityBadge(priority: p),
                        RepeatBadge(repeat: reminder.repeat),
                        if (reminder.snoozed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lend.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '💤 Snoozed',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                color: AppColors.lend,
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Action buttons
                    if (!reminder.done && (onDone != null || onSnooze != null))
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            if (onSnooze != null)
                              _ActionBtn(
                                label: '💤 Snooze 1h',
                                color: AppColors.lend,
                                onTap: onSnooze!,
                              ),
                            if (onSnooze != null) const SizedBox(width: 8),
                            if (onDone != null)
                              _ActionBtn(
                                label: '✓ Done',
                                color: AppColors.income,
                                onTap: onDone!,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'Nunito',
          color: color,
        ),
      ),
    ),
  );
}

// ── Reminder detail sheet ─────────────────────────────────────────────────────

class _ReminderDetailSheet extends StatelessWidget {
  final ReminderModel reminder;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onSnooze, onDone, onDelete;

  const _ReminderDetailSheet({
    required this.reminder,
    required this.isDark,
    required this.surfBg,
    required this.onSnooze,
    required this.onDone,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final member = mockMembers.firstWhere(
      (m) => m.id == reminder.assignedTo,
      orElse: () => const PlanMember(id: '?', name: '?', emoji: '👤'),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji + title
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: reminder.priority.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  reminder.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        PriorityBadge(priority: reminder.priority),
                        const SizedBox(width: 6),
                        RepeatBadge(repeat: reminder.repeat),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Info
          InfoRow(
            icon: Icons.schedule_rounded,
            label:
                '${fmtDate(reminder.dueDate)} at ${fmtTime(reminder.dueTime)} • ${daysUntil(reminder.dueDate)}',
            iconColor: daysUntilColor(reminder.dueDate),
          ),
          InfoRow(
            icon: Icons.person_rounded,
            label: 'Assigned to ${member.emoji} ${member.name}',
          ),
          if (reminder.note != null)
            InfoRow(icon: Icons.notes_rounded, label: reminder.note!),

          const SizedBox(height: 20),
          // Actions
          Row(
            children: [
              Expanded(
                child: _SheetActionBtn(
                  label: '💤 Snooze 1h',
                  color: AppColors.lend,
                  onTap: onSnooze,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SheetActionBtn(
                  label: '✓ Done',
                  color: AppColors.income,
                  onTap: onDone,
                ),
              ),
              const SizedBox(width: 8),
              _SheetIconBtn(
                icon: Icons.delete_outline_rounded,
                color: AppColors.expense,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SheetActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          fontFamily: 'Nunito',
          color: color,
        ),
      ),
    ),
  );
}

class _SheetIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SheetIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 20),
    ),
  );
}

// ── Add reminder sheet ────────────────────────────────────────────────────────

class _AddReminderSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final void Function(ReminderModel) onSave;
  const _AddReminderSheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    required this.onSave,
  });
  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _emoji = '🔔';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  RepeatMode _repeat = RepeatMode.none;
  Priority _priority = Priority.medium;
  String _assignedTo = 'me';

  final _emojis = [
    '🔔',
    '💊',
    '🚗',
    '💡',
    '🧾',
    '🎂',
    '🦷',
    '📅',
    '📞',
    '🏥',
    '💼',
    '🏋️',
  ];

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
            'New Reminder',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 16),

          // Emoji row
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _emojis
                  .map(
                    (e) => GestureDetector(
                      onTap: () => setState(() => _emoji = e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _emoji == e
                              ? AppColors.expense.withOpacity(0.15)
                              : widget.surfBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _emoji == e
                                ? AppColors.expense
                                : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Title
          PlanInputField(controller: _titleCtrl, hint: 'Reminder title *'),
          const SizedBox(height: 10),
          PlanInputField(
            controller: _noteCtrl,
            hint: 'Notes (optional)',
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Date + Time row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: _PickerTile(
                    icon: Icons.calendar_today_rounded,
                    surfBg: widget.surfBg,
                    label: fmtDateShort(_date),
                    sub: sub,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (t != null) setState(() => _time = t);
                  },
                  child: _PickerTile(
                    icon: Icons.access_time_rounded,
                    surfBg: widget.surfBg,
                    label: fmtTime(_time),
                    sub: sub,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Priority
          const SheetLabel(text: 'PRIORITY'),
          Row(
            children: Priority.values
                .map(
                  (p) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: p.index > 0 ? 6 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _priority = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _priority == p
                                ? p.color
                                : p.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _priority == p
                                  ? p.color
                                  : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            p.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: _priority == p ? Colors.white : p.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),

          // Repeat
          const SheetLabel(text: 'REPEAT'),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: RepeatMode.values
                  .map(
                    (rm) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _repeat = rm),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _repeat == rm
                                ? AppColors.primary.withOpacity(0.15)
                                : widget.surfBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _repeat == rm
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            rm.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: _repeat == rm ? AppColors.primary : sub,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Assign to
          const SheetLabel(text: 'ASSIGN TO'),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: mockMembers
                  .map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _assignedTo = m.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _assignedTo == m.id
                                ? AppColors.primary.withOpacity(0.15)
                                : widget.surfBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _assignedTo == m.id
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                m.emoji,
                                style: const TextStyle(fontSize: 18),
                              ),
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
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),

          SaveButton(
            label: 'Save Reminder',
            color: AppColors.expense,
            onTap: () {
              if (_titleCtrl.text.trim().isEmpty) return;
              widget.onSave(
                ReminderModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: _titleCtrl.text.trim(),
                  emoji: _emoji,
                  dueDate: _date,
                  dueTime: _time,
                  repeat: _repeat,
                  priority: _priority,
                  assignedTo: _assignedTo,
                  walletId: widget.walletId,
                  note: _noteCtrl.text.trim().isEmpty
                      ? null
                      : _noteCtrl.text.trim(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color surfBg, sub;
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.surfBg,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: surfBg,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
            color: AppColors.primary,
          ),
        ),
      ],
    ),
  );
}
