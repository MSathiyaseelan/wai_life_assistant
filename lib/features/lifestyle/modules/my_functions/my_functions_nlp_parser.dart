part of 'my_functions_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PARSED FUNCTION MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _ParsedFunction {
  final String title;
  final FunctionType type;
  final String? venue, personName, familyName;
  final DateTime? date;
  /// Gift given at the function, extracted from the AI response (attended_function
  /// prompt returns cash_amount/gold_grams/gift_type/etc.) — null if none found.
  final PlannedGiftItem? gift;
  const _ParsedFunction({
    required this.title,
    required this.type,
    this.venue,
    this.date,
    this.personName,
    this.familyName,
    this.gift,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// AI PARSER — routes through the shared Gemini edge function (AIParser)
// ─────────────────────────────────────────────────────────────────────────────

class _FunctionAIParser {
  static Future<_ParsedFunction> parse(String text, int tabIdx) async {
    final subFeature = tabIdx == 0
        ? 'upcoming_function'
        : tabIdx == 1
        ? 'attended_function'
        : 'my_function';
    final result = await AIParser.parseText(
      feature: 'functions',
      subFeature: subFeature,
      text: text,
    );
    if (!result.success || result.data == null)
      throw Exception(result.error ?? 'AI parse failed');
    final data = result.data!;
    DateTime? date;
    try {
      final raw = data['function_date'] ?? data['date'];
      if (raw != null &&
          raw.toString().isNotEmpty &&
          raw.toString() != 'null') {
        final parsed = DateTime.parse(raw.toString());
        // Sanity check: reject years far outside the current range (e.g. AI hallucination)
        final now = DateTime.now();
        if (parsed.year >= now.year - 1 && parsed.year <= now.year + 10) {
          date = parsed;
        } else {
          // Try to fix a 2-digit-year misparse (e.g. AI returned 2016 instead of 2026)
          final fixed = DateTime(now.year, parsed.month, parsed.day);
          if (fixed.isBefore(now)) {
            date = DateTime(now.year + 1, parsed.month, parsed.day);
          } else {
            date = fixed;
          }
        }
      }
    } catch (_) {}
    const typeMap = {
      'wedding': FunctionType.wedding,
      'birthday': FunctionType.birthday,
      'housewarming': FunctionType.houseWarming,
      'house_warming': FunctionType.houseWarming,
      'house warming': FunctionType.houseWarming,
      'naming': FunctionType.naming,
      'naming_ceremony': FunctionType.naming,
      'ear_piercing': FunctionType.earPiercing,
      'ear piercing': FunctionType.earPiercing,
      'engagement': FunctionType.engagement,
      'graduation': FunctionType.graduation,
      'anniversary': FunctionType.anniversary,
      'puberty': FunctionType.puberty,
      'puberty_ceremony': FunctionType.puberty,
    };
    // upcoming_function prompt returns 'function_type'; others return 'type'
    final rawType = (data['type'] ?? data['function_type'] as String? ?? '')
        .toString()
        .toLowerCase();
    final type = typeMap[rawType] ?? FunctionType.other;
    String? venue =
        (data['venue'] ?? data['function_venue'] ?? data['location'])
            as String?;
    if (venue == 'null' || venue == '') venue = null;
    // upcoming_function prompt returns 'contact_name'; others return 'person_name'
    String? personName =
        (data['person_name'] ??
                data['contact_name'] ??
                data['host_name'] ??
                data['person'])
            as String?;
    if (personName == 'null' || personName == '') personName = null;
    String? familyName =
        (data['family_name'] ?? data['contact_family'] ?? data['family'])
            as String?;
    if (familyName == 'null' || familyName == '') familyName = null;

    return _ParsedFunction(
      title: (data['function_name'] ?? data['title']) as String? ?? text,
      type: type,
      venue: venue,
      date: date,
      personName: personName,
      familyName: familyName,
      gift: _giftFromAiData(data),
    );
  }

  /// Maps the attended_function prompt's gift fields (gift_type, cash_amount,
  /// gold_grams, gold_approx_value, gift_description, saree_count,
  /// vessel_description, total_estimated_value, note) onto a PlannedGiftItem.
  /// Returns null when nothing gift-related was actually extracted.
  static PlannedGiftItem? _giftFromAiData(Map<String, dynamic> data) {
    final giftType = (data['gift_type'] as String?)?.toLowerCase();
    final cashAmount = (data['cash_amount'] as num?)?.toDouble();
    final goldGrams = (data['gold_grams'] as num?)?.toDouble();
    final goldValue = (data['gold_approx_value'] as num?)?.toDouble();
    final totalValue = (data['total_estimated_value'] as num?)?.toDouble();
    final giftDescription = data['gift_description'] as String?;
    final sareeCount = (data['saree_count'] as num?)?.toInt();
    final vesselDescription = data['vessel_description'] as String?;
    final note = data['note'] as String?;

    final hasAnyGiftData = cashAmount != null ||
        goldGrams != null ||
        goldValue != null ||
        totalValue != null ||
        (giftDescription != null && giftDescription.isNotEmpty) ||
        sareeCount != null ||
        (vesselDescription != null && vesselDescription.isNotEmpty);
    if (!hasAnyGiftData) return null;

    String category;
    double? amount;
    String? notes;
    switch (giftType) {
      case 'gold':
        category = 'Gold';
        amount = goldValue ?? totalValue;
        notes = goldGrams != null ? '${goldGrams}g gold' : note;
      case 'silver':
        category = 'Silver';
        amount = totalValue;
        notes = note;
      case 'saree':
      case 'clothes':
      case 'vessel_utensil':
      case 'electronics':
      case 'mixed':
      case 'other':
        category = 'Gift Item';
        amount = totalValue;
        notes = giftDescription ??
            vesselDescription ??
            (sareeCount != null ? '$sareeCount saree(s)' : note);
      case 'cash':
      default:
        category = 'Cash';
        amount = cashAmount ?? totalValue;
        notes = note;
    }

    return PlannedGiftItem(category: category, amount: amount, notes: notes);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCAL NLP PARSER  — rule-based fallback, zero network calls
// ─────────────────────────────────────────────────────────────────────────────

class _FunctionNlpParser {
  static _ParsedFunction parse(String raw, int tabIdx) {
    final text = raw.trim();
    final lower = text.toLowerCase();
    final now = DateTime.now();

    FunctionType type = FunctionType.other;
    if (lower.contains('wedding') ||
        lower.contains('marriage') ||
        lower.contains('kalyanam')) {
      type = FunctionType.wedding;
    } else if (lower.contains('birthday') || lower.contains('bday')) {
      type = FunctionType.birthday;
    } else if (lower.contains('housewarming') ||
        lower.contains('graha pravesh')) {
      type = FunctionType.houseWarming;
    } else if (lower.contains('naming') || lower.contains('name ceremony')) {
      type = FunctionType.naming;
    } else if (lower.contains('engagement') ||
        lower.contains('nichayathartham')) {
      type = FunctionType.engagement;
    } else if (lower.contains('graduation')) {
      type = FunctionType.graduation;
    } else if (lower.contains('anniversary')) {
      type = FunctionType.anniversary;
    } else if (lower.contains('ear piercing') || lower.contains('karnavedha')) {
      type = FunctionType.earPiercing;
    } else if (lower.contains('puberty') || lower.contains('seemantham')) {
      type = FunctionType.puberty;
    }

    DateTime? date;
    if (lower.contains('today')) {
      date = now;
    } else if (lower.contains('tomorrow')) {
      date = now.add(const Duration(days: 1));
    } else if (lower.contains('next week')) {
      date = now.add(const Duration(days: 7));
    } else if (lower.contains('next month')) {
      date = DateTime(now.year, now.month + 1, now.day);
    } else {
      final monthMatch = RegExp(
        r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s*(\d{1,2})?|(\d{1,2})\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)',
        caseSensitive: false,
      ).firstMatch(lower);
      if (monthMatch != null) {
        const months = {
          'jan': 1,
          'feb': 2,
          'mar': 3,
          'apr': 4,
          'may': 5,
          'jun': 6,
          'jul': 7,
          'aug': 8,
          'sep': 9,
          'oct': 10,
          'nov': 11,
          'dec': 12,
        };
        final m1 = monthMatch.group(1)?.toLowerCase().substring(0, 3);
        final m2 = monthMatch.group(4)?.toLowerCase().substring(0, 3);
        final monthKey = m1 ?? m2;
        final month = months[monthKey] ?? now.month;
        final day =
            int.tryParse(monthMatch.group(2) ?? monthMatch.group(3) ?? '') ?? 1;
        date = DateTime(now.year, month, day);
        if (date.isBefore(now)) date = DateTime(now.year + 1, month, day);
      } else {
        final onDay = RegExp(
          r'on (?:the )?(\d{1,2})(?:st|nd|rd|th)?',
        ).firstMatch(lower);
        if (onDay != null) {
          final day = int.parse(onDay.group(1)!);
          date = DateTime(now.year, now.month, day);
          if (date.isBefore(now)) date = DateTime(now.year, now.month + 1, day);
        }
      }
    }

    String? venue;
    final atMatch = RegExp(
      r'at\s+([A-Z][^,\.]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (atMatch != null) venue = atMatch.group(1)?.trim();

    String? personName;
    if (tabIdx == 0) {
      final possessive = RegExp(r"^([A-Za-z]+)'s").firstMatch(text);
      if (possessive != null) personName = possessive.group(1);
    }

    final title = personName != null
        ? "$personName's ${type.label}"
        : type != FunctionType.other
        ? type.label
        : text.split('\n').first;

    return _ParsedFunction(
      title: title,
      type: type,
      venue: venue,
      date: date,
      personName: personName,
    );
  }
}
