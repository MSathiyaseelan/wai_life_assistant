import 'package:flutter/material.dart';
import '../../../data/models/pantry/groceryitem.dart';
import '../../../data/enum/grocerycategory.dart';
import '../../../data/enum/storagetype.dart';

class AddGroceryFormContent extends StatelessWidget {
  const AddGroceryFormContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Add Grocery'),
        TextFormField(decoration: const InputDecoration(labelText: 'Name')),
        TextFormField(decoration: const InputDecoration(labelText: 'Quantity')),
        DropdownButtonFormField(
          items: GroceryCategory.values
              .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
              .toList(),
          onChanged: (_) {},
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

final dummyGroceries = [
  GroceryItem(
    id: '1',
    name: 'Milk',
    category: GroceryCategory.dairy,
    quantity: 1,
    unit: 'L',
    storage: StorageType.fridge,
    expiryDate: DateTime.now().add(const Duration(days: 1)),
  ),
  GroceryItem(
    id: '2',
    name: 'Rice',
    category: GroceryCategory.staples,
    quantity: 5,
    unit: 'kg',
    storage: StorageType.pantry,
  ),
];
