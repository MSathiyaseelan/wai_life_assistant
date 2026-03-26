import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/core/supabase/reminder_service.dart';
import 'package:wai_life_assistant/core/services/notification_service.dart';
import 'package:wai_life_assistant/core/services/network_service.dart';
import 'package:wai_life_assistant/services/ai_parser.dart';
import '../../widgets/plan_widgets.dart';
import 'package:wai_life_assistant/core/widgets/emoji_or_image.dart';

class AlertMeScreen extends StatefulWidget {
  final String walletId;
  final String walletName;
  final String walletEmoji;
  final List<PlanMember> members;
  final bool isPersonal;
  final List<ReminderModel> reminders; // lifted state for PlanIt summary
  final bool openAdd;
  const AlertMeScreen({
    super.key,
    required this.walletId,
    this.walletName = 'Personal',
    this.walletEmoji = '👤',
    this.members = const [],
    this.isPersonal = true,
    required this.reminders,
    this.openAdd = false,
  });
  @override
  State<AlertMeScreen> createState() => _AlertMeScreenState();
}

class _AlertMeScreenState extends State<AlertMeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<ReminderModel> _reminders = [];
  bool _loading = false;

  List<ReminderModel> get _active => _reminders
      .where((r) => !r.done)
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<ReminderModel> get _done =>
      _reminders.where((r) => r.done).toList();

  bool _wasOnline = true;

  void _onNetworkChange() {
    final online = NetworkService.instance.isOnline.value;
    if (online && !_wasOnline) _loadReminders();
    _wasOnline = online;
  }

  @override
  void initState() {
    super.initState();
    _wasOnline = NetworkService.instance.isOnline.value;
    NetworkService.instance.isOnline.addListener(_onNetworkChange);
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
    _loadReminders();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermissions();
    });
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
        _openAddSheet(context, isDark, surfBg);
      });
    }
  }

  @override
  void dispose() {
    NetworkService.instance.isOnline.removeListener(_onNetworkChange);
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    if (widget.walletId == 'personal' || widget.walletId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await ReminderService.instance.fetchReminders(widget.walletId);
      if (!mounted) return;
      final loaded = rows.map(ReminderModel.fromRow).toList();
      setState(() {
        _reminders = loaded;
        widget.reminders
          ..clear()
          ..addAll(loaded);
        _loading = false;
      });
      // Reschedule all active reminders on load
      NotificationService.instance.rescheduleAll(loaded);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Mutators ──────────────────────────────────────────────────────────────
  Future<void> _add(ReminderModel r) async {
    try {
      final row = await ReminderService.instance.addReminder(
        walletId: r.walletId,
        title: r.title,
        emoji: r.emoji,
        dueDate: r.dueDate,
        dueTime: '${r.dueTime.hour.toString().padLeft(2, '0')}:${r.dueTime.minute.toString().padLeft(2, '0')}',
        repeat: r.repeat.name,
        priority: r.priority.name,
        assignedTo: r.assignedTo,
        note: r.note,
      );
      final saved = ReminderModel.fromRow(row);
      if (mounted) setState(() => _reminders.add(saved));
      NotificationService.instance.schedule(saved);
    } catch (_) {
      if (mounted) setState(() => _reminders.add(r));
      NotificationService.instance.schedule(r);
    }
  }

  Future<void> _delete(ReminderModel r) async {
    setState(() => _reminders.remove(r));
    NotificationService.instance.cancel(r);
    try {
      await ReminderService.instance.deleteReminder(r.id);
    } catch (_) {}
  }

  Future<void> _update(ReminderModel updated) async {
    setState(() {
      final i = _reminders.indexWhere((r) => r.id == updated.id);
      if (i >= 0) _reminders[i] = updated;
    });
    // Cancel old, reschedule with new time
    await NotificationService.instance.cancel(updated);
    if (!updated.done) NotificationService.instance.schedule(updated);
    try {
      await ReminderService.instance.updateReminder(updated.id, updated.toMap());
    } catch (_) {}
  }

  Future<void> _markDone(ReminderModel r) async {
    setState(() => r.done = true);
    NotificationService.instance.cancel(r);
    try {
      await ReminderService.instance.updateReminder(r.id, {'done': true});
    } catch (_) {}
  }

  Future<void> _markActive(ReminderModel r) async {
    setState(() => r.done = false);
    NotificationService.instance.schedule(r);
    try {
      await ReminderService.instance.updateReminder(r.id, {'done': false});
    } catch (_) {}
  }

  Future<void> _snooze(ReminderModel r) async {
    final newDate = r.dueDate.add(const Duration(hours: 1));
    setState(() {
      r.dueDate = newDate;
      r.snoozed = true;
    });
    try {
      await ReminderService.instance.updateReminder(r.id, {
        'due_date': newDate.toIso8601String().split('T').first,
        'snoozed': true,
      });
    } catch (_) {}
  }

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
        actions: [
          if (widget.walletName != 'Personal')
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmojiOrImage(value: widget.walletEmoji, size: 18, borderRadius: 4),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 75,
                    child: Text(
                      widget.walletName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
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

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, isDark, surfBg),
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

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tab,
        children: [
          _ReminderList(
            key: ValueKey('active-${_active.length}'),
            reminders: _active,
            isDark: isDark,
            onDone: _markDone,
            onSnooze: _snooze,
            onDelete: _delete,
            onTap: (r) => _openDetailSheet(context, r, isDark, surfBg),
            onReactivate: null,
            onRefresh: _loadReminders,
          ),
          _ReminderList(
            key: ValueKey('done-${_done.length}'),
            reminders: _done,
            isDark: isDark,
            onDone: null,
            onSnooze: null,
            onDelete: _delete,
            onTap: null,
            onRefresh: _loadReminders,
            onReactivate: _markActive,
          ),
        ],
      ),
    );
  }

  // ── BUG FIX: use sheetCtx for pop so only the sheet closes, ──────────────
  // ── not the entire AlertMeScreen.                            ──────────────
  void _openAddSheet(BuildContext screenCtx, bool isDark, Color surfBg) {
    showModalBottomSheet(
      context: screenCtx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddReminderSheetHost(
        isDark: isDark,
        surfBg: surfBg,
        walletId: widget.walletId,
        members: widget.members,
        isPersonal: widget.isPersonal,
        onSave: (r) => _add(r),
      ),
    );
  }

  void _openDetailSheet(
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
        onEdit: () {
          Navigator.pop(context);
          _openEditSheet(context, r, isDark, surfBg);
        },
      ),
    );
  }

  void _openEditSheet(
    BuildContext screenCtx,
    ReminderModel existing,
    bool isDark,
    Color surfBg,
  ) {
    showModalBottomSheet(
      context: screenCtx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddReminderSheetHost(
        isDark: isDark,
        surfBg: surfBg,
        walletId: widget.walletId,
        members: widget.members,
        isPersonal: widget.isPersonal,
        existing: existing,
        onSave: (r) => _update(r),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REMINDER LIST
// ─────────────────────────────────────────────────────────────────────────────

class _ReminderList extends StatelessWidget {
  final List<ReminderModel> reminders;
  final bool isDark;
  final void Function(ReminderModel)? onDone;
  final void Function(ReminderModel)? onSnooze;
  final void Function(ReminderModel) onDelete;
  final void Function(ReminderModel)? onTap;
  final void Function(ReminderModel)? onReactivate;
  final Future<void> Function() onRefresh;

  const _ReminderList({
    super.key,
    required this.reminders,
    required this.isDark,
    required this.onDone,
    required this.onSnooze,
    required this.onDelete,
    required this.onTap,
    required this.onRefresh,
    this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 200),
            PlanEmptyState(
              emoji: '🔔',
              title: 'No reminders',
              subtitle: 'Tap + to add your first reminder',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
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
              onReactivate: onReactivate != null ? () => onReactivate!(reminders[i]) : null,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REMINDER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  final ReminderModel reminder;
  final bool isDark;
  final VoidCallback? onDone, onSnooze, onTap, onReactivate;

  const _ReminderCard({
    required this.reminder,
    required this.isDark,
    this.onDone,
    this.onSnooze,
    this.onTap,
    this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Priority colour strip
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
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
                      if (onDone != null || onSnooze != null || onReactivate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              if (onSnooze != null) ...[
                                _ActionBtn(
                                  label: '💤 Snooze 1h',
                                  color: AppColors.lend,
                                  onTap: onSnooze!,
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (onDone != null)
                                _ActionBtn(
                                  label: '✓ Done',
                                  color: AppColors.income,
                                  onTap: onDone!,
                                ),
                              if (onReactivate != null)
                                _ActionBtn(
                                  label: '↩ Reactivate',
                                  color: AppColors.primary,
                                  onTap: onReactivate!,
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
        ), // IntrinsicHeight
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

// ─────────────────────────────────────────────────────────────────────────────
// REMINDER DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ReminderDetailSheet extends StatelessWidget {
  final ReminderModel reminder;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onSnooze, onDone, onDelete, onEdit;

  const _ReminderDetailSheet({
    required this.reminder,
    required this.isDark,
    required this.surfBg,
    required this.onSnooze,
    required this.onDone,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final member = mockMembers.firstWhere(
      (m) => m.id == reminder.assignedTo,
      orElse: () => const PlanMember(id: '?', name: '?', emoji: '👤'),
    );

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
          // Edit button
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.expense, Color(0xFFFF8A65)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Edit Reminder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SheetBtn(
                  label: '💤 Snooze 1h',
                  color: AppColors.lend,
                  onTap: onSnooze,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SheetBtn(
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

class _SheetBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SheetBtn({
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

// ─────────────────────────────────────────────────────────────────────────────
// HOST WRAPPER — manages its own context for pop + snackbar
// ─────────────────────────────────────────────────────────────────────────────

class _AddReminderSheetHost extends StatelessWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final List<PlanMember> members;
  final bool isPersonal;
  final ReminderModel? existing; // null = add mode, non-null = edit mode
  final void Function(ReminderModel) onSave;

  const _AddReminderSheetHost({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    this.members = const [],
    this.isPersonal = true,
    this.existing,
    required this.onSave,
  });

  @override
  Widget build(BuildContext hostCtx) {
    final isEdit = existing != null;
    return Container(
      height: MediaQuery.of(hostCtx).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
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
          Expanded(
            child: _AddReminderSheet(
              isDark: isDark,
              surfBg: surfBg,
              walletId: walletId,
              members: members,
              isPersonal: isPersonal,
              existing: existing,
              onSave: (r) {
                Navigator.pop(hostCtx);
                onSave(r);
                ScaffoldMessenger.of(hostCtx).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEdit
                          ? '${r.emoji} "${r.title}" updated!'
                          : '${r.emoji} "${r.title}" saved!',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: AppColors.income,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD REMINDER SHEET  —  AI Parse tab  +  Manual tab
// ─────────────────────────────────────────────────────────────────────────────

class _AddReminderSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final List<PlanMember> members;
  final bool isPersonal;
  final ReminderModel? existing; // null = add, non-null = edit
  final void Function(ReminderModel) onSave;

  const _AddReminderSheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    this.members = const [],
    this.isPersonal = true,
    this.existing,
    required this.onSave,
  });

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet>
    with SingleTickerProviderStateMixin {
  late TabController _mode; // 0 = AI, 1 = Manual

  // AI mode
  final _aiCtrl = TextEditingController();
  bool _aiParsing = false;
  _ParsedReminder? _aiPreview;
  String? _aiError;
  bool _usingClaudeAI = false;

  // Shared form state — filled by AI parse OR manually
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _emoji = '🔔';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  RepeatMode _repeat = RepeatMode.none;
  Priority _priority = Priority.medium;
  String _assignedTo = 'me';

  // validation
  bool _titleError = false;

  static const _emojis = [
    '🔔',
    '⏰',
    '📅',
    '💊',
    '🏥',
    '💉',
    '🦷',
    '💼',
    '📞',
    '🎂',
    '🚗',
    '✈️',
    '🎓',
    '📚',
    '🏋️',
    '🛒',
    '💰',
    '🧾',
    '🏦',
    '⚠️',
    '🏠',
    '👨‍👩‍👧',
    '🌡️',
    '💸',
    '🗓️',
  ];

  @override
  void initState() {
    super.initState();
    // Edit mode: start on Manual tab pre-filled with existing data
    final e = widget.existing;
    _mode = TabController(
      length: 2,
      vsync: this,
      initialIndex: e != null ? 1 : 0,
    );
    _mode.addListener(() => setState(() {}));

    if (e != null) {
      _titleCtrl.text = e.title;
      _noteCtrl.text = e.note ?? '';
      _emoji = e.emoji;
      _date = e.dueDate;
      _time = e.dueTime;
      _repeat = e.repeat;
      _priority = e.priority;
      _assignedTo = e.assignedTo;
    }
  }

  @override
  void dispose() {
    _mode.dispose();
    _aiCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── AI parse: Claude API first, local NLP fallback ───────────────────────
  Future<void> _parseAI(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _aiParsing = true;
      _aiError = null;
      _aiPreview = null;
      _usingClaudeAI = false;
    });

    _ParsedReminder? result;
    try {
      result = await _ClaudeParser.parse(text.trim(), widget.walletId);
      _usingClaudeAI = true;
    } catch (_) {
      try {
        result = _NlpParser.parse(text.trim(), widget.walletId);
        _usingClaudeAI = false;
      } catch (e) {
        if (mounted) {
          setState(() {
            _aiParsing = false;
            _aiError = 'Could not understand — try again or fill manually.';
          });
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _aiPreview = result;
      _aiParsing = false;
      _titleCtrl.text = result!.title;
      _noteCtrl.text = result.note ?? '';
      _emoji = result.emoji;
      _date = result.date;
      _time = result.time;
      _priority = result.priority;
      _repeat = result.repeat;
      _assignedTo = result.assignedTo;
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      if (_mode.index == 0) _mode.animateTo(1);
      return;
    }
    setState(() => _titleError = false);
    final existing = widget.existing;
    widget.onSave(
      ReminderModel(
        id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        emoji: _emoji,
        dueDate: _date,
        dueTime: _time,
        repeat: _repeat,
        priority: _priority,
        assignedTo: _assignedTo,
        walletId: widget.walletId,
        done: existing?.done ?? false,
        snoozed: existing?.snoozed ?? false,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      children: [
        // ── Header ───────────────────────────────────────────────────────
        Row(
          children: [
            const Text('🔔', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(
              widget.existing != null ? 'Edit Reminder' : 'New Reminder',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Mode switcher ─────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: widget.surfBg,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(3),
          child: TabBar(
            controller: _mode,
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.expense, Color(0xFFFF8A65)],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: sub,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              fontFamily: 'Nunito',
            ),
            padding: EdgeInsets.zero,
            tabs: const [
              Tab(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('✨', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('AI Parse'),
                  ],
                ),
              ),
              Tab(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_outlined, size: 14),
                    SizedBox(width: 6),
                    Text('Manual'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── AI TAB ────────────────────────────────────────────────────────
        if (_mode.index == 0) ...[
          _AiHintBanner(isDark: widget.isDark),
          const SizedBox(height: 12),
          _AiInputBox(
            ctrl: _aiCtrl,
            surfBg: widget.surfBg,
            isDark: widget.isDark,
            isParsing: _aiParsing,
            onParse: () => _parseAI(_aiCtrl.text),
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 10),
            _ErrorBanner(message: _aiError!),
          ],
          if (_aiPreview != null) ...[
            const SizedBox(height: 12),
            _AiPreviewCard(
              preview: _aiPreview!,
              isDark: widget.isDark,
              surfBg: widget.surfBg,
              usedClaudeAI: _usingClaudeAI,
              onEdit: () => _mode.animateTo(1),
            ),
            const SizedBox(height: 16),
            SaveButton(
              label: widget.existing != null
                  ? 'Update Reminder →'
                  : 'Save Reminder →',
              color: AppColors.expense,
              onTap: _save,
            ),
          ],
          if (_aiPreview == null && !_aiParsing) ...[
            const SizedBox(height: 12),
            _ExamplesSection(
              surfBg: widget.surfBg,
              sub: sub,
              onTap: (s) => _aiCtrl.text = s,
            ),
          ],
        ],

        // ── MANUAL TAB ────────────────────────────────────────────────────
        if (_mode.index == 1) ...[
          _ManualForm(
            isDark: widget.isDark,
            surfBg: widget.surfBg,
            members: widget.members,
            isPersonal: widget.isPersonal,
            titleCtrl: _titleCtrl,
            noteCtrl: _noteCtrl,
            emoji: _emoji,
            date: _date,
            time: _time,
            repeat: _repeat,
            priority: _priority,
            assignedTo: _assignedTo,
            emojis: _emojis,
            titleError: _titleError,
            onEmojiChanged: (v) => setState(() => _emoji = v),
            onDateChanged: (v) => setState(() => _date = v),
            onTimeChanged: (v) => setState(() => _time = v),
            onRepeatChanged: (v) => setState(() => _repeat = v),
            onPriorityChanged: (v) => setState(() => _priority = v),
            onAssignedToChanged: (v) => setState(() => _assignedTo = v),
          ),
          const SizedBox(height: 16),
          SaveButton(
            label: widget.existing != null
                ? 'Update Reminder →'
                : 'Save Reminder →',
            color: AppColors.expense,
            onTap: _save,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AiHintBanner extends StatelessWidget {
  final bool isDark;
  const _AiHintBanner({required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.expense.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.expense.withOpacity(0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('✨', style: TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Describe your reminder in plain English — Claude AI will extract the title, date, time, priority and repeat for you.',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Nunito',
              color: isDark ? AppColors.textDark : AppColors.textLight,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AiInputBox extends StatelessWidget {
  final TextEditingController ctrl;
  final Color surfBg;
  final bool isDark, isParsing;
  final VoidCallback onParse;

  const _AiInputBox({
    required this.ctrl,
    required this.surfBg,
    required this.isDark,
    required this.isParsing,
    required this.onParse,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Container(
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.expense.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: TextField(
              controller: ctrl,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
              decoration: InputDecoration.collapsed(
                hintText:
                    '"Pay electricity bill on 5th at 10am, monthly, high priority"',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: sub,
                  fontFamily: 'Nunito',
                  height: 1.4,
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: AppColors.expense.withOpacity(0.15),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Plain text → AI fills all fields',
                    style: TextStyle(
                      fontSize: 11,
                      color: sub,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: isParsing ? null : onParse,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      gradient: isParsing
                          ? null
                          : const LinearGradient(
                              colors: [AppColors.expense, Color(0xFFFF8A65)],
                            ),
                      color: isParsing
                          ? AppColors.expense.withOpacity(0.3)
                          : null,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: isParsing
                        ? const SizedBox(
                            width: 64,
                            height: 16,
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.transparent,
                              color: Colors.white,
                              minHeight: 2,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('✨', style: TextStyle(fontSize: 13)),
                              SizedBox(width: 5),
                              Text(
                                'Parse',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.expense.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.expense.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.expense,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Nunito',
              color: AppColors.expense,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AiPreviewCard extends StatelessWidget {
  final _ParsedReminder preview;
  final bool isDark;
  final Color surfBg;
  final bool usedClaudeAI;
  final VoidCallback onEdit;

  const _AiPreviewCard({
    required this.preview,
    required this.isDark,
    required this.surfBg,
    required this.usedClaudeAI,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final member = mockMembers.firstWhere(
      (m) => m.id == preview.assignedTo,
      orElse: () => const PlanMember(id: '?', name: 'Me', emoji: '👤'),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.income.withOpacity(isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.income.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: preview.priority.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  preview.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.income.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        usedClaudeAI ? '🤖 AI Parsed' : '✨ AI Parsed',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.income,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Edit button → jump to Manual tab to tweak
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.income.withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 12,
                        color: AppColors.income,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.income,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Parsed field chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PreviewChip(
                icon: Icons.calendar_today_rounded,
                label:
                    '${fmtDateShort(preview.date)} • ${fmtTime(preview.time)}',
                color: daysUntilColor(preview.date),
              ),
              _PreviewChip(
                icon: Icons.flag_rounded,
                label: preview.priority.label,
                color: preview.priority.color,
              ),
              if (preview.repeat != RepeatMode.none)
                _PreviewChip(
                  icon: Icons.repeat_rounded,
                  label: preview.repeat.label,
                  color: AppColors.primary,
                ),
              _PreviewChip(
                icon: Icons.person_rounded,
                label: '${member.emoji} ${member.name}',
                color: AppColors.split,
              ),
              if (preview.note != null && preview.note!.isNotEmpty)
                _PreviewChip(
                  icon: Icons.notes_rounded,
                  label: preview.note!,
                  color: isDark ? AppColors.subDark : AppColors.subLight,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _PreviewChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamplesSection extends StatelessWidget {
  final Color surfBg, sub;
  final void Function(String) onTap;
  const _ExamplesSection({
    required this.surfBg,
    required this.sub,
    required this.onTap,
  });

  static const _examples = [
    'Pay electricity bill on the 5th at 10am, monthly',
    'Doctor appointment tomorrow at 11:30, high priority',
    "Mom's medicine refill every Friday evening",
    'Car insurance renewal in 2 weeks, urgent',
    'Remind me to call school every Monday morning',
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Try an example',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
          color: sub,
        ),
      ),
      const SizedBox(height: 8),
      ..._examples.map(
        (e) => GestureDetector(
          onTap: () => onTap(e),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.expense.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Text('💬', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                ),
                Icon(
                  Icons.north_west_rounded,
                  size: 12,
                  color: AppColors.expense.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MANUAL FORM
// ─────────────────────────────────────────────────────────────────────────────

class _ManualForm extends StatelessWidget {
  final bool isDark;
  final Color surfBg;
  final List<PlanMember> members;
  final bool isPersonal;
  final TextEditingController titleCtrl, noteCtrl;
  final String emoji, assignedTo;
  final DateTime date;
  final TimeOfDay time;
  final RepeatMode repeat;
  final Priority priority;
  final List<String> emojis;
  final bool titleError;
  final void Function(String) onEmojiChanged;
  final void Function(DateTime) onDateChanged;
  final void Function(TimeOfDay) onTimeChanged;
  final void Function(RepeatMode) onRepeatChanged;
  final void Function(Priority) onPriorityChanged;
  final void Function(String) onAssignedToChanged;

  const _ManualForm({
    required this.isDark,
    required this.surfBg,
    this.members = const [],
    this.isPersonal = true,
    required this.titleCtrl,
    required this.noteCtrl,
    required this.emoji,
    required this.date,
    required this.time,
    required this.repeat,
    required this.priority,
    required this.assignedTo,
    required this.emojis,
    required this.titleError,
    required this.onEmojiChanged,
    required this.onDateChanged,
    required this.onTimeChanged,
    required this.onRepeatChanged,
    required this.onPriorityChanged,
    required this.onAssignedToChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Emoji picker
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: emojis
                .map(
                  (e) => GestureDetector(
                    onTap: () => onEmojiChanged(e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: emoji == e
                            ? AppColors.expense.withOpacity(0.15)
                            : surfBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: emoji == e
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
        // Title field with validation
        Container(
          decoration: BoxDecoration(
            color: surfBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: titleError ? AppColors.expense : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                  fontFamily: 'Nunito',
                ),
                decoration: InputDecoration.collapsed(
                  hintText: 'Reminder title *',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: titleError
                        ? AppColors.expense
                        : (isDark ? AppColors.subDark : AppColors.subLight),
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
              if (titleError) ...[
                const SizedBox(height: 4),
                const Text(
                  'Title is required',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.expense,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        PlanInputField(
          controller: noteCtrl,
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
                    initialDate: date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (d != null) onDateChanged(d);
                },
                child: _PickerTile(
                  icon: Icons.calendar_today_rounded,
                  surfBg: surfBg,
                  label: fmtDateShort(date),
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
                    initialTime: time,
                  );
                  if (t != null) onTimeChanged(t);
                },
                child: _PickerTile(
                  icon: Icons.access_time_rounded,
                  surfBg: surfBg,
                  label: fmtTime(time),
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
                      onTap: () => onPriorityChanged(p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: priority == p
                              ? p.color
                              : p.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: priority == p ? p.color : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: priority == p ? Colors.white : p.color,
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
                      onTap: () => onRepeatChanged(rm),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: repeat == rm
                              ? AppColors.primary.withOpacity(0.15)
                              : surfBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: repeat == rm
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
                            color: repeat == rm ? AppColors.primary : sub,
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
        if (isPersonal)
          // Personal wallet — non-interactive "Me" chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👤', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'Me',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: (members.isNotEmpty ? members : mockMembers)
                  .map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => onAssignedToChanged(m.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: assignedTo == m.id
                                ? AppColors.primary.withOpacity(0.15)
                                : surfBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: assignedTo == m.id
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
      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// CLAUDE AI PARSER  —  real Anthropic API, returns structured JSON
// Replace 'YOUR_ANTHROPIC_API_KEY' with your actual key or inject via config.
// Falls back to _NlpParser automatically if no API key / no network.
// ─────────────────────────────────────────────────────────────────────────────

class _ClaudeParser {
  static Future<_ParsedReminder> parse(String text, String walletId) async {
    final result = await AIParser.parseText(
      feature: 'planit',
      subFeature: 'reminder',
      text: text,
    );

    if (!result.success || result.data == null) {
      throw Exception(result.error ?? 'AI parse failed');
    }

    final data = result.data!;
    final now = DateTime.now();

    DateTime date;
    try {
      date = DateTime.parse(data['date'] as String);
    } catch (_) {
      date = now.add(const Duration(days: 1));
    }

    // Parse HH:MM time string
    TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
    final timeStr = data['time'] as String?;
    if (timeStr != null && timeStr.contains(':')) {
      final parts = timeStr.split(':');
      final h = int.tryParse(parts[0]) ?? 9;
      final m = int.tryParse(parts[1]) ?? 0;
      time = TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    }

    const pm = {
      'low': Priority.low,
      'medium': Priority.medium,
      'high': Priority.high,
      'urgent': Priority.urgent,
    };
    const rm = {
      'none': RepeatMode.none,
      'daily': RepeatMode.daily,
      'weekly': RepeatMode.weekly,
      'monthly': RepeatMode.monthly,
      'yearly': RepeatMode.yearly,
    };

    return _ParsedReminder(
      title: data['title'] as String? ?? text,
      emoji: data['emoji'] as String? ?? '🔔',
      date: date,
      time: time,
      priority: pm[data['priority']] ?? Priority.medium,
      repeat: rm[data['repeat']] ?? RepeatMode.none,
      assignedTo: data['assigned_to'] as String? ?? 'me',
      walletId: walletId,
      note: data['note'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCAL NLP PARSER  —  rule-based fallback, zero network calls

class _ParsedReminder {
  final String title, emoji, assignedTo, walletId;
  final DateTime date;
  final TimeOfDay time;
  final Priority priority;
  final RepeatMode repeat;
  final String? note;

  const _ParsedReminder({
    required this.title,
    required this.emoji,
    required this.assignedTo,
    required this.walletId,
    required this.date,
    required this.time,
    required this.priority,
    required this.repeat,
    this.note,
  });
}

class _NlpParser {
  static _ParsedReminder parse(String raw, String walletId) {
    final text = raw.trim();
    final lower = text.toLowerCase();
    final now = DateTime.now();

    // ── Date ─────────────────────────────────────────────────────────────
    DateTime date = now.add(const Duration(days: 1));

    if (lower.contains('today')) {
      date = now;
    } else if (lower.contains('day after tomorrow')) {
      date = now.add(const Duration(days: 2));
    } else if (lower.contains('tomorrow')) {
      date = now.add(const Duration(days: 1));
    } else if (lower.contains('next week')) {
      date = now.add(const Duration(days: 7));
    } else if (lower.contains('next month')) {
      date = DateTime(now.year, now.month + 1, now.day);
    } else {
      final inDays = RegExp(r'in (\d+) days?').firstMatch(lower);
      final inWeeks = RegExp(r'in (\d+) weeks?').firstMatch(lower);
      final onDay = RegExp(
        r'on (?:the )?(\d{1,2})(?:st|nd|rd|th)?',
      ).firstMatch(lower);
      const wdNames = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];

      if (inDays != null) {
        date = now.add(Duration(days: int.parse(inDays.group(1)!)));
      } else if (inWeeks != null) {
        date = now.add(Duration(days: int.parse(inWeeks.group(1)!) * 7));
      } else if (onDay != null) {
        final day = int.parse(onDay.group(1)!);
        date = DateTime(now.year, now.month, day);
        if (date.isBefore(now)) {
          date = DateTime(now.year, now.month + 1, day);
        }
      } else {
        for (int i = 0; i < wdNames.length; i++) {
          if (lower.contains(wdNames[i])) {
            int ahead = (i + 1) - now.weekday;
            if (ahead <= 0) ahead += 7;
            date = now.add(Duration(days: ahead));
            break;
          }
        }
      }
    }

    // ── Time ─────────────────────────────────────────────────────────────
    TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
    final tMatch = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
    ).firstMatch(lower);
    if (tMatch != null) {
      int h = int.parse(tMatch.group(1)!);
      final min = int.tryParse(tMatch.group(2) ?? '0') ?? 0;
      final ap = tMatch.group(3);
      if (ap == 'pm' && h < 12) h += 12;
      if (ap == 'am' && h == 12) h = 0;
      if (h >= 0 && h <= 23) time = TimeOfDay(hour: h, minute: min);
    } else if (lower.contains('morning')) {
      time = const TimeOfDay(hour: 9, minute: 0);
    } else if (lower.contains('afternoon')) {
      time = const TimeOfDay(hour: 14, minute: 0);
    } else if (lower.contains('evening')) {
      time = const TimeOfDay(hour: 18, minute: 0);
    } else if (lower.contains('night')) {
      time = const TimeOfDay(hour: 21, minute: 0);
    } else if (lower.contains('noon') || lower.contains('lunch')) {
      time = const TimeOfDay(hour: 12, minute: 0);
    }

    // ── Priority ─────────────────────────────────────────────────────────
    Priority priority = Priority.medium;
    if (lower.contains('urgent') || lower.contains('asap')) {
      priority = Priority.urgent;
    } else if (lower.contains('high') || lower.contains('important')) {
      priority = Priority.high;
    } else if (lower.contains('low') || lower.contains('someday')) {
      priority = Priority.low;
    }

    // ── Repeat ───────────────────────────────────────────────────────────
    RepeatMode repeat = RepeatMode.none;
    if (lower.contains('every day') || lower.contains('daily')) {
      repeat = RepeatMode.daily;
    } else if (lower.contains('every week') ||
        lower.contains('weekly') ||
        RegExp(r'every (mon|tue|wed|thu|fri|sat|sun)').hasMatch(lower)) {
      repeat = RepeatMode.weekly;
    } else if (lower.contains('every month') || lower.contains('monthly')) {
      repeat = RepeatMode.monthly;
    } else if (lower.contains('every year') ||
        lower.contains('yearly') ||
        lower.contains('annually')) {
      repeat = RepeatMode.yearly;
    }

    // ── Assigned member ──────────────────────────────────────────────────
    String assignedTo = 'me';
    // member detection uses mockMembers as fallback
    for (final m in mockMembers) {
      if (m.id != 'me' && lower.contains(m.name.toLowerCase())) {
        assignedTo = m.id;
        break;
      }
    }

    // ── Emoji inference ──────────────────────────────────────────────────
    String emoji = '🔔';
    if (lower.contains('bill') ||
        lower.contains('electricity') ||
        lower.contains('payment')) {
      emoji = '💡';
    } else if (lower.contains('doctor') ||
        lower.contains('hospital') ||
        lower.contains('clinic')) {
      emoji = '🏥';
    } else if (lower.contains('medicine') ||
        lower.contains('pill') ||
        lower.contains('tablet')) {
      emoji = '💊';
    } else if (lower.contains('car') ||
        lower.contains('vehicle') ||
        lower.contains('insurance')) {
      emoji = '🚗';
    } else if (lower.contains('birthday') || lower.contains('anniversary')) {
      emoji = '🎂';
    } else if (lower.contains('school') ||
        lower.contains('class') ||
        lower.contains('study')) {
      emoji = '📚';
    } else if (lower.contains('meeting') || lower.contains('appointment')) {
      emoji = '📅';
    } else if (lower.contains('call') || lower.contains('phone')) {
      emoji = '📞';
    } else if (lower.contains('dentist') || lower.contains('dental')) {
      emoji = '🦷';
    } else if (lower.contains('gym') ||
        lower.contains('workout') ||
        lower.contains('exercise')) {
      emoji = '🏋️';
    } else if (lower.contains('travel') ||
        lower.contains('flight') ||
        lower.contains('trip')) {
      emoji = '✈️';
    } else if (lower.contains('shopping') || lower.contains('grocery')) {
      emoji = '🛒';
    }

    // ── Title — strip filler phrases & trailing metadata ─────────────────
    final title = _cleanTitle(text);

    return _ParsedReminder(
      title: title,
      emoji: emoji,
      assignedTo: assignedTo,
      walletId: walletId,
      date: date,
      time: time,
      priority: priority,
      repeat: repeat,
    );
  }

  static String _cleanTitle(String text) {
    String s = text;
    for (final pattern in [
      RegExp(r'remind me to\s*', caseSensitive: false),
      RegExp(r'remind me\s*', caseSensitive: false),
      RegExp(r"don'?t forget to\s*", caseSensitive: false),
      RegExp(r'please\s+', caseSensitive: false),
      RegExp(r'set a? ?reminder (?:to|for)?\s*', caseSensitive: false),
      RegExp(r'alert me (?:to|about)?\s*', caseSensitive: false),
    ]) {
      s = s.replaceFirst(pattern, '');
    }

    s = s
        .replaceAll(
          RegExp(
            r'\s+(today|tomorrow|tonight|next week|next month)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s+on (?:the )?\d{1,2}(?:st|nd|rd|th)?(?:\s+\w+)?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s+at \d{1,2}(?::\d{2})?\s*(?:am|pm)?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r',?\s*(?:high|low|urgent|medium)\s+priority',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r',?\s*(?:every day|daily|every week|weekly|every month|monthly|every year|yearly|annually)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r',?\s*(?:morning|afternoon|evening|night|noon)',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    if (s.isNotEmpty) s = s[0].toUpperCase() + s.substring(1);
    if (s.length < 3) s = text.trim(); // fallback to original
    if (s.length > 60) s = '${s.substring(0, 57)}...';
    return s;
  }
}
