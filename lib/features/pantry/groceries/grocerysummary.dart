import 'package:flutter/material.dart';
import '../../../data/models/pandry/groceryitem.dart';
import 'groceryitempage.dart';

class GrocerySummary extends StatelessWidget {
  final List<GroceryItem> items;

  const GrocerySummary({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48, // chip height
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _chip(context, 'In Stock', items.where((e) => !e.isOut).toList()),
            _gap(),
            _chip(context, 'Low', items.where((e) => e.isLow).toList()),
            _gap(),
            _chip(context, 'Out', items.where((e) => e.isOut).toList()),
            _gap(),
            _chip(
              context,
              'Expiring',
              items.where((e) => e.isExpiringSoon).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(width: 8);

  Widget _chip(
    BuildContext context,
    String label,
    List<GroceryItem> filteredItems,
  ) {
    return ActionChip(
      label: Text('$label (${filteredItems.length})'),
      visualDensity: VisualDensity.compact,
      backgroundColor: label == 'Out'
          ? Colors.red.shade100
          : label == 'Low'
          ? Colors.orange.shade100
          : label == 'Expiring'
          ? Colors.yellow.shade100
          : Colors.green.shade100,
      onPressed: filteredItems.isEmpty
          ? null
          : () {
              final itemsList = filteredItems
                  .map(
                    (e) => GroceryItemSummary(
                      name: e.name,
                      isOut: e.isOut,
                      isLow: e.isLow,
                      isExpiringSoon: e.isExpiringSoon,
                    ),
                  )
                  .toList();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      GroceryItemsPage(title: label, items: itemsList),
                ),
              );
            },
    );
  }
}
