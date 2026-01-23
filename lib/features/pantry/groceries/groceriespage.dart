import 'package:flutter/material.dart';
import '../../../data/enum/grocerycategory.dart';
import '../../../data/enum/storagetype.dart';
import '../../../data/models/pantry/groceryitem.dart';
import 'showaddgrocerybottomsheet.dart';
import 'grocerysummary.dart';
import 'grocerybuynow.dart';
import 'groceryitemcard.dart';
import 'grocerycategoryfilter.dart';

class GroceriesPage extends StatefulWidget {
  const GroceriesPage({super.key});

  @override
  State<GroceriesPage> createState() => _GroceriesPageState();
}

class _GroceriesPageState extends State<GroceriesPage> {
  GroceryCategory _selectedCategory = GroceryCategory.all;
  final List<GroceryCategory> _categories = GroceryCategory.values;
  final List<GroceryItem> _items = dummyGroceries;

  @override
  Widget build(BuildContext context) {
    final filteredItems = _selectedCategory == GroceryCategory.all
        ? dummyGroceries
        : dummyGroceries.where((g) => g.category == _selectedCategory).toList();

    final List<GroceryCategory> _categories = [
      GroceryCategory.all,
      GroceryCategory.vegetables,
      GroceryCategory.fruits,
      GroceryCategory.dairy,
      GroceryCategory.grains,
      GroceryCategory.spices,
      GroceryCategory.others,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groceries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showAddGroceryBottomSheet(context: context),
          ),
        ],
      ),
      body: Column(
        children: [
          /// 1️⃣ Summary chips
          GrocerySummary(items: _items),

          /// 2️⃣ Buy Now section
          GroceryBuyNow(items: _items),

          /// 3️⃣ Category filter
          GroceryCategoryFilter(
            selectedCategory: _selectedCategory,
            categories: _categories,
            onSelected: (c) {
              setState(() => _selectedCategory = c);
            },
          ),

          /// 4️⃣ Grocery list
          Expanded(
            child: filteredItems.isEmpty
                ? const _EmptyGroceries()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return GroceryItemCard(
                        item: filteredItems[index],
                        onUpdate: () => setState(() {}),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroceries extends StatelessWidget {
  const _EmptyGroceries();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 48,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'No groceries added yet',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add your first item',
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
    name: 'Curd',
    category: GroceryCategory.dairy,
    quantity: 500,
    unit: 'g',
    storage: StorageType.fridge,
    expiryDate: DateTime.now().add(const Duration(days: 2)),
  ),
  GroceryItem(
    id: '3',
    name: 'Rice',
    category: GroceryCategory.staples,
    quantity: 5,
    unit: 'kg',
    storage: StorageType.pantry,
  ),
  GroceryItem(
    id: '4',
    name: 'Wheat Flour',
    category: GroceryCategory.staples,
    quantity: 2,
    unit: 'kg',
    storage: StorageType.pantry,
  ),
  GroceryItem(
    id: '5',
    name: 'Toor Dal',
    category: GroceryCategory.pulses,
    quantity: 1,
    unit: 'kg',
    storage: StorageType.pantry,
  ),
  GroceryItem(
    id: '6',
    name: 'Potato',
    category: GroceryCategory.vegetables,
    quantity: 2,
    unit: 'kg',
    storage: StorageType.counter,
  ),
  GroceryItem(
    id: '7',
    name: 'Onion',
    category: GroceryCategory.vegetables,
    quantity: 1,
    unit: 'kg',
    storage: StorageType.counter,
  ),
  GroceryItem(
    id: '8',
    name: 'Tomato',
    category: GroceryCategory.vegetables,
    quantity: 500,
    unit: 'g',
    storage: StorageType.counter,
    expiryDate: DateTime.now().add(const Duration(days: 3)),
  ),
  GroceryItem(
    id: '9',
    name: 'Cooking Oil',
    category: GroceryCategory.essentials,
    quantity: 1,
    unit: 'L',
    storage: StorageType.pantry,
  ),
  GroceryItem(
    id: '10',
    name: 'Eggs',
    category: GroceryCategory.protein,
    quantity: 12,
    unit: 'pcs',
    storage: StorageType.fridge,
    expiryDate: DateTime.now().add(const Duration(days: 5)),
  ),
  GroceryItem(
    id: '11',
    name: 'Sugar',
    category: GroceryCategory.essentials,
    quantity: 1,
    unit: 'kg',
    storage: StorageType.pantry,
  ),
  GroceryItem(
    id: '12',
    name: 'Green Chilli',
    category: GroceryCategory.vegetables,
    quantity: 100,
    unit: 'g',
    storage: StorageType.fridge,
    expiryDate: DateTime.now().add(const Duration(days: 4)),
  ),
];
