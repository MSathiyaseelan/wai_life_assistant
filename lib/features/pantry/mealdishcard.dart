import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/pantry/mealdish.dart';

class MealDishCard extends StatelessWidget {
  final MealDish dish;

  const MealDishCard({super.key, required this.dish});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Name + link
          Row(
            children: [
              Expanded(child: Text(dish.name, style: textTheme.titleMedium)),
              if (dish.referenceLink != null)
                IconButton(
                  icon: const Icon(Icons.link),
                  onPressed: () {
                    // open url later
                  },
                ),
            ],
          ),

          const SizedBox(height: 4),
          Text(
            dish.cuisine,
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 8),

          /// Meal type chips
          Wrap(
            spacing: 6,
            children: dish.suitableFor
                .map((m) => Chip(label: Text(_mealTypeLabel(m))))
                .toList(),
          ),

          const SizedBox(height: 8),

          /// Ingredients
          Text(
            'Ingredients: ${dish.ingredients.take(4).join(', ')}',
            style: textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _mealTypeLabel(MealType t) {
    switch (t) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snacks:
        return 'Snacks';
    }
  }
}
