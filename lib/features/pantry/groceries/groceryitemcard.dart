import 'package:flutter/material.dart';
import '../../../data/models/pandry/groceryitem.dart';

class GroceryItemCard extends StatelessWidget {
  final GroceryItem item;
  final VoidCallback onUpdate;

  const GroceryItemCard({required this.item, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.name),
      subtitle: Text('${item.quantity} ${item.unit}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.remove), onPressed: onUpdate),
          IconButton(icon: const Icon(Icons.add), onPressed: onUpdate),
        ],
      ),
    );
  }
}
