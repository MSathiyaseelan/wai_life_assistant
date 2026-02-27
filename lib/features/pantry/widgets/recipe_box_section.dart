import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import '../sheets/add_recipe_sheet.dart';

class RecipeBoxSection extends StatefulWidget {
  final List<RecipeModel> recipes;
  final void Function(RecipeModel) onRecipeTapped;
  final void Function(RecipeModel) onToggleFavourite;
  final void Function(RecipeModel) onRecipeAdded;

  const RecipeBoxSection({
    super.key,
    required this.recipes,
    required this.onRecipeTapped,
    required this.onToggleFavourite,
    required this.onRecipeAdded,
  });

  @override
  State<RecipeBoxSection> createState() => _RecipeBoxSectionState();
}

class _RecipeBoxSectionState extends State<RecipeBoxSection> {
  CuisineType? _filterCuisine;
  MealTime? _filterTime;

  List<RecipeModel> get _filtered {
    return widget.recipes.where((r) {
      if (_filterCuisine != null && r.cuisine != _filterCuisine) return false;
      if (_filterTime != null && !r.suitableFor.contains(_filterTime))
        return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              const Text('📖', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Recipe Box',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    AddRecipeSheet.show(context, onSave: widget.onRecipeAdded),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7043).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 14,
                        color: Color(0xFFFF7043),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Add Recipe',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF7043),
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Cuisine filter chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                label: 'All',
                selected: _filterCuisine == null && _filterTime == null,
                color: AppColors.primary,
                onTap: () => setState(() {
                  _filterCuisine = null;
                  _filterTime = null;
                }),
              ),
              const SizedBox(width: 6),
              ...CuisineType.values.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FilterChip(
                    label: '${c.emoji} ${c.label}',
                    selected: _filterCuisine == c,
                    color: AppColors.lend,
                    onTap: () => setState(
                      () => _filterCuisine = _filterCuisine == c ? null : c,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ...MealTime.values.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FilterChip(
                    label: '${t.emoji} ${t.label}',
                    selected: _filterTime == t,
                    color: t.color,
                    onTap: () => setState(
                      () => _filterTime = _filterTime == t ? null : t,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Recipe cards
        if (_filtered.isEmpty)
          _EmptyRecipes(isDark: isDark)
        else
          ...(_filtered.map(
            (r) => RecipeCard(
              recipe: r,
              isDark: isDark,
              onTap: () => widget.onRecipeTapped(r),
              onFavTap: () => widget.onToggleFavourite(r),
            ),
          )),
      ],
    );
  }
}

// ── Recipe card ────────────────────────────────────────────────────────────────

class RecipeCard extends StatelessWidget {
  final RecipeModel recipe;
  final bool isDark;
  final VoidCallback onTap, onFavTap;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.isDark,
    required this.onTap,
    required this.onFavTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Emoji bubble
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: recipe.cuisine.emoji.isNotEmpty
                    ? AppColors.lend.withOpacity(0.1)
                    : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(recipe.emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: isDark
                                ? AppColors.textDark
                                : AppColors.textLight,
                          ),
                        ),
                      ),
                      // Fav toggle
                      GestureDetector(
                        onTap: onFavTap,
                        child: Icon(
                          recipe.isFavourite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: recipe.isFavourite
                              ? AppColors.expense
                              : AppColors.subLight,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Cuisine + time badges
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      _MiniBadge(
                        label:
                            '${recipe.cuisine.emoji} ${recipe.cuisine.label}',
                        color: AppColors.lend,
                      ),
                      ...recipe.suitableFor.map(
                        (t) => _MiniBadge(
                          label: '${t.emoji} ${t.label}',
                          color: t.color,
                        ),
                      ),
                      if (recipe.cookTimeMin != null)
                        _MiniBadge(
                          label: '⏱ ${recipe.cookTimeMin} min',
                          color: AppColors.subLight,
                        ),
                    ],
                  ),
                  if (recipe.socialLink != null) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 12,
                          color: AppColors.split,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            'Recipe link saved',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.split,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color,
        fontFamily: 'Nunito',
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color
              : (isDark ? AppColors.surfDark : AppColors.bgLight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            color: selected
                ? Colors.white
                : (isDark ? AppColors.subDark : AppColors.subLight),
          ),
        ),
      ),
    );
  }
}

class _EmptyRecipes extends StatelessWidget {
  final bool isDark;
  const _EmptyRecipes({required this.isDark});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Column(
        children: [
          const Text('📖', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          const Text(
            'No recipes yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontFamily: 'Nunito',
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Add your favourite recipes!',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Nunito',
              color: isDark ? AppColors.subDark : AppColors.subLight,
            ),
          ),
        ],
      ),
    ),
  );
}
