import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTRY FLOW SELECTOR
// Bottom sheet with 3 tiles: Meal Map / Recipe Box / Basket
// Shown when user taps + in the chat input bar (field empty)
// ─────────────────────────────────────────────────────────────────────────────

class PantryFlowSelector extends StatelessWidget {
  final VoidCallback onMeal;
  final VoidCallback onRecipe;
  final VoidCallback onBasket;

  const PantryFlowSelector({
    super.key,
    required this.onMeal,
    required this.onRecipe,
    required this.onBasket,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onMeal,
    required VoidCallback onRecipe,
    required VoidCallback onBasket,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PantryFlowSelector(
        onMeal: onMeal,
        onRecipe: onRecipe,
        onBasket: onBasket,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('🥗', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          const Text(
            'What would you like to add?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to open the form',
            style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _PantryFlowTile(
                emoji: '🗺️',
                label: 'Meal Map',
                subtitle: 'Log a meal\nfor any day',
                color: AppColors.income,
                onTap: () {
                  Navigator.pop(context);
                  onMeal();
                },
              ),
              const SizedBox(width: 12),
              _PantryFlowTile(
                emoji: '📖',
                label: 'Recipe Box',
                subtitle: 'Save a new\nrecipe',
                color: AppColors.lend,
                onTap: () {
                  Navigator.pop(context);
                  onRecipe();
                },
              ),
              const SizedBox(width: 12),
              _PantryFlowTile(
                emoji: '🧺',
                label: 'Basket',
                subtitle: 'Add items\nto buy',
                color: AppColors.expense,
                onTap: () {
                  Navigator.pop(context);
                  onBasket();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PantryFlowTile extends StatelessWidget {
  final String emoji, label, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _PantryFlowTile({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Nunito',
                color: color.withOpacity(0.7),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
