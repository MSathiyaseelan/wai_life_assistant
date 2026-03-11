import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

// ── MonthRange data class ─────────────────────────────────────────────────────

class MonthRange {
  /// Both are normalised to the 1st of the month (time == 00:00:00).
  final DateTime start;
  final DateTime end;

  const MonthRange({required this.start, required this.end});

  factory MonthRange.single(int year, int month) {
    final d = DateTime(year, month); // Dart normalises month overflow
    return MonthRange(start: d, end: d);
  }

  factory MonthRange.thisMonth() {
    final now = DateTime.now();
    return MonthRange.single(now.year, now.month);
  }

  bool get isSingleMonth =>
      start.year == end.year && start.month == end.month;

  /// True when [date]'s year+month falls inside [start]..[end] (inclusive).
  bool contains(DateTime date) {
    final d = DateTime(date.year, date.month);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  static const _short = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get label {
    if (isSingleMonth) return '${_short[start.month - 1]} ${start.year}';
    if (start.year == end.year) {
      return '${_short[start.month - 1]} – ${_short[end.month - 1]} ${start.year}';
    }
    return '${_short[start.month - 1]} ${start.year} – ${_short[end.month - 1]} ${end.year}';
  }
}

// ── MonthYearPicker header button ─────────────────────────────────────────────

class MonthYearPicker extends StatelessWidget {
  final MonthRange selected;
  final VoidCallback onTap;

  const MonthYearPicker({
    super.key,
    required this.selected,
    required this.onTap,
  });

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
            selected.label,
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

  static Future<MonthRange?> showPicker(
      BuildContext context, MonthRange initial) async {
    return showModalBottomSheet<MonthRange>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MonthRangeSheet(initial: initial),
    );
  }
}

// ── Picker sheet ──────────────────────────────────────────────────────────────

class _MonthRangeSheet extends StatefulWidget {
  final MonthRange initial;
  const _MonthRangeSheet({required this.initial});

  @override
  State<_MonthRangeSheet> createState() => _MonthRangeSheetState();
}

class _MonthRangeSheetState extends State<_MonthRangeSheet> {
  late int _year;
  DateTime? _start; // nullable = no selection yet
  DateTime? _end;   // nullable = awaiting second tap

  static const _short = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _full = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _year  = widget.initial.end.year;
    _start = widget.initial.start;
    _end   = widget.initial.end;
  }

  bool _isStart(int y, int m) =>
      _start != null && _start!.year == y && _start!.month == m;

  bool _isEnd(int y, int m) =>
      _end != null && _end!.year == y && _end!.month == m;

  bool _isInRange(int y, int m) {
    if (_start == null || _end == null) return false;
    final d = DateTime(y, m);
    return d.isAfter(_start!) && d.isBefore(_end!);
  }

  void _onMonthTap(int month) {
    final tapped = DateTime(_year, month);
    setState(() {
      if (_start == null || _end != null) {
        // Start a fresh selection
        _start = tapped;
        _end   = null;
      } else {
        // Second tap — set end (or collapse to single if same month)
        if (tapped == _start) {
          _end = _start; // single-month
        } else if (tapped.isBefore(_start!)) {
          _end   = _start;
          _start = tapped;
        } else {
          _end = tapped;
        }
      }
    });
  }

  void _applyQuick(MonthRange range) => Navigator.pop(context, range);

  void _confirm() {
    if (_start == null) return;
    Navigator.pop(context, MonthRange(start: _start!, end: _end ?? _start!));
  }

  String get _selectionLabel {
    if (_start == null) return 'Tap a month to start';
    if (_end == null)   return 'Tap another month to set range';
    if (_start == _end ||
        (_start!.year == _end!.year && _start!.month == _end!.month)) {
      return '${_full[_start!.month - 1]} ${_start!.year}';
    }
    final s = '${_full[_start!.month - 1]} ${_start!.year}';
    final e = '${_full[_end!.month - 1]} ${_end!.year}';
    return '$s  →  $e';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final now    = DateTime.now();

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2)),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [

            // ── Quick-select chips ────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _QuickChip('This Month', isDark,
                    onTap: () => _applyQuick(MonthRange.thisMonth())),
                _QuickChip('Last 3M', isDark,
                    onTap: () => _applyQuick(MonthRange(
                          start: DateTime(now.year, now.month - 2),
                          end:   DateTime(now.year, now.month),
                        ))),
                _QuickChip('Last 6M', isDark,
                    onTap: () => _applyQuick(MonthRange(
                          start: DateTime(now.year, now.month - 5),
                          end:   DateTime(now.year, now.month),
                        ))),
                _QuickChip('This Year', isDark,
                    onTap: () => _applyQuick(MonthRange(
                          start: DateTime(now.year, 1),
                          end:   DateTime(now.year, now.month),
                        ))),
              ]),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── Year navigation ───────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(
                onPressed: () => setState(() => _year--),
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.primary,
              ),
              Text('$_year', style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito', color: AppColors.primary)),
              IconButton(
                onPressed: () => setState(() => _year++),
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.primary,
              ),
            ]),
            const SizedBox(height: 10),

            // ── Month grid (3 cols × 4 rows) ──────────────────────────────
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: 12,
              itemBuilder: (_, i) {
                final m       = i + 1;
                final isStart = _isStart(_year, m);
                final isEnd   = _isEnd(_year, m);
                final inRange = _isInRange(_year, m);
                final isEdge  = isStart || isEnd;
                return GestureDetector(
                  onTap: () => _onMonthTap(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isEdge
                          ? AppColors.primary
                          : inRange
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEdge
                            ? AppColors.primary
                            : inRange
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : (isDark
                                    ? Colors.white12
                                    : Colors.black12),
                        width: 1.4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(_short[i], style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: isEdge
                          ? Colors.white
                          : inRange
                              ? AppColors.primary
                              : (isDark ? Colors.white70 : Colors.black87),
                    )),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // ── Selection label ───────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _selectionLabel,
                key: ValueKey(_selectionLabel),
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),

            // ── Confirm button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_start != null && _end != null) ? _confirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _end != null ? 'Apply Filter' : 'Select end month',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
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

// ── Quick-select chip ─────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickChip(this.label, this.isDark, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16213E) : const Color(0xFFEEEDFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          fontFamily: 'Nunito',
        )),
      ),
    );
  }
}
