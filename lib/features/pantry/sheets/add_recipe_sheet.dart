import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';

// ── Add Recipe Sheet ──────────────────────────────────────────────────────────

class AddRecipeSheet extends StatefulWidget {
  final void Function(RecipeModel) onSave;

  const AddRecipeSheet({super.key, required this.onSave});

  static Future<void> show(
    BuildContext context, {
    required void Function(RecipeModel) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddRecipeSheet(onSave: onSave),
    );
  }

  @override
  State<AddRecipeSheet> createState() => _AddRecipeSheetState();
}

class _AddRecipeSheetState extends State<AddRecipeSheet> {
  final _nameCtrl = TextEditingController();
  final _ingCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();

  String _emoji = '🍽️';
  CuisineType _cuisine = CuisineType.indian;
  final Set<MealTime> _suitableFor = {MealTime.lunch};
  bool _isFav = false;

  final _emojis = [
    '🍽️',
    '🍗',
    '🥘',
    '🍜',
    '🍛',
    '🥗',
    '🫕',
    '🍲',
    '🥞',
    '🫓',
    '🍝',
    '🌮',
    '🥙',
    '🍱',
    '🥟',
    '🧆',
    '🥭',
    '🍰',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ingCtrl.dispose();
    _linkCtrl.dispose();
    _noteCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final ings = _ingCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    widget.onSave(
      RecipeModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        emoji: _emoji,
        cuisine: _cuisine,
        suitableFor: _suitableFor.toList(),
        ingredients: ings,
        socialLink: _linkCtrl.text.trim().isEmpty
            ? null
            : _linkCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        cookTimeMin: int.tryParse(_timeCtrl.text.trim()),
        isFavourite: _isFav,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  // Header
                  Row(
                    children: [
                      const Text('📖', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      const Text(
                        'Add to Recipe Box',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _isFav = !_isFav),
                        child: Icon(
                          _isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _isFav ? AppColors.expense : sub,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Emoji picker
                  SizedBox(
                    height: 46,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _emojis.length,
                      itemBuilder: (_, i) {
                        final e = _emojis[i];
                        final sel = e == _emoji;
                        return GestureDetector(
                          onTap: () => setState(() => _emoji = e),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 44,
                            height: 44,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.primary.withOpacity(0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  _Field(
                    ctrl: _nameCtrl,
                    hint: 'Recipe name',
                    surfBg: surfBg,
                    tc: tc,
                    sub: sub,
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    ctrl: _ingCtrl,
                    hint: 'Ingredients (comma separated)',
                    surfBg: surfBg,
                    tc: tc,
                    sub: sub,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    ctrl: _timeCtrl,
                    hint: 'Cook time (minutes)',
                    surfBg: surfBg,
                    tc: tc,
                    sub: sub,
                    inputType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    ctrl: _linkCtrl,
                    hint: 'Social media link (YouTube/Instagram)',
                    surfBg: surfBg,
                    tc: tc,
                    sub: sub,
                    inputType: TextInputType.url,
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    ctrl: _noteCtrl,
                    hint: 'Notes / Tips (optional)',
                    surfBg: surfBg,
                    tc: tc,
                    sub: sub,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Cuisine selector
                  Text(
                    'Cuisine',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: CuisineType.values.map((c) {
                      final sel = c == _cuisine;
                      return GestureDetector(
                        onTap: () => setState(() => _cuisine = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.lend : surfBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? AppColors.lend : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '${c.emoji} ${c.label}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: sel ? Colors.white : sub,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Suitable for
                  Text(
                    'Suitable For',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: MealTime.values.map((mt) {
                      final sel = _suitableFor.contains(mt);
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            if (sel)
                              _suitableFor.remove(mt);
                            else
                              _suitableFor.add(mt);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: sel
                                  ? mt.color
                                  : mt.color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  mt.emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  mt.label,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                    color: sel ? Colors.white : mt.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Save button
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lend,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: AppColors.lend.withOpacity(0.4),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Save Recipe →',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recipe Detail Sheet ───────────────────────────────────────────────────────

class RecipeDetailSheet extends StatelessWidget {
  final RecipeModel recipe;
  const RecipeDetailSheet({super.key, required this.recipe});

  static Future<void> show(BuildContext context, RecipeModel recipe) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecipeDetailSheet(recipe: recipe),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 0),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [
                  // Hero row
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.lend.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          recipe.emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Nunito',
                                color: tc,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              children: [
                                _Tag(
                                  label:
                                      '${recipe.cuisine.emoji} ${recipe.cuisine.label}',
                                  color: AppColors.lend,
                                ),
                                if (recipe.cookTimeMin != null)
                                  _Tag(
                                    label: '⏱ ${recipe.cookTimeMin} min',
                                    color: sub,
                                  ),
                                if (recipe.isFavourite)
                                  _Tag(
                                    label: '❤️ Favourite',
                                    color: AppColors.expense,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Suitable for
                  const _SectionTitle(title: 'Suitable For'),
                  const SizedBox(height: 8),
                  Row(
                    children: recipe.suitableFor
                        .map(
                          (mt) => Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: mt.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: mt.color.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '${mt.emoji} ${mt.label}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: mt.color,
                                fontFamily: 'Nunito',
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),

                  // Ingredients
                  const _SectionTitle(title: 'Ingredients'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: recipe.ingredients
                          .asMap()
                          .entries
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: AppColors.income.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${e.key + 1}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.income,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    e.value,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'Nunito',
                                      color: tc,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                  if (recipe.note != null) ...[
                    const SizedBox(height: 16),
                    const _SectionTitle(title: '💡 Tips & Notes'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.lend.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.lend.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        recipe.note!,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          color: tc,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  if (recipe.socialLink != null) ...[
                    const SizedBox(height: 16),
                    const _SectionTitle(title: 'Recipe Link'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.split.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.split.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            color: AppColors.split,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              recipe.socialLink!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Nunito',
                                color: AppColors.split,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final Color surfBg, tc, sub;
  final int maxLines;
  final TextInputType inputType;

  const _Field({
    required this.ctrl,
    required this.hint,
    required this.surfBg,
    required this.tc,
    required this.sub,
    this.maxLines = 1,
    this.inputType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: surfBg,
      borderRadius: BorderRadius.circular(14),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: TextField(
      controller: ctrl,
      maxLines: maxLines,
      minLines: 1,
      keyboardType: inputType,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
      decoration: InputDecoration.collapsed(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: sub, fontFamily: 'Nunito'),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w900,
      fontFamily: 'Nunito',
      color: AppColors.primary,
    ),
  );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: color,
        fontFamily: 'Nunito',
      ),
    ),
  );
}
