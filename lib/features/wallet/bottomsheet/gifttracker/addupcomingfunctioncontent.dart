import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/wallet/upcominggiftplantype.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';

class AddUpcomingFunctionContent extends StatelessWidget {
  const AddUpcomingFunctionContent({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add Upcoming Function', style: textTheme.titleMedium),

        const SizedBox(height: AppSpacing.gapSM),

        TextField(
          decoration: const InputDecoration(labelText: 'Function Name'),
        ),
        TextField(
          decoration: const InputDecoration(labelText: "Who's Function"),
        ),
        TextField(decoration: const InputDecoration(labelText: 'Location')),

        const SizedBox(height: AppSpacing.gapSM),

        /// Date picker
        InkWell(
          onTap: () {},
          child: const InputDecorator(
            decoration: InputDecoration(labelText: 'Date'),
            child: Text('Select date'),
          ),
        ),

        const SizedBox(height: AppSpacing.gapSM),

        /// Plan
        DropdownMenu<UpcomingGiftPlanType>(
          label: const Text('What I need to do'),
          dropdownMenuEntries: const [
            DropdownMenuEntry(
              value: UpcomingGiftPlanType.money,
              label: 'Money',
            ),
            DropdownMenuEntry(
              value: UpcomingGiftPlanType.jewel,
              label: 'Jewel',
            ),
            DropdownMenuEntry(value: UpcomingGiftPlanType.gift, label: 'Gift'),
            DropdownMenuEntry(
              value: UpcomingGiftPlanType.giftCard,
              label: 'Gift Card',
            ),
            DropdownMenuEntry(
              value: UpcomingGiftPlanType.undecided,
              label: 'Not decided',
            ),
          ],
          onSelected: (_) {},
        ),

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
                onPressed: () {},
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
