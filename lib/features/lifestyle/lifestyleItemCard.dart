import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyleItem.dart';

class LifestyleItemCard extends StatelessWidget {
  final LifestyleItem item;

  const LifestyleItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: textTheme.titleMedium),

            if (item.brand != null) ...[
              const SizedBox(height: 4),
              Text(item.brand!, style: textTheme.bodySmall),
            ],

            const SizedBox(height: 8),

            Row(
              children: [
                if (item.price != null)
                  Text('₹${item.price!.toStringAsFixed(0)}'),

                if (item.purchaseDate != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Bought: ${item.purchaseDate!.toLocal().toString().split(' ')[0]}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ],
            ),

            if (item.notes != null) ...[
              const SizedBox(height: 8),
              Text(item.notes!, style: textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
