import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/data/models/wallet/flow_models.dart';
import 'nlp_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// INTENT CONFIRM SHEET
// Shown after NLP parses typed/spoken text.
// Displays what was understood, lets user edit inline, then saves or edits.
// ─────────────────────────────────────────────────────────────────────────────

class IntentConfirmSheet extends StatefulWidget {
  final ParsedIntent intent;
  final String walletId;
  final void Function(TxModel tx) onSave;
  final VoidCallback onOpenFlow; // "Edit in full flow" escape hatch

  const IntentConfirmSheet({
    super.key,
    required this.intent,
    required this.walletId,
    required this.onSave,
    required this.onOpenFlow,
  });

  static Future<void> show(
    BuildContext context, {
    required ParsedIntent intent,
    required String walletId,
    required void Function(TxModel) onSave,
    required VoidCallback onOpenFlow,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => IntentConfirmSheet(
        intent: intent,
        walletId: walletId,
        onSave: onSave,
        onOpenFlow: onOpenFlow,
      ),
    );
  }

  @override
  State<IntentConfirmSheet> createState() => _IntentConfirmSheetState();
}

class _IntentConfirmSheetState extends State<IntentConfirmSheet> {
  late FlowType _flowType;
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _personCtrl;
  String? _category;
  PayMode? _payMode;

  // All category options
  static const _expenseCategories = [
    'Food',
    'Grocery',
    'Travel',
    'Shopping',
    'Entertainment',
    'Bills',
    'Health',
    'Education',
    'Fuel',
    'Other',
  ];
  static const _incomeCategories = [
    'Salary',
    'Freelance',
    'Business',
    'Rent',
    'Investment',
    'Refund',
    'Gift',
    'Other',
  ];
  static const _transferCategories = [
    'Personal Loan',
    'Shared Expense',
    'Emergency',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final i = widget.intent;
    _flowType = i.flowType;
    _amountCtrl = TextEditingController(
      text: i.amount != null && i.amount! > 0
          ? i.amount!.toStringAsFixed(i.amount! == i.amount!.truncate() ? 0 : 2)
          : '',
    );
    _noteCtrl = TextEditingController(text: i.note ?? '');
    _personCtrl = TextEditingController(text: i.person ?? '');
    _category = i.category;
    _payMode = i.payMode;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _personCtrl.dispose();
    super.dispose();
  }

  bool get _needsPerson =>
      _flowType == FlowType.lend ||
      _flowType == FlowType.borrow ||
      _flowType == FlowType.split ||
      _flowType == FlowType.request;

  bool get _needsPayMode =>
      _flowType == FlowType.expense || _flowType == FlowType.income;

  List<String> get _categories {
    if (_flowType == FlowType.income) return _incomeCategories;
    if (_needsPerson) return _transferCategories;
    return _expenseCategories;
  }

  void _save() {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      // Shake animation would go here — for now just show error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    final now = DateTime.now();
    final tx = TxModel(
      id: '${now.millisecondsSinceEpoch}',
      type: _flowType.txType,
      payMode: _payMode,
      amount: amount,
      category:
          _category ?? (_flowType == FlowType.income ? 'Income' : 'Expense'),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      walletId: widget.walletId,
      date: now,
      person: _personCtrl.text.trim().isEmpty ? null : _personCtrl.text.trim(),
    );

    widget.onSave(tx);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final color = _flowType.color;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Handle ─────────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Header — understood intent ──────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _flowType.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Got it! This looks like a ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Nunito',
                                    color: sub,
                                  ),
                                ),
                                Text(
                                  _flowType.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Nunito',
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Review & save below',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color: sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Flow type switcher chips
                      _FlowChip(
                        label: 'Change',
                        color: color,
                        onTap: () =>
                            _showFlowTypePicker(context, isDark, surfBg),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Amount ─────────────────────────────────────────────────
                _Label('AMOUNT', sub),
                _AmountField(
                  controller: _amountCtrl,
                  color: color,
                  surfBg: surfBg,
                  tc: tc,
                ),
                const SizedBox(height: 14),

                // ── Category chips ──────────────────────────────────────────
                _Label('CATEGORY', sub),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories
                      .map(
                        (cat) => GestureDetector(
                          onTap: () => setState(() => _category = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 130),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _category == cat
                                  ? color.withOpacity(0.12)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _category == cat
                                    ? color
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                color: _category == cat ? color : sub,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),

                // ── Person (for lend/borrow/split/request) ─────────────────
                if (_needsPerson) ...[
                  _Label(
                    _flowType == FlowType.lend
                        ? 'LENT TO'
                        : _flowType == FlowType.borrow
                        ? 'BORROWED FROM'
                        : _flowType == FlowType.split
                        ? 'SPLIT WITH'
                        : 'REQUEST FROM',
                    sub,
                  ),
                  _InputField(
                    controller: _personCtrl,
                    hint: 'Person name',
                    surfBg: surfBg,
                    tc: tc,
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Pay mode (expense / income only) ───────────────────────
                if (_needsPayMode) ...[
                  _Label('PAID VIA', sub),
                  Row(
                    children: [
                      Expanded(
                        child: _PayModeChip(
                          label: 'Cash',
                          icon: Icons.money_rounded,
                          selected: _payMode == PayMode.cash,
                          color: AppColors.income,
                          surfBg: surfBg,
                          onTap: () => setState(
                            () => _payMode = _payMode == PayMode.cash
                                ? null
                                : PayMode.cash,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PayModeChip(
                          label: 'Online / UPI',
                          icon: Icons.phone_android_rounded,
                          selected: _payMode == PayMode.online,
                          color: AppColors.primary,
                          surfBg: surfBg,
                          onTap: () => setState(
                            () => _payMode = _payMode == PayMode.online
                                ? null
                                : PayMode.online,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Note ───────────────────────────────────────────────────
                _Label('NOTE (OPTIONAL)', sub),
                _InputField(
                  controller: _noteCtrl,
                  hint: 'Add a note…',
                  surfBg: surfBg,
                  tc: tc,
                ),
                const SizedBox(height: 22),

                // ── Action buttons ─────────────────────────────────────────
                Row(
                  children: [
                    // Edit in full flow
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onOpenFlow();
                        },
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text(
                          'Full Flow',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: sub,
                          side: BorderSide(color: sub.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Save
                    Expanded(
                      flex: 3,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          'Save ${_flowType.label}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            fontSize: 14,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
      ),
    );
  }

  void _showFlowTypePicker(BuildContext ctx, bool isDark, Color surfBg) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Change Transaction Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.1,
                physics: const NeverScrollableScrollPhysics(),
                children: FlowType.values
                    .map(
                      (f) => GestureDetector(
                        onTap: () {
                          setState(() {
                            _flowType = f;
                            _category = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          decoration: BoxDecoration(
                            color: _flowType == f
                                ? f.color.withOpacity(0.15)
                                : surfBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _flowType == f
                                  ? f.color
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                f.emoji,
                                style: const TextStyle(fontSize: 26),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                f.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Nunito',
                                  color: f.color,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  final Color color;
  const _Label(this.text, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        fontFamily: 'Nunito',
        color: color,
      ),
    ),
  );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color surfBg, tc;
  const _InputField({
    required this.controller,
    required this.hint,
    required this.surfBg,
    required this.tc,
  });
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: tc),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 12,
        color: AppColors.subLight,
      ),
      filled: true,
      fillColor: surfBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

// Large amount input with rupee prefix
class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final Color color, surfBg, tc;
  const _AmountField({
    required this.controller,
    required this.color,
    required this.surfBg,
    required this.tc,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: surfBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(
      children: [
        Text(
          '₹',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            fontFamily: 'DM Mono',
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              fontFamily: 'DM Mono',
              color: tc,
            ),
            decoration: InputDecoration.collapsed(
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                fontFamily: 'DM Mono',
                color: color.withOpacity(0.25),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PayModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color, surfBg;
  final VoidCallback onTap;
  const _PayModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.surfBg,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.1) : surfBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? color : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: selected ? color : AppColors.subLight),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
              color: selected ? color : AppColors.subLight,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FlowChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FlowChip({
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'Nunito',
          color: color,
        ),
      ),
    ),
  );
}
