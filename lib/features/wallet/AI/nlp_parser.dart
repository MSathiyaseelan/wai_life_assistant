import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/data/models/wallet/flow_models.dart';
// ─────────────────────────────────────────────────────────────────────────────
// NLP PARSER  — parses a natural-language transaction string
//
// Returns a ParsedIntent with:
//   • flowType   — detected intent (expense/income/lend/borrow/split/request)
//   • amount     — extracted number (₹500, 500, 5k, five hundred…)
//   • category   — matched category keyword
//   • person     — name after "to/from/with/for"
//   • payMode    — cash / online / upi / gpay / neft…
//   • note       — leftover text after all extractions
//   • confidence — 0.0–1.0  (drives whether to show confirm or flow selector)
// ─────────────────────────────────────────────────────────────────────────────

class ParsedIntent {
  final FlowType flowType;
  final double? amount;
  final String? category;
  final String? person;
  final PayMode? payMode;
  final String? note;
  final double confidence; // 0–1

  const ParsedIntent({
    required this.flowType,
    this.amount,
    this.category,
    this.person,
    this.payMode,
    this.note,
    required this.confidence,
  });
}

class NlpParser {
  // ── Category keyword map ──────────────────────────────────────────────────
  static const _catMap = {
    // Food & drink
    'food': 'Food',
    'lunch': 'Food',
    'dinner': 'Food',
    'breakfast': 'Food',
    'coffee': 'Food',
    'tea': 'Food',
    'snack': 'Food',
    'restaurant': 'Food',
    'hotel': 'Food',
    'zomato': 'Food',
    'swiggy': 'Food',
    'biryani': 'Food',
    'pizza': 'Food',
    'chai': 'Food',
    // Grocery
    'grocery': 'Grocery',
    'groceries': 'Grocery',
    'vegetables': 'Grocery',
    'milk': 'Grocery',
    'rice': 'Grocery',
    'bigbasket': 'Grocery',
    'dmart': 'Grocery',
    'blinkit': 'Grocery',
    // Travel
    'travel': 'Travel',
    'auto': 'Travel',
    'cab': 'Travel',
    'uber': 'Travel',
    'ola': 'Travel',
    'bus': 'Travel',
    'train': 'Travel',
    'flight': 'Travel',
    'petrol': 'Travel',
    'fuel': 'Travel',
    'toll': 'Travel',
    // Shopping
    'shopping': 'Shopping',
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'clothes': 'Shopping',
    'shirt': 'Shopping',
    'shoes': 'Shopping',
    // Entertainment
    'movie': 'Entertainment',
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
    'game': 'Entertainment',
    'cinema': 'Entertainment',
    'theatre': 'Entertainment',
    // Bills & utilities
    'bill': 'Bills',
    'electricity': 'Bills',
    'water': 'Bills',
    'gas': 'Bills',
    'internet': 'Bills',
    'wifi': 'Bills',
    'phone': 'Bills',
    'mobile': 'Bills',
    'recharge': 'Bills',
    // Health
    'medicine': 'Health',
    'medical': 'Health',
    'doctor': 'Health',
    'hospital': 'Health',
    'pharmacy': 'Health',
    'tablet': 'Health',
    // Income
    'salary': 'Salary',
    'freelance': 'Freelance',
    'dividend': 'Investment',
    'rent': 'Rent',
    'bonus': 'Salary',
  };

  // ── Intent keyword map ────────────────────────────────────────────────────
  static const _intentExpense = [
    'paid',
    'pay',
    'spent',
    'spend',
    'bought',
    'buy',
    'purchased',
    'purchase',
    'expense',
    'cost',
    'charged',
    'deducted',
    'debited',
  ];
  static const _intentIncome = [
    'received',
    'got',
    'earned',
    'income',
    'salary',
    'credited',
    'deposited',
    'refund',
    'reimbursed',
    'returned money',
  ];
  static const _intentLend = ['lent', 'lend', 'gave', 'given', 'loaned'];
  static const _intentBorrow = [
    'borrowed',
    'borrow',
    'took from',
    'taken from',
  ];
  static const _intentSplit = ['split', 'shared', 'share', 'divided', 'dutch'];
  static const _intentRequest = ['request', 'asking', 'owed', 'owes'];

  // ── PayMode keywords ──────────────────────────────────────────────────────
  static const _cashWords = ['cash', 'note', 'coin', 'hand'];
  static const _onlineWords = [
    'online',
    'upi',
    'gpay',
    'googlepay',
    'phonepay',
    'phonepe',
    'paytm',
    'neft',
    'imps',
    'card',
    'net banking',
    'netbanking',
    'transfer',
    'bank',
  ];

  // ── Word numbers ──────────────────────────────────────────────────────────
  static const _wordNums = {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
    'hundred': 100,
    'thousand': 1000,
    'lakh': 100000,
    'lac': 100000,
  };

  // ─────────────────────────────────────────────────────────────────────────
  static ParsedIntent parse(String raw) {
    final text = raw.trim();
    final lower = text.toLowerCase().replaceAll('₹', '').replaceAll(',', '');

    // ── 1. Amount extraction ──────────────────────────────────────────────
    double? amount;

    // "5k" / "2.5k" / "1L" / "50k"
    final shortMatch = RegExp(r'(\d+(?:\.\d+)?)\s*[kK]').firstMatch(lower);
    final lakhMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*[lL](?:akh|ac)?',
    ).firstMatch(lower);
    // plain number  "500" / "1299" / "2.50"
    final numMatch = RegExp(r'\b(\d+(?:\.\d{1,2})?)\b').firstMatch(lower);

    if (lakhMatch != null) {
      amount = double.parse(lakhMatch.group(1)!) * 100000;
    } else if (shortMatch != null) {
      amount = double.parse(shortMatch.group(1)!) * 1000;
    } else if (numMatch != null) {
      amount = double.parse(numMatch.group(1)!);
    } else {
      // Try word numbers  "five hundred"
      amount = _parseWordNumber(lower);
    }

    // ── 2. Flow type detection ────────────────────────────────────────────
    FlowType flowType = FlowType.expense; // default
    int typeScore = 0;

    void tryMatch(List<String> words, FlowType ft) {
      for (final w in words) {
        if (lower.contains(w)) {
          flowType = ft;
          typeScore++;
          return;
        }
      }
    }

    // Check in priority order — more specific first
    tryMatch(_intentLend, FlowType.lend);
    tryMatch(_intentBorrow, FlowType.borrow);
    tryMatch(_intentSplit, FlowType.split);
    tryMatch(_intentRequest, FlowType.request);
    if (typeScore == 0) {
      tryMatch(_intentIncome, FlowType.income);
      tryMatch(_intentExpense, FlowType.expense);
    }

    // ── 3. Category detection ─────────────────────────────────────────────
    String? category;
    for (final entry in _catMap.entries) {
      if (lower.contains(entry.key)) {
        category = entry.value;
        break;
      }
    }
    // For income flows default category
    if (category == null && flowType == FlowType.income) {
      if (lower.contains('salary') || lower.contains('bonus'))
        category = 'Salary';
      else if (lower.contains('freelance'))
        category = 'Freelance';
      else
        category = 'Income';
    }

    // ── 4. Person extraction — name after "to/from/with/for/by" ──────────
    String? person;
    final personMatch = RegExp(
      r'(?:to|from|with|lent to|borrowed from|gave to|split with|for)\s+([A-Z][a-z]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (personMatch != null) {
      person = personMatch.group(1);
    }

    // ── 5. PayMode ────────────────────────────────────────────────────────
    PayMode? payMode;
    for (final w in _onlineWords) {
      if (lower.contains(w)) {
        payMode = PayMode.online;
        break;
      }
    }
    if (payMode == null) {
      for (final w in _cashWords) {
        if (lower.contains(w)) {
          payMode = PayMode.cash;
          break;
        }
      }
    }

    // ── 6. Note — strip matched tokens, keep rest as note ─────────────────
    // Simple approach: use original text as note if it has useful info
    final noteText = text.length > 4 ? text : null;

    // ── 7. Confidence score ───────────────────────────────────────────────
    double confidence = 0.0;
    if (amount != null && amount > 0) confidence += 0.5;
    if (typeScore > 0) confidence += 0.25;
    if (category != null) confidence += 0.15;
    if (payMode != null) confidence += 0.10;

    return ParsedIntent(
      flowType: flowType,
      amount: amount,
      category: category,
      person: person,
      payMode: payMode,
      note: noteText,
      confidence: confidence.clamp(0.0, 1.0),
    );
  }

  static double? _parseWordNumber(String text) {
    double total = 0;
    double current = 0;
    bool found = false;
    for (final entry in _wordNums.entries) {
      if (text.contains(entry.key)) {
        found = true;
        final v = entry.value.toDouble();
        if (v == 100) {
          current = current == 0 ? 100 : current * 100;
        } else if (v >= 1000) {
          current = current == 0 ? v : current * v;
          total += current;
          current = 0;
        } else {
          current += v;
        }
      }
    }
    total += current;
    return found && total > 0 ? total : null;
  }
}
