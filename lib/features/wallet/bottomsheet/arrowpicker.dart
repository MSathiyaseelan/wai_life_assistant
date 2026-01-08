import 'package:flutter/material.dart';

class ArrowPicker extends StatelessWidget {
  final String placeholder;
  final String? value;
  final VoidCallback onTap;

  const ArrowPicker({
    super.key,
    required this.placeholder,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap, // 🔥 text + arrow both trigger
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? placeholder,
                style: textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }
}
