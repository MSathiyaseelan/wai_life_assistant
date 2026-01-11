import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';

class BorrowFormContent extends StatefulWidget {
  const BorrowFormContent({super.key});

  @override
  State<BorrowFormContent> createState() => _BorrowFormContentState();
}

class _BorrowFormContentState extends State<BorrowFormContent> {
  final _formKey = GlobalKey<FormState>();

  final _personCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _witnessCtrl = TextEditingController();

  DateTime? _returnDate;
  String _interestType = 'None';
  final TextEditingController _interestAmountController =
      TextEditingController();

  @override
  void dispose() {
    _personCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _witnessCtrl.dispose();
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
          Text('Add Borrow', style: textTheme.titleMedium),

          const SizedBox(height: AppSpacing.gapSM),

          /// Person
          TextFormField(
            controller: _personCtrl,
            decoration: const InputDecoration(labelText: 'Person'),
            validator: (v) =>
                v == null || v.isEmpty ? 'Enter person name' : null,
          ),

          const SizedBox(height: AppSpacing.gapSM),

          /// Amount
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

          /// Return Date
          InkWell(
            onTap: _pickReturnDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Return Date'),
              child: Text(
                _returnDate == null ? 'Select date' : _formatDate(_returnDate!),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.gapMM),

          /// Interest dropdown
          DropdownMenu<String>(
            initialSelection: _interestType,
            label: const Text('Interest'),
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 'None', label: 'No Interest'),
              DropdownMenuEntry(value: 'Daily', label: 'Daily'),
              DropdownMenuEntry(value: 'Monthly', label: 'Monthly'),
              DropdownMenuEntry(value: 'Yearly', label: 'Yearly'),
              DropdownMenuEntry(value: 'Fixed Amount', label: 'Fixed Amount'),
            ],
            onSelected: (value) {
              if (value != null) {
                setState(() {
                  _interestType = value;

                  // Reset amount if no interest
                  if (_interestType == 'None') {
                    _interestAmountController.clear();
                  }
                });
              }
            },
          ),

          const SizedBox(height: AppSpacing.gapSM),

          /// Interest Amount Field (Conditional)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _interestType != 'None'
                ? TextField(
                    key: const ValueKey('interest'),
                    controller: _interestAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Interest Amount',
                      prefixText: '₹ ',
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: AppSpacing.gapSM),

          /// Witness
          TextFormField(
            controller: _witnessCtrl,
            decoration: const InputDecoration(labelText: 'Witness'),
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

  Future<void> _pickReturnDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked != null) {
      setState(() => _returnDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final borrowData = {
      'person': _personCtrl.text,
      'amount': _amountCtrl.text,
      'description': _descCtrl.text,
      'returnDate': _returnDate,
      'interest': _interestType,
      'witness': _witnessCtrl.text,
    };

    debugPrint('Borrow Data: $borrowData');

    Navigator.pop(context);
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
