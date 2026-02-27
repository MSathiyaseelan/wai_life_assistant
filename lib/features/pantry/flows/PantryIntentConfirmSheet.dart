import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import 'pantry_nlp_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTRY INTENT CONFIRM SHEET
// Shown after NLP parses typed/spoken text.
// Pre-fills editable fields for Meal / Recipe / Basket, user confirms or
// taps "Full Form" to open the original detailed sheet.
// ─────────────────────────────────────────────────────────────────────────────

class PantryIntentConfirmSheet extends StatefulWidget {
  final PantryIntent intent;
  final String walletId;
  final void Function(MealEntry) onSaveMeal;
  final void Function(RecipeModel) onSaveRecipe;
  final void Function(GroceryItem) onSaveBasket;
  final VoidCallback onOpenMealForm;
  final VoidCallback onOpenRecipeForm;
  final VoidCallback onOpenBasketForm;

  const PantryIntentConfirmSheet({
    super.key,
    required this.intent,
    required this.walletId,
    required this.onSaveMeal,
    required this.onSaveRecipe,
    required this.onSaveBasket,
    required this.onOpenMealForm,
    required this.onOpenRecipeForm,
    required this.onOpenBasketForm,
  });

  static Future<void> show(
    BuildContext context, {
    required PantryIntent intent,
    required String walletId,
    required void Function(MealEntry) onSaveMeal,
    required void Function(RecipeModel) onSaveRecipe,
    required void Function(GroceryItem) onSaveBasket,
    required VoidCallback onOpenMealForm,
    required VoidCallback onOpenRecipeForm,
    required VoidCallback onOpenBasketForm,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PantryIntentConfirmSheet(
        intent: intent,
        walletId: walletId,
        onSaveMeal: onSaveMeal,
        onSaveRecipe: onSaveRecipe,
        onSaveBasket: onSaveBasket,
        onOpenMealForm: onOpenMealForm,
        onOpenRecipeForm: onOpenRecipeForm,
        onOpenBasketForm: onOpenBasketForm,
      ),
    );
  }

  @override
  State<PantryIntentConfirmSheet> createState() =>
      _PantryIntentConfirmSheetState();
}

class _PantryIntentConfirmSheetState extends State<PantryIntentConfirmSheet> {
  // Meal
  late TextEditingController _mealNameCtrl;
  late MealTime _mealTime;
  late DateTime _mealDate;
  String _mealEmoji = '🍽️';

  // Recipe
  late TextEditingController _recipeNameCtrl;

  // Basket
  late TextEditingController _itemNameCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _unitCtrl;
  late GroceryCategory _groceryCat;

  static const _mealEmojis = [
    '🍽️',
    '🍚',
    '🫙',
    '🍛',
    '🥘',
    '🫕',
    '🍲',
    '🥗',
    '🍜',
    '🥞',
    '🫓',
    '🥟',
    '🍱',
    '🥙',
    '🌮',
    '☕',
    '🧃',
    '🥤',
    '🍗',
    '🥚',
  ];

  @override
  void initState() {
    super.initState();
    final i = widget.intent;
    _mealNameCtrl = TextEditingController(text: i.mealName ?? '');
    _mealTime = i.mealTime ?? MealTime.lunch;
    _mealDate = i.mealDate ?? DateTime.now();
    _recipeNameCtrl = TextEditingController(text: i.recipeName ?? '');
    _itemNameCtrl = TextEditingController(text: i.groceryName ?? '');
    _qtyCtrl = TextEditingController(
      text: i.qty != null
          ? i.qty! == i.qty!.truncateToDouble()
                ? i.qty!.toInt().toString()
                : i.qty!.toString()
          : '1',
    );
    _unitCtrl = TextEditingController(text: i.unit ?? 'pcs');
    _groceryCat = i.groceryCat ?? GroceryCategory.other;
  }

  @override
  void dispose() {
    _mealNameCtrl.dispose();
    _recipeNameCtrl.dispose();
    _itemNameCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.intent.kind) {
      case PantryIntentKind.meal:
        return AppColors.income;
      case PantryIntentKind.recipe:
        return AppColors.lend;
      case PantryIntentKind.basket:
        return AppColors.expense;
    }
  }

  String get _kindEmoji {
    switch (widget.intent.kind) {
      case PantryIntentKind.meal:
        return '🗺️';
      case PantryIntentKind.recipe:
        return '📖';
      case PantryIntentKind.basket:
        return '🧺';
    }
  }

  String get _kindLabel {
    switch (widget.intent.kind) {
      case PantryIntentKind.meal:
        return 'Meal Map';
      case PantryIntentKind.recipe:
        return 'Recipe Box';
      case PantryIntentKind.basket:
        return 'Basket';
    }
  }

  VoidCallback get _fullForm {
    switch (widget.intent.kind) {
      case PantryIntentKind.meal:
        return widget.onOpenMealForm;
      case PantryIntentKind.recipe:
        return widget.onOpenRecipeForm;
      case PantryIntentKind.basket:
        return widget.onOpenBasketForm;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final color = _color;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
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
                const SizedBox(height: 16),

                // Header banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Text(_kindEmoji, style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Looks like a ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _kindLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Nunito',
                                      color: color,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' entry',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Review & confirm below',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color: sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Kind-specific fields
                if (widget.intent.kind == PantryIntentKind.meal)
                  _buildMealFields(surfBg, tc, sub, isDark, color)
                else if (widget.intent.kind == PantryIntentKind.recipe)
                  _buildRecipeFields(surfBg, tc, sub)
                else
                  _buildBasketFields(surfBg, tc, sub),

                const SizedBox(height: 22),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _fullForm();
                        },
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text(
                          'Full Form',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: sub,
                          side: BorderSide(color: sub.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          'Save to $_kindLabel',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            fontSize: 14,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── MEAL ───────────────────────────────────────────────────────────────────
  Widget _buildMealFields(
    Color surfBg,
    Color tc,
    Color sub,
    bool isDark,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SLabel('MEAL NAME', sub),
        Row(
          children: [
            GestureDetector(
              onTap: () => _pickEmoji(isDark, surfBg),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                alignment: Alignment.center,
                child: Text(_mealEmoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SField(
                ctrl: _mealNameCtrl,
                hint: 'e.g. Idli Sambar',
                surfBg: surfBg,
                tc: tc,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _SLabel('MEAL TIME', sub),
        Row(
          children: MealTime.values.map((mt) {
            final last = mt == MealTime.dinner;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: last ? 0 : 8),
                child: GestureDetector(
                  onTap: () => setState(() => _mealTime = mt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _mealTime == mt
                          ? mt.color.withOpacity(0.12)
                          : surfBg,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: _mealTime == mt ? mt.color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(mt.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 3),
                        Text(
                          mt.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: _mealTime == mt ? mt.color : sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        _SLabel('DATE', sub),
        Row(
          children: _dateOpts.map((opt) {
            final sel = _sameDay(_mealDate, opt.$2);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _mealDate = opt.$2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? color.withOpacity(0.12) : surfBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    opt.$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: sel ? color : sub,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<(String, DateTime)> get _dateOpts {
    final now = DateTime.now();
    return [
      ('Yesterday', now.subtract(const Duration(days: 1))),
      ('Today', now),
      ('Tomorrow', now.add(const Duration(days: 1))),
    ];
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _pickEmoji(bool isDark, Color surfBg) {
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pick emoji',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _mealEmojis
                  .map(
                    (e) => GestureDetector(
                      onTap: () {
                        setState(() => _mealEmoji = e);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _mealEmoji == e
                              ? AppColors.income.withOpacity(0.15)
                              : surfBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _mealEmoji == e
                                ? AppColors.income
                                : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── RECIPE ─────────────────────────────────────────────────────────────────
  Widget _buildRecipeFields(Color surfBg, Color tc, Color sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SLabel('RECIPE NAME', sub),
        _SField(
          ctrl: _recipeNameCtrl,
          hint: 'e.g. Butter Chicken',
          surfBg: surfBg,
          tc: tc,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.lend.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lend.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Text('📝', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'A basic recipe will be created. Tap "Full Form" '
                  'to add ingredients, cuisine type and cook time.',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    color: AppColors.lend,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── BASKET ─────────────────────────────────────────────────────────────────
  Widget _buildBasketFields(Color surfBg, Color tc, Color sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SLabel('ITEM NAME', sub),
        _SField(
          ctrl: _itemNameCtrl,
          hint: 'e.g. Onions',
          surfBg: surfBg,
          tc: tc,
        ),
        const SizedBox(height: 12),

        _SLabel('QUANTITY & UNIT', sub),
        Row(
          children: [
            SizedBox(
              width: 90,
              child: _SField(
                ctrl: _qtyCtrl,
                hint: '1',
                surfBg: surfBg,
                tc: tc,
                inputType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: _SField(
                ctrl: _unitCtrl,
                hint: 'pcs / kg / L',
                surfBg: surfBg,
                tc: tc,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _SLabel('CATEGORY', sub),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: GroceryCategory.values.map((cat) {
            final sel = cat == _groceryCat;
            return GestureDetector(
              onTap: () => setState(() => _groceryCat = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: sel ? AppColors.expense.withOpacity(0.12) : surfBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? AppColors.expense : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '${cat.emoji} ${cat.label}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                    color: sel ? AppColors.expense : sub,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  void _save() {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    switch (widget.intent.kind) {
      case PantryIntentKind.meal:
        final name = _mealNameCtrl.text.trim();
        if (name.isEmpty) return;
        widget.onSaveMeal(
          MealEntry(
            id: now.millisecondsSinceEpoch.toString(),
            name: name,
            mealTime: _mealTime,
            date: _mealDate,
            walletId: widget.walletId,
            emoji: _mealEmoji,
          ),
        );
      case PantryIntentKind.recipe:
        final name = _recipeNameCtrl.text.trim();
        if (name.isEmpty) return;
        widget.onSaveRecipe(
          RecipeModel(
            id: now.millisecondsSinceEpoch.toString(),
            name: name,
            emoji: '🍽️',
            cuisine: CuisineType.indian,
            suitableFor: [MealTime.lunch, MealTime.dinner],
            ingredients: [],
          ),
        );
      case PantryIntentKind.basket:
        final name = _itemNameCtrl.text.trim();
        if (name.isEmpty) return;
        widget.onSaveBasket(
          GroceryItem(
            id: now.millisecondsSinceEpoch.toString(),
            name: name,
            category: _groceryCat,
            quantity: double.tryParse(_qtyCtrl.text) ?? 1,
            unit: _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim(),
            walletId: widget.walletId,
            inStock: false,
            toBuy: true,
          ),
        );
    }
    Navigator.pop(context);
  }
}

// ── Private shared widgets (prefixed to avoid conflicts) ─────────────────────

class _SLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SLabel(this.text, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        fontFamily: 'Nunito',
        color: color,
      ),
    ),
  );
}

class _SField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final Color surfBg, tc;
  final TextInputType? inputType;
  const _SField({
    required this.ctrl,
    required this.hint,
    required this.surfBg,
    required this.tc,
    this.inputType,
  });
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: inputType,
    style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: tc),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 12,
        color: AppColors.subLight,
      ),
      filled: true,
      fillColor: surfBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
