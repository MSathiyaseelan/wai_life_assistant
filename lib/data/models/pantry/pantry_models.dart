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

  const MealEntry({
    required this.id,
    required this.name,
    required this.mealTime,
    required this.date,
    required this.walletId,
    this.recipeId,
    this.note,
    this.emoji = '🍽️',
  });

  MealEntry copyWith({
    String? name,
    MealTime? mealTime,
    DateTime? date,
    String? note,
    String? emoji,
  }) => MealEntry(
    id: id,
    walletId: walletId,
    recipeId: recipeId,
    name: name ?? this.name,
    mealTime: mealTime ?? this.mealTime,
    date: date ?? this.date,
    note: note ?? this.note,
    emoji: emoji ?? this.emoji,
  );
}

class RecipeModel {
  final String id;
  final String name;
  final String emoji;
  final CuisineType cuisine;
  final List<MealTime> suitableFor;
  final List<String> ingredients;
  final String? socialLink;
  final String? note;
  final int? cookTimeMin;
  bool isFavourite;

  RecipeModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.cuisine,
    required this.suitableFor,
    required this.ingredients,
    this.socialLink,
    this.note,
    this.cookTimeMin,
    this.isFavourite = false,
  });
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
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();
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
