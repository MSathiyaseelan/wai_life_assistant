import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/features/wallet/widgets/month_year_picker.dart';

class WeekCalendarStrip extends StatefulWidget {
  final DateTime selectedDate;
  final void Function(DateTime date) onDateSelected;
  /// How many weeks ahead of the current week the user may navigate.
  /// 1 = next week only (free plan). -1 = unlimited.
  final int maxWeeksAhead;

  const WeekCalendarStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.maxWeeksAhead = 1,
  });

  @override
  State<WeekCalendarStrip> createState() => _WeekCalendarStripState();
}

class _WeekCalendarStripState extends State<WeekCalendarStrip> {
  late DateTime _weekStart;

  static const _months = [
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

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(widget.selectedDate);
  }

  // Monday of the week containing [date]
  DateTime _mondayOf(DateTime date) {
    final diff = date.weekday - 1; // Mon=1 → diff=0, Sun=7 → diff=6
    return DateTime(date.year, date.month, date.day - diff);
  }

  void _prevWeek() {
    HapticFeedback.lightImpact();
    final newStart = _weekStart.subtract(const Duration(days: 7));
    setState(() => _weekStart = newStart);
    // Notify parent so selectedDate (and MealMapSection) update for the new week
    widget.onDateSelected(newStart);
  }

  bool get _canGoNextWeek {
    if (widget.maxWeeksAhead < 0) return true; // unlimited
    final now = DateTime.now();
    final currentMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final nextStart = _weekStart.add(const Duration(days: 7));
    final weeksAhead = nextStart.difference(currentMonday).inDays ~/ 7;
    return weeksAhead <= widget.maxWeeksAhead;
  }

  void _nextWeek() {
    if (!_canGoNextWeek) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Upgrade your plan to plan meals further ahead.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ));
      return;
    }
    HapticFeedback.lightImpact();
    final newStart = _weekStart.add(const Duration(days: 7));
    setState(() => _weekStart = newStart);
    widget.onDateSelected(newStart);
  }

  String get _headerLabel {
    final end = _weekStart.add(const Duration(days: 6));
    if (_weekStart.month == end.month) {
      return '${_months[_weekStart.month - 1]} ${_weekStart.year}';
    }
    return '${_months[_weekStart.month - 1]} – ${_months[end.month - 1]} ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.bgDark : AppColors.bgLight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Month header row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
            child: Row(
              children: [
                // Prev week
                _NavBtn(icon: Icons.chevron_left_rounded, onTap: _prevWeek),

                // Month label — tappable to open full calendar sheet
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await MonthYearPicker.showPicker(
                        context,
                        MonthRange.single(
                          widget.selectedDate.year,
                          widget.selectedDate.month,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _weekStart = _mondayOf(picked.start));
                        widget.onDateSelected(picked.start);
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _headerLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),

                // Next week — dimmed when plan limit reached
                _NavBtn(
                  icon: Icons.chevron_right_rounded,
                  onTap: _nextWeek,
                  locked: !_canGoNextWeek,
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool locked;
  const _NavBtn({required this.icon, required this.onTap, this.locked = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: locked ? 0.35 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfDark
                : AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            locked ? Icons.lock_rounded : icon,
            color: AppColors.primary,
            size: locked ? 16 : 22,
          ),
        ),
      ),
    );
  }
}
