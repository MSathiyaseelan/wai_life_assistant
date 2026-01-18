import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/enum/gifttype.dart';
import 'package:wai_life_assistant/data/enum/giftcontributiontype.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';

class AddGiftedFormContent extends StatefulWidget {
  const AddGiftedFormContent({super.key});

  @override
  State<AddGiftedFormContent> createState() => _AddGiftedFormContentState();
}

class _AddGiftedFormContentState extends State<AddGiftedFormContent> {
  final _personCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();

  GiftType _giftType = GiftType.money;
  ContributionType _contributionType = ContributionType.self;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add Gifted', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.gapSM),

        /// Person
        TextField(
          controller: _personCtrl,
          decoration: const InputDecoration(labelText: 'Person'),
        ),

        const SizedBox(height: AppSpacing.gapSM),

        /// Gift Type
        DropdownMenu<GiftType>(
          initialSelection: _giftType,
          label: const Text('Gift Type'),
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: GiftType.money, label: 'Money'),
            DropdownMenuEntry(value: GiftType.thing, label: 'Thing'),
            DropdownMenuEntry(value: GiftType.giftCard, label: 'Gift Card'),
          ],
          onSelected: (v) => setState(() => _giftType = v!),
        ),

        const SizedBox(height: AppSpacing.gapSM),

        /// Conditional Fields
        if (_giftType == GiftType.money)
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
            ),
          ),

        if (_giftType != GiftType.money)
          TextField(
            controller: _itemCtrl,
            decoration: InputDecoration(
              labelText: _giftType == GiftType.giftCard
                  ? 'Gift Card Brand'
                  : 'Item Name',
            ),
          ),

        const SizedBox(height: AppSpacing.gapSM),

        /// Contribution
        DropdownMenu<ContributionType>(
          initialSelection: _contributionType,
          label: const Text('Contribution'),
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: ContributionType.self, label: 'Self'),
            DropdownMenuEntry(value: ContributionType.group, label: 'Group'),
          ],
          onSelected: (v) => setState(() => _contributionType = v!),
        ),

        const SizedBox(height: AppSpacing.gapL),

        /// Actions
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
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    debugPrint('Gift saved');
    Navigator.pop(context);
  }
}
