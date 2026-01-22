import 'package:flutter/material.dart';
import '../../../data/enum/grocerycategory.dart';

class GroceryCategoryFilter extends StatelessWidget {
  final GroceryCategory selectedCategory;
  final List<GroceryCategory> categories;
  final ValueChanged<GroceryCategory> onSelected;

  const GroceryCategoryFilter({
    super.key,
    required this.selectedCategory,
    required this.categories,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;

          return ChoiceChip(
            label: Text(category.label),
            selected: isSelected,
            onSelected: (_) => onSelected(category),
          );
        },
      ),
    );
  }
}
