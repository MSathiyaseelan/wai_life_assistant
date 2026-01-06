import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_radius.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/core/theme/app_icon_sizes.dart';

class CounterChip extends StatelessWidget {
  final String label;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const CounterChip({
    super.key,
    required this.label,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = AppRadius.small; //BorderRadius.circular(8);

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ➖ icon
            InkWell(
              customBorder: RoundedRectangleBorder(borderRadius: borderRadius),
              onTap: onDecrement,
              child: const Padding(
                padding: AppSpacing.chipIconPadding,
                child: Icon(Icons.remove, size: AppIconSizes.small),
              ),
            ),

            Padding(
              padding: AppSpacing.chipPadding,
              child: Text(
                label,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),

            // ➕ icon
            InkWell(
              customBorder: RoundedRectangleBorder(borderRadius: borderRadius),
              onTap: onIncrement,
              child: const Padding(
                padding: AppSpacing.chipPadding,
                child: Icon(Icons.add, size: AppIconSizes.small),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
