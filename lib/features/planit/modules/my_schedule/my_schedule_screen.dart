import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import '../../widgets/plan_widgets.dart';

class MyScheduleScreen extends StatefulWidget {
  final String walletId;
  const MyScheduleScreen({super.key, required this.walletId});
  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final List<AppointmentModel> _appts = List.from(mockAppointments);

  List<AppointmentModel> get _upcoming =>
      _appts.where((a) => a.walletId == widget.walletId && !a.done).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  List<AppointmentModel> get _past =>
      _appts.where((a) => a.walletId == widget.walletId && a.done).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

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

  void _add(AppointmentModel a) => setState(() => _appts.add(a));
  void _delete(AppointmentModel a) => setState(() => _appts.remove(a));
  void _markDone(AppointmentModel a) => setState(() => a.done = true);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

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
            Text('🗓️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'My Schedule',
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
          indicatorColor: AppColors.income,
          labelColor: AppColors.income,
          unselectedLabelColor: sub,
          tabs: [
            Tab(text: 'Upcoming (${_upcoming.length})'),
            Tab(text: 'Past (${_past.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPlanSheet(
          context,
          child: _AddApptSheet(
            isDark: isDark,
            surfBg: surfBg,
            walletId: widget.walletId,
            onSave: (a) {
              _add(a);
              Navigator.pop(context);
            },
          ),
        ),
        backgroundColor: AppColors.income,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Appointment',
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
          _ApptList(
            appts: _upcoming,
            isDark: isDark,
            onDone: _markDone,
            onDelete: _delete,
            onTap: (a) => showPlanSheet(
              context,
              child: _ApptDetailSheet(
                appt: a,
                isDark: isDark,
                surfBg: surfBg,
                onDone: () {
                  _markDone(a);
                  Navigator.pop(context);
                },
                onDelete: () {
                  _delete(a);
                  Navigator.pop(context);
                },
              ),
            ),
          ),
          _ApptList(
            appts: _past,
            isDark: isDark,
            onDone: null,
            onDelete: _delete,
            onTap: null,
          ),
        ],
      ),
    );
  }
}

// ── Appointment list ──────────────────────────────────────────────────────────

class _ApptList extends StatelessWidget {
  final List<AppointmentModel> appts;
  final bool isDark;
  final void Function(AppointmentModel)? onDone;
  final void Function(AppointmentModel) onDelete;
  final void Function(AppointmentModel)? onTap;

  const _ApptList({
    required this.appts,
    required this.isDark,
    required this.onDone,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (appts.isEmpty) {
      return const PlanEmptyState(
        emoji: '🗓️',
        title: 'No appointments',
        subtitle: 'Tap + to add your first appointment',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: appts.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SwipeTile(
          onDelete: () => onDelete(appts[i]),
          child: _ApptCard(
            appt: appts[i],
            isDark: isDark,
            onDone: onDone != null ? () => onDone!(appts[i]) : null,
            onTap: onTap != null ? () => onTap!(appts[i]) : null,
          ),
        ),
      ),
    );
  }
}

// ── Appointment card ──────────────────────────────────────────────────────────

class _ApptCard extends StatelessWidget {
  final AppointmentModel appt;
  final bool isDark;
  final VoidCallback? onDone, onTap;
  const _ApptCard({
    required this.appt,
    required this.isDark,
    this.onDone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final due = daysUntil(appt.date);
    final dueCol = appt.done ? sub : daysUntilColor(appt.date);

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
            // Left: date column
            Container(
              width: 68,
              decoration: BoxDecoration(
                color: AppColors.income.withOpacity(0.1),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${appt.date.day}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'DM Mono',
                      color: tc,
                    ),
                  ),
                  Text(
                    [
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
                    ][appt.date.month - 1],
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                  Text(
                    fmtTime(appt.time),
                    style: const TextStyle(
                      fontSize: 9,
                      fontFamily: 'Nunito',
                      color: AppColors.income,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(appt.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            appt.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: tc,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: appt.withWhom,
                    ),
                    if (appt.address != null)
                      InfoRow(icon: Icons.place_rounded, label: appt.address!),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: dueCol.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            due,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: dueCol,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${appt.durationMin}min',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                        const Spacer(),
                        if (onDone != null)
                          GestureDetector(
                            onTap: onDone,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.income.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '✓ Done',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Nunito',
                                  color: AppColors.income,
                                ),
                              ),
                            ),
                          ),
                      ],
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

// ── Appointment detail sheet ──────────────────────────────────────────────────

class _ApptDetailSheet extends StatelessWidget {
  final AppointmentModel appt;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onDone, onDelete;
  const _ApptDetailSheet({
    required this.appt,
    required this.isDark,
    required this.surfBg,
    required this.onDone,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.income.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(appt.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appt.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    Text(
                      '${fmtDate(appt.date)}  •  ${fmtTime(appt.time)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Details
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfDark : const Color(0xFFEDEEF5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.person_rounded,
                  label: appt.withWhom,
                  iconColor: AppColors.income,
                ),
                if (appt.phone != null)
                  InfoRow(
                    icon: Icons.phone_rounded,
                    label: appt.phone!,
                    iconColor: AppColors.income,
                  ),
                if (appt.address != null)
                  InfoRow(icon: Icons.place_rounded, label: appt.address!),
                InfoRow(
                  icon: Icons.timer_outlined,
                  label: '${appt.durationMin} minutes',
                ),
                if (appt.notes != null)
                  InfoRow(icon: Icons.notes_rounded, label: appt.notes!),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text(
                    'Delete',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expense,
                    side: const BorderSide(color: AppColors.expense),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text(
                    'Mark Done',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.income,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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

// ── Add Appointment Sheet ─────────────────────────────────────────────────────

class _AddApptSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final void Function(AppointmentModel) onSave;
  const _AddApptSheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    required this.onSave,
  });
  @override
  State<_AddApptSheet> createState() => _AddApptSheetState();
}

class _AddApptSheetState extends State<_AddApptSheet> {
  final _titleCtrl = TextEditingController();
  final _withCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _durCtrl = TextEditingController(text: '60');
  String _emoji = '🗓️';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);

  final _emojis = [
    '🗓️',
    '👨‍⚕️',
    '🏦',
    '🎒',
    '💼',
    '🏥',
    '⚖️',
    '🔧',
    '📋',
    '🧑‍💼',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _withCtrl.dispose();
    _phoneCtrl.dispose();
    _addrCtrl.dispose();
    _notesCtrl.dispose();
    _durCtrl.dispose();
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
            'Add Appointment',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 14),

          // Emoji strip
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
                              ? AppColors.income.withOpacity(0.15)
                              : widget.surfBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _emoji == e
                                ? AppColors.income
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

          PlanInputField(controller: _titleCtrl, hint: 'Appointment title *'),
          const SizedBox(height: 8),
          PlanInputField(
            controller: _withCtrl,
            hint: 'With whom? (Dr. / Bank / School…)',
          ),
          const SizedBox(height: 8),
          PlanInputField(
            controller: _phoneCtrl,
            hint: 'Phone (optional)',
            inputType: TextInputType.phone,
          ),
          const SizedBox(height: 8),
          PlanInputField(controller: _addrCtrl, hint: 'Location / address'),
          const SizedBox(height: 8),
          PlanInputField(
            controller: _durCtrl,
            hint: 'Duration (minutes)',
            inputType: TextInputType.number,
          ),
          const SizedBox(height: 12),

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
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: widget.surfBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          fmtDateShort(_date),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (t != null) setState(() => _time = t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: widget.surfBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          fmtTime(_time),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PlanInputField(
            controller: _notesCtrl,
            hint: 'Notes (e.g. carry reports)',
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          SaveButton(
            label: 'Save Appointment',
            color: AppColors.income,
            onTap: () {
              if (_titleCtrl.text.trim().isEmpty ||
                  _withCtrl.text.trim().isEmpty)
                return;
              widget.onSave(
                AppointmentModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: _titleCtrl.text.trim(),
                  emoji: _emoji,
                  withWhom: _withCtrl.text.trim(),
                  date: _date,
                  time: _time,
                  walletId: widget.walletId,
                  phone: _phoneCtrl.text.trim().isEmpty
                      ? null
                      : _phoneCtrl.text.trim(),
                  address: _addrCtrl.text.trim().isEmpty
                      ? null
                      : _addrCtrl.text.trim(),
                  durationMin: int.tryParse(_durCtrl.text) ?? 60,
                  notes: _notesCtrl.text.trim().isEmpty
                      ? null
                      : _notesCtrl.text.trim(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
