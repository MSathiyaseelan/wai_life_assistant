import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';

/// Item-specific emoji for common groceries, keyed by normalized name
/// (lowercase, singular — see normalizeIngredientName). Only emoji from
/// Unicode 13 or earlier, so they render on older Android versions too
/// (newer ones like 🫚 ginger / 🫘 beans show as blank boxes there).
const _groceryEmoji = <String, String>{
  // Vegetables
  'onion': '🧅', 'big onion': '🧅', 'small onion': '🧅', 'shallot': '🧅',
  'tomato': '🍅', 'potato': '🥔', 'carrot': '🥕', 'garlic': '🧄',
  'chilli': '🌶️', 'chili': '🌶️', 'green chilli': '🌶️', 'red chilli': '🌶️',
  'mirchi': '🌶️', 'capsicum': '🫑', 'bell pepper': '🫑',
  'cucumber': '🥒', 'brinjal': '🍆', 'eggplant': '🍆', 'corn': '🌽',
  'sweet corn': '🌽', 'broccoli': '🥦', 'cauliflower': '🥦',
  'mushroom': '🍄', 'cabbage': '🥬', 'lettuce': '🥬', 'spinach': '🥬',
  'palak': '🥬', 'keerai': '🥬', 'coriander': '🌿', 'mint': '🌿',
  'curry leaf': '🌿', 'curry leave': '🌿', 'sweet potato': '🍠',
  'avocado': '🥑', 'pumpkin': '🎃', 'lemon': '🍋', 'lime': '🍋',
  'coconut': '🥥', 'olive': '🫒',
  // Fruits
  'apple': '🍎', 'green apple': '🍏', 'banana': '🍌', 'mango': '🥭',
  'orange': '🍊', 'grape': '🍇', 'watermelon': '🍉', 'melon': '🍈',
  'muskmelon': '🍈', 'pineapple': '🍍', 'strawberry': '🍓', 'cherry': '🍒',
  'peach': '🍑', 'pear': '🍐', 'kiwi': '🥝', 'blueberry': '🫐',
  // Dairy & eggs
  'milk': '🥛', 'cheese': '🧀', 'paneer': '🧀', 'butter': '🧈',
  'ghee': '🧈', 'egg': '🥚', 'ice cream': '🍨',
  // Meat & seafood
  'chicken': '🍗', 'chicken breast': '🍗', 'mutton': '🥩', 'meat': '🥩',
  'beef': '🥩', 'lamb': '🥩', 'pork': '🥩', 'fish': '🐟', 'prawn': '🦐',
  'shrimp': '🦐', 'crab': '🦀', 'squid': '🦑', 'bacon': '🥓',
  // Grains & staples
  'rice': '🍚', 'basmati': '🍚', 'poha': '🍚', 'bread': '🍞', 'bun': '🍞',
  'wheat': '🌾', 'atta': '🌾', 'flour': '🌾', 'maida': '🌾', 'rava': '🌾',
  'sooji': '🌾', 'semolina': '🌾', 'noodle': '🍜', 'pasta': '🍝',
  'spaghetti': '🍝', 'cereal': '🥣', 'corn flake': '🥣', 'oat': '🥣',
  'tortilla': '🫓', 'roti': '🫓', 'chapati': '🫓',
  // Snacks & sweets
  'biscuit': '🍪', 'cookie': '🍪', 'cooky': '🍪', 'chocolate': '🍫',
  'cake': '🍰', 'candy': '🍬', 'popcorn': '🍿', 'chip': '🍟',
  'peanut': '🥜', 'groundnut': '🥜', 'nut': '🥜', 'almond': '🥜',
  'cashew': '🥜', 'pretzel': '🥨', 'honey': '🍯', 'jam': '🍯',
  // Beverages
  'coffee': '☕', 'tea': '🍵', 'green tea': '🍵', 'juice': '🧃',
  'soda': '🥤', 'cola': '🥤', 'soft drink': '🥤', 'water': '💧',
  'beer': '🍺', 'wine': '🍷',
  // Spices & condiments
  'salt': '🧂', 'olive oil': '🫒',
  // Cleaning & household
  'soap': '🧼', 'sponge': '🧽', 'tissue': '🧻', 'toilet paper': '🧻',
  'detergent': '🧴', 'shampoo': '🧴', 'handwash': '🧴', 'dishwash': '🧴',
  'toothbrush': '🦷', 'toothpaste': '🦷', 'broom': '🧹', 'bucket': '🪣',
  'battery': '🔋', 'bulb': '💡', 'candle': '🕯️',
};

/// Emoji for a specific grocery ("Red onion" → 🧅), falling back to its
/// [category] emoji. [normalizedName] is the item's normalized key. Matches
/// the whole name first, then just its last one or two words (the main
/// noun: "basmati rice" → rice) — never an earlier word, so "coconut oil"
/// doesn't become 🥥.
String groceryEmojiFor(String normalizedName, GroceryCategory category) {
  final key = normalizedName.toLowerCase().trim();
  final direct = _groceryEmoji[key];
  if (direct != null) return direct;
  final words = key.split(' ');
  if (words.length > 2) {
    final lastTwo = _groceryEmoji[words.sublist(words.length - 2).join(' ')];
    if (lastTwo != null) return lastTwo;
  }
  if (words.length > 1) {
    final last = _groceryEmoji[words.last];
    if (last != null) return last;
  }
  return category.emoji;
}

extension GroceryItemEmoji on GroceryItem {
  /// See [groceryEmojiFor].
  String get displayEmoji => groceryEmojiFor(effectiveNormalizedName, category);
}
