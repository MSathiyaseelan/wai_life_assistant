import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import '../../widgets/plan_widgets.dart';
import 'dart:convert';
import 'dart:io';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class BillWatchScreen extends StatefulWidget {
  final String walletId;
  final String walletName;
  final String walletEmoji;
  final List<PlanMember> members;
  final List<BillModel> bills;
  /// When embedded inside another Scaffold (e.g. wallet tab), pass the outer
  /// context so SnackBars are shown on the root Scaffold instead of the nested one.
  final BuildContext? hostContext;
  const BillWatchScreen({
    super.key,
    required this.walletId,
    this.walletName = 'Personal',
    this.walletEmoji = '👤',
    this.members = const [],
    required this.bills,
    this.hostContext,
  });
  @override
  State<BillWatchScreen> createState() => BillWatchScreenState();
}

class BillWatchScreenState extends State<BillWatchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  // Uses widget.bills — shared state from PlanItScreen
  BillCategory? _filterCat;

  // Use hostContext when embedded in another Scaffold to avoid nested-Scaffold SnackBar issues.
  BuildContext get _snackCtx => widget.hostContext ?? context;

  List<BillModel> get _mine =>
      widget.bills.where((b) => b.walletId == widget.walletId).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<BillModel> get _filtered {
    var list = _mine;
    if (_filterCat != null)
      list = list.where((b) => b.category == _filterCat).toList();
    return list;
  }

  List<BillModel> get _unpaid => _filtered.where((b) => !b.paid).toList();
  List<BillModel> get _paid => _filtered.where((b) => b.paid).toList();
  double get _totalDue => _unpaid.fold(0, (s, b) => s + b.amount);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _add(BillModel b) => setState(() => widget.bills.add(b));

  void _delete(BillModel b) =>
      setState(() => widget.bills.removeWhere((x) => x.id == b.id));

  void _replace(BillModel updated) {
    final i = widget.bills.indexWhere((b) => b.id == updated.id);
    if (i >= 0) widget.bills[i] = updated;
  }

  void _update(BillModel u) => setState(() => _replace(u));

  void _markPaid(BillModel b) {
    final payment = BillPayment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      paidOn: DateTime.now(),
      amount: b.amount,
    );
    final paid = b.copyWith(paid: true, history: [payment, ...b.history]);
    String? nextId;
    BillModel? nextBill;
    if (b.repeat != RepeatMode.none) {
      final exists = widget.bills.any(
        (x) => x.name == b.name && !x.paid && x.id != b.id,
      );
      if (!exists) {
        nextId = '${b.id}_${DateTime.now().millisecondsSinceEpoch}';
        nextBill = b.copyWith(
          paid: false,
          dueDate: _nextDue(b.dueDate, b.repeat),
          history: [],
        );
      }
    }
    setState(() {
      _replace(paid);
      if (nextBill != null) {
        widget.bills.add(
          BillModel(
            id: nextId!,
            name: nextBill.name,
            category: nextBill.category,
            amount: nextBill.amount,
            dueDate: nextBill.dueDate,
            repeat: nextBill.repeat,
            walletId: nextBill.walletId,
            provider: nextBill.provider,
            accountNumber: nextBill.accountNumber,
            note: nextBill.note,
            history: const [],
          ),
        );
      }
    });
    final sm = ScaffoldMessenger.of(_snackCtx);
    sm.clearSnackBars();
    sm.showSnackBar(
      SnackBar(
        content: Text(
          '✅ "${b.name}" marked as paid!',
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.income,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            sm.clearSnackBars();
            setState(() {
              _replace(b); // restore original unpaid bill
              if (nextId != null)
                widget.bills.removeWhere((x) => x.id == nextId);
            });
          },
        ),
      ),
    );
  }

  void _markUnpaid(BillModel b) {
    final unpaid = b.copyWith(
      paid: false,
      history: b.history.isNotEmpty ? b.history.skip(1).toList() : [],
    );
    setState(() => _replace(unpaid));
    final sm = ScaffoldMessenger.of(_snackCtx);
    sm.clearSnackBars();
    sm.showSnackBar(
      SnackBar(
        content: Text(
          '↩️ "${b.name}" moved back to pending',
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.lend,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  DateTime _nextDue(DateTime d, RepeatMode r) {
    switch (r) {
      case RepeatMode.daily:
        return d.add(const Duration(days: 1));
      case RepeatMode.weekly:
        return d.add(const Duration(days: 7));
      case RepeatMode.monthly:
        return DateTime(d.year, d.month + 1, d.day);
      case RepeatMode.yearly:
        return DateTime(d.year + 1, d.month, d.day);
      default:
        return d.add(const Duration(days: 30));
    }
  }

  DateTime _prevDue(DateTime d, RepeatMode r) {
    switch (r) {
      case RepeatMode.daily:
        return d.subtract(const Duration(days: 1));
      case RepeatMode.weekly:
        return d.subtract(const Duration(days: 7));
      case RepeatMode.monthly:
        return DateTime(d.year, d.month - 1, d.day);
      case RepeatMode.yearly:
        return DateTime(d.year - 1, d.month, d.day);
      default:
        return d.subtract(const Duration(days: 30));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;
    final overdue = _unpaid.where((b) => b.isOverdue).length;
    final dueSoon = _unpaid.where((b) => b.isDueSoon).length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            fontSize: 12,
          ),
          indicatorColor: AppColors.borrow,
          labelColor: AppColors.borrow,
          unselectedLabelColor: subColor,
          tabs: [
            Tab(text: 'Pending (${_unpaid.length})'),
            Tab(text: 'Paid (${_paid.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          _BillSummary(
            total: _totalDue,
            overdue: overdue,
            dueSoon: dueSoon,
            isDark: isDark,
            count: _unpaid.length,
          ),
          _CategoryFilter(
            selected: _filterCat,
            subColor: subColor,
            onSelect: (c) => setState(() => _filterCat = c),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _BillList(
                  key: ValueKey('unpaid-${_unpaid.length}'),
                  bills: _unpaid,
                  isDark: isDark,
                  isPaidTab: false,
                  onPay: _markPaid,
                  onDelete: _delete,
                  onTap: (b) => _openDetailSheet(context, b, isDark, surfBg),
                ),
                _BillList(
                  key: ValueKey('paid-${_paid.length}'),
                  bills: _paid,
                  isDark: isDark,
                  isPaidTab: true,
                  onPay: null,
                  onDelete: _delete,
                  onTap: (b) => _openDetailSheet(context, b, isDark, surfBg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void openAddSheet(BuildContext ctx, bool isDark, Color surfBg) =>
      showModalBottomSheet(
        context: ctx,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _BillSheetHost(
          isDark: isDark,
          surfBg: surfBg,
          walletId: widget.walletId,
          onSave: _add,
        ),
      );

  void _openDetailSheet(
    BuildContext ctx,
    BillModel b,
    bool isDark,
    Color surfBg,
  ) {
    showPlanSheet(
      ctx,
      child: _BillDetailSheet(
        bill: b,
        isDark: isDark,
        surfBg: surfBg,
        prevDue: _prevDue,
        onPay: b.paid
            ? null
            : () {
                _markPaid(b);
                Navigator.pop(ctx);
              },
        onUnpay: b.paid
            ? () {
                _markUnpaid(b);
                Navigator.pop(ctx);
              }
            : null,
        onEdit: () {
          Navigator.pop(ctx);
          _openEditSheet(ctx, b, isDark, surfBg);
        },
        onDelete: () {
          _delete(b);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _openEditSheet(
    BuildContext ctx,
    BillModel existing,
    bool isDark,
    Color surfBg,
  ) => showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _BillSheetHost(
      isDark: isDark,
      surfBg: surfBg,
      walletId: widget.walletId,
      existing: existing,
      onSave: _update,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY BAR
// ─────────────────────────────────────────────────────────────────────────────

class _BillSummary extends StatelessWidget {
  final double total;
  final int overdue, dueSoon, count;
  final bool isDark;
  const _BillSummary({
    required this.total,
    required this.overdue,
    required this.dueSoon,
    required this.isDark,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Container(
      color: cardBg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: sub,
                  ),
                ),
                Text(
                  '₹${_fmtAmt(total)}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'DM Mono',
                    color: AppColors.borrow,
                  ),
                ),
                Text(
                  '$count bill${count == 1 ? "" : "s"} pending',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                ),
              ],
            ),
          ),
          _SumChip(count: overdue, label: 'Overdue', color: AppColors.expense),
          const SizedBox(width: 8),
          _SumChip(count: dueSoon, label: 'Due Soon', color: AppColors.lend),
        ],
      ),
    );
  }
}

class _SumChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _SumChip({
    required this.count,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: 'DM Mono',
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY FILTER
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryFilter extends StatelessWidget {
  final BillCategory? selected;
  final Color subColor;
  final void Function(BillCategory?) onSelect;
  const _CategoryFilter({
    required this.selected,
    required this.subColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        children: [
          _Pill(
            label: '🧾 All',
            selected: selected == null,
            color: AppColors.borrow,
            onTap: () => onSelect(null),
          ),
          ...BillCategory.values.map(
            (c) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _Pill(
                label: '${c.emoji} ${c.label}',
                selected: selected == c,
                color: AppColors.borrow,
                onTap: () => onSelect(selected == c ? null : c),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Pill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color
                : (isDark ? AppColors.surfDark : const Color(0xFFE0E0EC)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
            color: selected
                ? color
                : (isDark ? AppColors.subDark : AppColors.subLight),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BILL LIST
// ─────────────────────────────────────────────────────────────────────────────

class _BillList extends StatelessWidget {
  final List<BillModel> bills;
  final bool isDark, isPaidTab;
  final void Function(BillModel)? onPay;
  final void Function(BillModel) onDelete;
  final void Function(BillModel) onTap;
  const _BillList({
    super.key,
    required this.bills,
    required this.isDark,
    required this.isPaidTab,
    this.onPay,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty)
      return PlanEmptyState(
        emoji: isPaidTab ? '✅' : '🎉',
        title: isPaidTab ? 'No paid bills' : 'All clear!',
        subtitle: isPaidTab ? 'Paid bills appear here' : 'No pending bills',
      );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: bills.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SwipeTile(
          onDelete: () => onDelete(bills[i]),
          child: _BillCard(
            bill: bills[i],
            isDark: isDark,
            onPay: onPay != null ? () => onPay!(bills[i]) : null,
            onTap: () => onTap(bills[i]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BILL CARD
// ─────────────────────────────────────────────────────────────────────────────

class _BillCard extends StatelessWidget {
  final BillModel bill;
  final bool isDark;
  final VoidCallback? onPay, onTap;
  const _BillCard({
    required this.bill,
    required this.isDark,
    this.onPay,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final statusColor = bill.paid
        ? AppColors.income
        : bill.isOverdue
        ? AppColors.expense
        : bill.isDueSoon
        ? AppColors.lend
        : AppColors.borrow;

    return GestureDetector(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        bill.category.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bill.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: tc,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _StatusBadge(
                                bill: bill,
                                statusColor: statusColor,
                              ),
                              const SizedBox(width: 6),
                              RepeatBadge(repeat: bill.repeat),
                            ],
                          ),
                          if (bill.provider != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              bill.provider!,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color: sub,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${_fmtAmt(bill.amount)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'DM Mono',
                            color: AppColors.borrow,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (onPay != null)
                          GestureDetector(
                            onTap: onPay,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.income.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.income.withOpacity(0.3),
                                ),
                              ),
                              child: const Text(
                                'Pay ✓',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Nunito',
                                  color: AppColors.income,
                                ),
                              ),
                            ),
                          ),
                        if (bill.paid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.income.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '✓ Paid',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: AppColors.income,
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

class _StatusBadge extends StatelessWidget {
  final BillModel bill;
  final Color statusColor;
  const _StatusBadge({required this.bill, required this.statusColor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: statusColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      bill.paid
          ? '✓ Paid'
          : bill.isOverdue
          ? '⚠ Overdue'
          : bill.isDueSoon
          ? '⏰ Due Soon'
          : daysUntil(bill.dueDate),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        fontFamily: 'Nunito',
        color: statusColor,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _BillDetailSheet extends StatefulWidget {
  final BillModel bill;
  final bool isDark;
  final Color surfBg;
  final DateTime Function(DateTime, RepeatMode) prevDue;
  final VoidCallback? onPay, onUnpay;
  final VoidCallback onEdit, onDelete;
  const _BillDetailSheet({
    required this.bill,
    required this.isDark,
    required this.surfBg,
    required this.prevDue,
    this.onPay,
    this.onUnpay,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  State<_BillDetailSheet> createState() => _BillDetailSheetState();
}

class _BillDetailSheetState extends State<_BillDetailSheet> {
  bool _showAll = false;

  List<BillPayment> _buildHistory(BillModel b) {
    // Real history first
    if (b.history.isNotEmpty) return b.history;
    // For repeating bills with no recorded history yet, simulate past occurrences
    if (b.repeat == RepeatMode.none) return [];
    final sim = <BillPayment>[];
    DateTime date = b.dueDate;
    for (int i = 0; i < 5; i++) {
      date = widget.prevDue(date, b.repeat);
      if (date.isAfter(DateTime.now())) continue;
      sim.add(BillPayment(id: 'sim_$i', paidOn: date, amount: b.amount));
    }
    return sim;
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;
    final statusColor = b.paid
        ? AppColors.income
        : b.isOverdue
        ? AppColors.expense
        : b.isDueSoon
        ? AppColors.lend
        : AppColors.borrow;
    final history = _buildHistory(b);
    final display = _showAll ? history : history.take(4).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  b.category.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.name,
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
                        _StatusBadge(bill: b, statusColor: statusColor),
                        const SizedBox(width: 6),
                        RepeatBadge(repeat: b.repeat),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '₹${_fmtAmt(b.amount)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'DM Mono',
                  color: AppColors.borrow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Info tiles
          _InfoTile(
            icon: Icons.calendar_today_rounded,
            color: statusColor,
            label: 'Due Date',
            value: '${fmtDate(b.dueDate)} · ${daysUntil(b.dueDate)}',
          ),
          if (b.repeat != RepeatMode.none)
            _InfoTile(
              icon: Icons.repeat_rounded,
              color: AppColors.borrow,
              label: 'Repeats',
              value: b.repeat.label,
            ),
          if (b.provider != null)
            _InfoTile(
              icon: Icons.business_rounded,
              color: AppColors.split,
              label: 'Provider',
              value: b.provider!,
            ),
          if (b.accountNumber != null)
            _InfoTile(
              icon: Icons.numbers_rounded,
              color: AppColors.split,
              label: 'Account',
              value: b.accountNumber!,
            ),
          if (b.note != null && b.note!.isNotEmpty)
            _InfoTile(
              icon: Icons.notes_rounded,
              color: sub,
              label: 'Note',
              value: b.note!,
            ),
          const SizedBox(height: 12),

          // Payment / transaction history
          if (history.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Payment History',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.income.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${history.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: AppColors.income,
                    ),
                  ),
                ),
                const Spacer(),
                if (history.length > 4)
                  GestureDetector(
                    onTap: () => setState(() => _showAll = !_showAll),
                    child: Text(
                      _showAll ? 'Show less' : 'See all ${history.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: AppColors.borrow,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...display.map(
              (h) => _HistoryRow(payment: h, isDark: widget.isDark),
            ),
            const SizedBox(height: 12),
          ],

          // Repeat auto-renewal notice
          if (b.paid && b.repeat != RepeatMode.none) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.borrow.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borrow.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: AppColors.borrow,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Next recurring payment auto-added to Pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: AppColors.borrow,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: b.paid ? widget.onUnpay : widget.onPay,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: b.paid
                            ? [AppColors.lend, const Color(0xFFE8921C)]
                            : [AppColors.income, const Color(0xFF009E76)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          b.paid ? '↩️' : '✅',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          b.paid ? 'Move to Pending' : 'Mark as Paid',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
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
          GestureDetector(
            onTap: widget.onDelete,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.expense.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.expense.withOpacity(0.3)),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Delete Bill',
                style: TextStyle(
                  color: AppColors.expense,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final BillPayment payment;
  final bool isDark;
  const _HistoryRow({required this.payment, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final isSim = payment.id.startsWith('sim_');
    final color = isSim ? AppColors.borrow : AppColors.income;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isSim ? Icons.history_rounded : Icons.check_circle_rounded,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${_fmtAmt(payment.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'DM Mono',
                    color: color,
                  ),
                ),
                Text(
                  isSim ? 'Estimated recurring' : 'Paid',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                ),
              ],
            ),
          ),
          Text(
            fmtDate(payment.paidOn),
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Nunito',
              color: sub,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _InfoTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Nunito',
                  color: sub,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Nunito',
                  color: tc,
                  fontWeight: FontWeight.w700,
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
// SHEET HOST
// ─────────────────────────────────────────────────────────────────────────────

class _BillSheetHost extends StatelessWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final BillModel? existing;
  final void Function(BillModel) onSave;
  const _BillSheetHost({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    this.existing,
    required this.onSave,
  });

  @override
  Widget build(BuildContext hostCtx) {
    final isEdit = existing != null;
    final mq = MediaQuery.of(hostCtx);
    final kb = mq.viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Flexible(
              child: _AddBillSheet(
                isDark: isDark,
                surfBg: surfBg,
                walletId: walletId,
                existing: existing,
                onSave: (b) {
                  Navigator.pop(hostCtx);
                  onSave(b);
                  ScaffoldMessenger.of(hostCtx).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? '🧾 "${b.name}" updated!'
                            : '🧾 "${b.name}" added!',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: AppColors.borrow,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD / EDIT SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _AddBillSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final BillModel? existing;
  final void Function(BillModel) onSave;
  const _AddBillSheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    this.existing,
    required this.onSave,
  });
  @override
  State<_AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends State<_AddBillSheet>
    with SingleTickerProviderStateMixin {
  late TabController _mode;
  final _aiCtrl = TextEditingController();
  bool _aiParsing = false;
  _ParsedBill? _aiPreview;
  String? _aiError;
  bool _usingClaude = false;

  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _provCtrl = TextEditingController();
  final _accCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  BillCategory _cat = BillCategory.electricity;
  RepeatMode _repeat = RepeatMode.monthly;
  DateTime _due = DateTime.now().add(const Duration(days: 7));
  bool _nameError = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _mode = TabController(
      length: 2,
      vsync: this,
      initialIndex: e != null ? 1 : 0,
    );
    _mode.addListener(() => setState(() {}));
    if (e != null) {
      _nameCtrl.text = e.name;
      _amountCtrl.text = e.amount.toStringAsFixed(0);
      _provCtrl.text = e.provider ?? '';
      _accCtrl.text = e.accountNumber ?? '';
      _noteCtrl.text = e.note ?? '';
      _cat = e.category;
      _repeat = e.repeat;
      _due = e.dueDate;
    }
  }

  @override
  void dispose() {
    _mode.dispose();
    _aiCtrl.dispose();
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _provCtrl.dispose();
    _accCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _parseAI(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _aiParsing = true;
      _aiError = null;
      _aiPreview = null;
      _usingClaude = false;
    });
    _ParsedBill? result;
    try {
      result = await _BillClaudeParser.parse(text.trim());
      _usingClaude = true;
    } catch (_) {
      result = _BillNlpParser.parse(text.trim());
    }
    if (!mounted) return;
    setState(() {
      _aiParsing = false;
      _aiPreview = result;
      _nameCtrl.text = result!.name;
      _amountCtrl.text = result.amount > 0
          ? result.amount.toStringAsFixed(0)
          : '';
      _provCtrl.text = result.provider ?? '';
      _cat = result.category;
      _repeat = result.repeat;
      _due = result.dueDate;
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (name.isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    if (amount == null || amount <= 0) return;
    setState(() => _nameError = false);
    final e = widget.existing;
    widget.onSave(
      BillModel(
        id: e?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        category: _cat,
        amount: amount,
        dueDate: _due,
        repeat: _repeat,
        walletId: widget.walletId,
        paid: e?.paid ?? false,
        provider: _provCtrl.text.trim().isEmpty ? null : _provCtrl.text.trim(),
        accountNumber: _accCtrl.text.trim().isEmpty
            ? null
            : _accCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        history: e?.history ?? [],
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
        Row(
          children: [
            const Text('🧾', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(
              widget.existing != null ? 'Edit Bill' : 'New Bill',
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
                colors: [AppColors.borrow, Color(0xFF00A0D0)],
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

        if (_mode.index == 0) ...[
          _AiHint(isDark: widget.isDark),
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
              usedClaude: _usingClaude,
              onEdit: () => _mode.animateTo(1),
            ),
            const SizedBox(height: 16),
            SaveButton(
              label: widget.existing != null ? 'Update Bill →' : 'Save Bill →',
              color: AppColors.borrow,
              onTap: _save,
            ),
          ],
          if (_aiPreview == null && !_aiParsing) ...[
            const SizedBox(height: 12),
            _AiExamples(
              surfBg: widget.surfBg,
              sub: sub,
              onTap: (s) {
                _aiCtrl.text = s;
                _parseAI(s);
              },
            ),
          ],
        ],

        if (_mode.index == 1) ...[
          _ManualForm(
            isDark: widget.isDark,
            surfBg: widget.surfBg,
            nameCtrl: _nameCtrl,
            amountCtrl: _amountCtrl,
            provCtrl: _provCtrl,
            accCtrl: _accCtrl,
            noteCtrl: _noteCtrl,
            cat: _cat,
            repeat: _repeat,
            due: _due,
            nameError: _nameError,
            onCatChanged: (c) => setState(() => _cat = c),
            onRepeatChanged: (r) => setState(() => _repeat = r),
            onDueChanged: (d) => setState(() => _due = d),
          ),
          const SizedBox(height: 16),
          SaveButton(
            label: widget.existing != null ? 'Update Bill →' : 'Save Bill →',
            color: AppColors.borrow,
            onTap: _save,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MANUAL FORM
// ─────────────────────────────────────────────────────────────────────────────

class _ManualForm extends StatelessWidget {
  final bool isDark;
  final Color surfBg;
  final TextEditingController nameCtrl, amountCtrl, provCtrl, accCtrl, noteCtrl;
  final BillCategory cat;
  final RepeatMode repeat;
  final DateTime due;
  final bool nameError;
  final void Function(BillCategory) onCatChanged;
  final void Function(RepeatMode) onRepeatChanged;
  final void Function(DateTime) onDueChanged;

  const _ManualForm({
    required this.isDark,
    required this.surfBg,
    required this.nameCtrl,
    required this.amountCtrl,
    required this.provCtrl,
    required this.accCtrl,
    required this.noteCtrl,
    required this.cat,
    required this.repeat,
    required this.due,
    required this.nameError,
    required this.onCatChanged,
    required this.onRepeatChanged,
    required this.onDueChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetLabel(text: 'CATEGORY'),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: BillCategory.values
                .map(
                  (c) => GestureDetector(
                    onTap: () => onCatChanged(c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cat == c
                            ? AppColors.borrow.withOpacity(0.15)
                            : surfBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: cat == c
                              ? AppColors.borrow
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '${c.emoji} ${c.label}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: cat == c ? AppColors.borrow : sub,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: surfBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: nameError ? AppColors.expense : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
                decoration: InputDecoration.collapsed(
                  hintText: 'Bill name *',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Nunito',
                    color: nameError ? AppColors.expense : sub,
                  ),
                ),
              ),
              if (nameError) ...[
                const SizedBox(height: 4),
                const Text(
                  'Name is required',
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
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: surfBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Text(
                      '₹',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.borrow,
                        fontFamily: 'DM Mono',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: tc,
                          fontFamily: 'Nunito',
                        ),
                        decoration: InputDecoration.collapsed(
                          hintText: 'Amount *',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: sub,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: surfBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: TextField(
                  controller: provCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    fontSize: 14,
                    color: tc,
                    fontFamily: 'Nunito',
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: 'Provider',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: sub,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PlanInputField(
          controller: accCtrl,
          hint: 'Account / reference (optional)',
        ),
        const SizedBox(height: 8),
        PlanInputField(
          controller: noteCtrl,
          hint: 'Note (optional)',
          maxLines: 2,
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetLabel(text: 'DUE DATE'),
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: due,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 30),
                        ),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                      );
                      if (d != null) onDueChanged(d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: surfBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 15,
                            color: AppColors.borrow,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            fmtDateShort(due),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: AppColors.borrow,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetLabel(text: 'REPEAT'),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: surfBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButton<RepeatMode>(
                      value: repeat,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                      items: RepeatMode.values
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.label),
                            ),
                          )
                          .toList(),
                      onChanged: (r) => onRepeatChanged(r!),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _AiHint extends StatelessWidget {
  final bool isDark;
  const _AiHint({required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.borrow.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.borrow.withOpacity(0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('✨', style: TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Describe your bill — Claude AI extracts name, amount, category, due date and repeat.',
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
        border: Border.all(color: AppColors.borrow.withOpacity(0.3)),
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
                    '"BESCOM electricity ₹1850 due 15th monthly" or "LIC premium ₹12500 yearly"',
                hintStyle: TextStyle(
                  fontSize: 12,
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
            color: AppColors.borrow.withOpacity(0.15),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Plain text → Claude fills all fields',
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
                              colors: [AppColors.borrow, Color(0xFF00A0D0)],
                            ),
                      color: isParsing
                          ? AppColors.borrow.withOpacity(0.3)
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
  final _ParsedBill preview;
  final bool isDark, usedClaude;
  final Color surfBg;
  final VoidCallback onEdit;
  const _AiPreviewCard({
    required this.preview,
    required this.isDark,
    required this.surfBg,
    required this.usedClaude,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
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
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.borrow.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  preview.category.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.name,
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
                        usedClaude ? '🤖 Claude AI Parsed' : '✨ AI Parsed',
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(
                label: '${preview.category.emoji} ${preview.category.label}',
                color: AppColors.borrow,
              ),
              if (preview.amount > 0)
                _Chip(
                  label: '₹${_fmtAmt(preview.amount)}',
                  color: AppColors.income,
                ),
              _Chip(
                label: '📅 ${fmtDateShort(preview.dueDate)}',
                color: AppColors.primary,
              ),
              if (preview.repeat != RepeatMode.none)
                _Chip(
                  label: '🔁 ${preview.repeat.label}',
                  color: AppColors.split,
                ),
              if (preview.provider != null)
                _Chip(label: '🏢 ${preview.provider!}', color: AppColors.lend),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
          color: color,
        ),
      ),
    );
  }
}

class _AiExamples extends StatelessWidget {
  final Color surfBg, sub;
  final void Function(String) onTap;
  const _AiExamples({
    required this.surfBg,
    required this.sub,
    required this.onTap,
  });
  static const _examples = [
    'BESCOM electricity ₹1850 due 15th every month',
    'LIC premium ₹12500 due March 20 yearly',
    'Airtel broadband ₹999 monthly due on 5th',
    'School fees ₹8500 due April 10',
    'Netflix subscription ₹649 monthly',
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
              border: Border.all(color: AppColors.borrow.withOpacity(0.15)),
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
                  color: AppColors.borrow.withOpacity(0.5),
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
// PARSERS
// ─────────────────────────────────────────────────────────────────────────────

class _ParsedBill {
  final String name;
  final BillCategory category;
  final double amount;
  final DateTime dueDate;
  final RepeatMode repeat;
  final String? provider;
  const _ParsedBill({
    required this.name,
    required this.category,
    required this.amount,
    required this.dueDate,
    required this.repeat,
    this.provider,
  });
}

class _BillClaudeParser {
  static const _apiKey = 'YOUR_ANTHROPIC_API_KEY';
  static Future<_ParsedBill> parse(String text) async {
    if (_apiKey == 'YOUR_ANTHROPIC_API_KEY') throw Exception('No API key');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prompt =
        'Extract bill details from: "$text"\nToday: $today\n'
        'Return ONLY JSON: {"name":"","category":"electricity|water|gas|internet|phone|insurance|school|rent|subscription|medical|emi|other",'
        '"amount":0,"dueDate":"YYYY-MM-DD","repeat":"none|daily|weekly|monthly|yearly","provider":null}\n'
        'Rules: amount=number only, dueDate=next occurrence of the day mentioned, '
        'repeat=monthly for utilities/subscriptions yearly for insurance, provider=company name or null';
    final client = HttpClient();
    try {
      final req = await client.postUrl(
        Uri.parse('https://api.anthropic.com/v1/messages'),
      );
      req.headers
        ..set('x-api-key', _apiKey)
        ..set('anthropic-version', '2023-06-01')
        ..set('content-type', 'application/json');
      req.add(
        utf8.encode(
          jsonEncode({
            'model': 'claude-haiku-4-5-20251001',
            'max_tokens': 300,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
          }),
        ),
      );
      final res = await req.close().timeout(const Duration(seconds: 8));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw Exception('${res.statusCode}');
      final decoded = jsonDecode(body);
      final raw = (decoded['content'] as List).first['text'] as String;
      final data =
          jsonDecode(
                raw
                    .replaceAll(RegExp(r'```json\s*'), '')
                    .replaceAll('```', '')
                    .trim(),
              )
              as Map<String, dynamic>;
      DateTime due = DateTime.now().add(const Duration(days: 7));
      try {
        if (data['dueDate'] != null) due = DateTime.parse(data['dueDate']);
      } catch (_) {}
      const cm = {
        'electricity': BillCategory.electricity,
        'water': BillCategory.water,
        'gas': BillCategory.gas,
        'internet': BillCategory.internet,
        'phone': BillCategory.phone,
        'insurance': BillCategory.insurance,
        'school': BillCategory.school,
        'rent': BillCategory.rent,
        'subscription': BillCategory.subscription,
        'medical': BillCategory.medical,
        'emi': BillCategory.emi,
        'other': BillCategory.other,
      };
      const rm = {
        'none': RepeatMode.none,
        'daily': RepeatMode.daily,
        'weekly': RepeatMode.weekly,
        'monthly': RepeatMode.monthly,
        'yearly': RepeatMode.yearly,
      };
      return _ParsedBill(
        name: data['name'] as String,
        category: cm[data['category']] ?? BillCategory.other,
        amount: (data['amount'] as num?)?.toDouble() ?? 0,
        dueDate: due,
        repeat: rm[data['repeat']] ?? RepeatMode.monthly,
        provider: data['provider'] as String?,
      );
    } finally {
      client.close();
    }
  }
}

class _BillNlpParser {
  static _ParsedBill parse(String raw) {
    final lower = raw.toLowerCase();
    final now = DateTime.now();
    BillCategory cat = BillCategory.other;
    if (lower.contains('electric') ||
        lower.contains('bescom') ||
        lower.contains('tneb') ||
        lower.contains('power'))
      cat = BillCategory.electricity;
    else if (lower.contains('water') || lower.contains('bwssb'))
      cat = BillCategory.water;
    else if (lower.contains('gas') ||
        lower.contains('lpg') ||
        lower.contains('indane'))
      cat = BillCategory.gas;
    else if (lower.contains('internet') ||
        lower.contains('broadband') ||
        lower.contains('wifi') ||
        lower.contains('fiber'))
      cat = BillCategory.internet;
    else if (lower.contains('phone') ||
        lower.contains('mobile') ||
        lower.contains('recharge') ||
        lower.contains('airtel') ||
        lower.contains('jio'))
      cat = BillCategory.phone;
    else if (lower.contains('lic') ||
        lower.contains('insurance') ||
        lower.contains('premium'))
      cat = BillCategory.insurance;
    else if (lower.contains('school') ||
        lower.contains('tuition') ||
        lower.contains('fees'))
      cat = BillCategory.school;
    else if (lower.contains('rent') ||
        lower.contains('house') ||
        lower.contains('apartment'))
      cat = BillCategory.rent;
    else if (lower.contains('netflix') ||
        lower.contains('spotify') ||
        lower.contains('subscription'))
      cat = BillCategory.subscription;
    else if (lower.contains('emi') || lower.contains('loan'))
      cat = BillCategory.emi;

    RepeatMode repeat = RepeatMode.monthly;
    if (lower.contains('yearly') || lower.contains('annual'))
      repeat = RepeatMode.yearly;
    else if (lower.contains('weekly'))
      repeat = RepeatMode.weekly;
    else if (lower.contains('daily'))
      repeat = RepeatMode.daily;
    else if (lower.contains('once') || lower.contains('one time'))
      repeat = RepeatMode.none;

    double amount = 0;
    final am = RegExp(
      r'[₹rs\.]*\s*(\d[\d,]*)(?:\s*k)?',
      caseSensitive: false,
    ).firstMatch(raw);
    if (am != null) {
      amount = double.tryParse(am.group(1)!.replaceAll(',', '')) ?? 0;
      if (raw.toLowerCase().contains('k') && amount < 1000) amount *= 1000;
    }

    DateTime dueDate = now.add(const Duration(days: 7));
    final dm = RegExp(
      r'(?:due|on|by)\s*(?:the\s*)?(\d{1,2})(?:st|nd|rd|th)?',
    ).firstMatch(lower);
    if (dm != null) {
      final day = int.tryParse(dm.group(1)!) ?? 7;
      dueDate = DateTime(now.year, now.month, day);
      if (dueDate.isBefore(now))
        dueDate = DateTime(now.year, now.month + 1, day);
    }

    String? provider;
    for (final p in [
      'bescom',
      'lic',
      'airtel',
      'jio',
      'bsnl',
      'netflix',
      'spotify',
      'bwssb',
      'tneb',
    ]) {
      if (lower.contains(p)) {
        provider = p.toUpperCase();
        break;
      }
    }

    String name = raw
        .trim()
        .replaceAll(
          RegExp(r'[₹rs\.]*\s*[\d,]+(?:\s*k)?', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            r'\b(due|on|by|every|monthly|yearly|weekly|daily)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\d{1,2}(?:st|nd|rd|th)?'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    if (name.isEmpty) name = raw.trim();
    if (name.isNotEmpty) name = name[0].toUpperCase() + name.substring(1);

    return _ParsedBill(
      name: name,
      category: cat,
      amount: amount,
      dueDate: dueDate,
      repeat: repeat,
      provider: provider,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _fmtAmt(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}
