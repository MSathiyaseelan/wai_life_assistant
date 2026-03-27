import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/supabase/profile_service.dart';
import 'package:wai_life_assistant/core/supabase/pantry_service.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/widgets/family_switcher_sheet.dart';
import 'package:wai_life_assistant/core/widgets/wallet_switcher_pill.dart';
import 'package:wai_life_assistant/features/wallet/widgets/chat_input_bar.dart';
import 'package:wai_life_assistant/features/pantry/widgets/meal_map_section.dart';
import 'package:wai_life_assistant/features/pantry/widgets/family_food_prefs_card.dart';
import 'package:wai_life_assistant/features/pantry/widgets/recipe_box_section.dart';
import 'package:wai_life_assistant/features/pantry/widgets/shopping_basket_section.dart';
import 'package:wai_life_assistant/features/pantry/widgets/week_calendar_strip.dart';
import 'package:wai_life_assistant/features/pantry/sheets/add_meal_sheet.dart';
import 'package:wai_life_assistant/features/pantry/sheets/add_recipe_sheet.dart';
import 'package:wai_life_assistant/features/pantry/flows/pantry_nlp_parser.dart';
import 'package:wai_life_assistant/features/pantry/flows/pantry_flow_selector.dart';
import 'package:wai_life_assistant/features/pantry/flows/PantryIntentConfirmSheet.dart';
import 'package:wai_life_assistant/features/AppStateNotifier.dart';

class PantryScreen extends StatefulWidget {
  final String activeWalletId;
  final void Function(String) onWalletChange;
  const PantryScreen({
    super.key,
    required this.activeWalletId,
    required this.onWalletChange,
  });
  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  DateTime _selectedDate = DateTime.now();
  late TabController _sectionTab; // 0=MealMap, 1=Basket, 2=RecipeBox

  // Chat bar — mic + NLP
  bool _isListening = false;
  final _chatBarKey = GlobalKey<ChatInputBarState>();

  // Meal Map — loaded from DB
  List<MealEntry> _meals = [];
  bool _mealsLoading = true;

  // Logged-in user display name
  String _currentUserName = '';

  // Meal map clipboard
  List<MealEntry>? _clipboardMeals;
  String _clipboardLabel = '';
  bool _clipboardIsWeek = false;
  DateTime? _clipboardSourceWeekStart;
  List<RecipeModel> _recipes = [];
  bool _recipesLoading = true;
  List<GroceryItem> _groceries = [];
  bool _groceriesLoading = true;
  List<MemberFoodPrefs> _foodPrefs = [];

  // ── Family food prefs ────────────────────────────────────────────────────────
  List<PantryMember> get _currentMembers {
    if (widget.activeWalletId == 'personal') {
      return const [PantryMember(id: 'me', name: 'Me', emoji: '🧑')];
    }
    return const [
      PantryMember(id: 'me', name: 'Me', emoji: '🧑'),
      PantryMember(id: 'dad', name: 'Dad', emoji: '👨'),
      PantryMember(id: 'mom', name: 'Mom', emoji: '👩'),
      PantryMember(id: 'son', name: 'Arjun', emoji: '👦'),
      PantryMember(id: 'dau', name: 'Priya', emoji: '👧'),
    ];
  }

  Future<void> _saveFoodPrefs(MemberFoodPrefs updated) async {
    // Optimistic update
    setState(() {
      final idx = _foodPrefs.indexWhere((p) => p.memberId == updated.memberId);
      if (idx >= 0) {
        _foodPrefs[idx] = updated;
      } else {
        _foodPrefs.add(updated);
      }
    });
    try {
      final row = await PantryService.instance.upsertFoodPrefs(
        walletId: widget.activeWalletId,
        memberId: updated.memberId,
        memberName: updated.memberName,
        memberEmoji: updated.memberEmoji,
        allergies: updated.allergies,
        likes: updated.likes,
        dislikes: updated.dislikes,
        mandatoryFoods: updated.mandatoryFoods,
      );
      if (!mounted) return;
      final saved = MemberFoodPrefs.fromMap(row);
      setState(() {
        final idx = _foodPrefs.indexWhere((p) => p.memberId == saved.memberId);
        if (idx >= 0) _foodPrefs[idx] = saved;
      });
    } catch (e) {
      if (!mounted) return;
      _showSavedSnack('Failed to save food preferences', AppColors.expense);
      _loadFoodPrefs(); // reload to restore consistent state
    }
  }

  // Derived — read from AppStateScope so real Supabase wallet IDs resolve correctly
  WalletModel get _currentWallet => AppStateScope.of(context).activeWallet;

  // ── Meal map clipboard ─────────────────────────────────────────────────────

  void _copyMeal(MealEntry m) {
    setState(() {
      _clipboardMeals = [m];
      _clipboardLabel = '${m.emoji} ${m.name}';
      _clipboardIsWeek = false;
      _clipboardSourceWeekStart = null;
    });
    _showCopiedSnack('Copied: ${m.name}');
  }

  void _copyDay(DateTime day) {
    final meals = _meals.where((m) =>
        m.walletId == widget.activeWalletId &&
        m.date.year == day.year &&
        m.date.month == day.month &&
        m.date.day == day.day).toList();
    if (meals.isEmpty) { _showCopiedSnack('No meals on this day to copy'); return; }
    setState(() {
      _clipboardMeals = meals;
      _clipboardLabel = '${_shortDay(day)} (${meals.length} meal${meals.length == 1 ? '' : 's'})';
      _clipboardIsWeek = false;
      _clipboardSourceWeekStart = null;
    });
    _showCopiedSnack('Copied ${meals.length} meal${meals.length == 1 ? '' : 's'} from ${_shortDay(day)}');
  }

  void _copyWeek(DateTime weekStart) {
    // Normalise to midnight so isBefore/isAfter comparisons are day-accurate
    final mon = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final sun = mon.add(const Duration(days: 7)); // exclusive upper bound
    final meals = _meals.where((m) =>
        m.walletId == widget.activeWalletId &&
        !m.date.isBefore(mon) &&
        m.date.isBefore(sun)).toList();
    if (meals.isEmpty) { _showCopiedSnack('No meals this week to copy'); return; }
    setState(() {
      _clipboardMeals = meals;
      _clipboardLabel = 'Week (${meals.length} meal${meals.length == 1 ? '' : 's'})';
      _clipboardIsWeek = true;
      _clipboardSourceWeekStart = mon; // always store as midnight
    });
    _showCopiedSnack('Copied ${meals.length} meal${meals.length == 1 ? '' : 's'} from this week');
  }

  Future<void> _pasteToDay(DateTime targetDay) async {
    final clips = _clipboardMeals;
    if (clips == null || clips.isEmpty) return;
    final existing = _meals.where((m) =>
        m.walletId == widget.activeWalletId &&
        m.date.year == targetDay.year &&
        m.date.month == targetDay.month &&
        m.date.day == targetDay.day).toList();
    final toInsert = clips
        .where((m) => !existing.any((e) => e.name == m.name && e.mealTime == m.mealTime))
        .toList();
    if (toInsert.isEmpty) { _showCopiedSnack('Already exists on this day'); return; }

    final targetDate = DateTime(targetDay.year, targetDay.month, targetDay.day);
    // Optimistic add with temp IDs
    final temps = toInsert.map((m) => MealEntry(
      id: 'cp_${DateTime.now().microsecondsSinceEpoch}_${m.id}',
      name: m.name, mealTime: m.mealTime, date: targetDate,
      walletId: widget.activeWalletId, emoji: m.emoji, note: m.note, recipeId: m.recipeId,
    )).toList();
    setState(() => _meals.addAll(temps));
    _showCopiedSnack('Pasted ${temps.length} meal${temps.length == 1 ? '' : 's'} to ${_shortDay(targetDay)}');

    try {
      for (int i = 0; i < toInsert.length; i++) {
        final m = toInsert[i];
        final row = await PantryService.instance.addMealEntry(
          walletId: widget.activeWalletId,
          name: m.name, emoji: m.emoji, mealTime: m.mealTime.name,
          date: targetDate, recipeId: m.recipeId, note: m.note,
        );
        if (!mounted) return;
        final saved = MealEntry.fromMap(row);
        setState(() {
          final idx = _meals.indexWhere((e) => e.id == temps[i].id);
          if (idx >= 0) _meals[idx] = saved;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showSavedSnack('Failed to paste some meals', AppColors.expense);
      await _loadMeals(); // reload to get consistent state
    }
  }

  Future<void> _pasteToWeek(DateTime targetWeekStart) async {
    final clips = _clipboardMeals;
    final srcStart = _clipboardSourceWeekStart;
    if (clips == null || clips.isEmpty || srcStart == null) return;

    final srcMon = DateTime(srcStart.year, srcStart.month, srcStart.day);
    final targetMon = DateTime(targetWeekStart.year, targetWeekStart.month, targetWeekStart.day);

    final toInsert = <({MealEntry meal, DateTime targetDate})>[];
    for (final m in clips) {
      final mealDay = DateTime(m.date.year, m.date.month, m.date.day);
      final offset = mealDay.difference(srcMon).inDays.clamp(0, 6);
      final td = targetMon.add(Duration(days: offset));
      if (_meals.any((e) =>
          e.walletId == widget.activeWalletId &&
          e.name == m.name && e.mealTime == m.mealTime &&
          e.date.year == td.year && e.date.month == td.month && e.date.day == td.day)) {
        continue;
      }
      toInsert.add((meal: m, targetDate: td));
    }
    if (toInsert.isEmpty) { _showCopiedSnack('All meals already exist in this week'); return; }

    // Optimistic
    final temps = toInsert.map((item) => MealEntry(
      id: 'cp_${DateTime.now().microsecondsSinceEpoch}_${item.meal.id}',
      name: item.meal.name, mealTime: item.meal.mealTime, date: item.targetDate,
      walletId: widget.activeWalletId, emoji: item.meal.emoji,
      note: item.meal.note, recipeId: item.meal.recipeId,
    )).toList();
    setState(() => _meals.addAll(temps));
    _showCopiedSnack('Pasted ${temps.length} meal${temps.length == 1 ? '' : 's'} into this week');

    try {
      for (int i = 0; i < toInsert.length; i++) {
        final item = toInsert[i];
        final row = await PantryService.instance.addMealEntry(
          walletId: widget.activeWalletId,
          name: item.meal.name, emoji: item.meal.emoji,
          mealTime: item.meal.mealTime.name, date: item.targetDate,
          recipeId: item.meal.recipeId, note: item.meal.note,
        );
        if (!mounted) return;
        final saved = MealEntry.fromMap(row);
        setState(() {
          final idx = _meals.indexWhere((e) => e.id == temps[i].id);
          if (idx >= 0) _meals[idx] = saved;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showSavedSnack('Failed to paste some meals', AppColors.expense);
      await _loadMeals();
    }
  }

  String _shortDay(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]} ${d.day}';
  }

  void _clearClipboard() {
    setState(() {
      _clipboardMeals = null;
      _clipboardLabel = '';
      _clipboardIsWeek = false;
      _clipboardSourceWeekStart = null;
    });
  }

  void _showCopiedSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  void initState() {
    super.initState();
    _sectionTab = TabController(length: 3, vsync: this);
    _sectionTab.addListener(() => setState(() {}));
    _fetchUserName();
    _loadMeals();
    _loadRecipes();
    _loadGroceries();
    _loadFoodPrefs();
  }

  @override
  void didUpdateWidget(PantryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeWalletId != widget.activeWalletId) {
      _clearClipboard();
      _loadMeals();
      _loadRecipes();
      _loadGroceries();
      _loadFoodPrefs();
    }
  }

  Future<void> _loadRecipes() async {
    if (!mounted || widget.activeWalletId.isEmpty) return;
    setState(() => _recipesLoading = true);
    try {
      final rows = await PantryService.instance.fetchRecipes(widget.activeWalletId);
      if (!mounted) return;
      setState(() {
        _recipes = rows.map(RecipeModel.fromMap).toList();
        _recipesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _recipesLoading = false);
      _showSavedSnack('Failed to load recipes', AppColors.expense);
    }
  }

  Future<void> _loadMeals() async {
    if (!mounted || widget.activeWalletId.isEmpty) return;
    setState(() => _mealsLoading = true);
    try {
      final rows = await PantryService.instance.fetchMealEntries(widget.activeWalletId);
      if (!mounted) return;
      setState(() {
        _meals = rows.map(MealEntry.fromMap).toList();
        _mealsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _mealsLoading = false);
      _showSavedSnack('Failed to load meals', AppColors.expense);
    }
  }

  Future<void> _loadFoodPrefs() async {
    if (!mounted || widget.activeWalletId.isEmpty) return;
    try {
      final rows = await PantryService.instance.fetchFoodPrefs(widget.activeWalletId);
      if (!mounted) return;
      setState(() {
        _foodPrefs = rows.map(MemberFoodPrefs.fromMap).toList();
      });
    } catch (_) {} // non-critical — card shows empty state gracefully
  }

  Future<void> _loadGroceries() async {
    if (!mounted || widget.activeWalletId.isEmpty) return;
    setState(() => _groceriesLoading = true);
    try {
      final rows = await PantryService.instance.fetchGroceryItems(widget.activeWalletId);
      if (!mounted) return;
      setState(() {
        _groceries = rows.map(GroceryItem.fromMap).toList();
        _groceriesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _groceriesLoading = false);
      _showSavedSnack('Failed to load basket', AppColors.expense);
    }
  }

  Future<void> _fetchUserName() async {
    try {
      final profile = await ProfileService.instance.fetchProfile();
      if (profile != null) {
        final name = (profile['name'] as String? ?? '').trim();
        if (name.isNotEmpty && mounted) {
          setState(() => _currentUserName = name);
          return;
        }
      }
    } catch (_) {}
    // Fallback: use auth metadata name, or email prefix
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && mounted) {
        final metaName =
            (user.userMetadata?['full_name'] as String? ?? '').trim();
        final emailPrefix = (user.email ?? '').split('@').first;
        final fallback = metaName.isNotEmpty ? metaName : emailPrefix;
        if (fallback.isNotEmpty) setState(() => _currentUserName = fallback);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _sectionTab.dispose();
    super.dispose();
  }

  // ── Wallet switch ──────────────────────────────────────────────────────────
  void _switchWallet(String id) => widget.onWalletChange(id);

  // ── Mic toggle — simulates STT, fills bar with transcribed text ────────────
  void _onMicTap() {
    HapticFeedback.mediumImpact();
    if (_isListening) {
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      // Simulate STT — replace with speech_to_text plugin callback in production
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted || !_isListening) return;
        setState(() => _isListening = false);
        // Sample phrases that STT would return, context-aware per active tab
        final samples = switch (_sectionTab.index) {
          0 => [
            'had idli sambar for breakfast today',
            'paneer butter masala for dinner',
            'add dal rice lunch tomorrow',
            'masala chai evening snack',
          ],
          1 => [
            'save butter chicken recipe',
            'add pasta recipe',
            'recipe for rasam',
          ],
          _ => [
            'add milk 2 litre',
            'buy onions 1 kg',
            'need 3 eggs',
            'add tomatoes vegetables',
            'get bread 1 packet',
          ],
        };
        final sample = (samples..shuffle()).first;
        _chatBarKey.currentState?.setTextFromSpeech(sample);
      });
    }
  }

  // ── NLP submit — parse text, show confirm sheet or fall back to form ────────
  void _onChatSubmit(String text) {
    final intent = PantryNlpParser.parse(text);
    if (intent.confidence >= 0.4) {
      // Auto-switch to the matching tab
      final targetTab = switch (intent.kind) {
        PantryIntentKind.meal => 0,
        PantryIntentKind.recipe => 1,
        PantryIntentKind.basket => 2,
      };
      if (_sectionTab.index != targetTab) _sectionTab.animateTo(targetTab);

      PantryIntentConfirmSheet.show(
        context,
        intent: intent,
        walletId: widget.activeWalletId,
        onSaveMeal: (m) {
          _addMeal(m);
          _showSavedSnack('Meal logged! 🗺️', AppColors.income);
        },
        onSaveRecipe: (r) {
          _addRecipe(r);
          _showSavedSnack('Recipe saved! 📖', AppColors.lend);
        },
        onSaveBasket: (g) {
          _addGrocery(g);
          _showSavedSnack('Added to basket! 🧺', AppColors.expense);
        },
        onOpenMealForm: () => AddMealSheet.show(
          context,
          date: _selectedDate,
          walletId: widget.activeWalletId,
          recipes: _recipes,
          onSave: _addMeal,
          onUpdate: _updateMeal,
          dayMeals: _mealsForDate(_selectedDate),
        ),
        onOpenRecipeForm: () =>
            AddRecipeSheet.show(context, onSave: _addRecipe),
        onOpenBasketForm: () => _showAddGrocerySheet(context),
      );
    } else {
      // Low confidence — open the contextual form for the active tab
      _onFabTap(_sectionTab.index);
    }
  }

  void _showSavedSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Open flow selector (+ button) ─────────────────────────────────────────
  void _openFlowSelector() {
    PantryFlowSelector.show(
      context,
      onMeal: () {
        _sectionTab.animateTo(0);
        AddMealSheet.show(
          context,
          date: _selectedDate,
          walletId: widget.activeWalletId,
          recipes: _recipes,
          onSave: _addMeal,
          onUpdate: _updateMeal,
          dayMeals: _mealsForDate(_selectedDate),
        );
      },
      onRecipe: () {
        _sectionTab.animateTo(1);
        AddRecipeSheet.show(context, onSave: _addRecipe);
      },
      onBasket: () {
        _sectionTab.animateTo(2);
        _showAddGrocerySheet(context);
      },
    );
  }

  // ── Meal handlers ──────────────────────────────────────────────────────────

  List<MealEntry> _mealsForDate(DateTime date) => _meals
      .where((m) =>
          m.walletId == widget.activeWalletId &&
          m.date.year == date.year &&
          m.date.month == date.month &&
          m.date.day == date.day)
      .toList();

  // Adds a meal: optimistic insert → persist to DB → replace with real UUID row.
  Future<void> _addMeal(MealEntry m) async {
    setState(() => _meals.add(m)); // optimistic
    try {
      final row = await PantryService.instance.addMealEntry(
        walletId: m.walletId,
        name: m.name,
        emoji: m.emoji,
        mealTime: m.mealTime.name,
        date: m.date,
        recipeId: m.recipeId,
        note: m.note,
        ingredients: m.ingredients,
      );
      if (!mounted) return;
      final saved = MealEntry.fromMap(row);
      setState(() {
        final idx = _meals.indexWhere((e) => e.id == m.id);
        if (idx >= 0) _meals[idx] = saved;
      });
      PantryService.mealChangeSignal.value++;
      // Ingredient analysis — for recipe-linked meals or manually-entered ingredients
      if ((m.recipeId != null || m.ingredients.isNotEmpty) && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _analyzeIngredients(m));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _meals.remove(m));
      _showSavedSnack('Failed to save meal', AppColors.expense);
    }
  }

  Future<void> _updateMeal(MealEntry updated) async {
    final original = _meals.firstWhere(
      (e) => e.id == updated.id,
      orElse: () => updated,
    );
    setState(() {
      final idx = _meals.indexWhere((e) => e.id == updated.id);
      if (idx >= 0) _meals[idx] = updated;
    });
    try {
      await PantryService.instance.updateMealEntry(updated.id, {
        'name': updated.name,
        'emoji': updated.emoji,
        'meal_time': updated.mealTime.name,
        'date':
            '${updated.date.year}-${updated.date.month.toString().padLeft(2, '0')}-${updated.date.day.toString().padLeft(2, '0')}',
        'recipe_id': updated.recipeId,
        'note': updated.note,
        'ingredients': updated.ingredients,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final idx = _meals.indexWhere((e) => e.id == updated.id);
        if (idx >= 0) _meals[idx] = original;
      });
      _showSavedSnack('Failed to update meal', AppColors.expense);
    }
  }

  // ── Meal status / stock handlers ──────────────────────────────────────────

  Future<void> _updateMealStatus(
    MealEntry m,
    MealStatus status,
    int servingsCount,
  ) async {
    final original = m;
    setState(() {
      final idx = _meals.indexWhere((e) => e.id == m.id);
      if (idx >= 0) {
        _meals[idx] = _meals[idx].copyWith(
          mealStatus: status,
          servingsCount: servingsCount,
        );
      }
    });
    try {
      await PantryService.instance.updateMealStatus(
        m.id,
        status: status.name,
        servingsCount: servingsCount,
      );
      if (status == MealStatus.cooked && m.recipeId != null) {
        await _reduceStockForMeal(m.recipeId!);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final idx = _meals.indexWhere((e) => e.id == original.id);
        if (idx >= 0) _meals[idx] = original;
      });
      _showSavedSnack('Failed to update status', AppColors.expense);
    }
  }

  /// Extract the core ingredient name from strings like "2 cups basmati rice" → "basmati rice".
  String _extractIngredientName(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'^\s*[\d./]+\s*(cups?|tbsp|tsp|g|kg|ml|l|pcs|pieces?|medium|large|small)?\s*[-–:,]?\s*'), '')
        .replaceAll(RegExp(r'\s*[-–(,].*$'), '')
        .trim();
  }

  /// When a meal is cooked, reduce in-stock quantities for matching groceries.
  Future<void> _reduceStockForMeal(String recipeId) async {
    final rIdx = _recipes.indexWhere((r) => r.id == recipeId);
    if (rIdx < 0) return;
    final recipe = _recipes[rIdx];
    bool changed = false;

    for (final ingredient in recipe.ingredients) {
      final name = _extractIngredientName(ingredient);
      if (name.isEmpty) continue;

      final gIdx = _groceries.indexWhere((g) =>
          g.inStock &&
          (g.name.toLowerCase().contains(name) ||
              name.contains(g.name.toLowerCase())));
      if (gIdx < 0) continue;

      final item = _groceries[gIdx];
      final newQty = item.quantity - 1;
      final Map<String, dynamic> updates = {};

      if (newQty <= 0) {
        setState(() {
          _groceries[gIdx].inStock = false;
          _groceries[gIdx].toBuy = true;
          _groceries[gIdx].quantity = 0;
        });
        updates['in_stock'] = false;
        updates['to_buy'] = true;
        updates['quantity'] = 0;
      } else {
        setState(() => _groceries[gIdx].quantity = newQty);
        updates['quantity'] = newQty;
      }
      try {
        await PantryService.instance.updateGroceryItem(item.id, updates);
      } catch (_) {}
      changed = true;
    }

    if (changed && mounted) {
      _showSavedSnack('🧺 Basket updated for cooked meal', AppColors.income);
    }
  }

  /// After adding a meal with a recipe, check if ingredients are in stock.
  void _analyzeIngredients(MealEntry m) {
    // Use recipe ingredients when linked, otherwise fall back to manually entered ones
    final List<String> ingredientList;
    final String mealName;
    if (m.recipeId != null) {
      final rIdx = _recipes.indexWhere((r) => r.id == m.recipeId);
      if (rIdx < 0) return;
      ingredientList = _recipes[rIdx].ingredients;
      mealName = _recipes[rIdx].name;
    } else {
      ingredientList = m.ingredients;
      mealName = m.name;
    }
    if (ingredientList.isEmpty) return;

    final stockItems = _groceries
        .where((g) => g.walletId == widget.activeWalletId && g.inStock)
        .toList();
    final toBuyItems = _groceries
        .where((g) => g.walletId == widget.activeWalletId && g.toBuy)
        .toList();

    final missing = <String>[];
    final alreadyInToBuy = <String>[];
    for (final ingredient in ingredientList) {
      final name = _extractIngredientName(ingredient);
      if (name.isEmpty) continue;
      bool matches(GroceryItem g) =>
          g.name.toLowerCase().contains(name) ||
          name.contains(g.name.toLowerCase());
      if (stockItems.any(matches)) continue;
      if (toBuyItems.any(matches)) {
        alreadyInToBuy.add(ingredient);
      } else {
        missing.add(ingredient);
      }
    }

    if (missing.isEmpty && alreadyInToBuy.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _IngredientAnalysisSheet(
        recipeName: mealName,
        missingIngredients: missing,
        alreadyInToBuyIngredients: alreadyInToBuy,
        isDark: isDark,
        onAddToBasket: (items) {
          for (final label in items) {
            final item = GroceryItem(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: label,
              category: GroceryCategory.other,
              quantity: 1,
              unit: 'pcs',
              walletId: widget.activeWalletId,
              inStock: false,
              toBuy: true,
            );
            _addGrocery(item);
          }
          _showSavedSnack('${items.length} item(s) added to To Buy 🛒', AppColors.primary);
        },
      ),
    );
  }

  void _showMealDetail(MealEntry m) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _showHandleSheet(
      context,
      isDark: isDark,
      child: _MealDetailSheet(
        meal: m,
        isDark: isDark,
        currentUserName: _currentUserName,
        onEdit: () {
          Navigator.pop(context);
          AddMealSheet.show(
            context,
            date: m.date,
            walletId: m.walletId,
            recipes: _recipes,
            onSave: _addMeal,
            existing: m,
            onUpdate: _updateMeal,
          );
        },
        onDelete: () async {
          setState(() => _meals.remove(m)); // optimistic
          Navigator.pop(context);
          try {
            await PantryService.instance.deleteMealEntry(m.id);
            PantryService.mealChangeSignal.value++;
          } catch (e) {
            if (!mounted) return;
            setState(() => _meals.add(m)); // revert
            _showSavedSnack('Failed to delete meal', AppColors.expense);
          }
        },
        onReactionAdded: (reaction) async {
          // Optimistic add with temp identity
          setState(() {
            final idx = _meals.indexWhere((e) => e.id == m.id);
            if (idx >= 0) {
              _meals[idx] = _meals[idx].copyWith(
                reactions: [..._meals[idx].reactions, reaction],
              );
            }
          });
          try {
            final row = await PantryService.instance.addReaction(
              mealId: m.id,
              memberName: reaction.memberName,
              reactionEmoji: reaction.reactionEmoji,
              comment: reaction.comment,
              replyTo: reaction.replyTo,
            );
            if (!mounted) return;
            // Replace temp reaction with DB-assigned ID version
            final saved = MealReaction.fromMap(row);
            setState(() {
              final idx = _meals.indexWhere((e) => e.id == m.id);
              if (idx >= 0) {
                final list = List<MealReaction>.from(_meals[idx].reactions);
                final ri = list.lastIndexWhere(
                  (r) => r.id == null &&
                      r.memberName == reaction.memberName &&
                      r.reactionEmoji == reaction.reactionEmoji,
                );
                if (ri >= 0) list[ri] = saved;
                _meals[idx] = _meals[idx].copyWith(reactions: list);
              }
            });
          } catch (e) {
            if (!mounted) return;
            setState(() {
              final idx = _meals.indexWhere((e) => e.id == m.id);
              if (idx >= 0) {
                final list = List<MealReaction>.from(_meals[idx].reactions)
                  ..remove(reaction);
                _meals[idx] = _meals[idx].copyWith(reactions: list);
              }
            });
            _showSavedSnack('Failed to save reaction', AppColors.expense);
          }
        },
        onReactionUpdated: (reactionIndex, updated) async {
          // Read DB id BEFORE setState overwrites the list
          final mealIdx = _meals.indexWhere((e) => e.id == m.id);
          final dbId = mealIdx >= 0 && reactionIndex < _meals[mealIdx].reactions.length
              ? _meals[mealIdx].reactions[reactionIndex].id
              : null;
          setState(() {
            if (mealIdx >= 0) {
              final list = List<MealReaction>.from(_meals[mealIdx].reactions);
              // Preserve the DB id so it isn't lost from the parent's list
              list[reactionIndex] = updated.copyWith(id: dbId ?? updated.id);
              _meals[mealIdx] = _meals[mealIdx].copyWith(reactions: list);
            }
          });
          if (dbId == null) return; // not yet persisted
          try {
            await PantryService.instance.updateReaction(dbId, {
              'member_name': updated.memberName,
              'reaction_emoji': updated.reactionEmoji,
              'comment': updated.comment,
            });
          } catch (_) {
            // Reactions are non-critical; swallow silently
          }
        },
        onReactionDeleted: (reactionIndex) async {
          final mealIdx = _meals.indexWhere((e) => e.id == m.id);
          final dbId = mealIdx >= 0 && reactionIndex < _meals[mealIdx].reactions.length
              ? _meals[mealIdx].reactions[reactionIndex].id
              : null;
          setState(() {
            if (mealIdx >= 0) {
              final list = List<MealReaction>.from(_meals[mealIdx].reactions)
                ..removeAt(reactionIndex);
              _meals[mealIdx] = _meals[mealIdx].copyWith(reactions: list);
            }
          });
          if (dbId == null) return;
          try {
            await PantryService.instance.deleteReaction(dbId);
          } catch (_) {
            // Reactions are non-critical; swallow silently
          }
        },
        onStatusChanged: (status, servingsCount) =>
            _updateMealStatus(m, status, servingsCount),
        onCheckStock: (m.recipeId != null || m.ingredients.isNotEmpty) ? () => _analyzeIngredients(m) : null,
      ),
    );
  }

  // ── Recipe handlers ────────────────────────────────────────────────────────

  Future<void> _addRecipe(RecipeModel r) async {
    setState(() => _recipes.add(r)); // optimistic
    try {
      final row = await PantryService.instance.addRecipe(
        walletId: widget.activeWalletId,
        name: r.name,
        emoji: r.emoji,
        cuisine: r.cuisine.name,
        suitableFor: r.suitableFor.map((t) => t.name).toList(),
        ingredients: r.ingredients,
        socialLink: r.socialLink,
        note: r.note,
        cookTimeMin: r.cookTimeMin,
        isFavourite: r.isFavourite,
        libraryRecipeId: r.libraryRecipeId,
      );
      if (!mounted) return;
      final saved = RecipeModel.fromMap(row);
      setState(() {
        final idx = _recipes.indexWhere((e) => e.id == r.id);
        if (idx >= 0) _recipes[idx] = saved;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _recipes.remove(r));
      _showSavedSnack('Failed to save recipe', AppColors.expense);
    }
  }

  Future<void> _updateRecipe(RecipeModel updated) async {
    final idx = _recipes.indexWhere((r) => r.id == updated.id);
    if (idx < 0) return;
    final old = _recipes[idx];
    setState(() => _recipes[idx] = updated); // optimistic
    try {
      await PantryService.instance.updateRecipe(updated.id, {
        'name': updated.name,
        'emoji': updated.emoji,
        'cuisine': updated.cuisine.name,
        'suitable_for': updated.suitableFor.map((t) => t.name).toList(),
        'ingredients': updated.ingredients,
        'social_link': updated.socialLink,
        'note': updated.note,
        'cook_time_min': updated.cookTimeMin,
        'is_favourite': updated.isFavourite,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _recipes[idx] = old); // revert
      _showSavedSnack('Failed to update recipe', AppColors.expense);
    }
  }

  Future<void> _deleteRecipe(RecipeModel r) async {
    setState(() => _recipes.remove(r));
    try {
      await PantryService.instance.deleteRecipe(r.id);
      _showSavedSnack('Recipe removed from your box', AppColors.subLight);
    } catch (e) {
      if (!mounted) return;
      setState(() => _recipes.add(r));
      _showSavedSnack('Failed to remove recipe', AppColors.expense);
    }
  }

  void _showRecipeDetail(RecipeModel r) => RecipeDetailSheet.show(
    context,
    r,
    groceries: _groceries
        .where((g) => g.walletId == widget.activeWalletId)
        .toList(),
    onAddMissingToBasket: (items) {
      for (final label in items) {
        _addGrocery(GroceryItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: label,
          category: GroceryCategory.other,
          quantity: 1,
          unit: 'pcs',
          walletId: widget.activeWalletId,
          inStock: false,
          toBuy: true,
        ));
      }
      _showSavedSnack('${items.length} item(s) added to 🛒 To Buy', AppColors.primary);
    },
    onEdit: () {
      Navigator.pop(context);
      AddRecipeSheet.show(
        context,
        onSave: _addRecipe,
        existing: r,
        onUpdate: _updateRecipe,
      );
    },
    onLogMeal: (meal) {
      // Resolve correct walletId
      final entry = MealEntry(
        id: meal.id,
        name: meal.name,
        mealTime: meal.mealTime,
        date: meal.date,
        walletId: widget.activeWalletId,
        recipeId: meal.recipeId,
        emoji: meal.emoji,
      );
      _addMeal(entry);
      _sectionTab.animateTo(0);
      _showSavedSnack(
        '${r.emoji} ${r.name} logged as ${meal.mealTime.label}! 🗺️',
        AppColors.income,
      );
    },
    onAddToBasket: (item) {
      _addGrocery(
        GroceryItem(
          id: item.id,
          name: item.name,
          category: item.category,
          quantity: item.quantity,
          unit: item.unit,
          walletId: widget.activeWalletId,
          toBuy: true,
          inStock: false,
        ),
      );
    },
  );

  // ── Grocery handlers ───────────────────────────────────────────────────────
  Future<void> _toggleBuy(GroceryItem i) async {
    final newToBuy = !i.toBuy;
    final updates = <String, dynamic>{'to_buy': newToBuy};
    setState(() {
      i.toBuy = newToBuy;
      if (newToBuy) {
        i.inStock = false;
        updates['in_stock'] = false;
      }
    });
    try {
      await PantryService.instance.updateGroceryItem(i.id, updates);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        i.toBuy = !newToBuy;
        if (newToBuy) i.inStock = true;
      });
      _showSavedSnack('Failed to update item', AppColors.expense);
    }
  }

  void _toggleStock(GroceryItem i) => setState(() => i.inStock = !i.inStock);

  /// Mark a To-Buy item as purchased: move it to In Stock, off the shopping list.
  Future<void> _markBought(GroceryItem i) async {
    setState(() {
      i.inStock = true;
      i.toBuy = false;
    });
    try {
      await PantryService.instance.updateGroceryItem(i.id, {
        'in_stock': true,
        'to_buy': false,
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        i.inStock = false;
        i.toBuy = true;
      });
      _showSavedSnack('Failed to update item', AppColors.expense);
    }
  }

  Future<void> _addGrocery(GroceryItem i) async {
    setState(() => _groceries.add(i)); // optimistic
    try {
      final row = await PantryService.instance.addGroceryItem(
        walletId: widget.activeWalletId,
        name: i.name,
        category: i.category.name,
        quantity: i.quantity,
        unit: i.unit,
        inStock: i.inStock,
        toBuy: i.toBuy,
        expiryDate: i.expiryDate,
        note: i.note,
      );
      if (!mounted) return;
      final saved = GroceryItem.fromMap(row);
      setState(() {
        final idx = _groceries.indexWhere((g) => g.id == i.id);
        if (idx >= 0) _groceries[idx] = saved;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _groceries.remove(i));
      _showSavedSnack('Failed to save item', AppColors.expense);
    }
  }

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
    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      // ── Chat input bar at bottom — replaces FAB as primary entry point ──────
      bottomNavigationBar: ChatInputBar(
        key: _chatBarKey,
        onSubmit: _onChatSubmit,
        onMicTap: _onMicTap,
        onAddTap: _openFlowSelector,
        isListening: _isListening,
        hintText: switch (_sectionTab.index) {
          0 => 'e.g. "had idli sambar for breakfast today"',
          1 => 'e.g. "add chicken biryani recipe"',
          _ => 'e.g. "add 2kg tomatoes to basket"',
        },
      ),
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          // ── Sliver AppBar ────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            expandedHeight: 0,
            backgroundColor: cardBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: 0,
            title: _buildAppBarTitle(isDark, textColor),
            actions: [
              WalletSwitcherPill(
                wallet: _currentWallet,
                onTap: () => FamilySwitcherSheet.show(
                  context,
                  currentWalletId: widget.activeWalletId,
                  onSelect: widget.onWalletChange,
                ),
              ),
            ],
          ),


          // ── Stats row ────────────────────────────────────────────────────
          // SliverToBoxAdapter(
          //   child: _buildStatsRow(isDark, cardBg, subColor, textColor),
          // ),

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
            // ── TAB 2: Basket ─────────────────────────────────────────────
            _buildBasketTab(isDark),
          ],
        ),
      ),

      // ── Context-aware mini FAB (form shortcut per active tab) ─────────────
      //floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ── AppBar title ──────────────────────────────────────────────────────────
  Widget _buildAppBarTitle(bool isDark, Color textColor) {
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;
    return Row(
      children: [
        const Text('🥗', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
              switch (_sectionTab.index) {
                0 => '· Meal Map ·',
                1 => '· Recipe Box ·',
                _ => '· Basket ·',
              },
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFamily: 'Nunito',
                color: subColor,
              ),
            ),
          ],
        ),
      ],
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
                _tabColor(_sectionTab.index).withValues(alpha: 0.75),
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
          tabs: labels.map((l) {
            return Tab(
              height: 36,
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l.$1, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(l.$2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
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
    if (_mealsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.income, strokeWidth: 2),
      );
    }
    return PrimaryScrollController.none(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          WeekCalendarStrip(
            selectedDate: _selectedDate,
            onDateSelected: (d) => setState(() => _selectedDate = d),
          ),
          FamilyFoodPrefsCard(
            members: _currentMembers,
            foodPrefs: _foodPrefs
                .where((p) => p.walletId == widget.activeWalletId)
                .toList(),
            currentUserId: 'me',
            walletId: widget.activeWalletId,
            isAdmin: true,
            onSave: _saveFoodPrefs,
          ),
          _SectionDivider(isDark: isDark),
          MealMapSection(
            meals: _meals,
            recipes: _recipes,
            selectedDate: _selectedDate,
            walletId: widget.activeWalletId,
            onMealAdded: _addMeal,
            onMealUpdated: _updateMeal,
            onMealTapped: _showMealDetail,
            clipboardMeals: _clipboardMeals,
            clipboardLabel: _clipboardLabel,
            clipboardIsWeek: _clipboardIsWeek,
            onCopyMeal: _copyMeal,
            onCopyDay: _copyDay,
            onPasteToDay: _pasteToDay,
            onCopyWeek: _copyWeek,
            onPasteToWeek: _pasteToWeek,
            onClearClipboard: _clearClipboard,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRecipeBoxTab(bool isDark) {
    if (_recipesLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.lend, strokeWidth: 2),
      );
    }
    return PrimaryScrollController.none(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          RecipeBoxSection(
            recipes: _recipes,
            onRecipeTapped: _showRecipeDetail,
            onRecipeAdded: _addRecipe,
            onUntagRecipe: _deleteRecipe,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBasketTab(bool isDark) {
    // Items expiring within 3 days
    final now = DateTime.now();
    final expiring =
        _groceries
            .where((g) {
              if (g.walletId != widget.activeWalletId) return false;
              if (g.expiryDate == null) return false;
              final expiryDay = DateTime(g.expiryDate!.year, g.expiryDate!.month, g.expiryDate!.day);
              final todayDay = DateTime(now.year, now.month, now.day);
              // Only show items that have already expired (strictly before today)
              return expiryDay.isBefore(todayDay);
            })
            .toList()
          ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));

    // Use Column not ListView — ShoppingBasketSection manages its own scrolling
    // via internal ListView inside a fixed/expanded area. A wrapping ListView
    // creates a scroll conflict that causes content to stick.
    return Column(
      children: [
        if (expiring.isNotEmpty) _ExpiryBanner(items: expiring, isDark: isDark),
        Expanded(
          child: ShoppingBasketSection(
            items: _groceries,
            walletId: widget.activeWalletId,
            onItemToggleBuy: _toggleBuy,
            onItemToggleStock: _toggleStock,
            onItemMarkBought: _markBought,
            onItemAdded: _addGrocery,
            onItemDeleted: _deleteGrocery,
          ),
        ),
      ],
    );
  }

  void _onFabTap(int tab) {
    HapticFeedback.mediumImpact();
    switch (tab) {
      case 0:
        AddMealSheet.show(
          context,
          date: _selectedDate,
          walletId: widget.activeWalletId,
          recipes: _recipes,
          onSave: _addMeal,
          onUpdate: _updateMeal,
          dayMeals: _mealsForDate(_selectedDate),
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
    final noteCtrl = TextEditingController();
    GroceryCategory cat = GroceryCategory.other;
    String selectedUnit = 'pieces';
    DateTime? expiryDate = DateTime.now(); // defaults to today
    bool addToInStock = true;   // true = In Stock, false = To Buy

    const units = ['kg', 'g', 'litre', 'ml', 'pieces', 'packet', 'bunch'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          final dateLabel = expiryDate == null
              ? 'No date'
              : '${expiryDate!.day.toString().padLeft(2, '0')}/'
                '${expiryDate!.month.toString().padLeft(2, '0')}/'
                '${expiryDate!.year}';

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
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

                  // Qty + date row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
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
                      // Date picker button
                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: expiryDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) setSt(() => expiryDate = picked);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: surfBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: AppColors.expense,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    dateLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'Nunito',
                                      fontWeight: FontWeight.w700,
                                      color: tc,
                                    ),
                                  ),
                                ),
                                if (expiryDate != null)
                                  GestureDetector(
                                    onTap: () => setSt(() => expiryDate = null),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: sub,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Unit chips
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: units.map((u) {
                        final sel = u == selectedUnit;
                        return GestureDetector(
                          onTap: () => setSt(() => selectedUnit = u),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.expense.withValues(alpha: 0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel
                                    ? AppColors.expense
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              u,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: sel ? AppColors.expense : sub,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
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
                                ? AppColors.expense.withValues(alpha: 0.15)
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
                  const SizedBox(height: 10),

                  // Notes
                  _inputField(
                    noteCtrl,
                    'Notes (optional)',
                    surfBg,
                    tc,
                    sub,
                  ),
                  const SizedBox(height: 14),

                  // In Stock / To Buy toggle
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSt(() => addToInStock = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: addToInStock
                                  ? AppColors.income.withValues(alpha: 0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: addToInStock
                                    ? AppColors.income
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              '🏠  In Stock',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: addToInStock ? AppColors.income : sub,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSt(() => addToInStock = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: !addToInStock
                                  ? AppColors.expense.withValues(alpha: 0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: !addToInStock
                                    ? AppColors.expense
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              '🛒  To Buy',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: !addToInStock ? AppColors.expense : sub,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                            unit: selectedUnit,
                            walletId: widget.activeWalletId,
                            inStock: addToInStock,
                            toBuy: !addToInStock,
                            expiryDate: expiryDate,
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
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
                        shadowColor: AppColors.expense.withValues(alpha: 0.4),
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
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.92;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Flexible(child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEAL DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _MealDetailSheet extends StatefulWidget {
  final MealEntry meal;
  final bool isDark;
  final String currentUserName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(MealReaction reaction) onReactionAdded;
  final void Function(int index, MealReaction updated) onReactionUpdated;
  final void Function(int index) onReactionDeleted;
  final void Function(MealStatus status, int servingsCount)? onStatusChanged;
  final VoidCallback? onCheckStock;

  const _MealDetailSheet({
    required this.meal,
    required this.isDark,
    required this.currentUserName,
    required this.onEdit,
    required this.onDelete,
    required this.onReactionAdded,
    required this.onReactionUpdated,
    required this.onReactionDeleted,
    this.onStatusChanged,
    this.onCheckStock,
  });

  @override
  State<_MealDetailSheet> createState() => _MealDetailSheetState();
}

class _MealDetailSheetState extends State<_MealDetailSheet> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _reactionOptions = [
    ('👍', 'Love it'),
    ('😋', 'Yummy'),
    ('🤔', 'Not sure'),
    ('❌', "Don't want it"),
    ('🔄', 'Want alternative'),
  ];

  static const _replyOptions = [
    ('✅', 'Accepted'),
    ('❌', 'Rejected'),
    ('🤔', 'Let me think'),
    ('🔄', 'Suggest alternative'),
    ('💬', 'Noted'),
    ('🙏', 'Thanks for sharing'),
  ];

  // Local state — mirrors parent but allows immediate in-sheet feedback
  late List<MealReaction> _reactions;
  bool _showForm = false;
  String _selectedEmoji = '👍';
  final _nameCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  // Status state
  late MealStatus _status;
  late int _servings;

  // Edit / reply state
  int? _editingIndex;    // null = add mode, int = editing that index
  String? _replyingTo;   // null = not a reply, String = replying to this name

  @override
  void initState() {
    super.initState();
    _reactions = List.from(widget.meal.reactions);
    _status = widget.meal.mealStatus;
    _servings = widget.meal.servingsCount;
    if (widget.currentUserName.isNotEmpty) {
      _nameCtrl.text = widget.currentUserName;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _startEdit(int index) {
    final r = _reactions[index];
    setState(() {
      _editingIndex = index;
      _replyingTo = r.replyTo; // preserve reply context so options show correctly
      _nameCtrl.text = r.memberName;
      _commentCtrl.text = r.comment ?? '';
      _selectedEmoji = r.reactionEmoji;
      _showForm = true;
    });
  }

  void _startReply(int index) {
    final r = _reactions[index];
    setState(() {
      _editingIndex = null;
      _replyingTo = r.memberName;
      _nameCtrl.text = widget.currentUserName;
      _commentCtrl.clear();
      _selectedEmoji = '✅'; // first reply option
      _showForm = true;
    });
  }

  void _cancelForm() {
    setState(() {
      _showForm = false;
      _editingIndex = null;
      _replyingTo = null;
      _nameCtrl.text = widget.currentUserName;
      _commentCtrl.clear();
      _selectedEmoji = '👍'; // back to opinion default
    });
  }

  void _deleteReaction(int index) {
    setState(() => _reactions.removeAt(index));
    widget.onReactionDeleted(index);
  }

  void _submitReaction() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final comment = _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim();

    if (_editingIndex != null) {
      // Capture index before setState clears it
      final idx = _editingIndex!;
      final updated = _reactions[idx].copyWith(
        memberName: name,
        reactionEmoji: _selectedEmoji,
        comment: comment,
      );
      setState(() {
        _reactions[idx] = updated;
        _showForm = false;
        _editingIndex = null;
        _nameCtrl.text = widget.currentUserName;
        _commentCtrl.clear();
        _selectedEmoji = '👍';
      });
      widget.onReactionUpdated(idx, updated);
    } else {
      // Add new (or reply)
      final r = MealReaction(
        memberName: name,
        reactionEmoji: _selectedEmoji,
        comment: comment,
        replyTo: _replyingTo,
      );
      setState(() {
        _reactions = [..._reactions, r];
        _showForm = false;
        _replyingTo = null;
        _nameCtrl.text = widget.currentUserName;
        _commentCtrl.clear();
        _selectedEmoji = '👍';
      });
      widget.onReactionAdded(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;
    final surfBg = widget.isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final c = widget.meal.mealTime.color;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Meal header ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(widget.meal.emoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.meal.name,
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito', color: tc,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${widget.meal.mealTime.emoji} ${widget.meal.mealTime.label}',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800,
                                color: c, fontFamily: 'Nunito',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_months[widget.meal.date.month - 1]} ${widget.meal.date.day}',
                            style: TextStyle(fontSize: 12, color: sub, fontFamily: 'Nunito'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Edit / Delete ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.expense,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── Status picker ────────────────────────────────────────────────
            Text(
              '📍  Meal Status',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900,
                fontFamily: 'Nunito', color: tc,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: MealStatus.values.map((s) {
                final active = _status == s;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: s != MealStatus.values.last ? 8 : 0,
                    ),
                    child: GestureDetector(
                      onTap: () => setState(() => _status = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: active
                              ? s.color.withValues(alpha: 0.15)
                              : (widget.isDark ? AppColors.surfDark : AppColors.bgLight),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active ? s.color : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(s.emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 3),
                            Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: active ? s.color : sub,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_status == MealStatus.cooked || _status == MealStatus.ordered) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '👥  Serves',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito', color: tc,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _servings > 1 ? () => setState(() => _servings--) : null,
                    child: Icon(Icons.remove_circle_outline,
                        size: 22,
                        color: _servings > 1 ? AppColors.primary : sub),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '$_servings',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito', color: tc,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _servings++),
                    child: const Icon(Icons.add_circle_outline,
                        size: 22, color: AppColors.primary),
                  ),
                ],
              ),
            ],
            if (_status != widget.meal.mealStatus ||
                _servings != widget.meal.servingsCount) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onStatusChanged?.call(_status, _servings);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _status.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    '${_status.emoji}  Save Status',
                    style: const TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 22),

            // ── Check Stock ──────────────────────────────────────────────────
            if (widget.onCheckStock != null) ...[
              GestureDetector(
                onTap: widget.onCheckStock,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('🧺', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Check Ingredients in Stock',
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito', color: AppColors.primary,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
            ],

            // ── Opinions section ─────────────────────────────────────────────
            Row(
              children: [
                Text(
                  '💬  Family Opinions',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito', color: tc,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showForm ? _cancelForm() : setState(() => _showForm = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _showForm ? 'Cancel' : '+ Add Opinion',
                      style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito', color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Existing reactions
            if (_reactions.isEmpty && !_showForm)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No opinions yet. Be the first to share!',
                  style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
                ),
              )
            else
              ...List.generate(_reactions.length, (i) {
                final r = _reactions[i];
                final isReply = r.replyTo != null;
                return Container(
                  margin: EdgeInsets.only(bottom: 8, left: isReply ? 16 : 0),
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(12),
                    border: isReply
                        ? Border(left: BorderSide(color: AppColors.primary.withValues(alpha: 0.4), width: 3))
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isReply)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Text(
                            '↩ replying to ${r.replyTo}',
                            style: TextStyle(fontSize: 10, fontFamily: 'Nunito',
                                color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.reactionEmoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.memberName,
                                    style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w800,
                                      fontFamily: 'Nunito', color: tc,
                                    ),
                                  ),
                                  Text(
                                    ([..._reactionOptions, ..._replyOptions].firstWhere(
                                      (o) => o.$1 == r.reactionEmoji,
                                      orElse: () => (r.reactionEmoji, r.reactionEmoji),
                                    )).$2,
                                    style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
                                  ),
                                  if (r.comment != null && r.comment!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        '"${r.comment}"',
                                        style: TextStyle(
                                          fontSize: 11, fontFamily: 'Nunito',
                                          fontStyle: FontStyle.italic, color: sub,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Action buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ReactionActionBtn(
                                  icon: Icons.reply_rounded,
                                  color: AppColors.primary,
                                  onTap: () => _startReply(i),
                                  tooltip: 'Reply',
                                ),
                                _ReactionActionBtn(
                                  icon: Icons.edit_rounded,
                                  color: sub,
                                  onTap: () => _startEdit(i),
                                  tooltip: 'Edit',
                                ),
                                _ReactionActionBtn(
                                  icon: Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                  onTap: () => _deleteReaction(i),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

            // Add / Edit / Reply form
            if (_showForm) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Context label for reply / edit
                    if (_replyingTo != null) ...[
                      Row(
                        children: [
                          Icon(Icons.reply_rounded, size: 13, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Replying to $_replyingTo',
                            style: const TextStyle(
                              fontSize: 11, fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700, color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ] else if (_editingIndex != null) ...[
                      Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 13, color: sub),
                          const SizedBox(width: 4),
                          Text(
                            'Editing opinion',
                            style: TextStyle(
                              fontSize: 11, fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700, color: sub,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Name field — read-only when logged-in user name is known
                    TextField(
                      controller: _nameCtrl,
                      readOnly: widget.currentUserName.isNotEmpty && _editingIndex == null,
                      style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: tc),
                      decoration: InputDecoration(
                        hintText: 'Your name (e.g. Mom, Dad)',
                        hintStyle: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
                        prefixIcon: widget.currentUserName.isNotEmpty && _editingIndex == null
                            ? Icon(Icons.person_rounded, size: 16, color: AppColors.primary)
                            : null,
                        filled: true,
                        fillColor: widget.currentUserName.isNotEmpty && _editingIndex == null
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : (widget.isDark ? AppColors.cardDark : Colors.white),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Reaction / reply options row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (_replyingTo != null ? _replyOptions : _reactionOptions).map((opt) {
                        final selected = _selectedEmoji == opt.$1;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedEmoji = opt.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : (widget.isDark ? AppColors.cardDark : Colors.white),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(opt.$1, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 5),
                                Text(
                                  opt.$2,
                                  style: TextStyle(
                                    fontSize: 11, fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w700,
                                    color: selected ? AppColors.primary : sub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    // Comment field
                    TextField(
                      controller: _commentCtrl,
                      style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: tc),
                      decoration: InputDecoration(
                        hintText: 'Add a comment or suggestion (optional)',
                        hintStyle: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
                        filled: true,
                        fillColor: widget.isDark ? AppColors.cardDark : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitReaction,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _editingIndex != null ? 'Update Opinion' : _replyingTo != null ? 'Post Reply' : 'Share Opinion',
                          style: const TextStyle(
                            fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REACTION ACTION BUTTON — small icon button used in opinion cards
// ─────────────────────────────────────────────────────────────────────────────

class _ReactionActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  const _ReactionActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  final bool isDark;
  const _SectionDivider({required this.isDark});
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPIRY BANNER — shown at top of Basket tab when items expire within 3 days
// ─────────────────────────────────────────────────────────────────────────────

class _ExpiryBanner extends StatelessWidget {
  final List<GroceryItem> items;
  final bool isDark;

  const _ExpiryBanner({required this.items, required this.isDark});

  String _expiryLabel(GroceryItem item) {
    final expiryDay = DateTime(item.expiryDate!.year, item.expiryDate!.month, item.expiryDate!.day);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final days = expiryDay.difference(todayDay).inDays;
    if (days == 0) return 'expired today';
    if (days == -1) return 'expired yesterday';
    return 'expired ${(-days)} days ago';
  }

  Color _urgencyColor(GroceryItem item) {
    final expiryDay = DateTime(item.expiryDate!.year, item.expiryDate!.month, item.expiryDate!.day);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final days = expiryDay.difference(todayDay).inDays;
    if (days >= -1) return AppColors.expense;
    if (days >= -3) return const Color(0xFFFF7043);
    return const Color(0xFFFFAA2C);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7043).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF7043).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Text(
                'Expiring Soon',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                  color: Color(0xFFFF7043),
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} item${items.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Nunito',
                  color: Color(0xFFFF7043),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Item list
          ...items.map((item) {
            final urgency = _urgencyColor(item);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    item.category.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: isDark
                                ? AppColors.textDark
                                : AppColors.textLight,
                          ),
                        ),
                        Text(
                          '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit} · ${_expiryLabel(item)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: urgency,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: urgency,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INGREDIENT ANALYSIS SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _IngredientAnalysisSheet extends StatefulWidget {
  final String recipeName;
  final List<String> missingIngredients;
  final List<String> alreadyInToBuyIngredients;
  final bool isDark;
  final void Function(List<String>) onAddToBasket;

  const _IngredientAnalysisSheet({
    required this.recipeName,
    required this.missingIngredients,
    required this.isDark,
    required this.onAddToBasket,
    this.alreadyInToBuyIngredients = const [],
  });

  @override
  State<_IngredientAnalysisSheet> createState() =>
      _IngredientAnalysisSheetState();
}

class _IngredientAnalysisSheetState extends State<_IngredientAnalysisSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.missingIngredients);
  }

  Widget _buildRow(String ingredient, {required bool alreadyInToBuy, required colorSub}) {
    final isDark = widget.isDark;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    if (alreadyInToBuy) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.playlist_add_check_rounded, size: 18, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ingredient,
                style: TextStyle(
                  fontSize: 13, fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  color: tc.withValues(alpha: 0.5),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '· In To Buy',
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final checked = _selected.contains(ingredient);
    return GestureDetector(
      onTap: () => setState(() {
        if (checked) { _selected.remove(ingredient); }
        else { _selected.add(ingredient); }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              checked ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 18,
              color: checked ? AppColors.primary : sub,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ingredient,
                style: TextStyle(
                  fontSize: 13, fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700, color: tc,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Not in stock',
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  color: AppColors.expense,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = widget.isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;
    final totalShown = widget.missingIngredients.length + widget.alreadyInToBuyIngredients.length;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Text('🛒', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingredient Check',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito', color: tc,
                      ),
                    ),
                    Text(
                      '$totalShown items from "${widget.recipeName}" not in stock',
                      style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ...widget.missingIngredients.map((i) =>
                      _buildRow(i, alreadyInToBuy: false, colorSub: sub)),
                  ...widget.alreadyInToBuyIngredients.map((i) =>
                      _buildRow(i, alreadyInToBuy: true, colorSub: sub)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Skip',
                      style: TextStyle(
                          fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () {
                          widget.onAddToBasket(_selected.toList());
                          Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Add ${_selected.length} to 🛒 To Buy',
                    style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w900,
                        fontSize: 13),
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
  Widget build(_, _, _) => child;
  @override
  bool shouldRebuild(covariant _PinnedDelegate o) =>
      o.child != child || o.minH != minH || o.maxH != maxH;
}
