import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class MonthYearPicker extends StatelessWidget {
  final DateTime selected;
  final VoidCallback onTap;

  const MonthYearPicker({
    super.key,
    required this.selected,
    required this.onTap,
  });

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16213E) : const Color(0xFFEEEDFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_month_rounded,
            color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            '${_months[selected.month - 1]} ${selected.year}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary, size: 18),
        ]),
      ),
    );
  }

  static Future<DateTime?> showPicker(
    BuildContext context, DateTime initial) async {
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CalendarSheet(initial: initial),
    );
  }
}

class _CalendarSheet extends StatefulWidget {
  final DateTime initial;
  const _CalendarSheet({required this.initial});
  @override State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet> {
  late int _year, _month;
  int? _day;

  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];
  static const _shortMonths = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  @override
  void initState() {
    super.initState();
    _year  = widget.initial.year;
    _month = widget.initial.month;
    _day   = widget.initial.day;
  }

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;
  int get _firstWeekday => DateTime(_year, _month, 1).weekday % 7; // 0=Sun

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 20),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2)),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            // ── Year selector ─────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(
                onPressed: () => setState(() => _year--),
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.primary,
              ),
              Text('$_year', style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Nunito',
                color: AppColors.primary)),
              IconButton(
                onPressed: () => setState(() => _year++),
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.primary,
              ),
            ]),
            const SizedBox(height: 8),

            // ── Month selector ────────────────────────────────────────
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 12,
                itemBuilder: (_, i) {
                  final sel = i + 1 == _month;
                  return GestureDetector(
                    onTap: () => setState(() { _month = i + 1; _day = null; }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_shortMonths[i], style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13,
                        fontFamily: 'Nunito',
                        color: sel ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                      )),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // ── Day header ────────────────────────────────────────────
            Row(children: ['S','M','T','W','T','F','S'].map((d) =>
              Expanded(child: Center(child: Text(d, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white38 : Colors.black38))))).toList()),
            const SizedBox(height: 8),

            // ── Day grid ──────────────────────────────────────────────
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4, crossAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemCount: _firstWeekday + _daysInMonth,
              itemBuilder: (_, i) {
                if (i < _firstWeekday) return const SizedBox();
                final day = i - _firstWeekday + 1;
                final isToday = day == DateTime.now().day &&
                    _month == DateTime.now().month &&
                    _year == DateTime.now().year;
                final isSel = day == _day;
                return GestureDetector(
                  onTap: () => setState(() => _day = day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSel ? AppColors.primary
                          : isToday ? AppColors.primary.withOpacity(0.12)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text('$day', style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSel || isToday ? FontWeight.w800 : FontWeight.w500,
                      color: isSel ? Colors.white
                          : isToday ? AppColors.primary
                          : (isDark ? Colors.white70 : Colors.black87),
                    )),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // ── Confirm button ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context,
                    DateTime(_year, _month, _day ?? 1));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _day != null
                    ? 'Confirm: ${_months[_month-1]} $_day, $_year'
                    : 'Confirm: ${_months[_month-1]} $_year',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15,
                    fontFamily: 'Nunito'),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
