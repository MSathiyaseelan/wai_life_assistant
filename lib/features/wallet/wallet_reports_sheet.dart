import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WALLET REPORTS SHEET
// Daily / Weekly / Monthly / Yearly / Category breakdown
// ─────────────────────────────────────────────────────────────────────────────

class WalletReportsSheet extends StatefulWidget {
  final List<TxModel> transactions;
  final WalletModel wallet;

  const WalletReportsSheet({
    super.key,
    required this.transactions,
    required this.wallet,
  });

  static Future<void> show(
    BuildContext context, {
    required List<TxModel> transactions,
    required WalletModel wallet,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WalletReportsSheet(
        transactions: transactions,
        wallet: wallet,
      ),
    );
  }

  @override
  State<WalletReportsSheet> createState() => _WalletReportsSheetState();
}

// ── Period tabs ───────────────────────────────────────────────────────────────

enum _Period { daily, weekly, monthly, yearly, category }

extension _PeriodExt on _Period {
  String get label {
    switch (this) {
      case _Period.daily:    return 'Daily';
      case _Period.weekly:   return 'Weekly';
      case _Period.monthly:  return 'Monthly';
      case _Period.yearly:   return 'Yearly';
      case _Period.category: return 'Category';
    }
  }

  String get emoji {
    switch (this) {
      case _Period.daily:    return '📅';
      case _Period.weekly:   return '📆';
      case _Period.monthly:  return '🗓️';
      case _Period.yearly:   return '📊';
      case _Period.category: return '🏷️';
    }
  }
}

// ── Data bucket ───────────────────────────────────────────────────────────────

class _Bucket {
  final String label;
  double income = 0;
  double expense = 0;
  _Bucket(this.label);
  double get net => income - expense;
}

// ─────────────────────────────────────────────────────────────────────────────

class _WalletReportsSheetState extends State<WalletReportsSheet> {
  _Period _period = _Period.monthly;
  bool _catExpense = true; // category tab: expense vs income toggle

  // Transactions relevant for income/expense charts
  List<TxModel> get _ie => widget.transactions
      .where((t) => t.type == TxType.income || t.type == TxType.expense)
      .toList();

  // ── Data builders ─────────────────────────────────────────────────────────

  List<_Bucket> _daily() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final b = _Bucket(_dayLabel(day, i == 6));
      for (final t in _ie) {
        final td = DateTime(t.date.year, t.date.month, t.date.day);
        if (td == day) _add(b, t);
      }
      return b;
    });
  }

  List<_Bucket> _weekly() {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    // Start of current week (Monday)
    final currentWeekStart =
        todayMidnight.subtract(Duration(days: todayMidnight.weekday - 1));
    return List.generate(8, (i) {
      final ws = currentWeekStart.subtract(Duration(days: 7 * (7 - i)));
      final we = ws.add(const Duration(days: 6));
      final b = _Bucket('${ws.day}/${ws.month}');
      for (final t in _ie) {
        final td = DateTime(t.date.year, t.date.month, t.date.day);
        if (!td.isBefore(ws) && !td.isAfter(we)) _add(b, t);
      }
      return b;
    });
  }

  List<_Bucket> _monthly() {
    final now = DateTime.now();
    return List.generate(12, (i) {
      // subtract months properly
      int year = now.year;
      int month = now.month - (11 - i);
      while (month <= 0) {
        month += 12;
        year--;
      }
      final b = _Bucket(DateFormat('MMM').format(DateTime(year, month)));
      for (final t in _ie) {
        if (t.date.year == year && t.date.month == month) _add(b, t);
      }
      return b;
    });
  }

  List<_Bucket> _yearly() {
    if (_ie.isEmpty) return [_Bucket('${DateTime.now().year}')];
    final years = _ie.map((t) => t.date.year).toSet().toList()..sort();
    return years.map((y) {
      final b = _Bucket('$y');
      for (final t in _ie) {
        if (t.date.year == y) _add(b, t);
      }
      return b;
    }).toList();
  }

  void _add(_Bucket b, TxModel t) {
    if (t.type == TxType.income) {
      b.income += t.amount;
    } else {
      b.expense += t.amount;
    }
  }

  // ── Category data ─────────────────────────────────────────────────────────

  List<MapEntry<String, double>> _categoryData() {
    final target = _catExpense ? TxType.expense : TxType.income;
    final map = <String, double>{};
    for (final t in widget.transactions) {
      if (t.type == target) {
        map[t.category] = (map[t.category] ?? 0) + t.amount;
      }
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  // ── Summary totals ────────────────────────────────────────────────────────

  ({double income, double expense, double net}) _totals(List<_Bucket> buckets) {
    final inc = buckets.fold(0.0, (s, b) => s + b.income);
    final exp = buckets.fold(0.0, (s, b) => s + b.expense);
    return (income: inc, expense: exp, net: inc - exp);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  String _dayLabel(DateTime d, bool isToday) {
    if (isToday) return 'Today';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final color = widget.wallet.gradient[0];

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // ── Handle ────────────────────────────────────────────────────
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: widget.wallet.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.wallet.emoji.startsWith('http') ||
                              widget.wallet.emoji.isEmpty
                          ? (widget.wallet.isPersonal ? '👤' : '👨‍👩‍👧')
                          : widget.wallet.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.wallet.name} Reports',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            color: tc,
                          ),
                        ),
                        Text(
                          '${widget.transactions.length} transactions',
                          style: TextStyle(
                            fontSize: 12,
                            color: sub,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: surfBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: sub,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Period tabs ───────────────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _Period.values.map((p) {
                  final active = _period == p;
                  return GestureDetector(
                    onTap: () => setState(() => _period = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? color.withValues(alpha: 0.12)
                            : surfBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? color : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '${p.emoji} ${p.label}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: active ? color : sub,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: _period == _Period.category
                  ? _CategoryBody(
                      data: _categoryData(),
                      isExpense: _catExpense,
                      onToggle: (v) => setState(() => _catExpense = v),
                      isDark: isDark,
                      surfBg: surfBg,
                      tc: tc,
                      sub: sub,
                      color: color,
                      fmt: _fmt,
                      ctrl: ctrl,
                    )
                  : _ChartBody(
                      buckets: _getPeriodBuckets(),
                      totals: _totals(_getPeriodBuckets()),
                      isDark: isDark,
                      surfBg: surfBg,
                      tc: tc,
                      sub: sub,
                      fmt: _fmt,
                      ctrl: ctrl,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Bucket> _getPeriodBuckets() {
    switch (_period) {
      case _Period.daily:    return _daily();
      case _Period.weekly:   return _weekly();
      case _Period.monthly:  return _monthly();
      case _Period.yearly:   return _yearly();
      case _Period.category: return [];
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHART BODY — bar chart for time-based periods
// ─────────────────────────────────────────────────────────────────────────────

class _ChartBody extends StatelessWidget {
  final List<_Bucket> buckets;
  final ({double income, double expense, double net}) totals;
  final bool isDark;
  final Color surfBg, tc, sub;
  final String Function(double) fmt;
  final ScrollController ctrl;

  const _ChartBody({
    required this.buckets,
    required this.totals,
    required this.isDark,
    required this.surfBg,
    required this.tc,
    required this.sub,
    required this.fmt,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = buckets.fold(0.0, (m, b) => max(m, max(b.income, b.expense)));
    final hasData = maxVal > 0;

    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        // ── Summary cards ────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Income',
                amount: fmt(totals.income),
                color: AppColors.income,
                icon: '💰',
                surfBg: surfBg,
                tc: tc,
                sub: sub,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(
                label: 'Expense',
                amount: fmt(totals.expense),
                color: AppColors.expense,
                icon: '💸',
                surfBg: surfBg,
                tc: tc,
                sub: sub,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(
                label: 'Net',
                amount: fmt(totals.net.abs()),
                color: totals.net >= 0 ? AppColors.income : AppColors.expense,
                icon: totals.net >= 0 ? '📈' : '📉',
                prefix: totals.net >= 0 ? '+' : '-',
                surfBg: surfBg,
                tc: tc,
                sub: sub,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Legend ───────────────────────────────────────────────────────
        Row(
          children: [
            _Legend(color: AppColors.income, label: 'Income'),
            const SizedBox(width: 16),
            _Legend(color: AppColors.expense, label: 'Expense'),
          ],
        ),
        const SizedBox(height: 12),

        // ── Bar chart ────────────────────────────────────────────────────
        if (!hasData)
          _EmptyState(sub: sub)
        else
          SizedBox(
            height: 180,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: buckets.map((b) {
                  final incH = maxVal > 0 ? (b.income / maxVal) * 140 : 0.0;
                  final expH = maxVal > 0 ? (b.expense / maxVal) * 140 : 0.0;
                  return _BarGroup(
                    label: b.label,
                    incomeHeight: incH,
                    expenseHeight: expH,
                    isDark: isDark,
                    sub: sub,
                  );
                }).toList(),
              ),
            ),
          ),

        const SizedBox(height: 24),

        // ── Period detail list ────────────────────────────────────────────
        if (hasData) ...[
          Text(
            'Breakdown',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: 'Nunito',
              color: sub,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          ...buckets.where((b) => b.income > 0 || b.expense > 0).map(
            (b) => _BucketRow(
              bucket: b,
              maxVal: maxVal,
              surfBg: surfBg,
              tc: tc,
              sub: sub,
              fmt: fmt,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY BODY
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryBody extends StatelessWidget {
  final List<MapEntry<String, double>> data;
  final bool isExpense;
  final void Function(bool) onToggle;
  final bool isDark;
  final Color surfBg, tc, sub, color;
  final String Function(double) fmt;
  final ScrollController ctrl;

  const _CategoryBody({
    required this.data,
    required this.isExpense,
    required this.onToggle,
    required this.isDark,
    required this.surfBg,
    required this.tc,
    required this.sub,
    required this.color,
    required this.fmt,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final total = data.fold(0.0, (s, e) => s + e.value);
    final barColor = isExpense ? AppColors.expense : AppColors.income;

    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        // ── Toggle: Expense / Income ──────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onToggle(true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isExpense
                        ? AppColors.expense.withValues(alpha: 0.12)
                        : surfBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isExpense ? AppColors.expense : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    '💸 Expenses',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: isExpense ? AppColors.expense : sub,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => onToggle(false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !isExpense
                        ? AppColors.income.withValues(alpha: 0.12)
                        : surfBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: !isExpense ? AppColors.income : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    '💰 Income',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: !isExpense ? AppColors.income : sub,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (data.isEmpty)
          _EmptyState(sub: sub)
        else ...[
          // ── Total ───────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${data.length} categories',
                style: TextStyle(fontSize: 12, color: sub, fontFamily: 'Nunito'),
              ),
              Text(
                'Total ${fmt(total)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito',
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Category rows ────────────────────────────────────────────────
          ...data.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final pct = total > 0 ? e.value / total : 0.0;
            return _CategoryRow(
              rank: i + 1,
              name: e.key,
              amount: fmt(e.value),
              pct: pct,
              color: barColor,
              surfBg: surfBg,
              tc: tc,
              sub: sub,
            );
          }),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label, amount, icon;
  final Color color, surfBg, tc, sub;
  final String prefix;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.surfBg,
    required this.tc,
    required this.sub,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              '$prefix$amount',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: sub,
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
      );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
            ),
          ),
        ],
      );
}

class _BarGroup extends StatelessWidget {
  final String label;
  final double incomeHeight, expenseHeight;
  final bool isDark;
  final Color sub;

  const _BarGroup({
    required this.label,
    required this.incomeHeight,
    required this.expenseHeight,
    required this.isDark,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        margin: const EdgeInsets.only(right: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Bars side by side
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Income bar
                _Bar(height: incomeHeight, color: AppColors.income),
                const SizedBox(width: 3),
                // Expense bar
                _Bar(height: expenseHeight, color: AppColors.expense),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: sub,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}

class _Bar extends StatelessWidget {
  final double height;
  final Color color;
  const _Bar({required this.height, required this.color});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        width: 16,
        height: height < 4 ? 4 : height,
        decoration: BoxDecoration(
          color: height < 4 ? color.withValues(alpha: 0.2) : color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        ),
      );
}

class _BucketRow extends StatelessWidget {
  final _Bucket bucket;
  final double maxVal;
  final Color surfBg, tc, sub;
  final String Function(double) fmt;

  const _BucketRow({
    required this.bucket,
    required this.maxVal,
    required this.surfBg,
    required this.tc,
    required this.sub,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: surfBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                bucket.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Nunito',
                  color: tc,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  _MiniBar(
                    value: bucket.income,
                    max: maxVal,
                    color: AppColors.income,
                  ),
                  const SizedBox(height: 4),
                  _MiniBar(
                    value: bucket.expense,
                    max: maxVal,
                    color: AppColors.expense,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmt(bucket.income),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.income,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                  ),
                ),
                Text(
                  fmt(bucket.expense),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.expense,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _MiniBar extends StatelessWidget {
  final double value, max;
  final Color color;
  const _MiniBar({required this.value, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    final fraction = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return LayoutBuilder(
      builder: (_, c) => Container(
        height: 5,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction < 0.02 ? 0.02 : fraction,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final int rank;
  final String name, amount;
  final double pct;
  final Color color, surfBg, tc, sub;

  const _CategoryRow({
    required this.rank,
    required this.name,
    required this.amount,
    required this.pct,
    required this.color,
    required this.surfBg,
    required this.tc,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: surfBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: sub,
                      fontFamily: 'Nunito',
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final Color sub;
  const _EmptyState({required this.sub});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Text('📭', style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 14,
                color: sub,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}
