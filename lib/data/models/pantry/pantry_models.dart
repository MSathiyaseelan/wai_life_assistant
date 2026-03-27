import 'package:flutter/material.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum MealTime { breakfast, lunch, snack, dinner }

extension MealTimeExt on MealTime {
  String get label {
    switch (this) {
      case MealTime.breakfast:
        return 'Breakfast';
      case MealTime.lunch:
        return 'Lunch';
      case MealTime.snack:
        return 'Snack';
      case MealTime.dinner:
        return 'Dinner';
    }
  }

  String get emoji {
    switch (this) {
      case MealTime.breakfast:
        return '🌅';
      case MealTime.lunch:
        return '☀️';
      case MealTime.snack:
        return '🍎';
      case MealTime.dinner:
        return '🌙';
    }
  }

  Color get color {
    switch (this) {
      case MealTime.breakfast:
        return const Color(0xFFFF9800);
      case MealTime.lunch:
        return const Color(0xFF4CAF50);
      case MealTime.snack:
        return const Color(0xFF9C27B0);
      case MealTime.dinner:
        return const Color(0xFF1565C0);
    }
  }
}

enum GroceryCategory {
  vegetables,
  fruits,
  dairy,
  meat,
  grains,
  beverages,
  snacks,
  spices,
  cleaning,
  other,
}

extension GroceryCategoryExt on GroceryCategory {
  String get label {
    switch (this) {
      case GroceryCategory.vegetables:
        return 'Vegetables';
      case GroceryCategory.fruits:
        return 'Fruits';
      case GroceryCategory.dairy:
        return 'Dairy';
      case GroceryCategory.meat:
        return 'Meat';
      case GroceryCategory.grains:
        return 'Grains';
      case GroceryCategory.beverages:
        return 'Beverages';
      case GroceryCategory.snacks:
        return 'Snacks';
      case GroceryCategory.spices:
        return 'Spices';
      case GroceryCategory.cleaning:
        return 'Cleaning';
      case GroceryCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case GroceryCategory.vegetables:
        return '🥬';
      case GroceryCategory.fruits:
        return '🍎';
      case GroceryCategory.dairy:
        return '🥛';
      case GroceryCategory.meat:
        return '🥩';
      case GroceryCategory.grains:
        return '🌾';
      case GroceryCategory.beverages:
        return '🧃';
      case GroceryCategory.snacks:
        return '🍿';
      case GroceryCategory.spices:
        return '🌶️';
      case GroceryCategory.cleaning:
        return '🧹';
      case GroceryCategory.other:
        return '📦';
    }
  }
}

enum CuisineType {
  indian,
  chinese,
  italian,
  mexican,
  mediterranean,
  thai,
  japanese,
  continental,
}

extension CuisineTypeExt on CuisineType {
  String get label {
    switch (this) {
      case CuisineType.indian:
        return 'Indian';
      case CuisineType.chinese:
        return 'Chinese';
      case CuisineType.italian:
        return 'Italian';
      case CuisineType.mexican:
        return 'Mexican';
      case CuisineType.mediterranean:
        return 'Mediterranean';
      case CuisineType.thai:
        return 'Thai';
      case CuisineType.japanese:
        return 'Japanese';
      case CuisineType.continental:
        return 'Continental';
    }
  }

  String get emoji {
    switch (this) {
      case CuisineType.indian:
        return '🇮🇳';
      case CuisineType.chinese:
        return '🇨🇳';
      case CuisineType.italian:
        return '🇮🇹';
      case CuisineType.mexican:
        return '🇲🇽';
      case CuisineType.mediterranean:
        return '🫒';
      case CuisineType.thai:
        return '🇹🇭';
      case CuisineType.japanese:
        return '🇯🇵';
      case CuisineType.continental:
        return '🌍';
    }
  }
}

enum MealStatus { planned, cooked, ordered }

extension MealStatusExt on MealStatus {
  String get label {
    switch (this) {
      case MealStatus.planned: return 'Planned';
      case MealStatus.cooked:  return 'Cooked';
      case MealStatus.ordered: return 'Ordered';
    }
  }

  String get emoji {
    switch (this) {
      case MealStatus.planned: return '⏰';
      case MealStatus.cooked:  return '🏠';
      case MealStatus.ordered: return '🛵';
    }
  }

  Color get color {
    switch (this) {
      case MealStatus.planned: return const Color(0xFF8E8EA0);
      case MealStatus.cooked:  return const Color(0xFF00C897);
      case MealStatus.ordered: return const Color(0xFFFF9800);
    }
  }
}

// ── Meal reaction ─────────────────────────────────────────────────────────────

class MealReaction {
  final String? id;          // DB UUID; null for locally-created reactions not yet persisted
  final String memberName;
  final String reactionEmoji; // e.g. 👍 😋 🤔 ❌ 🔄
  final String? comment;
  final String? replyTo;     // name of the person being replied to

  const MealReaction({
    this.id,
    required this.memberName,
    required this.reactionEmoji,
    this.comment,
    this.replyTo,
  });

  MealReaction copyWith({
    String? id,
    String? memberName,
    String? reactionEmoji,
    String? comment,
    String? replyTo,
  }) => MealReaction(
    id: id ?? this.id,
    memberName: memberName ?? this.memberName,
    reactionEmoji: reactionEmoji ?? this.reactionEmoji,
    comment: comment ?? this.comment,
    replyTo: replyTo ?? this.replyTo,
  );

  factory MealReaction.fromMap(Map<String, dynamic> m) => MealReaction(
    id: m['id'] as String?,
    memberName: m['member_name'] as String,
    reactionEmoji: m['reaction_emoji'] as String,
    comment: m['comment'] as String?,
    replyTo: m['reply_to'] as String?,
  );
}

// ── Models ────────────────────────────────────────────────────────────────────

class MealEntry {
  final String id;
  final String name;
  final MealTime mealTime;
  final DateTime date;
  final String? recipeId; // links to RecipeModel
  final String? note;
  final String walletId; // 'personal' or family id
  final String emoji;
  final MealStatus mealStatus;
  final int servingsCount; // how many members it was prepared for
  // Nullable backing fields — getters ensure non-null even on hot-reload / missing DB column
  final List<String>? _ingredients;
  List<String> get ingredients => _ingredients ?? const [];
  final List<MealReaction>? _reactions;
  List<MealReaction> get reactions => _reactions ?? const [];

  const MealEntry({
    required this.id,
    required this.name,
    required this.mealTime,
    required this.date,
    required this.walletId,
    this.recipeId,
    this.note,
    this.emoji = '🍽️',
    this.mealStatus = MealStatus.planned,
    this.servingsCount = 1,
    List<String>? ingredients,
    List<MealReaction>? reactions,
  }) : _ingredients = ingredients,
       _reactions = reactions;

  MealEntry copyWith({
    String? name,
    MealTime? mealTime,
    DateTime? date,
    String? note,
    String? emoji,
    String? recipeId,
    MealStatus? mealStatus,
    int? servingsCount,
    List<String>? ingredients,
    List<MealReaction>? reactions,
  }) => MealEntry(
    id: id,
    walletId: walletId,
    recipeId: recipeId ?? this.recipeId,
    name: name ?? this.name,
    mealTime: mealTime ?? this.mealTime,
    date: date ?? this.date,
    note: note ?? this.note,
    emoji: emoji ?? this.emoji,
    mealStatus: mealStatus ?? this.mealStatus,
    servingsCount: servingsCount ?? this.servingsCount,
    ingredients: ingredients ?? _ingredients,
    reactions: reactions ?? this.reactions,
  );

  /// Deserialise a Supabase row (with optional nested meal_reactions list).
  factory MealEntry.fromMap(Map<String, dynamic> m) {
    final rawReactions = m['meal_reactions'];
    final reactions = rawReactions is List
        ? rawReactions
            .map((r) => MealReaction.fromMap(r as Map<String, dynamic>))
            .toList()
        : <MealReaction>[];
    return MealEntry(
      id: m['id'] as String,
      walletId: m['wallet_id'] as String,
      name: m['name'] as String,
      emoji: (m['emoji'] as String?) ?? '🍽️',
      mealTime: MealTime.values.firstWhere(
        (t) => t.name == (m['meal_time'] as String),
        orElse: () => MealTime.lunch,
      ),
      date: DateTime.parse(m['date'] as String),
      recipeId: m['recipe_id'] as String?,
      note: m['note'] as String?,
      mealStatus: MealStatus.values.firstWhere(
        (s) => s.name == (m['meal_status'] as String?),
        orElse: () => MealStatus.planned,
      ),
      servingsCount: (m['servings_count'] as int?) ?? 1,
      ingredients: (m['ingredients'] as List<dynamic>?)?.cast<String>(),
      reactions: reactions,
    );
  }
}

class RecipeModel {
  final String id;
  final String walletId;
  final String name;
  final String emoji;
  final CuisineType cuisine;
  final List<MealTime> suitableFor;
  final List<String> ingredients;
  final String? socialLink;
  final String? note;
  final int? cookTimeMin;
  bool isFavourite;
  /// Non-null when this recipe was tagged from the master library.
  final String? libraryRecipeId;

  RecipeModel({
    required this.id,
    this.walletId = 'personal',
    required this.name,
    required this.emoji,
    required this.cuisine,
    required this.suitableFor,
    required this.ingredients,
    this.socialLink,
    this.note,
    this.cookTimeMin,
    this.isFavourite = false,
    this.libraryRecipeId,
  });

  /// Deserialise a Supabase row.
  factory RecipeModel.fromMap(Map<String, dynamic> m) {
    final suitableRaw = (m['suitable_for'] as List<dynamic>?)?.cast<String>() ?? [];
    final ingredientsRaw = (m['ingredients'] as List<dynamic>?)?.cast<String>() ?? [];
    return RecipeModel(
      id: m['id'] as String,
      walletId: m['wallet_id'] as String,
      name: m['name'] as String,
      emoji: (m['emoji'] as String?) ?? '🍽️',
      cuisine: CuisineType.values.firstWhere(
        (c) => c.name == (m['cuisine'] as String),
        orElse: () => CuisineType.indian,
      ),
      suitableFor: suitableRaw
          .map((s) => MealTime.values.firstWhere(
                (t) => t.name == s,
                orElse: () => MealTime.lunch,
              ))
          .toList(),
      ingredients: ingredientsRaw,
      socialLink: m['social_link'] as String?,
      note: m['note'] as String?,
      cookTimeMin: m['cook_time_min'] as int?,
      isFavourite: (m['is_favourite'] as bool?) ?? false,
      libraryRecipeId: m['library_recipe_id'] as String?,
    );
  }
}

class GroceryItem {
  final String id;
  String name;
  GroceryCategory category;
  double quantity;
  String unit; // 'kg', 'g', 'L', 'pcs', etc.
  bool inStock;
  bool toBuy; // on shopping list
  DateTime? expiryDate;
  DateTime lastUpdated;
  String walletId;
  String? note;

  GroceryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.walletId,
    this.inStock = true,
    this.toBuy = false,
    this.expiryDate,
    this.note,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// Deserialise a Supabase row.
  factory GroceryItem.fromMap(Map<String, dynamic> m) => GroceryItem(
    id: m['id'] as String,
    walletId: m['wallet_id'] as String,
    name: m['name'] as String,
    category: GroceryCategory.values.firstWhere(
      (c) => c.name == (m['category'] as String),
      orElse: () => GroceryCategory.other,
    ),
    quantity: (m['quantity'] as num).toDouble(),
    unit: m['unit'] as String,
    inStock: (m['in_stock'] as bool?) ?? true,
    toBuy: (m['to_buy'] as bool?) ?? false,
    expiryDate: m['expiry_date'] != null
        ? DateTime.parse(m['expiry_date'] as String)
        : null,
    note: m['note'] as String?,
    lastUpdated: m['last_updated'] != null
        ? DateTime.parse(m['last_updated'] as String)
        : DateTime.now(),
  );
}

// ── Master Recipe (shared catalogue, read from DB) ────────────────────────────

class MasterRecipe {
  final String id;
  final String name;
  final String emoji;
  final String cuisine;          // plain string, not an enum
  final List<String> mealTypes;  // raw strings: 'breakfast', 'lunch', etc.
  final List<String> ingredients; // formatted "Name (qty unit)"
  final int? cookTimeMin;
  final int? prepTimeMin;
  final int? servings;
  final int? calories;
  final String? youtubeSearch;
  final List<String> tags;

  const MasterRecipe({
    required this.id,
    required this.name,
    required this.emoji,
    required this.cuisine,
    required this.mealTypes,
    required this.ingredients,
    this.cookTimeMin,
    this.prepTimeMin,
    this.servings,
    this.calories,
    this.youtubeSearch,
    this.tags = const [],
  });

  factory MasterRecipe.fromMap(Map<String, dynamic> m) {
    // ingredients stored as jsonb: [{name, qty, unit}, ...]
    final rawIngs = m['ingredients'] as List? ?? [];
    final ingredients = rawIngs.map((i) {
      final name = (i['name'] as String?) ?? '';
      final qty  = i['qty'];
      final unit = (i['unit'] as String?) ?? '';
      final qtyStr = qty is double && qty == qty.truncateToDouble()
          ? qty.toInt().toString()
          : qty?.toString() ?? '';
      return '$name ($qtyStr $unit)'.trim();
    }).toList();

    return MasterRecipe(
      id:            m['id'] as String,
      name:          m['name'] as String,
      emoji:         (m['emoji'] as String?) ?? '🍽️',
      cuisine:       m['cuisine'] as String,
      mealTypes:     List<String>.from(m['meal_types'] as List? ?? []),
      ingredients:   ingredients,
      cookTimeMin:   m['cook_time_min'] as int?,
      prepTimeMin:   m['prep_time_min'] as int?,
      servings:      m['servings'] as int?,
      calories:      m['calories'] as int?,
      youtubeSearch: m['youtube_search'] as String?,
      tags:          List<String>.from(m['tags'] as List? ?? []),
    );
  }

  /// Convert to a RecipeModel to save in the user's Recipe Box.
  RecipeModel toRecipeModel() {
    // Map raw meal_type strings to MealTime enum (skip 'beverage', 'dessert')
    final suitableFor = mealTypes
        .map((t) {
          switch (t) {
            case 'breakfast': return MealTime.breakfast;
            case 'lunch':     return MealTime.lunch;
            case 'dinner':    return MealTime.dinner;
            case 'snacks':    return MealTime.snack;
            default:          return null;
          }
        })
        .whereType<MealTime>()
        .toList();

    // Map cuisine string to CuisineType enum
    CuisineType cuisineType = CuisineType.indian;
    final cl = cuisine.toLowerCase();
    if (cl.contains('chinese') || cl.contains('indo-chinese')) {
      cuisineType = CuisineType.chinese;
    } else if (cl.contains('continental') || cl.contains('italian')) {
      cuisineType = cl.contains('italian') ? CuisineType.italian : CuisineType.continental;
    } else if (cl.contains('beverage') || cl.contains('snack') || cl.contains('street') ||
               cl.contains('dessert') || cl.contains('rice') ||
               cl.contains('north indian') || cl.contains('south indian')) {
      cuisineType = CuisineType.indian;
    }

    return RecipeModel(
      id:              DateTime.now().millisecondsSinceEpoch.toString(),
      name:            name,
      emoji:           emoji,
      cuisine:         cuisineType,
      suitableFor:     suitableFor.isEmpty ? [MealTime.lunch] : suitableFor,
      ingredients:     ingredients,
      cookTimeMin:     cookTimeMin,
      libraryRecipeId: id, // links back to this master recipe
    );
  }
}

// ── Mock Data ──────────────────────────────────────────────────────────────────

final DateTime _today = DateTime.now();
DateTime _d(int offset) => _today.add(Duration(days: offset));

List<MealEntry> mockMeals = [
  // Today
  MealEntry(
    id: 'm1',
    name: 'Idli & Sambar',
    mealTime: MealTime.breakfast,
    date: _d(0),
    walletId: 'personal',
    emoji: '🫙',
  ),
  MealEntry(
    id: 'm2',
    name: 'Dal Rice',
    mealTime: MealTime.lunch,
    date: _d(0),
    walletId: 'personal',
    emoji: '🍚',
  ),
  MealEntry(
    id: 'm3',
    name: 'Masala Chai',
    mealTime: MealTime.snack,
    date: _d(0),
    walletId: 'personal',
    emoji: '☕',
  ),
  MealEntry(
    id: 'm4',
    name: 'Paneer Butter Masala',
    mealTime: MealTime.dinner,
    date: _d(0),
    walletId: 'personal',
    emoji: '🫕',
  ),
  // Tomorrow
  MealEntry(
    id: 'm5',
    name: 'Poha',
    mealTime: MealTime.breakfast,
    date: _d(1),
    walletId: 'personal',
    emoji: '🍛',
  ),
  MealEntry(
    id: 'm6',
    name: 'Curd Rice',
    mealTime: MealTime.lunch,
    date: _d(1),
    walletId: 'personal',
    emoji: '🍚',
  ),
  MealEntry(
    id: 'm7',
    name: 'Samosa',
    mealTime: MealTime.snack,
    date: _d(1),
    walletId: 'personal',
    emoji: '🥟',
  ),
  // Day 3
  MealEntry(
    id: 'm8',
    name: 'Dosa & Chutney',
    mealTime: MealTime.breakfast,
    date: _d(2),
    walletId: 'personal',
    emoji: '🫓',
  ),
  MealEntry(
    id: 'm9',
    name: 'Biryani',
    mealTime: MealTime.lunch,
    date: _d(2),
    walletId: 'personal',
    emoji: '🍚',
  ),
  // Family meals
  MealEntry(
    id: 'm10',
    name: 'Chapati & Sabzi',
    mealTime: MealTime.dinner,
    date: _d(0),
    walletId: 'f1',
    emoji: '🫓',
  ),
  MealEntry(
    id: 'm11',
    name: 'Pongal',
    mealTime: MealTime.breakfast,
    date: _d(0),
    walletId: 'f1',
    emoji: '🍲',
  ),
];

List<RecipeModel> mockRecipes = [
  RecipeModel(
    id: 'r1',
    name: 'Butter Chicken',
    emoji: '🍗',
    cuisine: CuisineType.indian,
    suitableFor: [MealTime.lunch, MealTime.dinner],
    ingredients: [
      'Chicken 500g',
      'Butter 3tbsp',
      'Tomatoes 4',
      'Cream ½ cup',
      'Garam masala',
      'Ginger garlic paste',
    ],
    cookTimeMin: 40,
    isFavourite: true,
    note: 'Marinate overnight for best results',
    socialLink: 'https://instagram.com/reel/example1',
  ),
  RecipeModel(
    id: 'r2',
    name: 'Masala Dosa',
    emoji: '🫓',
    cuisine: CuisineType.indian,
    suitableFor: [MealTime.breakfast, MealTime.snack],
    ingredients: [
      'Rice 2 cups',
      'Urad dal 1 cup',
      'Fenugreek seeds',
      'Potato filling',
      'Ghee',
    ],
    cookTimeMin: 25,
    isFavourite: true,
    socialLink: 'https://youtube.com/watch?v=example2',
  ),
  RecipeModel(
    id: 'r3',
    name: 'Pasta Arrabiata',
    emoji: '🍝',
    cuisine: CuisineType.italian,
    suitableFor: [MealTime.lunch, MealTime.dinner],
    ingredients: [
      'Pasta 200g',
      'Tomatoes 3',
      'Garlic 4 cloves',
      'Red chilli flakes',
      'Olive oil',
      'Basil',
    ],
    cookTimeMin: 20,
    isFavourite: false,
  ),
  RecipeModel(
    id: 'r4',
    name: 'Mango Lassi',
    emoji: '🥭',
    cuisine: CuisineType.indian,
    suitableFor: [MealTime.breakfast, MealTime.snack],
    ingredients: ['Mango 1', 'Yogurt 1 cup', 'Sugar 2tsp', 'Cardamom pinch'],
    cookTimeMin: 5,
    isFavourite: true,
    socialLink: 'https://instagram.com/reel/example4',
  ),
  RecipeModel(
    id: 'r5',
    name: 'Fried Rice',
    emoji: '🍳',
    cuisine: CuisineType.chinese,
    suitableFor: [MealTime.lunch, MealTime.dinner],
    ingredients: [
      'Rice 2 cups',
      'Eggs 2',
      'Mixed veg 1 cup',
      'Soy sauce 3tbsp',
      'Spring onion',
      'Sesame oil',
    ],
    cookTimeMin: 20,
    isFavourite: false,
  ),
  RecipeModel(
    id: 'r6',
    name: 'Aloo Paratha',
    emoji: '🫓',
    cuisine: CuisineType.indian,
    suitableFor: [MealTime.breakfast, MealTime.lunch],
    ingredients: [
      'Wheat flour 2 cups',
      'Potato 3 boiled',
      'Cumin seeds',
      'Coriander',
      'Green chilli',
      'Ghee',
    ],
    cookTimeMin: 30,
    isFavourite: true,
    socialLink: 'https://youtube.com/watch?v=example6',
  ),
];

// ── Family member (pantry context) ────────────────────────────────────────────

class PantryMember {
  final String id;
  final String name;
  final String emoji;
  const PantryMember({required this.id, required this.name, required this.emoji});
}

// ── Member Food Preferences ────────────────────────────────────────────────────

class MemberFoodPrefs {
  final String id;
  final String memberId;
  final String memberName;
  final String memberEmoji;
  final String walletId;
  final List<String> allergies;
  final List<String> likes;
  final List<String> dislikes;
  final List<String> mandatoryFoods;

  MemberFoodPrefs({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.memberEmoji,
    required this.walletId,
    List<String>? allergies,
    List<String>? likes,
    List<String>? dislikes,
    List<String>? mandatoryFoods,
  })  : allergies = allergies ?? [],
        likes = likes ?? [],
        dislikes = dislikes ?? [],
        mandatoryFoods = mandatoryFoods ?? [];

  /// Deserialise a Supabase row.
  factory MemberFoodPrefs.fromMap(Map<String, dynamic> m) => MemberFoodPrefs(
    id: m['id'] as String,
    memberId: m['member_id'] as String,
    memberName: m['member_name'] as String,
    memberEmoji: (m['member_emoji'] as String?) ?? '👤',
    walletId: m['wallet_id'] as String,
    allergies: (m['allergies'] as List<dynamic>?)?.cast<String>() ?? [],
    likes: (m['likes'] as List<dynamic>?)?.cast<String>() ?? [],
    dislikes: (m['dislikes'] as List<dynamic>?)?.cast<String>() ?? [],
    mandatoryFoods: (m['mandatory_foods'] as List<dynamic>?)?.cast<String>() ?? [],
  );

  MemberFoodPrefs copyWith({
    List<String>? allergies,
    List<String>? likes,
    List<String>? dislikes,
    List<String>? mandatoryFoods,
  }) => MemberFoodPrefs(
        id: id,
        memberId: memberId,
        memberName: memberName,
        memberEmoji: memberEmoji,
        walletId: walletId,
        allergies: allergies ?? List.from(this.allergies),
        likes: likes ?? List.from(this.likes),
        dislikes: dislikes ?? List.from(this.dislikes),
        mandatoryFoods: mandatoryFoods ?? List.from(this.mandatoryFoods),
      );
}

final List<MemberFoodPrefs> mockFoodPrefs = [
  MemberFoodPrefs(
    id: 'fp_me',
    memberId: 'me',
    memberName: 'Me',
    memberEmoji: '🧑',
    walletId: 'personal',
    likes: ['Biryani', 'Dosa', 'Idly'],
    dislikes: ['Bitter Gourd'],
    mandatoryFoods: ['Fruits (morning)'],
  ),
  MemberFoodPrefs(
    id: 'fp_dad',
    memberId: 'dad',
    memberName: 'Dad',
    memberEmoji: '👨',
    walletId: 'f1',
    allergies: ['Peanuts'],
    likes: ['Rice', 'Sambar'],
    dislikes: ['Spicy food'],
    mandatoryFoods: ['Curd Rice (dinner)'],
  ),
  MemberFoodPrefs(
    id: 'fp_mom',
    memberId: 'mom',
    memberName: 'Mom',
    memberEmoji: '👩',
    walletId: 'f1',
    likes: ['Chapati', 'Dal'],
    mandatoryFoods: ['Milk (morning)', 'Salad (lunch)'],
  ),
  MemberFoodPrefs(
    id: 'fp_arjun',
    memberId: 'son',
    memberName: 'Arjun',
    memberEmoji: '👦',
    walletId: 'f1',
    allergies: ['Milk', 'Eggs'],
    likes: ['Pizza', 'Pasta'],
    dislikes: ['Vegetables'],
    mandatoryFoods: ['Protein shake (morning)'],
  ),
  MemberFoodPrefs(
    id: 'fp_priya',
    memberId: 'dau',
    memberName: 'Priya',
    memberEmoji: '👧',
    walletId: 'f1',
    likes: ['Noodles', 'Fruits'],
    dislikes: ['Fish'],
  ),
];

List<GroceryItem> mockGroceries = [
  GroceryItem(
    id: 'g1',
    name: 'Tomatoes',
    category: GroceryCategory.vegetables,
    quantity: 0.5,
    unit: 'kg',
    walletId: 'personal',
    inStock: true,
    toBuy: false,
  ),
  GroceryItem(
    id: 'g2',
    name: 'Onions',
    category: GroceryCategory.vegetables,
    quantity: 1.0,
    unit: 'kg',
    walletId: 'personal',
    inStock: true,
    toBuy: false,
  ),
  GroceryItem(
    id: 'g3',
    name: 'Milk',
    category: GroceryCategory.dairy,
    quantity: 1.0,
    unit: 'L',
    walletId: 'personal',
    inStock: true,
    toBuy: false,
    expiryDate: _d(2),
  ),
  GroceryItem(
    id: 'g4',
    name: 'Paneer',
    category: GroceryCategory.dairy,
    quantity: 200,
    unit: 'g',
    walletId: 'personal',
    inStock: true,
    toBuy: false,
    expiryDate: _d(1),
  ),
  GroceryItem(
    id: 'g5',
    name: 'Rice',
    category: GroceryCategory.grains,
    quantity: 5.0,
    unit: 'kg',
    walletId: 'personal',
    inStock: true,
    toBuy: false,
  ),
  GroceryItem(
    id: 'g6',
    name: 'Dal',
    category: GroceryCategory.grains,
    quantity: 0.2,
    unit: 'kg',
    walletId: 'personal',
    inStock: true,
    toBuy: true,
  ),
  GroceryItem(
    id: 'g7',
    name: 'Butter',
    category: GroceryCategory.dairy,
    quantity: 100,
    unit: 'g',
    walletId: 'personal',
    inStock: false,
    toBuy: true,
  ),
  GroceryItem(
    id: 'g8',
    name: 'Eggs',
    category: GroceryCategory.dairy,
    quantity: 6,
    unit: 'pcs',
    walletId: 'personal',
    inStock: true,
    toBuy: false,
  ),
  GroceryItem(
    id: 'g9',
    name: 'Bread',
    category: GroceryCategory.grains,
    quantity: 1,
    unit: 'pcs',
    walletId: 'personal',
    inStock: false,
    toBuy: true,
  ),
  GroceryItem(
    id: 'g10',
    name: 'Apple',
    category: GroceryCategory.fruits,
    quantity: 4,
    unit: 'pcs',
    walletId: 'personal',
    inStock: true,
    toBuy: false,
  ),
  GroceryItem(
    id: 'g11',
    name: 'Chicken',
    category: GroceryCategory.meat,
    quantity: 500,
    unit: 'g',
    walletId: 'f1',
    inStock: true,
    toBuy: false,
  ),
  GroceryItem(
    id: 'g12',
    name: 'Basmati Rice',
    category: GroceryCategory.grains,
    quantity: 2.0,
    unit: 'kg',
    walletId: 'f1',
    inStock: true,
    toBuy: false,
  ),
];
