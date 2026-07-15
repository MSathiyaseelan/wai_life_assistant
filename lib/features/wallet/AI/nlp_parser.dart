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
  final String? title;
  final String? person;
  final PayMode? payMode;
  final String? note;
  final DateTime? date;
  final double confidence; // 0–1

  /// `ai_parse_logs` row id, set only when this intent came from Gemini
  /// (not the local NLP fallback). Used to write back corrections.
  final String? parseLogId;
  /// Raw fields Gemini returned, kept so the confirm sheet can diff the
  /// user's final edits against what the AI originally said.
  final Map<String, dynamic>? aiRawData;

  const ParsedIntent({
    required this.flowType,
    this.amount,
    this.category,
    this.title,
    this.person,
    this.payMode,
    this.note,
    this.date,
    required this.confidence,
    this.parseLogId,
    this.aiRawData,
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
    // Groceries
    'grocery': 'Groceries',
    'groceries': 'Groceries',
    'vegetables': 'Groceries',
    'milk': 'Groceries',
    'rice': 'Groceries',
    'bigbasket': 'Groceries',
    'dmart': 'Groceries',
    'blinkit': 'Groceries',
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
    'netflix': 'Subscription',
    'spotify': 'Subscription',
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
    // Subscription
    'subscription': 'Subscription',
    'hotstar': 'Subscription',
    'prime': 'Subscription',
    'youtube': 'Subscription',
    'icloud': 'Subscription',
    // Income
    'salary': 'Salary',
    'freelance': 'Freelance',
    'dividend': 'Investment',
    'investment': 'Investment',
    'stocks': 'Investment',
    'sip': 'Investment',
    'mutual fund': 'Investment',
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
    String? amountToken; // matched substring, stripped later when building title

    // "5k" / "2.5k" / "1L" / "50k"
    final shortMatch = RegExp(r'(\d+(?:\.\d+)?)\s*[kK]').firstMatch(lower);
    final lakhMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*[lL](?:akh|ac)?',
    ).firstMatch(lower);
    // plain number  "500" / "1299" / "2.50"
    final numMatch = RegExp(r'\b(\d+(?:\.\d{1,2})?)\b').firstMatch(lower);

    if (lakhMatch != null) {
      amount = double.parse(lakhMatch.group(1)!) * 100000;
      amountToken = lakhMatch.group(0);
    } else if (shortMatch != null) {
      amount = double.parse(shortMatch.group(1)!) * 1000;
      amountToken = shortMatch.group(0);
    } else if (numMatch != null) {
      amount = double.parse(numMatch.group(1)!);
      amountToken = numMatch.group(0);
    } else {
      // Try word numbers  "five hundred"
      amount = _parseWordNumber(lower);
    }

    // ── 1b. Relative date extraction ──────────────────────────────────────
    // AI prompts resolve "yesterday"/"today" against the real date; the local
    // parser previously ignored these words entirely, always leaving date
    // null (→ confirm sheet defaults to DateTime.now()) even when the text
    // explicitly said otherwise.
    DateTime? date;
    String? dateToken;
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    if (lower.contains('day before yesterday')) {
      date = todayMidnight.subtract(const Duration(days: 2));
      dateToken = 'day before yesterday';
    } else if (lower.contains('yesterday')) {
      date = todayMidnight.subtract(const Duration(days: 1));
      dateToken = 'yesterday';
    } else if (lower.contains('today') || lower.contains('tonight')) {
      dateToken = lower.contains('today') ? 'today' : 'tonight';
      date = todayMidnight;
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
    String? categoryToken;
    for (final entry in _catMap.entries) {
      if (lower.contains(entry.key)) {
        category = entry.value;
        categoryToken = entry.key;
        break;
      }
    }
    // For income flows default category
    if (category == null && flowType == FlowType.income) {
      if (lower.contains('salary') || lower.contains('bonus')) {
        category = 'Salary';
      } else if (lower.contains('freelance'))
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
    String? payModeToken;
    for (final w in _onlineWords) {
      if (lower.contains(w)) {
        payMode = PayMode.online;
        payModeToken = w;
        break;
      }
    }
    if (payMode == null) {
      for (final w in _cashWords) {
        if (lower.contains(w)) {
          payMode = PayMode.cash;
          payModeToken = w;
          break;
        }
      }
    }

    // ── 6. Title — whatever's left after stripping every matched token,
    // e.g. "oil 220 yesterday in gpay" → "Oil". Falls back to null (blank
    // title, user fills it in) rather than ever dumping the raw input into
    // note like this used to.
    var remaining = ' $lower ';
    void strip(String? token) {
      if (token == null || token.isEmpty) return;
      remaining = remaining.replaceAll(' $token ', '  ');
    }

    strip(amountToken);
    strip(dateToken);
    strip(categoryToken);
    strip(payModeToken);
    if (person != null) {
      remaining = remaining.replaceAll(
        RegExp(
          r'\b(?:to|from|with|lent to|borrowed from|gave to|split with|for)\s+' +
              RegExp.escape(person.toLowerCase()) +
              r'\b',
        ),
        ' ',
      );
    }
    const fillerWords = [
      'in', 'on', 'at', 'via', 'using', 'through', 'with', 'for',
      'the', 'a', 'an', 'rs', 'rs.', 'inr', 'and',
    ];
    for (final f in fillerWords) {
      strip(f);
    }

    final titleWords = remaining
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty && double.tryParse(w) == null)
        .toList();
    final title = titleWords.isEmpty
        ? null
        : titleWords
            .map((w) => w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''))
            .join(' ');

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
      title: title,
      person: person,
      payMode: payMode,
      date: date,
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
