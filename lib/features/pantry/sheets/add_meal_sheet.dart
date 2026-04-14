import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import 'meal_conversation_flow.dart';

class AddMealSheet extends StatefulWidget {
  final DateTime date;
  final String walletId;
  final List<RecipeModel> recipes;
  final void Function(MealEntry) onSave;
  // Edit mode — provide existing meal + onUpdate
  final MealEntry? existing;
  final void Function(MealEntry)? onUpdate;
  // Meals already logged for this day — used to pre-fill when slot occupied
  final List<MealEntry> dayMeals;

  const AddMealSheet({
    super.key,
    required this.date,
    required this.walletId,
    required this.recipes,
    required this.onSave,
    this.existing,
    this.onUpdate,
    this.dayMeals = const [],
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime date,
    required String walletId,
    required List<RecipeModel> recipes,
    required void Function(MealEntry) onSave,
    MealEntry? existing,
    void Function(MealEntry)? onUpdate,
    List<MealEntry> dayMeals = const [],
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMealSheet(
        date: date,
        walletId: walletId,
        recipes: recipes,
        onSave: onSave,
        existing: existing,
        onUpdate: onUpdate,
        dayMeals: dayMeals,
      ),
    );
  }

  @override
  State<AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<AddMealSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Manual tab state ────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _ingredientCtrl = TextEditingController();
  MealTime _mealTime = MealTime.lunch;
  String _emoji = '🍛';
  Set<String> _selectedRecipeIds = {};
  final List<String> _ingredients = [];
  late DateTime _selectedDate;

  /// Set when user taps an already-occupied meal time slot (pre-fill mode).
  MealEntry? _prefilledExisting;

  bool get _isEdit => widget.existing != null || _prefilledExisting != null;

  // Recipes sorted: matching meal time first, then others
  List<RecipeModel> get _sortedRecipes {
    final matched =
        widget.recipes.where((r) => r.suitableFor.contains(_mealTime)).toList();
    final rest = widget.recipes
        .where((r) => !r.suitableFor.contains(_mealTime))
        .toList();
    return [...matched, ...rest];
  }

  /// Returns the existing meal for [mt] in dayMeals, if any.
  MealEntry? _slotMeal(MealTime mt) =>
      widget.dayMeals.where((m) => m.mealTime == mt).firstOrNull;

  void _pickRecipe(RecipeModel r) {
    setState(() {
      if (_selectedRecipeIds.contains(r.id)) {
        // ── Deselect: remove this recipe's name from the field (best-effort) ──
        _selectedRecipeIds.remove(r.id);
        var text = _nameCtrl.text;
        if (text.contains(' + ${r.name}')) {
          text = text.replaceFirst(' + ${r.name}', '');
        } else if (text.startsWith('${r.name} + ')) {
          text = text.replaceFirst('${r.name} + ', '');
        } else if (text == r.name) {
          text = '';
        }
        _nameCtrl.text = text.trim();
        if (_selectedRecipeIds.isEmpty) {
          _emoji = '🍛';
        } else {
          _emoji = _sortedRecipes
              .firstWhere((rec) => _selectedRecipeIds.contains(rec.id))
              .emoji;
        }
      } else {
        // ── Select: append this recipe's name to whatever is in the field ──
        _selectedRecipeIds.add(r.id);
        final current = _nameCtrl.text.trim();
        _nameCtrl.text = current.isEmpty ? r.name : '$current + ${r.name}';
        if (_selectedRecipeIds.length == 1) _emoji = r.emoji;
      }
    });
  }

  void _clearRecipe() {
    setState(() {
      _selectedRecipeIds.clear();
      _nameCtrl.clear();
      _emoji = '🍛';
    });
  }

  // Indian-food-relevant emoji palette
  final _emojis = const [
    '🍛', '🫓', '🥘', '🍲', '🫕', '🍚', '🥗', '🍽️',
    '☕', '🧋', '🍜', '🫙', '🥟', '🫔', '🍱', '🥞', '🥛', '🌶️',
  ];

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    // Edit mode → open directly on Manual tab (index 1); add mode → Chat tab (index 0)
    _selectedDate = widget.date;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.existing != null ? 1 : 0,
    );
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _mealTime = widget.existing!.mealTime;
      _emoji = widget.existing!.emoji;
      _selectedRecipeIds = widget.existing!.recipeIds.toSet();
      _ingredients.addAll(widget.existing!.ingredients);
    } else {
      // Auto-select the first unoccupied meal slot for the day.
      // If all slots are occupied, keep the default and pre-fill it.
      final occupiedTimes = widget.dayMeals.map((m) => m.mealTime).toSet();
      final firstEmpty = MealTime.values
          .where((mt) => !occupiedTimes.contains(mt))
          .firstOrNull;
      if (firstEmpty != null) {
        _mealTime = firstEmpty;
      }
      // Pre-fill _prefilledExisting for whichever slot is initially selected.
      final slotMeal = _slotMeal(_mealTime);
      if (slotMeal != null) {
        _prefilledExisting = slotMeal;
        _nameCtrl.text = slotMeal.name;
        _emoji = slotMeal.emoji;
        _selectedRecipeIds = slotMeal.recipeIds.toSet();
        _ingredients.addAll(slotMeal.ingredients);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _ingredientCtrl.dispose();
    super.dispose();
  }

  // ── Manual tab helpers ──────────────────────────────────────────────────────

  void _addIngredient() {
    final val = _ingredientCtrl.text.trim();
    if (val.isEmpty) return;
    setState(() => _ingredients.add(val));
    _ingredientCtrl.clear();
  }

  String get _dateLabel {
    final now = DateTime.now();
    final diff =
        _selectedDate.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    final wd = _selectedDate.weekday - 1;
    return '${_weekDays[wd]}, ${_months[_selectedDate.month - 1]} ${_selectedDate.day}';
  }

  void _onMealTimeTap(MealTime mt) {
    final slotMeal = _slotMeal(mt);
    setState(() {
      _mealTime = mt;
      if (slotMeal != null) {
        _prefilledExisting = slotMeal;
        _nameCtrl.text = slotMeal.name;
        _emoji = slotMeal.emoji;
        _selectedRecipeIds = slotMeal.recipeIds.toSet();
      } else if (_prefilledExisting != null) {
        _prefilledExisting = null;
        _nameCtrl.clear();
        _emoji = '🍛';
        _selectedRecipeIds = {};
      }
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final ingredients =
        _selectedRecipeIds.isEmpty ? List<String>.from(_ingredients) : <String>[];
    final recipeIds = _selectedRecipeIds.toList();

    if (widget.existing != null) {
      widget.onUpdate!(
        widget.existing!.copyWith(
          name: name,
          mealTime: _mealTime,
          emoji: _emoji,
          recipeIds: recipeIds,
          ingredients: ingredients,
        ),
      );
    } else if (_prefilledExisting != null && widget.onUpdate != null) {
      widget.onUpdate!(
        _prefilledExisting!.copyWith(
          name: name,
          mealTime: _mealTime,
          emoji: _emoji,
          recipeIds: recipeIds,
          ingredients: ingredients,
        ),
      );
    } else {
      widget.onSave(
        MealEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          mealTime: _mealTime,
          date: _selectedDate,
          walletId: widget.walletId,
          emoji: _emoji,
          recipeIds: recipeIds,
          ingredients: ingredients,
        ),
      );
    }
    Navigator.pop(context);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
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
              margin: const EdgeInsets.only(top: 12, bottom: 14),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('🍽️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? 'Edit Meal' : 'Add Meal',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      Text(
                        _dateLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab bar — only in add mode; edit always goes to manual
            if (widget.existing == null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTabBar(isDark),
              ),
              const SizedBox(height: 8),
            ],

            // Date picker — visible in both tabs and edit mode
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildDateRow(isDark),
            ),
            const SizedBox(height: 8),

            // Content
            Expanded(
              child: widget.existing != null
                  ? _buildManualTab(context, isDark)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 0: Conversational flow
                        MealConversationFlow(
                          date: _selectedDate,
                          walletId: widget.walletId,
                          recipes: widget.recipes,
                          dayMeals: widget.dayMeals,
                          onSave: widget.onSave,
                          onUpdate: widget.onUpdate,
                          onClose: () => Navigator.pop(context),
                        ),
                        // Tab 1: Manual form
                        _buildManualTab(context, isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfDark : const Color(0xFFEDEEF5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(11),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor:
            isDark ? AppColors.subDark : AppColors.subLight,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          fontFamily: 'Nunito',
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
        ),
        tabs: const [
          Tab(text: '💬  Chat'),
          Tab(text: '✏️  Manual'),
        ],
      ),
    );
  }

  // ── Date picker button ───────────────────────────────────────────────────────

  Widget _buildDateRow(bool isDark) {
    final surfBg = isDark ? AppColors.surfDark : AppColors.bgLight;
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: surfBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 14, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(
              _dateLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.expand_more_rounded,
                size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // ── Manual Tab ──────────────────────────────────────────────────────────────

  Widget _buildManualTab(BuildContext context, bool isDark) {
    final surfBg = isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Meal time selector ─────────────────────────────────────────
          Row(
            children: MealTime.values.map((mt) {
              final sel = mt == _mealTime;
              final occupied =
                  _slotMeal(mt) != null && widget.existing == null;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onMealTimeTap(mt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel
                          ? mt.color
                          : mt.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(2),
                              child: Text(mt.emoji,
                                  style: const TextStyle(fontSize: 18)),
                            ),
                            if (occupied)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: sel ? Colors.white : mt.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: sel
                                        ? mt.color
                                        : (isDark
                                            ? AppColors.cardDark
                                            : AppColors.cardLight),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          mt.label,
                          style: TextStyle(
                            fontSize: 10,
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
          const SizedBox(height: 14),

          // ── Recipe picker ──────────────────────────────────────────────
          if (widget.recipes.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  '📖  From Recipe Box',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: isDark ? AppColors.subDark : AppColors.subLight,
                  ),
                ),
                if (_selectedRecipeIds.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedRecipeIds.length} selected',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _clearRecipe,
                    child: const Text(
                      '✕ Clear',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _sortedRecipes.length,
                itemBuilder: (_, i) {
                  final r = _sortedRecipes[i];
                  final sel = _selectedRecipeIds.contains(r.id);
                  return GestureDetector(
                    onTap: () => _pickRecipe(r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : surfBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: sel
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(r.emoji,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                r.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Nunito',
                                  color: sel ? AppColors.primary : tc,
                                ),
                              ),
                              if (r.suitableFor.isNotEmpty)
                                Text(
                                  r.suitableFor
                                      .map((m) => m.label)
                                      .join(', '),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontFamily: 'Nunito',
                                    color: isDark
                                        ? AppColors.subDark
                                        : AppColors.subLight,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
          ],

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
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : surfBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? AppColors.primary : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Name field
          Container(
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(16),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _nameCtrl,
              autofocus: widget.existing != null,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(fontSize: 15, color: tc, fontFamily: 'Nunito'),
              decoration: InputDecoration.collapsed(
                hintText: 'Meal name (e.g. Idli & Sambar)',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.subDark : AppColors.subLight,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Ingredients (manual meals only) ───────────────────────────
          if (_selectedRecipeIds.isEmpty) ...[
            Row(
              children: [
                Text(
                  '🥕  Ingredients',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: isDark ? AppColors.subDark : AppColors.subLight,
                  ),
                ),
                Text(
                  '  optional',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Nunito',
                    color:
                        (isDark ? AppColors.subDark : AppColors.subLight)
                            .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_ingredients.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _ingredients.asMap().entries.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e.value,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _ingredients.removeAt(e.key)),
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: AppColors.primary),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: TextField(
                      controller: _ingredientCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(
                          fontSize: 13, color: tc, fontFamily: 'Nunito'),
                      onSubmitted: (_) => _addIngredient(),
                      decoration: InputDecoration.collapsed(
                        hintText: 'e.g. Tomato, Rice 2 cups…',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Nunito',
                          color: isDark
                              ? AppColors.subDark
                              : AppColors.subLight,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addIngredient,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          const SizedBox(height: 14),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _mealTime.color,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: _mealTime.color.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _isEdit
                    ? 'Update ${_mealTime.label} Meal →'
                    : 'Save ${_mealTime.label} Meal →',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
