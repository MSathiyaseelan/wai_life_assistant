import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';

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
    final borderRadius = BorderRadius.circular(8);

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Icon(Icons.remove, size: 18),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(label),
            ),

            // ➕ icon
            InkWell(
              customBorder: RoundedRectangleBorder(borderRadius: borderRadius),
              onTap: onIncrement,
              child: const Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Icon(Icons.add, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
