import 'package:flutter/material.dart';

class ChipBar extends StatelessWidget {
  final List<String> labels;
  final ValueChanged<String>? onChipPressed;

  const ChipBar({super.key, required this.labels, this.onChipPressed});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: labels.map((label) {
            return ActionChip(
              label: Text(label),
              elevation: 0,
              pressElevation: 0,
              shadowColor: Colors.transparent,
              backgroundColor: Theme.of(context).colorScheme.surface,
              onPressed: () {
                debugPrint('$label pressed');
                onChipPressed?.call(label);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
