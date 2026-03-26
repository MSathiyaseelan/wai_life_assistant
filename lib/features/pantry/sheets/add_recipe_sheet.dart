import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import 'package:wai_life_assistant/core/supabase/pantry_service.dart';

// ── Add Recipe Sheet ──────────────────────────────────────────────────────────

class AddRecipeSheet extends StatefulWidget {
  final void Function(RecipeModel) onSave;
  final RecipeModel? existing;
  final void Function(RecipeModel)? onUpdate;

  const AddRecipeSheet({
    super.key,
    required this.onSave,
    this.existing,
    this.onUpdate,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(RecipeModel) onSave,
    RecipeModel? existing,
    void Function(RecipeModel)? onUpdate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddRecipeSheet(
        onSave: onSave,
        existing: existing,
        onUpdate: onUpdate,
      ),
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

  // ─── Library tab ────────────────────────────────────────────────────────────
  int _tab = 0; // 0 = Custom, 1 = From Library
  final _searchCtrl = TextEditingController();
  List<MasterRecipe> _masterResults = [];
  bool _searching = false;
  bool _libraryLoaded = false;

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

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _emoji = e.emoji;
      _cuisine = e.cuisine;
      _suitableFor
        ..clear()
        ..addAll(e.suitableFor);
      _isFav = e.isFavourite;
      _ingCtrl.text = e.ingredients.join(', ');
      _linkCtrl.text = e.socialLink ?? '';
      _noteCtrl.text = e.note ?? '';
      _timeCtrl.text = e.cookTimeMin?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ingCtrl.dispose();
    _linkCtrl.dispose();
    _noteCtrl.dispose();
    _timeCtrl.dispose();
    _searchCtrl.dispose();
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

    final recipe = RecipeModel(
      id: _isEdit
          ? widget.existing!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      walletId: widget.existing?.walletId ?? '',
      name: name,
      emoji: _emoji,
      cuisine: _cuisine,
      suitableFor: _suitableFor.toList(),
      ingredients: ings,
      socialLink:
          _linkCtrl.text.trim().isEmpty ? null : _linkCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      cookTimeMin: int.tryParse(_timeCtrl.text.trim()),
      isFavourite: _isFav,
    );

    if (_isEdit) {
      widget.onUpdate!(recipe);
    } else {
      widget.onSave(recipe);
    }
    Navigator.pop(context);
  }

  Future<void> _doSearch(String q) async {
    if (!mounted) return;
    setState(() => _searching = true);
    try {
      final rows = await PantryService.instance.searchMasterRecipes(q);
      if (!mounted) return;
      setState(() {
        _masterResults = rows.map(MasterRecipe.fromMap).toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _loadLibrary() {
    if (!_libraryLoaded) {
      _libraryLoaded = true;
      _doSearch('');
    }
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

            // ── Tab switcher (hidden in edit mode) ───────────────────────────
            if (!_isEdit)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(children: [
                  _tabBtn(0, '✏️  Custom', surfBg, sub),
                  const SizedBox(width: 8),
                  _tabBtn(1, '📚  Library', surfBg, sub),
                ]),
              ),

            Expanded(
              child: _tab == 0
                  ? ListView(
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
                            if (sel) {
                              _suitableFor.remove(mt);
                            } else {
                              _suitableFor.add(mt);
                            }
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
                    child: Text(
                      _isEdit ? 'Update Recipe →' : 'Save Recipe →',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ],
                  )
                  : _buildLibrary(surfBg, tc, sub),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab button ───────────────────────────────────────────────────────────────

  Widget _tabBtn(int idx, String label, Color surfBg, Color sub) {
    final sel = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tab = idx);
          if (idx == 1) _loadLibrary();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: sel ? AppColors.lend : surfBg,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: 'Nunito',
              color: sel ? Colors.white : sub,
            ),
          ),
        ),
      ),
    );
  }

  // ── Library tab body ─────────────────────────────────────────────────────────

  Widget _buildLibrary(Color surfBg, Color tc, Color sub) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Container(
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: sub, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _doSearch,
                    style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Search by name or cuisine…',
                      hintStyle: TextStyle(fontSize: 13, color: sub, fontFamily: 'Nunito'),
                    ),
                  ),
                ),
                if (_searching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lend),
                  ),
              ],
            ),
          ),
        ),

        // Results list
        Expanded(
          child: _masterResults.isEmpty && !_searching
              ? Center(
                  child: Text(
                    _libraryLoaded ? 'No recipes found 🍽️' : 'Loading…',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: sub),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: _masterResults.length,
                  separatorBuilder: (_, i) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final r = _masterResults[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.lend.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(r.emoji, style: const TextStyle(fontSize: 22)),
                      ),
                      title: Text(
                        r.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      subtitle: Text(
                        '${r.cuisine}${r.cookTimeMin != null ? '  ·  ⏱ ${r.cookTimeMin} min' : ''}',
                        style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
                      ),
                      trailing: GestureDetector(
                        onTap: () => _quickAdd(ctx, r),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lend,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '+ Add',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ),
                      ),
                      onTap: () => _showPreview(ctx, r),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _quickAdd(BuildContext ctx, MasterRecipe r) {
    widget.onSave(r.toRecipeModel());
    Navigator.pop(context);
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(
          '${r.emoji} ${r.name} added to Recipe Box!',
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.lend,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPreview(BuildContext ctx, MasterRecipe r) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MasterPreviewSheet(
        recipe: r,
        onAdd: () {
          widget.onSave(r.toRecipeModel());
          Navigator.pop(ctx);    // close preview
          Navigator.pop(context); // close add sheet
        },
      ),
    );
  }
}

// ── Master Recipe Preview Sheet ───────────────────────────────────────────────

class _MasterPreviewSheet extends StatelessWidget {
  final MasterRecipe recipe;
  final VoidCallback onAdd;

  const _MasterPreviewSheet({required this.recipe, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg    = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc    = isDark ? AppColors.textDark : AppColors.textLight;
    final sub   = isDark ? AppColors.subDark : AppColors.subLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
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
                color: Colors.grey.withValues(alpha: 0.3),
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
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.lend.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(recipe.emoji, style: const TextStyle(fontSize: 30)),
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
                                _PrvTag(label: recipe.cuisine, color: AppColors.lend),
                                if (recipe.cookTimeMin != null)
                                  _PrvTag(label: '⏱ ${recipe.cookTimeMin} min', color: sub),
                                if (recipe.calories != null)
                                  _PrvTag(label: '🔥 ${recipe.calories} kcal', color: AppColors.income),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Meal types
                  if (recipe.mealTypes.isNotEmpty) ...[
                    Text(
                      'Suitable For',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: recipe.mealTypes.map((t) {
                        final mt = MealTime.values.firstWhere(
                          (m) => m.name == t || (t == 'snacks' && m.name == 'snack'),
                          orElse: () => MealTime.lunch,
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: mt.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: mt.color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${mt.emoji} ${mt.label}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: mt.color, fontFamily: 'Nunito'),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Ingredients
                  Text(
                    'Ingredients',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: recipe.ingredients.asMap().entries.map((e) =>
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 20, height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.income.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${e.key + 1}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.income),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: tc),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tags
                  if (recipe.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: recipe.tags.map((t) =>
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#$t',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ),
                      ).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Add button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lend,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        '📖  Add to My Recipe Box →',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrvTag extends StatelessWidget {
  final String label;
  final Color color;
  const _PrvTag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, fontFamily: 'Nunito'),
    ),
  );
}

// ── Recipe Detail Sheet ───────────────────────────────────────────────────────

class RecipeDetailSheet extends StatelessWidget {
  final RecipeModel recipe;
  final void Function(MealEntry)? onLogMeal;
  final void Function(GroceryItem)? onAddToBasket;
  final VoidCallback? onEdit;

  const RecipeDetailSheet({
    super.key,
    required this.recipe,
    this.onLogMeal,
    this.onAddToBasket,
    this.onEdit,
  });

  static Future<void> show(
    BuildContext context,
    RecipeModel recipe, {
    void Function(MealEntry)? onLogMeal,
    void Function(GroceryItem)? onAddToBasket,
    VoidCallback? onEdit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecipeDetailSheet(
        recipe: recipe,
        onLogMeal: onLogMeal,
        onAddToBasket: onAddToBasket,
        onEdit: onEdit,
      ),
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
                      if (onEdit != null)
                        IconButton(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_rounded),
                          color: AppColors.lend,
                          tooltip: 'Edit Recipe',
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
                  const SizedBox(height: 20),

                  // ── Action buttons ───────────────────────────────────────────
                  _RecipeActions(
                    recipe: recipe,
                    onLogMeal: onLogMeal,
                    onAddToBasket: onAddToBasket,
                  ),

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

// ── Recipe action buttons ─────────────────────────────────────────────────────

class _RecipeActions extends StatefulWidget {
  final RecipeModel recipe;
  final void Function(MealEntry)? onLogMeal;
  final void Function(GroceryItem)? onAddToBasket;

  const _RecipeActions({
    required this.recipe,
    this.onLogMeal,
    this.onAddToBasket,
  });

  @override
  State<_RecipeActions> createState() => _RecipeActionsState();
}

class _RecipeActionsState extends State<_RecipeActions> {
  MealTime _selectedTime = MealTime.lunch;
  bool _basketAdded = false;

  void _logMeal() {
    if (widget.onLogMeal == null) return;
    widget.onLogMeal!(
      MealEntry(
        id: 'meal_${DateTime.now().millisecondsSinceEpoch}',
        name: widget.recipe.name,
        mealTime: _selectedTime,
        date: DateTime.now(),
        walletId: 'personal',
        recipeId: widget.recipe.id,
        emoji: widget.recipe.emoji,
      ),
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.recipe.emoji} ${widget.recipe.name} logged as ${_selectedTime.label}!',
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.income,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addAllToBasket() {
    if (widget.onAddToBasket == null) return;
    for (final ing in widget.recipe.ingredients) {
      // Parse "Chicken 500g" → name="Chicken", qty=500, unit="g"
      final parts = ing.trim().split(RegExp(r'\s+'));
      final name = parts.first;
      double qty = 1;
      String unit = 'pcs';
      if (parts.length > 1) {
        final raw = parts.sublist(1).join(' ');
        final m = RegExp(r'([\d.]+)\s*(\w+)?').firstMatch(raw);
        if (m != null) {
          qty = double.tryParse(m.group(1) ?? '1') ?? 1;
          unit = m.group(2) ?? 'pcs';
        }
      }
      widget.onAddToBasket!(
        GroceryItem(
          id: 'g_${widget.recipe.id}_${ing.hashCode}',
          name: name,
          category: GroceryCategory.other,
          quantity: qty,
          unit: unit,
          walletId: 'personal',
          toBuy: true,
          inStock: false,
        ),
      );
    }
    setState(() => _basketAdded = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.recipe.ingredients.length} ingredients added to basket 🧺',
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.expense,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Log as Meal ──────────────────────────────────────────────────────
        if (widget.onLogMeal != null) ...[
          const _SectionTitle(title: '🗺️  Log as Meal'),
          const SizedBox(height: 10),

          // Meal time selector
          Row(
            children: MealTime.values.map((mt) {
              final sel = mt == _selectedTime;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTime = mt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? mt.color : mt.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(mt.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 2),
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
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logMeal,
              icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
              label: Text(
                'Log as ${_selectedTime.label} Today →',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  fontFamily: 'Nunito',
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedTime.color,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: _selectedTime.color.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Add ingredients to basket ────────────────────────────────────────
        if (widget.onAddToBasket != null &&
            widget.recipe.ingredients.isNotEmpty) ...[
          const _SectionTitle(title: '🧺  Add to Basket'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.recipe.ingredients.length} ingredients will be added to your shopping list',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _basketAdded ? null : _addAllToBasket,
                    icon: Icon(
                      _basketAdded
                          ? Icons.check_circle_rounded
                          : Icons.add_shopping_cart_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _basketAdded
                          ? 'Added to Basket ✓'
                          : 'Add All Ingredients →',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _basketAdded
                          ? AppColors.income
                          : AppColors.expense,
                      foregroundColor: Colors.white,
                      elevation: _basketAdded ? 0 : 3,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
