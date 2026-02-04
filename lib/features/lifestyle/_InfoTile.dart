import 'package:flutter/material.dart';

class InfoTile extends StatelessWidget {
  final String label;
  final String? value;

  const InfoTile(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: Text(value!, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
