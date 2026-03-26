import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';

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

class _AddMealSheetState extends State<AddMealSheet> {
  final _nameCtrl = TextEditingController();
  MealTime _mealTime = MealTime.lunch;
  String _emoji = '🍛';
  String? _selectedRecipeId;

  /// Set when user taps an already-occupied meal time slot (pre-fill mode).
  MealEntry? _prefilledExisting;

  bool get _isEdit => widget.existing != null || _prefilledExisting != null;

  // Recipes sorted: matching meal time first, then others
  List<RecipeModel> get _sortedRecipes {
    final matched = widget.recipes.where((r) => r.suitableFor.contains(_mealTime)).toList();
    final rest = widget.recipes.where((r) => !r.suitableFor.contains(_mealTime)).toList();
    return [...matched, ...rest];
  }

  /// Returns the existing meal for [mt] in dayMeals, if any.
  MealEntry? _slotMeal(MealTime mt) =>
      widget.dayMeals.where((m) => m.mealTime == mt).firstOrNull;

  void _pickRecipe(RecipeModel r) {
    setState(() {
      _selectedRecipeId = r.id;
      _nameCtrl.text = r.name;
      _emoji = r.emoji;
    });
  }

  void _clearRecipe() {
    setState(() {
      _selectedRecipeId = null;
      _nameCtrl.clear();
      _emoji = '🍛';
    });
  }

  // Indian-food-relevant emoji palette
  final _emojis = const [
    '🍛', // Curry / biryani
    '🫓', // Chapati / roti
    '🥘', // Sabzi / dry curry
    '🍲', // Dal / stew
    '🫕', // Khichdi / one-pot
    '🍚', // Plain rice
    '🥗', // Salad / raita
    '🍽️', // Generic plate
    '☕', // Chai
    '🧋', // Lassi / shake
    '🍜', // Maggi / noodles
    '🫙', // Pickle / chutney
    '🥟', // Samosa
    '🫔', // Kathi roll / wrap
    '🍱', // Tiffin box
    '🥞', // Dosa / uttapam
    '🥛', // Milk / chaas
    '🌶️', // Spicy / chilli
  ];

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _mealTime = widget.existing!.mealTime;
      _emoji = widget.existing!.emoji;
      _selectedRecipeId = widget.existing!.recipeId;
    } else {
      // Auto-select the first unoccupied meal slot for the day
      final occupiedTimes = widget.dayMeals.map((m) => m.mealTime).toSet();
      final firstEmpty = MealTime.values
          .where((mt) => !occupiedTimes.contains(mt))
          .firstOrNull;
      if (firstEmpty != null) _mealTime = firstEmpty;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String get _dateLabel {
    final now = DateTime.now();
    final diff = widget.date
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    final wd = widget.date.weekday - 1;
    return '${_weekDays[wd]}, ${_months[widget.date.month - 1]} ${widget.date.day}';
  }

  void _onMealTimeTap(MealTime mt) {
    final slotMeal = _slotMeal(mt);
    setState(() {
      _mealTime = mt;
      if (slotMeal != null) {
        // Slot occupied — pre-fill with the existing meal for editing
        _prefilledExisting = slotMeal;
        _nameCtrl.text = slotMeal.name;
        _emoji = slotMeal.emoji;
        _selectedRecipeId = slotMeal.recipeId;
      } else if (_prefilledExisting != null) {
        // Switching from an occupied slot to an empty one — clear pre-fill
        _prefilledExisting = null;
        _nameCtrl.clear();
        _emoji = '🍛';
        _selectedRecipeId = null;
      }
      // Switching between two empty slots — keep whatever user has typed
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    if (widget.existing != null) {
      // Explicit edit mode (opened from meal detail sheet)
      widget.onUpdate!(
        widget.existing!.copyWith(
          name: name,
          mealTime: _mealTime,
          emoji: _emoji,
          recipeId: _selectedRecipeId,
        ),
      );
    } else if (_prefilledExisting != null && widget.onUpdate != null) {
      // Pre-fill mode — update the pre-existing meal in that slot
      widget.onUpdate!(
        _prefilledExisting!.copyWith(
          name: name,
          mealTime: _mealTime,
          emoji: _emoji,
          recipeId: _selectedRecipeId,
        ),
      );
    } else {
      // New meal
      widget.onSave(
        MealEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          mealTime: _mealTime,
          date: widget.date,
          walletId: widget.walletId,
          emoji: _emoji,
          recipeId: _selectedRecipeId,
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Row(
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
            const SizedBox(height: 16),

            // ── Meal time selector ─────────────────────────────────────────
            Row(
              children: MealTime.values.map((mt) {
                final sel = mt == _mealTime;
                final occupied = _slotMeal(mt) != null && widget.existing == null;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onMealTimeTap(mt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? mt.color : mt.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(2),
                                child: Text(
                                  mt.emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
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
                                          : (isDark ? AppColors.cardDark : AppColors.cardLight),
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
                  if (_selectedRecipeId != null) ...[
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
                    final sel = r.id == _selectedRecipeId;
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
                                // Always show 'suitable for' tags
                                if (r.suitableFor.isNotEmpty)
                                  Text(
                                    r.suitableFor.map((m) => m.label).join(', '),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                controller: _nameCtrl,
                autofocus: true,
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
            const SizedBox(height: 18),

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
      ),
    );
  }
}
