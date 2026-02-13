import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitequally_participants.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitunequallybyparticipants.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitbypercentagebyparticipants.dart';
import 'package:wai_life_assistant/data/models/wallet/SplitExpense.dart';

class AddSpendFormContent extends StatefulWidget {
  final List<String> participants;

  const AddSpendFormContent({super.key, required this.participants});

  @override
  State<AddSpendFormContent> createState() => _AddSpendFormContentState();
}

class _AddSpendFormContentState extends State<AddSpendFormContent> {
  final _formKey = GlobalKey<FormState>();

  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _paidBy;
  String? _category;
  String _splitType = 'Equally';

  final List<File> _bills = [];
  final _picker = ImagePicker();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Title
          Text('Add Spend', style: textTheme.titleMedium),

          const SizedBox(height: AppSpacing.gapSM),

          /// Spend amount
          TextFormField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
            ),
            validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
          ),

          const SizedBox(height: AppSpacing.gapSM),

          /// Description
          TextFormField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 2,
          ),

          const SizedBox(height: AppSpacing.gapMM),

          /// Paid by
          DropdownMenu<String>(
            width: double.infinity,
            label: const Text('Paid by'),
            dropdownMenuEntries: widget.participants
                .map((p) => DropdownMenuEntry(value: p, label: p))
                .toList(),
            onSelected: (v) => setState(() => _paidBy = v),
          ),

          const SizedBox(height: AppSpacing.gapSM),

          /// Category
          DropdownMenu<String>(
            width: double.infinity,
            label: const Text('Category'),
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 'Food', label: 'Food'),
              DropdownMenuEntry(value: 'Travel', label: 'Travel'),
              DropdownMenuEntry(value: 'Shopping', label: 'Shopping'),
              DropdownMenuEntry(value: 'Others', label: 'Others'),
            ],
            onSelected: (v) => setState(() => _category = v),
          ),

          const SizedBox(height: AppSpacing.gapSM),

          /// Split type
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

              if (v == 'Equally') {
                final amount = double.tryParse(_amountCtrl.text) ?? 0;

                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter amount first')),
                  );
                  return;
                }

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SplitEquallybyParticipantsPage(
                      totalAmount: amount,
                      participants: widget.participants,
                    ),
                  ),
                );
              }

              if (v == 'Unequally') {
                final amount = double.tryParse(_amountCtrl.text) ?? 0;
                if (amount <= 0) return;

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SplitUnequallybyParticipantsPage(
                      totalAmount: amount,
                      participants: widget.participants,
                    ),
                  ),
                );

                if (result != null) {
                  // result contains per-user amounts
                  debugPrint('Unequal split result: $result');
                }
              }

              if (v == 'Percentage') {
                final amount = double.tryParse(_amountCtrl.text) ?? 0;
                if (amount <= 0) return;

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SplitByPercentagePage(
                      totalAmount: amount,
                      participants: widget.participants,
                    ),
                  ),
                );

                if (result != null) {
                  debugPrint('Percentage split result: $result');
                }
              }
            },
          ),

          const SizedBox(height: AppSpacing.gapMM),

          /// Bill upload
          _BillUploadSection(
            bills: _bills,
            onAdd: _pickBill,
            onRemove: _removeBill,
          ),

          const SizedBox(height: AppSpacing.gapL),

          /// Buttons
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
    );
  }

  // ---------------- Helpers ----------------

  Future<void> _pickBill() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _bills.add(File(picked.path)));
    }
  }

  void _removeBill(int index) {
    setState(() => _bills.removeAt(index));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_paidBy == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select who paid')));
      return;
    }

    final total = double.parse(_amountCtrl.text);
    final perHead = total / widget.participants.length;

    /// 🔥 Build split map
    final Map<String, double> splitMap = {};

    for (final member in widget.participants) {
      splitMap[member] = perHead;
    }

    final expense = SplitExpense(
      amount: total,
      description: _descCtrl.text.isEmpty ? 'Expense' : _descCtrl.text,
      paidBy: _paidBy!,
      category: _category,
      createdAt: DateTime.now(),
      splitMap: splitMap,
    );

    Navigator.pop(context, expense);
  }
}

class _BillUploadSection extends StatelessWidget {
  final List<File> bills;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _BillUploadSection({
    required this.bills,
    required this.onAdd,
    required this.onRemove,
  });

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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_a_photo_outlined),
              ),
            ),

            ...bills.asMap().entries.map(
              (e) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      e.value,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => onRemove(e.key),
                    ),
                  ),
                ],
              ),
            ),

            /// Add image
          ],
        ),
      ],
    );
  }
}
