import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import '../../../../data/enum/borrowfields.dart';
import 'borrowfocusnodes.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/borrow/voiceformnavigator.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/borrow/voicenavigatorbar.dart';

class BorrowFormContent extends StatefulWidget {
  const BorrowFormContent({super.key});

  @override
  State<BorrowFormContent> createState() => _BorrowFormContentState();
}

class _BorrowFormContentState extends State<BorrowFormContent> {
  final _formKey = GlobalKey<FormState>();

  DateTime? _returnDate;
  String _interestType = 'None';

  late VoiceFormNavigator<BorrowField> voiceNavigator;
  //late final List<BorrowField> fieldOrder;
  final _focusNodes = List.generate(7, (_) => FocusNode());

  @override
  void initState() {
    super.initState();

    voiceNavigator = VoiceFormNavigator<BorrowField>(
      fieldOrder: const [
        BorrowField.person,
        BorrowField.amount,
        BorrowField.description,
        BorrowField.returnDate,
        BorrowField.interestType,
        BorrowField.interestAmount,
        BorrowField.witness,
      ],
      controllers: {
        BorrowField.person: TextEditingController(),
        BorrowField.amount: TextEditingController(),
        BorrowField.description: TextEditingController(),
        BorrowField.returnDate: TextEditingController(),
        BorrowField.interestType: TextEditingController(),
        BorrowField.interestAmount: TextEditingController(),
        BorrowField.witness: TextEditingController(),
      },
      focusNodes: {
        BorrowField.person: FocusNode(),
        BorrowField.amount: FocusNode(),
        BorrowField.description: FocusNode(),
        BorrowField.returnDate: FocusNode(),
        BorrowField.interestType: FocusNode(),
        BorrowField.interestAmount: FocusNode(),
        BorrowField.witness: FocusNode(),
      },
    );
  }

  @override
  void dispose() {
    voiceNavigator.disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: voiceNavigator,
      builder: (_, __) {
        return Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Borrow', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.gapSM),

              /// Person
              _fieldWrapper(
                BorrowField.person,
                TextFormField(
                  controller: voiceNavigator.controllers[BorrowField.person],
                  focusNode: voiceNavigator.focusNodes[BorrowField.person],
                  decoration: const InputDecoration(labelText: 'Person'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter person name' : null,
                ),
              ),

              const SizedBox(height: AppSpacing.gapSM),

              /// Amount
              _fieldWrapper(
                BorrowField.amount,
                TextFormField(
                  controller: voiceNavigator.controllers[BorrowField.amount],
                  focusNode: voiceNavigator.focusNodes[BorrowField.amount],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter amount' : null,
                ),
              ),

              const SizedBox(height: AppSpacing.gapSM),

              /// Description
              _fieldWrapper(
                BorrowField.description,
                TextFormField(
                  controller:
                      voiceNavigator.controllers[BorrowField.description],
                  focusNode: voiceNavigator.focusNodes[BorrowField.description],
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ),

              const SizedBox(height: AppSpacing.gapMM),

              /// Return Date
              _fieldWrapper(
                BorrowField.returnDate,
                InkWell(
                  onTap: _pickReturnDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Return Date'),
                    child: Text(
                      _returnDate == null
                          ? 'Select date'
                          : _formatDate(_returnDate!),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.gapMM),

              /// Interest Type
              _fieldWrapper(
                BorrowField.interestType,
                DropdownMenu<String>(
                  initialSelection: _interestType,
                  label: const Text('Interest'),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'None', label: 'No Interest'),
                    DropdownMenuEntry(value: 'Daily', label: 'Daily'),
                    DropdownMenuEntry(value: 'Monthly', label: 'Monthly'),
                    DropdownMenuEntry(value: 'Yearly', label: 'Yearly'),
                    DropdownMenuEntry(
                      value: 'Fixed Amount',
                      label: 'Fixed Amount',
                    ),
                  ],
                  onSelected: (value) {
                    if (value != null) {
                      setState(() {
                        _interestType = value;
                        if (_interestType == 'None') {
                          voiceNavigator.controllers[BorrowField.interestAmount]
                              ?.clear();
                        }
                      });
                    }
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.gapSM),

              /// Interest Amount (conditional)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _interestType != 'None'
                    ? _fieldWrapper(
                        BorrowField.interestAmount,
                        TextFormField(
                          controller: voiceNavigator
                              .controllers[BorrowField.interestAmount],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Interest Amount',
                            prefixText: '₹ ',
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.gapSM),

              /// Witness
              _fieldWrapper(
                BorrowField.witness,
                TextFormField(
                  controller: voiceNavigator.controllers[BorrowField.witness],
                  focusNode: voiceNavigator.focusNodes[BorrowField.witness],
                  decoration: const InputDecoration(labelText: 'Witness'),
                ),
              ),

              const SizedBox(height: AppSpacing.gapL),

              /// Voice Navigator Controls
              //VoiceNavigatorBar<BorrowField>(navigator: voiceNavigator),
              const SizedBox(height: AppSpacing.gapSM),

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
      },
    );
  }

  // ---------------- Helpers ----------------

  Widget _fieldWrapper(BorrowField field, Widget child) {
    final active = voiceNavigator.isActive(field);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: active
            ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
            : null,
      ),
      child: child,
    );
  }

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
      'person': voiceNavigator.controllers[BorrowField.person]?.text,
      'amount': voiceNavigator.controllers[BorrowField.amount]?.text,
      'description': voiceNavigator.controllers[BorrowField.description]?.text,
      'returnDate': _returnDate,
      'interestType': _interestType,
      'interestAmount':
          voiceNavigator.controllers[BorrowField.interestAmount]?.text,
      'witness': voiceNavigator.controllers[BorrowField.witness]?.text,
    };

    debugPrint('Borrow Data: $borrowData');
    Navigator.pop(context);
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
