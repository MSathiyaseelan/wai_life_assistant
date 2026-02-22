import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/widgets/family_switcher_sheet.dart';
import 'package:wai_life_assistant/features/pantry/wigets/meal_map_section.dart';
import 'package:wai_life_assistant/features/pantry/wigets/recipe_box_section.dart';
import 'package:wai_life_assistant/features/pantry/wigets/shopping_basket_section.dart';
import 'package:wai_life_assistant/features/pantry/wigets/week_calendar_strip.dart';
import 'package:wai_life_assistant/features/pantry/sheets/add_meal_sheet.dart';
import 'package:wai_life_assistant/features/pantry/sheets/add_recipe_sheet.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});
  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  DateTime _selectedDate = DateTime.now();
  String _activeWalletId = 'personal';
  late TabController _sectionTab; // 0=MealMap, 1=RecipeBox, 2=Basket

  // Live data (starts with mock)
  final List<MealEntry> _meals = List.from(mockMeals);
  final List<RecipeModel> _recipes = List.from(mockRecipes);
  final List<GroceryItem> _groceries = List.from(mockGroceries);

  // Derived
  List<WalletModel> get _allWallets => [personalWallet, ...familyWallets];
  WalletModel get _currentWallet => _allWallets.firstWhere(
    (w) => w.id == _activeWalletId,
    orElse: () => personalWallet,
  );

  List<MealEntry> get _todayMeals {
    final now = DateTime.now();
    return _meals
        .where(
          (m) =>
              m.walletId == _activeWalletId &&
              m.date.year == now.year &&
              m.date.month == now.month &&
              m.date.day == now.day,
        )
        .toList()
      ..sort((a, b) => a.mealTime.index.compareTo(b.mealTime.index));
  }

  // Stats helpers
  int get _mealsThisWeek {
    final weekStart = _mondayOf(_selectedDate);
    final weekEnd = weekStart.add(const Duration(days: 7));
    return _meals
        .where(
          (m) =>
              m.walletId == _activeWalletId &&
              m.date.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
              m.date.isBefore(weekEnd),
        )
        .length;
  }

  int get _toBuyCount =>
      _groceries.where((g) => g.walletId == _activeWalletId && g.toBuy).length;

  int get _favRecipes => _recipes.where((r) => r.isFavourite).length;

  DateTime _mondayOf(DateTime d) {
    final diff = d.weekday - 1;
    return DateTime(d.year, d.month, d.day - diff);
  }

  @override
  void initState() {
    super.initState();
    _sectionTab = TabController(length: 3, vsync: this);
    _sectionTab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sectionTab.dispose();
    super.dispose();
  }

  // ── Wallet switch ──────────────────────────────────────────────────────────
  void _switchWallet(String id) => setState(() => _activeWalletId = id);

  // ── Meal handlers ──────────────────────────────────────────────────────────
  void _addMeal(MealEntry m) => setState(() => _meals.add(m));
  void _showMealDetail(MealEntry m) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _showHandleSheet(
      context,
      isDark: isDark,
      child: _MealDetailSheet(
        meal: m,
        isDark: isDark,
        onDelete: () {
          setState(() => _meals.remove(m));
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Recipe handlers ────────────────────────────────────────────────────────
  void _addRecipe(RecipeModel r) => setState(() => _recipes.add(r));
  void _toggleFav(RecipeModel r) =>
      setState(() => r.isFavourite = !r.isFavourite);
  void _showRecipeDetail(RecipeModel r) => RecipeDetailSheet.show(context, r);

  // ── Grocery handlers ───────────────────────────────────────────────────────
  void _toggleBuy(GroceryItem i) => setState(() => i.toBuy = !i.toBuy);
  void _toggleStock(GroceryItem i) => setState(() => i.inStock = !i.inStock);
  void _addGrocery(GroceryItem i) => setState(() => _groceries.add(i));
  void _deleteGrocery(GroceryItem i) => setState(() => _groceries.remove(i));

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          // ── Sliver AppBar ────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            expandedHeight: 0,
            backgroundColor: cardBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: _buildAppBarTitle(isDark, textColor),
            actions: [_buildWalletSwitcher(isDark)],
          ),

          // ── Week calendar (pinned below appbar) ──────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedDelegate(
              minH: 114,
              maxH: 114,
              child: Container(
                color: cardBg,
                child: Column(
                  children: [
                    WeekCalendarStrip(
                      selectedDate: _selectedDate,
                      onDateSelected: (d) => setState(() => _selectedDate = d),
                    ),
                    // thin divider
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.06),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Stats row ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildStatsRow(isDark, cardBg, subColor, textColor),
          ),

          // ── Section tab bar (pinned) ─────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedDelegate(
              minH: 56,
              maxH: 56,
              child: _buildSectionTabBar(isDark, surfBg),
            ),
          ),
        ],

        body: TabBarView(
          controller: _sectionTab,
          children: [
            // ── TAB 0: Meal Map ───────────────────────────────────────────
            _buildMealMapTab(isDark),
            // ── TAB 1: Recipe Box ─────────────────────────────────────────
            _buildRecipeBoxTab(isDark),
            // ── TAB 2: Shopping Basket ────────────────────────────────────
            _buildBasketTab(isDark),
          ],
        ),
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButton: _buildFAB(isDark),
    );
  }

  // ── AppBar title ──────────────────────────────────────────────────────────
  Widget _buildAppBarTitle(bool isDark, Color textColor) {
    return Row(
      children: [
        const Text('🥗', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pantry',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: textColor,
              ),
            ),
            Text(
              'Meal Map · Recipe Box · Basket',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFamily: 'Nunito',
                color: isDark ? AppColors.subDark : AppColors.subLight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Wallet switcher (same as Wallet tab) ──────────────────────────────────
  Widget _buildWalletSwitcher(bool isDark) {
    return GestureDetector(
      onTap: () => FamilySwitcherSheet.show(
        context,
        currentWalletId: _activeWalletId,
        onSelect: _switchWallet,
      ),
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _currentWallet.gradient),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_currentWallet.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 5),
            Text(
              _currentWallet.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow(bool isDark, Color cardBg, Color sub, Color text) {
    return Container(
      color: cardBg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          _StatPill(
            emoji: '🗓️',
            value: '$_mealsThisWeek',
            label: 'Meals\nThis Week',
            color: AppColors.income,
          ),
          const SizedBox(width: 10),
          _StatPill(
            emoji: '📖',
            value: '$_favRecipes',
            label: 'Fav\nRecipes',
            color: AppColors.lend,
          ),
          const SizedBox(width: 10),
          _StatPill(
            emoji: '🛒',
            value: '$_toBuyCount',
            label: 'Items\nTo Buy',
            color: AppColors.expense,
            onTap: () => _sectionTab.animateTo(2),
          ),
        ],
      ),
    );
  }

  // ── Section tab bar ───────────────────────────────────────────────────────
  Widget _buildSectionTabBar(bool isDark, Color surfBg) {
    const labels = [
      ('🗺️', 'Meal Map'),
      ('📖', 'Recipe Box'),
      ('🧺', 'Basket'),
    ];
    return Container(
      color: isDark ? AppColors.bgDark : AppColors.bgLight,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: surfBg,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(4),
        child: TabBar(
          controller: _sectionTab,
          isScrollable: false,
          indicator: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _tabColor(_sectionTab.index),
                _tabColor(_sectionTab.index).withOpacity(0.75),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            fontFamily: 'Nunito',
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
            fontFamily: 'Nunito',
          ),
          padding: EdgeInsets.zero,
          tabs: labels
              .map(
                (l) => Tab(
                  height: 36,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.$1, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(l.$2),
                      ],
                    ),
                  ),
                ),
                // (l) => Tab(
                //   height: 36,
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.center,
                //     children: [
                //       Text(l.$1, style: const TextStyle(fontSize: 14)),
                //       const SizedBox(width: 5),
                //       Text(l.$2),
                //     ],
                //   ),
                // ),
              )
              .toList(),
        ),
      ),
    );
  }

  Color _tabColor(int i) {
    switch (i) {
      case 0:
        return AppColors.income;
      case 1:
        return AppColors.lend;
      default:
        return AppColors.expense;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB BODIES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMealMapTab(bool isDark) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Today's Plate ──────────────────────────────────────────────────
        TodaysPlateSection(
          todayMeals: _todayMeals,
          walletId: _activeWalletId,
          isDark: isDark,
          onMealTapped: _showMealDetail,
          onAddMeal: () => AddMealSheet.show(
            context,
            date: DateTime.now(),
            walletId: _activeWalletId,
            onSave: _addMeal,
          ),
        ),

        _SectionDivider(isDark: isDark),

        // ── Meal Map (weekly horizontal scroll) ────────────────────────────
        MealMapSection(
          meals: _meals,
          selectedDate: _selectedDate,
          walletId: _activeWalletId,
          onMealAdded: _addMeal,
          onMealTapped: _showMealDetail,
        ),

        const SizedBox(height: 100), // FAB clearance
      ],
    );
  }

  Widget _buildRecipeBoxTab(bool isDark) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        RecipeBoxSection(
          recipes: _recipes,
          onRecipeTapped: _showRecipeDetail,
          onToggleFavourite: _toggleFav,
          onRecipeAdded: _addRecipe,
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildBasketTab(bool isDark) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ShoppingBasketSection(
          items: _groceries,
          walletId: _activeWalletId,
          onItemToggleBuy: _toggleBuy,
          onItemToggleStock: _toggleStock,
          onItemAdded: _addGrocery,
          onItemDeleted: _deleteGrocery,
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  // ── FAB (context-aware) ───────────────────────────────────────────────────
  Widget _buildFAB(bool isDark) {
    final tab = _sectionTab.index;
    final (label, icon, color) = switch (tab) {
      0 => ('Add Meal', Icons.restaurant_menu_rounded, AppColors.income),
      1 => ('Add Recipe', Icons.menu_book_rounded, AppColors.lend),
      _ => ('Add Item', Icons.add_shopping_cart_rounded, AppColors.expense),
    };

    return FloatingActionButton.extended(
      onPressed: () => _onFabTap(tab),
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 6,
      extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          fontFamily: 'Nunito',
        ),
      ),
    );
  }

  void _onFabTap(int tab) {
    HapticFeedback.mediumImpact();
    switch (tab) {
      case 0:
        AddMealSheet.show(
          context,
          date: _selectedDate,
          walletId: _activeWalletId,
          onSave: _addMeal,
        );
      case 1:
        AddRecipeSheet.show(context, onSave: _addRecipe);
      case 2:
        _showAddGrocerySheet(context);
    }
  }

  void _showAddGrocerySheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: 'pcs');
    GroceryCategory cat = GroceryCategory.other;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  Row(
                    children: [
                      const Text('🛒', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      const Text(
                        'Add to Basket',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Item name
                  _inputField(nameCtrl, 'Item name', surfBg, tc, sub),
                  const SizedBox(height: 10),

                  // Qty + unit row
                  Row(
                    children: [
                      Expanded(
                        child: _inputField(
                          qtyCtrl,
                          'Qty',
                          surfBg,
                          tc,
                          sub,
                          inputType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _inputField(
                          unitCtrl,
                          'Unit (kg/g/pcs)',
                          surfBg,
                          tc,
                          sub,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Category chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: GroceryCategory.values.map((c) {
                      final sel = c == cat;
                      return GestureDetector(
                        onTap: () => setSt(() => cat = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.expense.withOpacity(0.15)
                                : surfBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: sel
                                  ? AppColors.expense
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '${c.emoji} ${c.label}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: sel ? AppColors.expense : sub,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Save
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        _addGrocery(
                          GroceryItem(
                            id: DateTime.now().millisecondsSinceEpoch
                                .toString(),
                            name: name,
                            category: cat,
                            quantity: double.tryParse(qtyCtrl.text) ?? 1,
                            unit: unitCtrl.text.trim().isEmpty
                                ? 'pcs'
                                : unitCtrl.text.trim(),
                            walletId: _activeWalletId,
                            inStock: false,
                            toBuy: true,
                          ),
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '$name added to basket!',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            backgroundColor: AppColors.expense,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            margin: const EdgeInsets.all(16),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.expense,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.expense.withOpacity(0.4),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Add to Basket →',
                        style: TextStyle(
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
        },
      ),
    );
  }

  Widget _inputField(
    TextEditingController ctrl,
    String hint,
    Color surfBg,
    Color tc,
    Color sub, {
    TextInputType? inputType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: inputType ?? TextInputType.text,
        textCapitalization: TextCapitalization.words,
        style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: sub, fontFamily: 'Nunito'),
        ),
      ),
    );
  }

  // ── Generic bottom sheet helper with handle ───────────────────────────────
  void _showHandleSheet(
    BuildContext context, {
    required bool isDark,
    required Widget child,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEAL DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _MealDetailSheet extends StatelessWidget {
  final MealEntry meal;
  final bool isDark;
  final VoidCallback onDelete;

  const _MealDetailSheet({
    required this.meal,
    required this.isDark,
    required this.onDelete,
  });

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final c = meal.mealTime.color;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji + name
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(meal.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${meal.mealTime.emoji} ${meal.mealTime.label}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: c,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_months[meal.date.month - 1]} ${meal.date.day}',
                          style: TextStyle(
                            fontSize: 12,
                            color: sub,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text(
                    'Delete',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.expense,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  final VoidCallback? onTap;

  const _StatPill({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'DM Mono',
                  color: color,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Nunito',
                  color: color.withOpacity(0.75),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final bool isDark;
  const _SectionDivider({required this.isDark});
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIVER DELEGATE
// ─────────────────────────────────────────────────────────────────────────────

class _PinnedDelegate extends SliverPersistentHeaderDelegate {
  final double minH, maxH;
  final Widget child;
  const _PinnedDelegate({
    required this.minH,
    required this.maxH,
    required this.child,
  });
  @override
  double get minExtent => minH;
  @override
  double get maxExtent => maxH;
  @override
  Widget build(_, __, ___) => child;
  @override
  bool shouldRebuild(covariant _PinnedDelegate o) =>
      o.child != child || o.minH != minH || o.maxH != maxH;
}

// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'weeklymealplanner.dart';
// import 'package:wai_life_assistant/core/theme/app_text.dart';
// import 'bottomsheet/showpantrybottomsheet.dart';

// class PantryScreen extends StatefulWidget {
//   const PantryScreen({super.key});

//   @override
//   State<PantryScreen> createState() => _PantryScreenState();
// }

// class _PantryScreenState extends State<PantryScreen> {
//   DateTime _selectedDate = DateTime.now();

//   @override
//   Widget build(BuildContext context) {
//     final textTheme = Theme.of(context).textTheme;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(AppText.pantryTitle),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.more_vert),
//             onPressed: () {
//               showPantryBottomSheet(context);
//             },
//           ),
//         ],
//       ),

//       //resizeToAvoidBottomInset: true,
//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           /// 1️⃣ Calendar
//           _WeeklyCalendar(
//             selectedDate: _selectedDate,
//             onDateSelected: (d) {
//               setState(() => _selectedDate = d);
//             },
//           ),

//           const SizedBox(height: 10),

//           Text(
//             'Upcoming Food Planner',
//             style: textTheme.titleMedium,
//             textAlign: TextAlign.left,
//           ),

//           const SizedBox(height: 10),

//           /// 2️⃣ Weekly planner (compact)
//           //Expanded(child: WeeklyMealPlanner(selectedDate: _selectedDate)),
//           SizedBox(
//             height: 160,
//             child: WeeklyMealPlanner(selectedDate: _selectedDate),
//           ),

//           //const Divider(),

//           /// 3️⃣ Today's detail
//           //Expanded(child: _TodayMealDetail(date: _selectedDate)),
//           Expanded(
//             child: AnimatedPadding(
//               duration: const Duration(milliseconds: 250),
//               curve: Curves.easeOut,
//               padding: EdgeInsets.only(
//                 bottom:
//                     MediaQuery.of(context).viewInsets.bottom +
//                     MediaQuery.of(context).padding.bottom,
//               ),
//               child: _TodayMealDetail(date: _selectedDate),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _WeeklyCalendar extends StatelessWidget {
//   final DateTime selectedDate;
//   final ValueChanged<DateTime> onDateSelected;

//   const _WeeklyCalendar({
//     required this.selectedDate,
//     required this.onDateSelected,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final weekStart = _startOfWeek(selectedDate);
//     final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

//     return Row(
//       children: [
//         /// ⬅ Previous week
//         IconButton(
//           icon: const Icon(Icons.chevron_left),
//           onPressed: () {
//             onDateSelected(selectedDate.subtract(const Duration(days: 7)));
//           },
//         ),

//         /// Days (FIXED)
//         Expanded(
//           child: Row(
//             children: days.map((day) {
//               final isSelected = _isSameDay(day, selectedDate);

//               return Expanded(
//                 child: GestureDetector(
//                   onTap: () => onDateSelected(day),
//                   child: Container(
//                     margin: const EdgeInsets.symmetric(horizontal: 2),
//                     padding: const EdgeInsets.symmetric(vertical: 6),
//                     decoration: BoxDecoration(
//                       color: isSelected
//                           ? Theme.of(context).colorScheme.primary
//                           : Colors.transparent,
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         /// Day name
//                         Text(
//                           DateFormat('EEE').format(day),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: TextStyle(
//                             fontSize: 11,
//                             color: isSelected
//                                 ? Colors.white
//                                 : Theme.of(
//                                     context,
//                                   ).colorScheme.onSurfaceVariant,
//                           ),
//                         ),

//                         const SizedBox(height: 4),

//                         /// Date
//                         Text(
//                           day.day.toString(),
//                           style: TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w600,
//                             color: isSelected
//                                 ? Colors.white
//                                 : Theme.of(context).colorScheme.onSurface,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//         ),

//         /// ➡ Next week
//         IconButton(
//           icon: const Icon(Icons.chevron_right),
//           onPressed: () {
//             onDateSelected(selectedDate.add(const Duration(days: 7)));
//           },
//         ),
//       ],
//     );
//   }

//   DateTime _startOfWeek(DateTime date) {
//     return date.subtract(Duration(days: date.weekday - 1));
//   }

//   bool _isSameDay(DateTime a, DateTime b) {
//     return a.year == b.year && a.month == b.month && a.day == b.day;
//   }
// }

// class _WeeklyMealPlanner extends StatelessWidget {
//   final DateTime selectedDate;
//   final ValueChanged<DateTime> onDayTap;

//   const _WeeklyMealPlanner({
//     required this.selectedDate,
//     required this.onDayTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return ListView.separated(
//       padding: const EdgeInsets.all(12),
//       scrollDirection: Axis.horizontal,
//       itemCount: 7,
//       separatorBuilder: (_, __) => const SizedBox(width: 8),
//       itemBuilder: (context, index) {
//         final day = DateTime.now().add(Duration(days: index));

//         return GestureDetector(
//           onTap: () => onDayTap(day),
//           child: Container(
//             width: 130,
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(16),
//               color: day.day == selectedDate.day
//                   ? Theme.of(context).colorScheme.primaryContainer
//                   : Theme.of(context).colorScheme.surface,
//               boxShadow: const [
//                 BoxShadow(blurRadius: 4, color: Colors.black12),
//               ],
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: const [
//                 Text('Mon', style: TextStyle(fontWeight: FontWeight.bold)),
//                 SizedBox(height: 6),
//                 Text('B: Idli'),
//                 Text('L: Rice'),
//                 Text('D: Chapati'),
//                 Text('S: Fruits'),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// class _TodayMealDetail extends StatefulWidget {
//   final DateTime date;

//   const _TodayMealDetail({required this.date});

//   @override
//   State<_TodayMealDetail> createState() => _TodayMealDetailState();
// }

// class _TodayMealDetailState extends State<_TodayMealDetail> {
//   late Map<String, String> meals;

//   @override
//   void initState() {
//     super.initState();
//     meals = {
//       'Breakfast': 'Idli & Chutney',
//       'Lunch': 'Sambar Rice',
//       'Snacks': 'Tea & Fruits',
//       'Dinner': 'Chapati & Kurma',
//     };
//   }

//   @override
//   Widget build(BuildContext context) {
//     final textTheme = Theme.of(context).textTheme;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // 🔒 Sticky header
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
//           child: Text('Today\'s Meals', style: textTheme.titleMedium),
//         ),

//         Expanded(
//           child: ListView(
//             padding: const EdgeInsets.all(4),
//             children: meals.entries.map((entry) {
//               return GestureDetector(
//                 onTap: () => _editMeal(entry.key, entry.value),
//                 child: _MealSection(title: entry.key, value: entry.value),
//               );
//             }).toList(),
//           ),
//         ),
//       ],
//     );
//   }

//   void _editMeal(String mealType, String currentValue) {
//     final controller = TextEditingController(text: currentValue);

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (_) {
//         return Padding(
//           padding: EdgeInsets.fromLTRB(
//             16,
//             16,
//             16,
//             MediaQuery.of(context).viewInsets.bottom + 16,
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Edit $mealType',
//                 style: Theme.of(context).textTheme.titleMedium,
//               ),

//               const SizedBox(height: 12),

//               TextField(
//                 controller: controller,
//                 decoration: const InputDecoration(
//                   hintText: 'Enter meal details',
//                   border: OutlineInputBorder(),
//                 ),
//               ),

//               const SizedBox(height: 16),

//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     setState(() {
//                       meals[mealType] = controller.text;
//                     });
//                     Navigator.pop(context);
//                   },
//                   child: const Text('Save'),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

// class _MealSection extends StatelessWidget {
//   final String title;
//   final String value;

//   const _MealSection({required this.title, required this.value});

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 12),
//       child: ListTile(
//         title: Text(title),
//         subtitle: Text(value),
//         trailing: const Icon(Icons.edit),
//       ),
//     );
//   }
// }
