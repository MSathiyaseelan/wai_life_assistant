import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTRY NLP PARSER
//
// Parses natural-language pantry input into one of three intents:
//   meal    → "had idli for breakfast", "paneer butter masala for dinner"
//   recipe  → "save pasta recipe", "add butter chicken recipe"
//   basket  → "add milk 2L", "buy onions 1kg", "need 3 eggs"
//
// Returns PantryIntent with:
//   kind        — meal | recipe | basket
//   mealName    — extracted dish name
//   mealTime    — breakfast / lunch / snack / dinner
//   mealDate    — today / tomorrow / specific day
//   recipeName  — name of recipe to save
//   groceryName — item name for basket
//   qty / unit  — "2" "L", "500" "g", "3" "pcs"
//   groceryCat  — inferred grocery category
//   confidence  — 0.0–1.0
// ─────────────────────────────────────────────────────────────────────────────

enum PantryIntentKind { meal, recipe, basket }

class PantryIntent {
  final PantryIntentKind kind;
  // meal fields
  final String? mealName;
  final MealTime? mealTime;
  final DateTime? mealDate;
  // recipe fields
  final String? recipeName;
  // basket fields
  final String? groceryName;
  final double? qty;
  final String? unit;
  final GroceryCategory? groceryCat;
  // meta
  final double confidence;

  const PantryIntent({
    required this.kind,
    this.mealName,
    this.mealTime,
    this.mealDate,
    this.recipeName,
    this.groceryName,
    this.qty,
    this.unit,
    this.groceryCat,
    required this.confidence,
  });
}

class PantryNlpParser {
  // ── Intent trigger words ────────────────────────────────────────────────────
  static const _mealTriggers = [
    'had',
    'ate',
    'eat',
    'having',
    'cooked',
    'made',
    'prepared',
    'meal',
    'food for',
    'lunch',
    'dinner',
    'breakfast',
    'snack',
    'brunch',
  ];
  static const _recipeTriggers = [
    'recipe',
    'how to make',
    'how to cook',
    'method for',
    'steps for',
    'save recipe',
    'add recipe',
  ];
  static const _basketTriggers = [
    'add',
    'buy',
    'get',
    'need',
    'purchase',
    'order',
    'pick up',
    'stock',
    'shopping',
    'basket',
    'list',
  ];

  // ── Meal time keywords ─────────────────────────────────────────────────────
  static const _mtMap = {
    'breakfast': MealTime.breakfast,
    'morning': MealTime.breakfast,
    'lunch': MealTime.lunch,
    'afternoon': MealTime.lunch,
    'noon': MealTime.lunch,
    'snack': MealTime.snack,
    'evening': MealTime.snack,
    'tea time': MealTime.snack,
    'dinner': MealTime.dinner,
    'night': MealTime.dinner,
    'supper': MealTime.dinner,
    'brunch': MealTime.breakfast,
  };

  // ── Grocery category keyword map ──────────────────────────────────────────
  static const _catMap = <String, GroceryCategory>{
    // Vegetables
    'onion': GroceryCategory.vegetables, 'tomato': GroceryCategory.vegetables,
    'potato': GroceryCategory.vegetables, 'carrot': GroceryCategory.vegetables,
    'beans': GroceryCategory.vegetables, 'spinach': GroceryCategory.vegetables,
    'cabbage': GroceryCategory.vegetables,
    'broccoli': GroceryCategory.vegetables,
    'capsicum': GroceryCategory.vegetables,
    'pepper': GroceryCategory.vegetables,
    'garlic': GroceryCategory.vegetables, 'ginger': GroceryCategory.vegetables,
    'vegetable': GroceryCategory.vegetables,
    'veggies': GroceryCategory.vegetables,
    // Fruits
    'apple': GroceryCategory.fruits, 'banana': GroceryCategory.fruits,
    'mango': GroceryCategory.fruits, 'orange': GroceryCategory.fruits,
    'grapes': GroceryCategory.fruits, 'lemon': GroceryCategory.fruits,
    'fruit': GroceryCategory.fruits, 'fruits': GroceryCategory.fruits,
    // Dairy
    'milk': GroceryCategory.dairy, 'curd': GroceryCategory.dairy,
    'yogurt': GroceryCategory.dairy, 'butter': GroceryCategory.dairy,
    'cheese': GroceryCategory.dairy, 'paneer': GroceryCategory.dairy,
    'cream': GroceryCategory.dairy, 'ghee': GroceryCategory.dairy,
    'egg': GroceryCategory.dairy, 'eggs': GroceryCategory.dairy,
    // Meat
    'chicken': GroceryCategory.meat, 'mutton': GroceryCategory.meat,
    'fish': GroceryCategory.meat, 'prawn': GroceryCategory.meat,
    'beef': GroceryCategory.meat, 'pork': GroceryCategory.meat,
    'meat': GroceryCategory.meat,
    // Grains
    'rice': GroceryCategory.grains, 'wheat': GroceryCategory.grains,
    'flour': GroceryCategory.grains, 'dal': GroceryCategory.grains,
    'lentil': GroceryCategory.grains, 'oats': GroceryCategory.grains,
    'bread': GroceryCategory.grains, 'roti': GroceryCategory.grains,
    'pasta': GroceryCategory.grains, 'noodles': GroceryCategory.grains,
    // Beverages
    'water': GroceryCategory.beverages, 'juice': GroceryCategory.beverages,
    'tea': GroceryCategory.beverages, 'coffee': GroceryCategory.beverages,
    'soft drink': GroceryCategory.beverages, 'cola': GroceryCategory.beverages,
    'drink': GroceryCategory.beverages,
    // Spices
    'salt': GroceryCategory.spices, 'sugar': GroceryCategory.spices,
    'spice': GroceryCategory.spices, 'turmeric': GroceryCategory.spices,
    'cumin': GroceryCategory.spices, 'masala': GroceryCategory.spices,
    'chili': GroceryCategory.spices, 'pepper powder': GroceryCategory.spices,
    // Snacks
    'biscuit': GroceryCategory.snacks, 'chips': GroceryCategory.snacks,
    'chocolate': GroceryCategory.snacks, 'candy': GroceryCategory.snacks,
    'snack': GroceryCategory.snacks, 'cookie': GroceryCategory.snacks,
    // Cleaning
    'soap': GroceryCategory.cleaning, 'detergent': GroceryCategory.cleaning,
    'shampoo': GroceryCategory.cleaning, 'dish wash': GroceryCategory.cleaning,
    'cleanser': GroceryCategory.cleaning,
  };

  // ── Unit keywords ─────────────────────────────────────────────────────────
  static const _units = [
    'kg',
    'g',
    'gm',
    'gram',
    'grams',
    'l',
    'ltr',
    'litre',
    'liters',
    'ml',
    'pcs',
    'pieces',
    'piece',
    'dozen',
    'pack',
    'packet',
    'bottle',
    'box',
    'bag',
    'bunch',
  ];

  // ── Meal emojis for known dishes ─────────────────────────────────────────
  static const _dishEmoji = <String, String>{
    'idli': '🫙',
    'dosa': '🥞',
    'poha': '🍛',
    'upma': '🍲',
    'rice': '🍚',
    'biryani': '🍛',
    'dal': '🫕',
    'curry': '🫕',
    'roti': '🫓',
    'paratha': '🥞',
    'sabzi': '🥘',
    'sambar': '🫙',
    'chai': '☕',
    'coffee': '☕',
    'juice': '🧃',
    'milk': '🥛',
    'salad': '🥗',
    'sandwich': '🥪',
    'burger': '🍔',
    'pizza': '🍕',
    'pasta': '🍝',
    'noodles': '🍜',
    'soup': '🍜',
    'egg': '🥚',
    'oats': '🥣',
    'cereal': '🥣',
    'smoothie': '🥤',
    'paneer': '🫕',
    'chicken': '🍗',
    'fish': '🐟',
    'mutton': '🥩',
    'prawn': '🦐',
    'payasam': '🍮',
    'kheer': '🍮',
    'halwa': '🍮',
    'ladoo': '🍡',
  };

  // ─────────────────────────────────────────────────────────────────────────
  static PantryIntent parse(String raw) {
    final text = raw.trim();
    final lower = text.toLowerCase();

    // ── 1. Determine kind ────────────────────────────────────────────────────
    PantryIntentKind kind = PantryIntentKind.meal; // default
    int score = 0;

    for (final w in _recipeTriggers) {
      if (lower.contains(w)) {
        kind = PantryIntentKind.recipe;
        score += 2;
        break;
      }
    }
    if (score == 0) {
      for (final w in _basketTriggers) {
        if (lower.contains(w) && !_mealTriggers.any((m) => lower.contains(m))) {
          kind = PantryIntentKind.basket;
          score++;
          break;
        }
      }
    }
    if (score == 0) {
      for (final w in _mealTriggers) {
        if (lower.contains(w)) {
          kind = PantryIntentKind.meal;
          score++;
          break;
        }
      }
    }

    // ── 2. Parse by kind ─────────────────────────────────────────────────────
    switch (kind) {
      case PantryIntentKind.meal:
        return _parseMeal(text, lower, score);
      case PantryIntentKind.recipe:
        return _parseRecipe(text, lower, score);
      case PantryIntentKind.basket:
        return _parseBasket(text, lower, score);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  static PantryIntent _parseMeal(String text, String lower, int baseScore) {
    // Meal time
    MealTime? mt;
    for (final e in _mtMap.entries) {
      if (lower.contains(e.key)) {
        mt = e.value;
        baseScore++;
        break;
      }
    }

    // Date
    DateTime? date;
    if (lower.contains('tomorrow')) {
      date = DateTime.now().add(const Duration(days: 1));
    } else if (lower.contains('yesterday')) {
      date = DateTime.now().subtract(const Duration(days: 1));
    } else {
      date = DateTime.now();
    }

    // Strip trigger/time/date words to extract dish name
    var name = lower;
    for (final w in [
      ..._mealTriggers,
      ..._mtMap.keys,
      'today',
      'tomorrow',
      'yesterday',
      'tonight',
      'this morning',
      'for',
      'had',
      'ate',
      'having',
      'add',
      'log',
    ]) {
      name = name.replaceAll(w, ' ');
    }
    name = name.trim().replaceAll(RegExp(r'\s+'), ' ').trim();
    // Title-case
    if (name.isNotEmpty) {
      name = name
          .split(' ')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }

    // Emoji
    String emoji = '🍽️';
    for (final e in _dishEmoji.entries) {
      if (lower.contains(e.key)) {
        emoji = e.value;
        break;
      }
    }

    final confidence =
        ((name.isNotEmpty ? 0.4 : 0.1) +
                (mt != null ? 0.4 : 0.0) +
                (baseScore > 0 ? 0.2 : 0.0))
            .clamp(0.0, 1.0);

    return PantryIntent(
      kind: PantryIntentKind.meal,
      mealName: name.isEmpty ? null : name,
      mealTime: mt ?? MealTime.lunch,
      mealDate: date,
      confidence: confidence,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  static PantryIntent _parseRecipe(String text, String lower, int baseScore) {
    var name = lower;
    for (final w in _recipeTriggers) name = name.replaceAll(w, ' ');
    name = name.trim().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (name.isNotEmpty) {
      name = name
          .split(' ')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }

    return PantryIntent(
      kind: PantryIntentKind.recipe,
      recipeName: name.isEmpty ? null : name,
      confidence: (name.isNotEmpty ? 0.7 : 0.3).clamp(0.0, 1.0),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  static PantryIntent _parseBasket(String text, String lower, int baseScore) {
    // Qty + unit
    double? qty;
    String? unit;

    // "2 kg" / "500g" / "1.5L" / "3 pcs"
    final qtyMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*(' + _units.join('|') + r')\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (qtyMatch != null) {
      qty = double.tryParse(qtyMatch.group(1)!);
      unit = _normaliseUnit(qtyMatch.group(2)!.toLowerCase());
    } else {
      // Just a number like "3 eggs"
      final numOnly = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(lower);
      if (numOnly != null) qty = double.tryParse(numOnly.group(1)!);
      unit = 'pcs';
    }

    // Category
    GroceryCategory? cat;
    for (final e in _catMap.entries) {
      if (lower.contains(e.key)) {
        cat = e.value;
        break;
      }
    }

    // Strip trigger/qty/unit words to get item name
    var name = lower;
    for (final w in _basketTriggers) name = name.replaceAll(w, ' ');
    // remove number+unit
    name = name.replaceAll(
      RegExp(
        r'\d+(?:\.\d+)?\s*(?:' + _units.join('|') + r')?\b',
        caseSensitive: false,
      ),
      ' ',
    );
    name = name.replaceAll(RegExp(r'\b\d+\b'), ' ');
    name = name.trim().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (name.isNotEmpty) {
      name = name
          .split(' ')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }

    final confidence =
        ((name.isNotEmpty ? 0.4 : 0.1) +
                (qty != null ? 0.3 : 0.0) +
                (cat != null ? 0.3 : 0.0))
            .clamp(0.0, 1.0);

    return PantryIntent(
      kind: PantryIntentKind.basket,
      groceryName: name.isEmpty ? null : name,
      qty: qty ?? 1,
      unit: unit ?? 'pcs',
      groceryCat: cat ?? GroceryCategory.other,
      confidence: confidence,
    );
  }

  static String _normaliseUnit(String u) {
    switch (u) {
      case 'gram':
      case 'grams':
      case 'gm':
        return 'g';
      case 'litre':
      case 'liters':
      case 'ltr':
        return 'L';
      case 'pieces':
      case 'piece':
        return 'pcs';
      default:
        return u;
    }
  }
}
