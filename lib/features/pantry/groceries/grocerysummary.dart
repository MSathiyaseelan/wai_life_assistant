import 'package:flutter/material.dart';
import '../../../data/models/pandry/groceryitem.dart';
import 'groceryitempage.dart';

class GrocerySummary extends StatelessWidget {
  final List<GroceryItem> items;

  const GrocerySummary({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        children: [
          _chip(context, 'In Stock', items.where((e) => !e.isOut).toList()),
          _chip(context, 'Low', items.where((e) => e.isLow).toList()),
          _chip(context, 'Out', items.where((e) => e.isOut).toList()),
          _chip(
            context,
            'Expiring',
            items.where((e) => e.isExpiringSoon).toList(),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    List<GroceryItem> filteredItems,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final itemsList = items
            .map(
              (e) => GroceryItemSummary(
                name: e.name,
                isOut: e.isOut,
                isLow: e.isLow,
                isExpiringSoon: e.isExpiringSoon,
              ),
            )
            .toList();

        // Open a page or bottom sheet with filtered items
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroceryItemsPage(title: label, items: itemsList),
          ),
        );
      },
      child: Chip(label: Text('$label (${filteredItems.length})')),
    );
  }
}
