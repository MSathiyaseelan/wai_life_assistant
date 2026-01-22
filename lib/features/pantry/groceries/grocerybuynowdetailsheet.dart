import 'package:flutter/material.dart';
import '../../../data/models/pandry/groceryitem.dart';

class BuyNowDetailsSheet extends StatelessWidget {
  final List<GroceryItem> items;

  const BuyNowDetailsSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Drag handle
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 12),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Items to Buy (${items.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),

              IconButton(
                tooltip: 'Add Item',
                icon: const Icon(Icons.add),
                onPressed: () {
                  _openAddItemSheet(context);
                },
              ),

              IconButton(
                tooltip: 'Download',
                icon: const Icon(Icons.download),
                onPressed: () {
                  // TODO: Export PDF / CSV
                },
              ),

              IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.share),
                onPressed: () {
                  // TODO: Share list
                },
              ),
            ],
          ),
        ),

        const Divider(),

        // List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final item = items[index];
              return ListTile(
                leading: Icon(
                  item.isOut ? Icons.remove_shopping_cart : Icons.warning_amber,
                  color: item.isOut ? Colors.red : Colors.orange,
                ),
                title: Text(item.name),
                subtitle: Text('${item.quantity} ${item.unit}'),
              );
            },
          ),
        ),
      ],
    );
  }
}

void _openAddItemSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _AddBuyItemSheet(),
  );
}

class _AddBuyItemSheet extends StatelessWidget {
  const _AddBuyItemSheet();

  @override
  Widget build(BuildContext context) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Add Item to Buy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Item name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

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
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;

                    // TODO: Add item to BuyNow list / state
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
