import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ── CategoryDetector ──────────────────────────────────────────────────────────
// Shared utility for keyword-based + learned category detection.
// Used by both the conversational flow and Quick Add sheet.

class CategoryDetector {
  CategoryDetector._();

  static const _learnedKey = 'wallet_cat_learned';

  // In-memory cache shared across callers
  static Map<String, String> _learned = {};
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_learnedKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _learned = decoded.cast<String, String>();
    }
    _loaded = true;
  }

  static Future<void> learn(String title, String category) async {
    final key = title.toLowerCase().trim();
    if (key.isEmpty) return;
    _learned[key] = category;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_learnedKey, jsonEncode(_learned));
  }

  /// Returns detected category or null. Pass [isIncome] based on flow type.
  static String? detect(String title, {required bool isIncome}) {
    final t = title.toLowerCase().trim();
    if (t.isEmpty) return null;

    // Learned mappings take priority
    if (_learned.containsKey(t)) return _learned[t];
    for (final entry in _learned.entries) {
      if (t.contains(entry.key) || entry.key.contains(t)) return entry.value;
    }

    bool has(List<String> kw) => kw.any((k) => t.contains(k));

    if (isIncome) {
      if (has(['salary', 'paycheck', 'wage', 'payroll'])) return '💼 Salary';
      if (has(['freelance', 'project', 'client', 'contract', 'consulting', 'gig'])) return '💻 Freelance';
      if (has(['dividend', 'stock', 'mutual', 'sip', 'interest', 'invest'])) return '📈 Investment';
      if (has(['rent', 'rental', 'lease', 'tenant'])) return '🏠 Rent';
      if (has(['bonus', 'incentive', 'reward', 'increment', 'hike'])) return '💰 Bonus';
      if (has(['refund', 'cashback', 'reimburse'])) return '🔁 Refund';
      if (has(['gift', 'present', 'birthday', 'festival', 'diwali', 'wedding'])) return '🎁 Gift';
      if (has(['business', 'revenue', 'sale', 'selling', 'earning'])) return '📦 Business';
    } else {
      if (has(['food', 'eat', 'lunch', 'dinner', 'breakfast', 'snack', 'restaurant', 'cafe', 'coffee', 'pizza', 'burger', 'grocery', 'groceries', 'meal', 'swiggy', 'zomato', 'bake', 'chai', 'tea'])) return '🍕 Food';
      if (has(['petrol', 'diesel', 'fuel', 'cab', 'uber', 'ola', 'rapido', 'metro', 'bus', 'train', 'toll', 'parking', 'flight', 'auto', 'commute', 'namma'])) return '🚗 Travel';
      if (has(['shopping', 'amazon', 'flipkart', 'meesho', 'myntra', 'purchase', 'order', 'bought', 'buy'])) return '🛒 Shopping';
      if (has(['medicine', 'medical', 'doctor', 'hospital', 'pharmacy', 'clinic', 'dental', 'tablet', 'pill', 'health', 'checkup'])) return '💊 Health';
      if (has(['movie', 'netflix', 'prime', 'hotstar', 'game', 'gaming', 'concert', 'party', 'entertainment', 'theatre'])) return '🎬 Entertainment';
      if (has(['rent', 'housing', 'maintenance', 'repair', 'plumber', 'electrician', 'society', 'house', 'home'])) return '🏠 Housing';
      if (has(['school', 'college', 'course', 'book', 'tuition', 'fee', 'exam', 'education', 'study', 'learning', 'coaching'])) return '📚 Education';
      if (has(['electric', 'internet', 'wifi', 'utility', 'gas', 'recharge', 'subscription', 'broadband', 'dth'])) return '💡 Utilities';
      if (has(['shirt', 'pant', 'dress', 'cloth', 'fashion', 'jeans', 'kurta', 'saree', 'outfit', 'wear', 'footwear', 'shoes'])) return '👕 Clothing';
      if (has(['gift', 'present', 'birthday', 'anniversary', 'wedding', 'festival', 'diwali'])) return '🎁 Gifts';
      if (has(['gym', 'yoga', 'workout', 'fitness', 'cycling', 'swim', 'run', 'zumba', 'pilates'])) return '🏋️ Fitness';
      if (has(['vacation', 'holiday', 'trip', 'tour', 'hotel', 'resort', 'beach', 'hill', 'trek', 'outing'])) return '✈️ Vacation';
    }
    return null;
  }
}
