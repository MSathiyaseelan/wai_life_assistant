import 'package:flutter/material.dart';
import '../../../data/models/pandry/groceryitem.dart';

class GroceryBuyNow extends StatelessWidget {
  final List<GroceryItem> items;

  const GroceryBuyNow({required this.items});

  @override
  Widget build(BuildContext context) {
    final buyNow = items.where((e) => e.isOut || e.isLow).toList();
    if (buyNow.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.all(12),
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.shopping_cart),
            title: Text('Buy Today'),
          ),
          ...buyNow.map(
            (e) => CheckboxListTile(
              title: Text(e.name),
              subtitle: Text('${e.quantity} ${e.unit}'),
              value: false,
              onChanged: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}
