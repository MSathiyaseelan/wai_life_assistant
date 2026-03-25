import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitequally_participants.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitunequallybyparticipants.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitbypercentagebyparticipants.dart';
import 'package:wai_life_assistant/data/models/wallet/SplitExpense.dart';
import 'package:wai_life_assistant/services/ai_parser.dart';

class AddSpendFormContent extends StatefulWidget {
  final List<String> participants;

  const AddSpendFormContent({super.key, required this.participants});

  @override
  State<AddSpendFormContent> createState() => _AddSpendFormContentState();
}

class _AddSpendFormContentState extends State<AddSpendFormContent>
    with SingleTickerProviderStateMixin {
  late TabController _mode;

  // AI Parse state
  final _aiCtrl = TextEditingController();
  bool _aiLoading = false;
  String? _aiError;

  // Manual form state
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _paidBy;
  String? _category;
  String _splitType = 'Equally';

  final List<File> _bills = [];
  final _picker = ImagePicker();

  static const _categories = ['Food', 'Travel', 'Shopping', 'Entertainment', 'Utilities', 'Health', 'Others'];

  @override
  void initState() {
    super.initState();
    _mode = TabController(length: 2, vsync: this);
    _mode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _mode.dispose();
    _aiCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── AI Parse ────────────────────────────────────────────────────────────────

  Future<void> _parseAI() async {
    final text = _aiCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _aiLoading = true; _aiError = null; });
    try {
      final result = await AIParser.parseText(
        feature: 'wallet',
        subFeature: 'split_expense',
        text: text,
        context: {'members': widget.participants},
      );
      if (!mounted) return;
      if (!result.success || result.data == null) {
        setState(() {
          _aiLoading = false;
          _aiError = result.error ?? 'Could not understand. Try rephrasing.';
        });
        return;
      }
      final data = result.data!;

      // Pre-fill manual form
      final rawAmount = data['amount'];
      if (rawAmount != null) {
        final amt = (rawAmount as num).toDouble();
        _amountCtrl.text = amt == amt.roundToDouble()
            ? amt.toInt().toString()
            : amt.toStringAsFixed(2);
      }
      _descCtrl.text = data['description'] as String? ?? '';

      // Match paid_by to a participant
      final rawPaidBy = (data['paid_by'] as String? ?? '').toLowerCase();
      if (rawPaidBy.isNotEmpty && rawPaidBy != 'null') {
        _paidBy = widget.participants.firstWhere(
          (p) => p.toLowerCase().contains(rawPaidBy) || rawPaidBy.contains(p.toLowerCase()),
          orElse: () => widget.participants.first,
        );
      }

      // Category
      final rawCat = (data['category'] as String? ?? '').toLowerCase();
      if (rawCat.isNotEmpty) {
        _category = _categories.firstWhere(
          (c) => c.toLowerCase() == rawCat,
          orElse: () => 'Others',
        );
      }

      // Split type
      final rawSplit = (data['split_type'] as String? ?? 'equally').toLowerCase();
      _splitType = rawSplit.contains('unequal') ? 'Unequally'
                 : rawSplit.contains('percent') ? 'Percentage'
                 : 'Equally';

      setState(() => _aiLoading = false);
      _mode.animateTo(1); // switch to Manual tab with pre-filled fields
    } catch (e) {
      if (mounted) setState(() { _aiLoading = false; _aiError = 'Parse failed. Fill manually.'; });
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────────

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_paidBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select who paid')),
      );
      return;
    }
    final total = double.parse(_amountCtrl.text);
    final perHead = total / widget.participants.length;
    final splitMap = {for (final m in widget.participants) m: perHead};
    Navigator.pop(
      context,
      SplitExpense(
        amount: total,
        description: _descCtrl.text.trim().isEmpty ? 'Expense' : _descCtrl.text.trim(),
        paidBy: _paidBy!,
        category: _category,
        createdAt: DateTime.now(),
        splitMap: splitMap,
      ),
    );
  }

  // ── Bill helpers ─────────────────────────────────────────────────────────────

  Future<void> _pickBill() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _bills.add(File(picked.path)));
  }

  void _removeBill(int i) => setState(() => _bills.removeAt(i));

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final primary = AppColors.primary;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text('Add Expense', style: textTheme.titleMedium),
        const SizedBox(height: 14),

        // ── Mode switcher ──────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.all(3),
          child: TabBar(
            controller: _mode,
            indicator: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(11)),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: sub,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, fontFamily: 'Nunito'),
            padding: EdgeInsets.zero,
            tabs: const [
              Tab(height: 36, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('✨', style: TextStyle(fontSize: 14)), SizedBox(width: 6), Text('AI Parse'),
              ])),
              Tab(height: 36, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.edit_outlined, size: 14), SizedBox(width: 6), Text('Manual'),
              ])),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── AI Parse tab ───────────────────────────────────────────────────────
        if (_mode.index == 0) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('✨', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Describe the expense — e.g. "Ravi paid ₹1200 for dinner, split equally"',
                style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub, height: 1.4),
              )),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: TextField(
              controller: _aiCtrl,
              maxLines: 3,
              minLines: 2,
              style: TextStyle(fontSize: 14, fontFamily: 'Nunito', color: tc),
              decoration: InputDecoration.collapsed(
                hintText: 'e.g. "Lunch at Saravana Bhavan, ₹840, Priya paid"',
                hintStyle: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: sub),
              ),
            ),
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 8),
            Text(_aiError!, style: const TextStyle(fontSize: 12, fontFamily: 'Nunito', color: AppColors.expense)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _aiLoading ? null : _parseAI,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _aiLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('✨', style: TextStyle(fontSize: 16)),
              label: Text(
                _aiLoading ? 'Parsing…' : 'Parse & Fill',
                style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Nunito', fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _mode.animateTo(1),
              child: Text('Fill manually instead',
                  style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub)),
            ),
          ),
        ],

        // ── Manual tab ─────────────────────────────────────────────────────────
        if (_mode.index == 1) ...[
          Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
                  validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
                ),
                const SizedBox(height: AppSpacing.gapSM),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.gapMM),
                DropdownMenu<String>(
                  width: double.infinity,
                  label: const Text('Paid by'),
                  initialSelection: _paidBy,
                  dropdownMenuEntries: widget.participants
                      .map((p) => DropdownMenuEntry(value: p, label: p))
                      .toList(),
                  onSelected: (v) => setState(() => _paidBy = v),
                ),
                const SizedBox(height: AppSpacing.gapSM),
                DropdownMenu<String>(
                  width: double.infinity,
                  label: const Text('Category'),
                  initialSelection: _category,
                  dropdownMenuEntries: _categories
                      .map((c) => DropdownMenuEntry(value: c, label: c))
                      .toList(),
                  onSelected: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: AppSpacing.gapSM),
                DropdownMenu<String>(
                  width: double.infinity,
                  initialSelection: _splitType,
                  label: const Text('Split type'),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'Equally', label: 'Equally'),
                    DropdownMenuEntry(value: 'Unequally', label: 'Unequally'),
                    DropdownMenuEntry(value: 'Percentage', label: 'Percentage'),
                  ],
                  onSelected: (v) async {
                    if (v == null) return;
                    setState(() => _splitType = v);
                    final amount = double.tryParse(_amountCtrl.text) ?? 0;
                    if (v == 'Equally' && amount > 0) {
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SplitEquallybyParticipantsPage(
                          totalAmount: amount, participants: widget.participants),
                      ));
                    } else if (v == 'Unequally' && amount > 0) {
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SplitUnequallybyParticipantsPage(
                          totalAmount: amount, participants: widget.participants),
                      ));
                    } else if (v == 'Percentage' && amount > 0) {
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SplitByPercentagePage(
                          totalAmount: amount, participants: widget.participants),
                      ));
                    } else if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter amount first')));
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.gapMM),
                _BillUploadSection(bills: _bills, onAdd: _pickBill, onRemove: _removeBill),
                const SizedBox(height: AppSpacing.gapL),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Bill upload section ────────────────────────────────────────────────────────

class _BillUploadSection extends StatelessWidget {
  final List<File> bills;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _BillUploadSection({required this.bills, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bill', style: textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.gapSS),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InkWell(
              onTap: onAdd,
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_a_photo_outlined),
              ),
            ),
            ...bills.asMap().entries.map((e) => Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(e.value, width: 64, height: 64, fit: BoxFit.cover),
                ),
                Positioned(
                  top: -6, right: -6,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => onRemove(e.key),
                  ),
                ),
              ],
            )),
          ],
        ),
      ],
    );
  }
}
