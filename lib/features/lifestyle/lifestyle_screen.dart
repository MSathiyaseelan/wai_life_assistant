import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lifestyleController.dart';
import 'lifestyleItemCard.dart';
import 'package:wai_life_assistant/data/enum/lifestyleCategory.dart';
import 'addLifestyleItemSheet.dart';

class LifeStyleScreen extends StatelessWidget {
  const LifeStyleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LifestyleController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('LifeStyle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => AddLifestyleItemSheet(
                  category: controller.selectedCategory,
                ),
              );
            },
          ),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔝 Category Selector
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: LifestyleCategory.values.map((category) {
                final selected = controller.selectedCategory == category;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_categoryLabel(category)),
                    selected: selected,
                    onSelected: (_) => controller.changeCategory(category),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // 📦 Content
          Expanded(
            child: controller.filteredItems.isEmpty
                ? const _EmptyLifestyle()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: controller.filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      return LifestyleItemCard(
                        item: controller.filteredItems[index],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLifestyle extends StatelessWidget {
  const _EmptyLifestyle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.category_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('No items added yet'),
        ],
      ),
    );
  }
}

String _categoryLabel(LifestyleCategory c) {
  switch (c) {
    case LifestyleCategory.vehicle:
      return 'Vehicle';
    case LifestyleCategory.dresses:
      return 'Dresses';
    case LifestyleCategory.gadgets:
      return 'Gadgets';
    case LifestyleCategory.appliances:
      return 'Appliances';
    case LifestyleCategory.collections:
      return 'Collections';
  }
}
