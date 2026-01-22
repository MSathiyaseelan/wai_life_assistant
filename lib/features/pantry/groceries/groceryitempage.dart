import 'package:flutter/material.dart';

class GroceryItemsPage extends StatelessWidget {
  final String title;
  final List<GroceryItemSummary> items;

  const GroceryItemsPage({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: items.isEmpty
          ? Center(
              child: Text(
                'No items in "$title"',
                style: textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return _GroceryItemCard(item: item);
              },
            ),
    );
  }
}

class _GroceryItemCard extends StatelessWidget {
  final GroceryItemSummary item;

  const _GroceryItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(blurRadius: 4, color: Colors.black12, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            color: item.isOut
                ? Colors.red
                : item.isLow
                ? Colors.orange
                : Colors.green,
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: textTheme.titleMedium),
                if (item.quantity != null)
                  Text(
                    'Quantity: ${item.quantity}',
                    style: textTheme.bodySmall,
                  ),
                if (item.notes != null)
                  Text(item.notes!, style: textTheme.bodySmall),
              ],
            ),
          ),
          if (item.isExpiringSoon)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.yellow.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Expiring',
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// Example GroceryItem class (replace with your own)
class GroceryItemSummary {
  final String name;
  final bool isOut;
  final bool isLow;
  final bool isExpiringSoon;
  final String? quantity;
  final String? notes;

  GroceryItemSummary({
    required this.name,
    this.isOut = false,
    this.isLow = false,
    this.isExpiringSoon = false,
    this.quantity,
    this.notes,
  });
}
