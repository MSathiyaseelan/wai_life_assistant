import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin service layer between the Pantry UI and Supabase.
/// All methods throw [PostgrestException] on failure — callers should catch.
///
/// Covers all three Pantry sub-tabs:
///   • Meal Map  → meal_entries + meal_reactions
///   • Recipe Box → recipes
///   • Basket    → grocery_items
///   • Family Food Guide → member_food_prefs
class PantryService {
  PantryService._();
  static final PantryService instance = PantryService._();

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  // ═══════════════════════════════════════════════════════════════════════════
  // RECIPE BOX
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch all recipes for a wallet, newest first.
  Future<List<Map<String, dynamic>>> fetchRecipes(String walletId) async {
    final rows = await _db
        .from('recipes')
        .select()
        .eq('wallet_id', walletId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Add a new recipe.
  Future<Map<String, dynamic>> addRecipe({
    required String walletId,
    required String name,
    required String emoji,
    required String cuisine,       // CuisineType.name
    required List<String> suitableFor,  // MealTime names
    required List<String> ingredients,
    String? socialLink,
    String? note,
    int? cookTimeMin,
    bool isFavourite = false,
  }) async {
    final row = await _db.from('recipes').insert({
      'wallet_id':     walletId,
      'created_by':    _uid,
      'name':          name,
      'emoji':         emoji,
      'cuisine':       cuisine,
      'suitable_for':  suitableFor,
      'ingredients':   ingredients,
      'social_link':   socialLink,
      'note':          note,
      'cook_time_min': cookTimeMin,
      'is_favourite':  isFavourite,
    }).select().single();
    return row;
  }

  /// Update mutable fields on a recipe.
  Future<void> updateRecipe(String id, Map<String, dynamic> updates) async {
    await _db.from('recipes').update(updates).eq('id', id);
  }

  /// Toggle the favourite flag on a recipe.
  Future<void> toggleFavourite(String id, {required bool isFavourite}) async {
    await _db
        .from('recipes')
        .update({'is_favourite': isFavourite})
        .eq('id', id);
  }

  /// Delete a recipe (cascades to any meal_entries that referenced it via SET NULL).
  Future<void> deleteRecipe(String id) async {
    await _db.from('recipes').delete().eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEAL MAP — entries
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch all meal entries for a wallet, with reactions eager-loaded.
  Future<List<Map<String, dynamic>>> fetchMealEntries(String walletId) async {
    final rows = await _db
        .from('meal_entries')
        .select('*, meal_reactions(*)')
        .eq('wallet_id', walletId)
        .order('date', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Fetch meal entries for the current week (Mon–Sun of [weekStart]).
  Future<List<Map<String, dynamic>>> fetchMealEntriesForWeek(
    String walletId,
    DateTime weekStart,
  ) async {
    final mon = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final sun = mon.add(const Duration(days: 7));
    final rows = await _db
        .from('meal_entries')
        .select('*, meal_reactions(*)')
        .eq('wallet_id', walletId)
        .gte('date', mon.toIso8601String().substring(0, 10))
        .lt('date', sun.toIso8601String().substring(0, 10))
        .order('date');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Fetch meal entries for a single day.
  Future<List<Map<String, dynamic>>> fetchMealEntriesForDay(
    String walletId,
    DateTime day,
  ) async {
    final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final rows = await _db
        .from('meal_entries')
        .select('*, meal_reactions(*)')
        .eq('wallet_id', walletId)
        .eq('date', dateStr)
        .order('meal_time');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Add a new meal entry.
  Future<Map<String, dynamic>> addMealEntry({
    required String walletId,
    required String name,
    required String emoji,
    required String mealTime,   // MealTime.name
    required DateTime date,
    String? recipeId,
    String? note,
  }) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final row = await _db.from('meal_entries').insert({
      'wallet_id':  walletId,
      'created_by': _uid,
      'name':       name,
      'emoji':      emoji,
      'meal_time':  mealTime,
      'date':       dateStr,
      'recipe_id':  recipeId,
      'note':       note,
    }).select().single();
    return row;
  }

  /// Update mutable fields on a meal entry.
  Future<void> updateMealEntry(String id, Map<String, dynamic> updates) async {
    await _db.from('meal_entries').update(updates).eq('id', id);
  }

  /// Delete a meal entry (cascades to its reactions).
  Future<void> deleteMealEntry(String id) async {
    await _db.from('meal_entries').delete().eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEAL MAP — reactions (family opinions)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch all reactions for a meal entry.
  Future<List<Map<String, dynamic>>> fetchReactions(String mealId) async {
    final rows = await _db
        .from('meal_reactions')
        .select()
        .eq('meal_id', mealId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Add a reaction / opinion to a meal entry.
  Future<Map<String, dynamic>> addReaction({
    required String mealId,
    required String memberName,
    required String reactionEmoji,
    String? comment,
    String? replyTo,
  }) async {
    final row = await _db.from('meal_reactions').insert({
      'meal_id':        mealId,
      'user_id':        _uid,
      'member_name':    memberName,
      'reaction_emoji': reactionEmoji,
      'comment':        comment,
      'reply_to':       replyTo,
    }).select().single();
    return row;
  }

  /// Update a reaction's emoji or comment.
  Future<void> updateReaction(String id, Map<String, dynamic> updates) async {
    await _db.from('meal_reactions').update(updates).eq('id', id);
  }

  /// Delete a reaction.
  Future<void> deleteReaction(String id) async {
    await _db.from('meal_reactions').delete().eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BASKET — grocery items
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch all grocery items for a wallet.
  Future<List<Map<String, dynamic>>> fetchGroceryItems(String walletId) async {
    final rows = await _db
        .from('grocery_items')
        .select()
        .eq('wallet_id', walletId)
        .order('category')
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Fetch items on the shopping list (to_buy = true) for a wallet.
  Future<List<Map<String, dynamic>>> fetchShoppingList(String walletId) async {
    final rows = await _db
        .from('grocery_items')
        .select()
        .eq('wallet_id', walletId)
        .eq('to_buy', true)
        .order('category')
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Add a new grocery item.
  Future<Map<String, dynamic>> addGroceryItem({
    required String walletId,
    required String name,
    required String category,    // GroceryCategory.name
    required double quantity,
    required String unit,
    bool inStock = true,
    bool toBuy = false,
    DateTime? expiryDate,
  }) async {
    final row = await _db.from('grocery_items').insert({
      'wallet_id':    walletId,
      'created_by':   _uid,
      'name':         name,
      'category':     category,
      'quantity':     quantity,
      'unit':         unit,
      'in_stock':     inStock,
      'to_buy':       toBuy,
      'expiry_date':  expiryDate?.toIso8601String().substring(0, 10),
      'last_updated': DateTime.now().toIso8601String(),
    }).select().single();
    return row;
  }

  /// Update mutable fields on a grocery item.
  Future<void> updateGroceryItem(String id, Map<String, dynamic> updates) async {
    await _db.from('grocery_items').update({
      ...updates,
      'last_updated': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Toggle the in-stock flag (moves between In Stock and empty).
  Future<void> toggleInStock(String id, {required bool inStock}) async {
    await _db.from('grocery_items').update({
      'in_stock':    inStock,
      'last_updated': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Toggle the to-buy flag (add/remove from shopping list).
  Future<void> toggleToBuy(String id, {required bool toBuy}) async {
    await _db.from('grocery_items').update({
      'to_buy':      toBuy,
      'last_updated': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Delete a grocery item.
  Future<void> deleteGroceryItem(String id) async {
    await _db.from('grocery_items').delete().eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FAMILY FOOD PREFERENCES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch all food preferences for a wallet (one row per family member).
  Future<List<Map<String, dynamic>>> fetchFoodPrefs(String walletId) async {
    final rows = await _db
        .from('member_food_prefs')
        .select()
        .eq('wallet_id', walletId)
        .order('member_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Insert or update food preferences for a specific member.
  /// Uses Postgres UPSERT on the (wallet_id, member_id) unique constraint.
  Future<Map<String, dynamic>> upsertFoodPrefs({
    required String walletId,
    required String memberId,
    required String memberName,
    required String memberEmoji,
    required List<String> allergies,
    required List<String> likes,
    required List<String> dislikes,
    required List<String> mandatoryFoods,
  }) async {
    final row = await _db.from('member_food_prefs').upsert(
      {
        'wallet_id':       walletId,
        'created_by':      _uid,
        'member_id':       memberId,
        'member_name':     memberName,
        'member_emoji':    memberEmoji,
        'allergies':       allergies,
        'likes':           likes,
        'dislikes':        dislikes,
        'mandatory_foods': mandatoryFoods,
      },
      onConflict: 'wallet_id,member_id',
    ).select().single();
    return row;
  }

  /// Delete the food-prefs record for a member.
  Future<void> deleteFoodPrefs(String id) async {
    await _db.from('member_food_prefs').delete().eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COPY / PASTE helpers (Meal Map clipboard)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Copy all meal entries from [sourceDay] and insert them into [targetDay].
  /// Returns the list of newly created entry rows.
  Future<List<Map<String, dynamic>>> copyDayMeals({
    required String walletId,
    required DateTime sourceDay,
    required DateTime targetDay,
  }) async {
    // Fetch source
    final source = await fetchMealEntriesForDay(walletId, sourceDay);
    if (source.isEmpty) return [];

    final targetStr =
        '${targetDay.year}-${targetDay.month.toString().padLeft(2, '0')}-${targetDay.day.toString().padLeft(2, '0')}';

    // Remove existing target-day meals first (replace, not merge)
    await _db
        .from('meal_entries')
        .delete()
        .eq('wallet_id', walletId)
        .eq('date', targetStr);

    final inserts = source.map((m) => {
      'wallet_id':  walletId,
      'created_by': _uid,
      'name':       m['name'],
      'emoji':      m['emoji'],
      'meal_time':  m['meal_time'],
      'date':       targetStr,
      'recipe_id':  m['recipe_id'],
      'note':       m['note'],
    }).toList();

    final rows = await _db
        .from('meal_entries')
        .insert(inserts)
        .select();
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Copy a full week of meals (Mon–Sun of [sourceWeekStart]) into
  /// the week starting [targetWeekStart], preserving day offsets.
  Future<List<Map<String, dynamic>>> copyWeekMeals({
    required String walletId,
    required DateTime sourceWeekStart,
    required DateTime targetWeekStart,
  }) async {
    final source = await fetchMealEntriesForWeek(walletId, sourceWeekStart);
    if (source.isEmpty) return [];

    final srcMon = DateTime(
      sourceWeekStart.year, sourceWeekStart.month, sourceWeekStart.day,
    );
    final tgtMon = DateTime(
      targetWeekStart.year, targetWeekStart.month, targetWeekStart.day,
    );

    // Clear the entire target week first
    final tgtSun = tgtMon.add(const Duration(days: 7));
    await _db
        .from('meal_entries')
        .delete()
        .eq('wallet_id', walletId)
        .gte('date', tgtMon.toIso8601String().substring(0, 10))
        .lt('date', tgtSun.toIso8601String().substring(0, 10));

    final inserts = source.map((m) {
      final srcDate = DateTime.parse(m['date'] as String);
      final offset = srcDate.difference(srcMon).inDays.clamp(0, 6);
      final tgtDate = tgtMon.add(Duration(days: offset));
      final tgtStr =
          '${tgtDate.year}-${tgtDate.month.toString().padLeft(2, '0')}-${tgtDate.day.toString().padLeft(2, '0')}';
      return {
        'wallet_id':  walletId,
        'created_by': _uid,
        'name':       m['name'],
        'emoji':      m['emoji'],
        'meal_time':  m['meal_time'],
        'date':       tgtStr,
        'recipe_id':  m['recipe_id'],
        'note':       m['note'],
      };
    }).toList();

    final rows = await _db
        .from('meal_entries')
        .insert(inserts)
        .select();
    return List<Map<String, dynamic>>.from(rows);
  }
}
