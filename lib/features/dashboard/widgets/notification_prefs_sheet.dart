import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/notification_prefs.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION PREFERENCES SHEET
// Full notification settings tree under Settings → Preferences → Notifications
// ─────────────────────────────────────────────────────────────────────────────

class NotificationPrefsSheet extends StatefulWidget {
  final bool isDark;
  const NotificationPrefsSheet({super.key, required this.isDark});

  @override
  State<NotificationPrefsSheet> createState() => _NotificationPrefsSheetState();
}

class _NotificationPrefsSheetState extends State<NotificationPrefsSheet> {
  final _prefs = NotificationPrefs.instance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _prefs.init().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  // ── colours ────────────────────────────────────────────────────────────────
  Color get _bg   => widget.isDark ? AppColors.cardDark  : AppColors.cardLight;
  Color get _surf => widget.isDark ? AppColors.surfDark  : const Color(0xFFEDEEF5);
  Color get _tc   => widget.isDark ? AppColors.textDark  : AppColors.textLight;
  Color get _sub  => widget.isDark ? AppColors.subDark   : AppColors.subLight;
  Color get _div  => widget.isDark
      ? Colors.white.withAlpha(18)
      : Colors.black.withAlpha(18);

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _prefs,
      builder: (_, _) => Container(
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _handle(),
            _header(context),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      children: [
                        _masterToggle(),
                        if (_prefs.masterOn) ...[
                          const SizedBox(height: 12),
                          _section('Wallet', [
                            _toggle(
                              '👨‍👩‍👧',
                              'Family expense added',
                              'Notify when a family member adds a transaction',
                              _prefs.walletFamilyExpense,
                              (v) => setState(() => _prefs.walletFamilyExpense = v),
                            ),
                            _toggle(
                              '🤝',
                              'Lend / Borrow reminders',
                              'Remind you of pending lend or borrow entries',
                              _prefs.walletLendBorrow,
                              (v) => setState(() => _prefs.walletLendBorrow = v),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          _section('Pantry', [
                            _toggle(
                              '📦',
                              'Low stock alerts',
                              'Alert when pantry items are running low',
                              _prefs.pantryLowStock,
                              (v) => setState(() => _prefs.pantryLowStock = v),
                            ),
                            _toggle(
                              '⏰',
                              'Expiry alerts',
                              'Alert before items expire',
                              _prefs.pantryExpiry,
                              (v) => setState(() => _prefs.pantryExpiry = v),
                              child: _prefs.pantryExpiry
                                  ? _chipPicker(
                                      label: 'Alert days before expiry',
                                      options: const [1, 2, 3, 7],
                                      selected: _prefs.pantryExpiryDays,
                                      onSelect: (v) => setState(() => _prefs.pantryExpiryDays = v),
                                      suffix: 'd',
                                    )
                                  : null,
                            ),
                            _toggle(
                              '🍽️',
                              'Meal plan reminder',
                              'Daily reminder to log your meals',
                              _prefs.pantryMealReminder,
                              (v) => setState(() => _prefs.pantryMealReminder = v),
                              child: _prefs.pantryMealReminder
                                  ? _timePicker(
                                      label: 'Remind at',
                                      time: _prefs.pantryMealTimeOfDay,
                                      onPick: (t) => setState(() =>
                                          _prefs.pantryMealTime =
                                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'),
                                    )
                                  : null,
                            ),
                          ]),
                          const SizedBox(height: 12),
                          _section('PlanIt', [
                            _toggle(
                              '✅',
                              'Task due reminders',
                              'Remind before tasks are due',
                              _prefs.planItTaskDue,
                              (v) => setState(() => _prefs.planItTaskDue = v),
                              child: _prefs.planItTaskDue
                                  ? _chipPicker(
                                      label: 'Remind days before due',
                                      options: const [1, 3, 7],
                                      selected: _prefs.planItTaskDueDays,
                                      onSelect: (v) => setState(() => _prefs.planItTaskDueDays = v),
                                      suffix: 'd',
                                    )
                                  : null,
                            ),
                            _toggle(
                              '🎉',
                              'Special day countdowns',
                              'Remind you before birthdays and anniversaries',
                              _prefs.planItSpecialDay,
                              (v) => setState(() => _prefs.planItSpecialDay = v),
                              child: _prefs.planItSpecialDay
                                  ? _chipPicker(
                                      label: 'Remind days before',
                                      options: const [1, 3, 7],
                                      selected: _prefs.planItSpecialDayDays,
                                      onSelect: (v) => setState(() => _prefs.planItSpecialDayDays = v),
                                      suffix: 'd',
                                    )
                                  : null,
                            ),
                            _toggle(
                              '🔔',
                              'Alert Me reminders',
                              'Custom reminders you\'ve set in PlanIt',
                              _prefs.planItAlertMe,
                              (v) => setState(() => _prefs.planItAlertMe = v),
                            ),
                            _toggle(
                              '📝',
                              'Sticky note mentions',
                              'Notify when you\'re mentioned in a family note',
                              _prefs.planItStickyMentions,
                              (v) => setState(() => _prefs.planItStickyMentions = v),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          _section('Functions', [
                            _toggle(
                              '📅',
                              'Upcoming function reminders',
                              'Remind you before events and functions',
                              _prefs.functionsUpcoming,
                              (v) => setState(() => _prefs.functionsUpcoming = v),
                              child: _prefs.functionsUpcoming
                                  ? _chipPicker(
                                      label: 'Remind days before',
                                      options: const [3, 7, 14],
                                      selected: _prefs.functionsUpcomingDays,
                                      onSelect: (v) => setState(() => _prefs.functionsUpcomingDays = v),
                                      suffix: 'd',
                                    )
                                  : null,
                            ),
                          ]),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── components ─────────────────────────────────────────────────────────────

  Widget _handle() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _sub.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 10),
        child: Row(
          children: [
            Text(
              '🔔  Notifications',
              style: TextStyle(
                fontSize: 17,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                color: _tc,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close_rounded, color: _sub, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

  Widget _masterToggle() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _prefs.masterOn
              ? AppColors.primary.withAlpha(20)
              : _surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _prefs.masterOn
                ? AppColors.primary.withAlpha(60)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _prefs.masterOn
                    ? AppColors.primary.withAlpha(30)
                    : _sub.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _prefs.masterOn
                    ? Icons.notifications_rounded
                    : Icons.notifications_off_rounded,
                size: 20,
                color: _prefs.masterOn ? AppColors.primary : _sub,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Notifications',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      color: _tc,
                    ),
                  ),
                  Text(
                    _prefs.masterOn ? 'Enabled' : 'All notifications are off',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      color: _prefs.masterOn ? AppColors.primary : _sub,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _prefs.masterOn,
              onChanged: (v) => setState(() => _prefs.masterOn = v),
              activeTrackColor: AppColors.primary,
            ),
          ],
        ),
      );

  Widget _section(String title, List<Widget> rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: _sub,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _surf,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: rows.asMap().entries.map((e) {
                return Column(
                  children: [
                    if (e.key > 0) Divider(height: 1, color: _div, indent: 16),
                    e.value,
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      );

  Widget _toggle(
    String emoji,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    Widget? child,
  }) =>
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          color: _tc,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: _sub,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeTrackColor: AppColors.primary,
                ),
              ],
            ),
          ),
          if (child != null)
            Padding(
              padding: const EdgeInsets.only(left: 46, right: 14, bottom: 12),
              child: child,
            ),
        ],
      );

  Widget _chipPicker({
    required String label,
    required List<int> options,
    required int selected,
    required ValueChanged<int> onSelect,
    String suffix = '',
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              color: _sub,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: options.map((v) {
              final active = v == selected;
              return GestureDetector(
                onTap: () => onSelect(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : AppColors.primary.withAlpha(18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$v$suffix',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );

  Widget _timePicker({
    required String label,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onPick,
  }) =>
      Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              color: _sub,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
                builder: (ctx, child) => MediaQuery(
                  data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
                  child: child!,
                ),
              );
              if (picked != null) onPick(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                time.format(context),
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      );
}
