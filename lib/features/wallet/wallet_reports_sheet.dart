import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import 'package:wai_life_assistant/core/utils/amount_format.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WALLET REPORTS SHEET
// Daily / Weekly / Monthly / Yearly / Category breakdown
// ─────────────────────────────────────────────────────────────────────────────

class WalletReportsSheet extends StatefulWidget {
  final List<TxModel> transactions;
  final WalletModel wallet;
  /// userId → 'emoji name' — non-null only for family wallets
  final Map<String, String> memberNames;

  const WalletReportsSheet({
    super.key,
    required this.transactions,
    required this.wallet,
    this.memberNames = const {},
  });

  static Future<void> show(
    BuildContext context, {
    required List<TxModel> transactions,
    required WalletModel wallet,
    Map<String, String> memberNames = const {},
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WalletReportsSheet(
        transactions: transactions,
        wallet: wallet,
        memberNames: memberNames,
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

  IconData get icon {
    switch (this) {
      case _Period.daily:    return Icons.today_rounded;
      case _Period.weekly:   return Icons.view_week_rounded;
      case _Period.monthly:  return Icons.calendar_month_rounded;
      case _Period.yearly:   return Icons.bar_chart_rounded;
      case _Period.category: return Icons.donut_small_rounded;
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

// ── Category emoji helper ─────────────────────────────────────────────────────

String _catEmoji(String cat) {
  final c = cat.toLowerCase();
  if (c.contains('food') || c.contains('eat') || c.contains('restaurant') ||
      c.contains('groceri') || c.contains('snack') || c.contains('meal')) { return '🍽️'; }
  if (c.contains('transport') || c.contains('travel') || c.contains('fuel') ||
      c.contains('petrol') || c.contains('cab') || c.contains('uber') ||
      c.contains('auto') || c.contains('vehicle')) { return '🚗'; }
  if (c.contains('shop') || c.contains('purchase') || c.contains('buy') ||
      c.contains('order') || c.contains('amazon') || c.contains('flipkart')) { return '🛍️'; }
  if (c.contains('entertain') || c.contains('movie') || c.contains('fun') ||
      c.contains('game') || c.contains('sport') || c.contains('netflix') ||
      c.contains('subscri')) { return '🎬'; }
  if (c.contains('health') || c.contains('medical') || c.contains('medicine') ||
      c.contains('doctor') || c.contains('hospital') || c.contains('pharmacy')) { return '💊'; }
  if (c.contains('utilit') || c.contains('bill') || c.contains('electric') ||
      c.contains('water') || c.contains('gas') || c.contains('internet') ||
      c.contains('phone') || c.contains('mobile')) { return '💡'; }
  if (c.contains('educat') || c.contains('school') || c.contains('college') ||
      c.contains('course') || c.contains('book') || c.contains('fee')) { return '📚'; }
  if (c.contains('salary') || c.contains('income') || c.contains('wage') ||
      c.contains('earning') || c.contains('bonus')) { return '💼'; }
  if (c.contains('rent') || c.contains('hous') || c.contains('home') ||
      c.contains('property') || c.contains('mortgage')) { return '🏠'; }
  if (c.contains('cloth') || c.contains('fashion') || c.contains('wear') ||
      c.contains('dress') || c.contains('shoes')) { return '👗'; }
  if (c.contains('invest') || c.contains('mutual') || c.contains('stock') ||
      c.contains('sip') || c.contains('saving')) { return '📈'; }
  if (c.contains('gift') || c.contains('present') || c.contains('donation')) { return '🎁'; }
  return '📦';
}

// ─────────────────────────────────────────────────────────────────────────────

class _WalletReportsSheetState extends State<WalletReportsSheet> {
  _Period _period = _Period.monthly;
  bool _catExpense = true;
  String? _memberFilter; // null = all members

  List<TxModel> get _filtered => _memberFilter == null
      ? widget.transactions
      : widget.transactions.where((t) => t.userId == _memberFilter).toList();

  List<TxModel> get _ie => _filtered
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

  List<MapEntry<String, double>> _categoryData() {
    final target = _catExpense ? TxType.expense : TxType.income;
    final map = <String, double>{};
    for (final t in _filtered) {
      if (t.type == target) {
        map[t.category] = (map[t.category] ?? 0) + t.amount;
      }
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  ({double income, double expense, double net}) _totals(List<_Bucket> buckets) {
    final inc = buckets.fold(0.0, (s, b) => s + b.income);
    final exp = buckets.fold(0.0, (s, b) => s + b.expense);
    return (income: inc, expense: exp, net: inc - exp);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(double v) {
    final cs = AppPrefs.cs;
    final large = formatLargeAmount(v);
    if (large != null) return '$cs$large';
    if (v >= 1000) return '$cs${(v / 1000).toStringAsFixed(1)}K';
    return '$cs${v.toStringAsFixed(0)}';
  }

  String _dayLabel(DateTime d, bool isToday) {
    if (isToday) return 'Today';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
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

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final accentColor = widget.wallet.gradient[0];

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
            // ── Gradient hero header ──────────────────────────────────────
            _HeroHeader(wallet: widget.wallet, txCount: widget.transactions.length),

            // ── Period tabs ───────────────────────────────────────────────
            _PeriodTabBar(
              selected: _period,
              accentColor: accentColor,
              surfBg: surfBg,
              sub: sub,
              onSelect: (p) => setState(() => _period = p),
            ),

            // ── Member filter strip (family wallets only) ─────────────────
            if (widget.memberNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              _MemberFilterStrip(
                members: widget.memberNames,
                selected: _memberFilter,
                accentColor: accentColor,
                surfBg: surfBg,
                sub: sub,
                onSelect: (uid) => setState(() =>
                    _memberFilter = _memberFilter == uid ? null : uid),
              ),
            ],
            const SizedBox(height: 4),

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
                      accentColor: accentColor,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO HEADER — gradient banner with wallet info
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final WalletModel wallet;
  final int txCount;
  const _HeroHeader({required this.wallet, required this.txCount});

  @override
  Widget build(BuildContext context) {
    final emoji = wallet.emoji.startsWith('http') || wallet.emoji.isEmpty
        ? (wallet.isPersonal ? '👤' : '👨‍👩‍👧')
        : wallet.emoji;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: wallet.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    Text(
                      '$txCount transactions',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
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
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 17,
                    color: Colors.white,
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

// ─────────────────────────────────────────────────────────────────────────────
// PERIOD TAB BAR — icon + label pill tabs
// ─────────────────────────────────────────────────────────────────────────────

class _PeriodTabBar extends StatelessWidget {
  final _Period selected;
  final Color accentColor, surfBg, sub;
  final void Function(_Period) onSelect;
  const _PeriodTabBar({
    required this.selected,
    required this.accentColor,
    required this.surfBg,
    required this.sub,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          children: _Period.values.map((p) {
            final active = selected == p;
            return GestureDetector(
              onTap: () => onSelect(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? accentColor
                      : surfBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      p.icon,
                      size: 13,
                      color: active ? Colors.white : sub,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: active ? Colors.white : sub,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ── Stats row: income + expense cards ────────────────────────────
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Income',
                amount: fmt(totals.income),
                color: AppColors.income,
                icon: Icons.arrow_downward_rounded,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Expense',
                amount: fmt(totals.expense),
                color: AppColors.expense,
                icon: Icons.arrow_upward_rounded,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ── Net flow full-width banner ────────────────────────────────────
        _NetFlowBanner(net: totals.net, fmt: fmt, isDark: isDark),
        const SizedBox(height: 20),

        // ── Legend ───────────────────────────────────────────────────────
        if (hasData) ...[
          Row(
            children: [
              _Legend(color: AppColors.income, label: 'Income'),
              const SizedBox(width: 16),
              _Legend(color: AppColors.expense, label: 'Expense'),
            ],
          ),
          const SizedBox(height: 12),

          // ── Bar chart ─────────────────────────────────────────────────
          SizedBox(
            height: 220,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: buckets.map((b) {
                  final incH = maxVal > 0 ? (b.income / maxVal) * 160 : 0.0;
                  final expH = maxVal > 0 ? (b.expense / maxVal) * 160 : 0.0;
                  return _BarGroup(
                    label: b.label,
                    incomeHeight: incH,
                    expenseHeight: expH,
                    incomeVal: b.income,
                    expenseVal: b.expense,
                    sub: sub,
                    fmt: fmt,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Breakdown list ────────────────────────────────────────────────
        if (hasData) ...[
          Row(
            children: [
              Text(
                'BREAKDOWN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito',
                  color: sub,
                  letterSpacing: 1.0,
                ),
              ),
            ],
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

        if (!hasData) _EmptyState(sub: sub),
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
  final Color surfBg, tc, sub, accentColor;
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
    required this.accentColor,
    required this.fmt,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final total = data.fold(0.0, (s, e) => s + e.value);
    final barColor = isExpense ? AppColors.expense : AppColors.income;

    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ── Toggle ───────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: surfBg,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: _ToggleChip(
                  label: 'Expenses',
                  icon: Icons.arrow_upward_rounded,
                  active: isExpense,
                  color: AppColors.expense,
                  onTap: () => onToggle(true),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _ToggleChip(
                  label: 'Income',
                  icon: Icons.arrow_downward_rounded,
                  active: !isExpense,
                  color: AppColors.income,
                  onTap: () => onToggle(false),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (data.isEmpty)
          _EmptyState(sub: sub)
        else ...[
          // ── Summary header ───────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${data.length} ${isExpense ? 'expense' : 'income'} categories',
                style: TextStyle(
                  fontSize: 12,
                  color: sub,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fmt(total),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: barColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

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
// REDESIGNED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, amount;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _NetFlowBanner extends StatelessWidget {
  final double net;
  final String Function(double) fmt;
  final bool isDark;
  const _NetFlowBanner({required this.net, required this.fmt, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final positive = net >= 0;
    final color = positive ? AppColors.income : AppColors.expense;
    final icon = positive ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    final label = positive ? 'Net Surplus' : 'Net Deficit';
    final prefix = positive ? '+' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: isDark ? 0.18 : 0.1),
            color.withValues(alpha: isDark ? 0.08 : 0.04),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const Spacer(),
          Text(
            '$prefix${fmt(net.abs())}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
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
  final double incomeHeight, expenseHeight, incomeVal, expenseVal;
  final Color sub;
  final String Function(double) fmt;

  const _BarGroup({
    required this.label,
    required this.incomeHeight,
    required this.expenseHeight,
    required this.incomeVal,
    required this.expenseVal,
    required this.sub,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: 68,
        margin: const EdgeInsets.only(right: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _GradientBar(
                  height: incomeHeight,
                  value: incomeVal,
                  color: AppColors.income,
                  fmt: fmt,
                ),
                const SizedBox(width: 4),
                _GradientBar(
                  height: expenseHeight,
                  value: expenseVal,
                  color: AppColors.expense,
                  fmt: fmt,
                ),
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

class _GradientBar extends StatelessWidget {
  final double height, value;
  final Color color;
  final String Function(double) fmt;
  const _GradientBar({required this.height, required this.value, required this.color, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final h = height < 4 ? 4.0 : height;
    final showLabel = height > 40 && value > 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showLabel)
          Text(
            fmt(value),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              fontFamily: 'Nunito',
              color: color,
            ),
          ),
        if (showLabel) const SizedBox(height: 2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          width: 22,
          height: h,
          decoration: BoxDecoration(
            gradient: height < 4
                ? null
                : LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      color.withValues(alpha: 0.5),
                      color,
                    ],
                  ),
            color: height < 4 ? color.withValues(alpha: 0.15) : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
          ),
        ),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    final positive = bucket.net >= 0;
    final netColor = positive ? AppColors.income : AppColors.expense;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              bucket.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                _MiniBar(value: bucket.income, max: maxVal, color: AppColors.income),
                const SizedBox(height: 5),
                _MiniBar(value: bucket.expense, max: maxVal, color: AppColors.expense),
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
          const SizedBox(width: 8),
          // Net indicator pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: netColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${positive ? '+' : '-'}${fmt(bucket.net.abs())}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: netColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
        height: 6,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction < 0.02 ? 0.02 : fraction,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.6), color],
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surfBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Category emoji avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _catEmoji(name),
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '#$rank',
                        style: TextStyle(
                          fontSize: 10,
                          color: sub,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Amount
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                // % pill badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Gradient progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Container(
                height: 7,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: pct.clamp(0.01, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.6), color],
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: active ? Colors.white : color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Nunito',
                  color: active ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MEMBER FILTER STRIP — horizontal participant chips (family wallets only)
// ─────────────────────────────────────────────────────────────────────────────

class _MemberFilterStrip extends StatelessWidget {
  final Map<String, String> members;
  final String? selected;
  final Color accentColor, surfBg, sub;
  final void Function(String uid) onSelect;

  const _MemberFilterStrip({
    required this.members,
    required this.selected,
    required this.accentColor,
    required this.surfBg,
    required this.sub,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // "All" chip
            _MemberChip(
              label: '👥 All',
              active: selected == null,
              accentColor: accentColor,
              surfBg: surfBg,
              sub: sub,
              onTap: () {
                if (selected != null) onSelect(selected!);
              },
            ),
            ...members.entries.map(
              (e) => _MemberChip(
                label: e.value,
                active: selected == e.key,
                accentColor: accentColor,
                surfBg: surfBg,
                sub: sub,
                onTap: () => onSelect(e.key),
              ),
            ),
          ],
        ),
      );
}

class _MemberChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color accentColor, surfBg, sub;
  final VoidCallback onTap;

  const _MemberChip({
    required this.label,
    required this.active,
    required this.accentColor,
    required this.surfBg,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: active ? accentColor : surfBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: active
                ? [BoxShadow(color: accentColor.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
              color: active ? Colors.white : sub,
            ),
          ),
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
            const Text('📭', style: TextStyle(fontSize: 40)),
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
