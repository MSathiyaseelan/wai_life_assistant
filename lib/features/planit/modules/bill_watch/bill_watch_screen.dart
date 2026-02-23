import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import '../../widgets/plan_widgets.dart';

class BillWatchScreen extends StatefulWidget {
  final String walletId;
  const BillWatchScreen({super.key, required this.walletId});
  @override
  State<BillWatchScreen> createState() => _BillWatchScreenState();
}

class _BillWatchScreenState extends State<BillWatchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final List<BillModel> _bills = List.from(mockBills);

  List<BillModel> get _all =>
      _bills.where((b) => b.walletId == widget.walletId).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  List<BillModel> get _unpaid => _all.where((b) => !b.paid).toList();
  List<BillModel> get _paid => _all.where((b) => b.paid).toList();

  double get _totalDue => _unpaid.fold(0, (s, b) => s + b.amount);

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

  void _markPaid(BillModel b) => setState(() {
    b.paid = true;
    b.history = [
      BillPayment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        paidOn: DateTime.now(),
        amount: b.amount,
      ),
      ...b.history,
    ];
  });
  void _delete(BillModel b) => setState(() => _bills.remove(b));

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('🧾', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Bill Watch',
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
          indicatorColor: AppColors.borrow,
          labelColor: AppColors.borrow,
          unselectedLabelColor: subColor,
          tabs: [
            Tab(text: 'Pending (${_unpaid.length})'),
            Tab(text: 'Paid (${_paid.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, isDark, surfBg),
        backgroundColor: AppColors.borrow,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Bill',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: Column(
        children: [
          // Summary
          _BillSummary(
            total: _totalDue,
            overdue: overdue,
            dueSoon: dueSoon,
            isDark: isDark,
          ),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _BillList(
                  bills: _unpaid,
                  isDark: isDark,
                  showPay: true,
                  onPay: _markPaid,
                  onDelete: _delete,
                  onTap: (b) => _showDetailSheet(context, b, isDark),
                ),
                _BillList(
                  bills: _paid,
                  isDark: isDark,
                  showPay: false,
                  onPay: null,
                  onDelete: _delete,
                  onTap: (b) => _showDetailSheet(context, b, isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, bool isDark, Color surfBg) {
    showPlanSheet(
      context,
      child: _AddBillSheet(
        isDark: isDark,
        surfBg: surfBg,
        walletId: widget.walletId,
        onSave: (b) {
          setState(() => _bills.add(b));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDetailSheet(BuildContext context, BillModel b, bool isDark) {
    showPlanSheet(
      context,
      child: _BillDetailSheet(
        bill: b,
        isDark: isDark,
        onPay: b.paid
            ? null
            : () {
                _markPaid(b);
                Navigator.pop(context);
              },
        onDelete: () {
          _delete(b);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _BillSummary extends StatelessWidget {
  final double total;
  final int overdue, dueSoon;
  final bool isDark;
  const _BillSummary({
    required this.total,
    required this.overdue,
    required this.dueSoon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
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
                  'Total Due',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.subDark : AppColors.subLight,
                  ),
                ),
                Text(
                  '₹${(total / 1000).toStringAsFixed(1)}K',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'DM Mono',
                    color: AppColors.borrow,
                  ),
                ),
              ],
            ),
          ),
          _SumChip(count: overdue, label: 'Overdue', color: AppColors.expense),
          const SizedBox(width: 10),
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

class _BillList extends StatelessWidget {
  final List<BillModel> bills;
  final bool isDark, showPay;
  final void Function(BillModel)? onPay;
  final void Function(BillModel) onDelete;
  final void Function(BillModel) onTap;
  const _BillList({
    required this.bills,
    required this.isDark,
    required this.showPay,
    required this.onPay,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty)
      return const PlanEmptyState(
        emoji: '🎉',
        title: 'All clear!',
        subtitle: 'No bills here',
      );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: bills.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SwipeTile(
          onDelete: () => onDelete(bills[i]),
          child: _BillCard(
            bill: bills[i],
            isDark: isDark,
            onPay: showPay && onPay != null ? () => onPay!(bills[i]) : null,
            onTap: () => onTap(bills[i]),
          ),
        ),
      ),
    );
  }
}

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
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withOpacity(0.25)),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
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
                      ),
                      const SizedBox(width: 6),
                      RepeatBadge(repeat: bill.repeat),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${(bill.amount / 1000).toStringAsFixed(1)}K',
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
                        vertical: 4,
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BillDetailSheet extends StatelessWidget {
  final BillModel bill;
  final bool isDark;
  final VoidCallback? onPay;
  final VoidCallback onDelete;
  const _BillDetailSheet({
    required this.bill,
    required this.isDark,
    this.onPay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final statusColor = bill.paid
        ? AppColors.income
        : bill.isOverdue
        ? AppColors.expense
        : bill.isDueSoon
        ? AppColors.lend
        : AppColors.borrow;

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
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  bill.category.emoji,
                  style: const TextStyle(fontSize: 26),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    Text(
                      bill.category.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${(bill.amount / 1000).toStringAsFixed(1)}K',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'DM Mono',
                  color: AppColors.borrow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Due: ${fmtDate(bill.dueDate)} · ${daysUntil(bill.dueDate)}',
            iconColor: statusColor,
          ),
          InfoRow(icon: Icons.repeat_rounded, label: bill.repeat.label),
          if (bill.provider != null)
            InfoRow(icon: Icons.business_rounded, label: bill.provider!),
          if (bill.accountNumber != null)
            InfoRow(
              icon: Icons.numbers_rounded,
              label: 'Account: ${bill.accountNumber}',
            ),

          // Payment history
          if (bill.history.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Payment History',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
            const SizedBox(height: 6),
            ...bill.history
                .take(3)
                .map(
                  (h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 14,
                          color: AppColors.income,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹${h.amount.toStringAsFixed(0)} – ${fmtDateShort(h.paidOn)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              if (onPay != null)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: onPay,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.income, Color(0xFF009E76)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '✓ Mark as Paid',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.expense.withOpacity(0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.expense,
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

class _AddBillSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final void Function(BillModel) onSave;
  const _AddBillSheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    required this.onSave,
  });
  @override
  State<_AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends State<_AddBillSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _provCtrl = TextEditingController();
  final _accCtrl = TextEditingController();
  BillCategory _cat = BillCategory.electricity;
  RepeatMode _repeat = RepeatMode.monthly;
  DateTime _due = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _provCtrl.dispose();
    _accCtrl.dispose();
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
            'Add Bill',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 16),
          PlanInputField(controller: _nameCtrl, hint: 'Bill name *'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PlanInputField(
                  controller: _amountCtrl,
                  hint: 'Amount (₹) *',
                  inputType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PlanInputField(controller: _provCtrl, hint: 'Provider'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PlanInputField(
            controller: _accCtrl,
            hint: 'Account / reference number',
          ),
          const SizedBox(height: 16),

          const SheetLabel(text: 'CATEGORY'),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: BillCategory.values
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _cat = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _cat == c
                                ? AppColors.borrow.withOpacity(0.15)
                                : widget.surfBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _cat == c
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
                              color: _cat == c ? AppColors.borrow : sub,
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
                          initialDate: _due,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 30),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (d != null) setState(() => _due = d);
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
                              color: AppColors.borrow,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              fmtDateShort(_due),
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
                        color: widget.surfBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButton<RepeatMode>(
                        value: _repeat,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: widget.isDark
                            ? AppColors.cardDark
                            : Colors.white,
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
                        onChanged: (r) => setState(() => _repeat = r!),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SaveButton(
            label: 'Save Bill',
            color: AppColors.borrow,
            onTap: () {
              if (_nameCtrl.text.trim().isEmpty ||
                  _amountCtrl.text.trim().isEmpty)
                return;
              widget.onSave(
                BillModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: _nameCtrl.text.trim(),
                  category: _cat,
                  amount: double.tryParse(_amountCtrl.text.trim()) ?? 0,
                  dueDate: _due,
                  repeat: _repeat,
                  walletId: widget.walletId,
                  provider: _provCtrl.text.trim().isEmpty
                      ? null
                      : _provCtrl.text.trim(),
                  accountNumber: _accCtrl.text.trim().isEmpty
                      ? null
                      : _accCtrl.text.trim(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
