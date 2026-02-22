import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/features/wallet/widgets/month_year_picker.dart';

class WeekCalendarStrip extends StatefulWidget {
  final DateTime selectedDate;
  final void Function(DateTime date) onDateSelected;

  const WeekCalendarStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<WeekCalendarStrip> createState() => _WeekCalendarStripState();
}

class _WeekCalendarStripState extends State<WeekCalendarStrip> {
  late DateTime _weekStart;

  static const _weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
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

  List<DateTime> get _weekDates =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  bool _isSelected(DateTime d) =>
      d.year == widget.selectedDate.year &&
      d.month == widget.selectedDate.month &&
      d.day == widget.selectedDate.day;

  void _prevWeek() {
    HapticFeedback.lightImpact();
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  }

  void _nextWeek() {
    HapticFeedback.lightImpact();
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
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
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    return Container(
      color: isDark ? AppColors.bgDark : AppColors.bgLight,
      child: Column(
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
                        widget.selectedDate,
                      );
                      if (picked != null) {
                        setState(() => _weekStart = _mondayOf(picked));
                        widget.onDateSelected(picked);
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

                // Next week
                _NavBtn(icon: Icons.chevron_right_rounded, onTap: _nextWeek),
              ],
            ),
          ),

          // ── Day pills row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: _weekDates.map((date) {
                final today = _isToday(date);
                final selected = _isSelected(date);
                final dayName = _weekDays[date.weekday % 7];

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onDateSelected(date);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : today
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          // Day name
                          Text(
                            dayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: selected
                                  ? Colors.white70
                                  : today
                                  ? AppColors.primary
                                  : subColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Date number
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Nunito',
                              color: selected
                                  ? Colors.white
                                  : today
                                  ? AppColors.primary
                                  : textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
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
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfDark
              : AppColors.primary.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}
