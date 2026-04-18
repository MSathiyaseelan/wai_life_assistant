// ─────────────────────────────────────────────────────────────────────────────
// IntentClassifier — determines which data sources are needed for a question
// ─────────────────────────────────────────────────────────────────────────────

enum DataSource { wallet, pantry, planit, functions, family, crossTab, general }

enum TimeRange { today, thisWeek, thisMonth, lastMonth, custom, allTime }

enum QueryType { summary, specific, comparison, suggestion, prediction }

class QuestionIntent {
  final Set<DataSource> dataSources;
  final TimeRange timeRange;
  final bool needsFamily;
  final QueryType queryType;

  const QuestionIntent({
    required this.dataSources,
    required this.timeRange,
    required this.needsFamily,
    required this.queryType,
  });
}

class IntentClassifier {
  IntentClassifier._();
  static final IntentClassifier instance = IntentClassifier._();

  QuestionIntent classify(String question) {
    final q = question.toLowerCase();
    final sources = <DataSource>{};

    // Wallet signals
    if (RegExp(
      r'spend|spent|expense|income|salary|balance|money|₹|paid|transaction|budget|earn|cash|transfer|lend|borrow|split|finance|credit|debit|bill|cost|price|fee|charge|pay|purchase|buy|wallet|split group|group expense|shared expense|settle up',
    ).hasMatch(q)) {
      sources.add(DataSource.wallet);
    }

    // Pantry signals
    if (RegExp(
      r'pantry|grocery|groceries|food|cook|recipe|meal|ingredient|eat|basket|shopping|buy|fridge|tobuy|instock|in stock|basket|breakfast|lunch|dinner|snack|cuisine|dish|menu',
    ).hasMatch(q)) {
      sources.add(DataSource.pantry);
    }

    // PlanIt signals
    if (RegExp(
      r'task|todo|to-do|plan|bill|remind|schedule|appointment|upcoming|due|deadline|wish|note|pending|wishlist|task|todo|to-do|plan|remind|schedule|appointment|upcoming|due|deadline|wish|note|pending',
    ).hasMatch(q)) {
      sources.add(DataSource.planit);
    }

    // Functions signals
    if (RegExp(
      r'function|upcoming function|attended function|moi|event|wedding|birthday|occasion|ceremony|attend|party|celebration',
    ).hasMatch(q)) {
      sources.add(DataSource.functions);
    }

    // Family signals
    if (RegExp(
      r'family|member|together|group|shared|husband|wife|son|daughter|parent',
    ).hasMatch(q)) {
      sources.add(DataSource.family);
      sources.add(DataSource.wallet);
    }

    // Cross-tab / summary
    if (RegExp(
      r'summarise|summary|overview|everything|all|total|overall|report',
    ).hasMatch(q)) {
      sources.add(DataSource.crossTab);
    }

    // Default: wallet + planit
    if (sources.isEmpty) {
      sources.add(DataSource.wallet);
      sources.add(DataSource.planit);
    }

    return QuestionIntent(
      dataSources: sources,
      timeRange: _detectTimeRange(q),
      needsFamily: sources.contains(DataSource.family),
      queryType: _detectQueryType(q),
    );
  }

  TimeRange _detectTimeRange(String q) {
    if (RegExp(r'today|tonight|this morning').hasMatch(q))
      return TimeRange.today;
    if (RegExp(r'this week|week').hasMatch(q)) return TimeRange.thisWeek;
    if (RegExp(r'last month|previous month').hasMatch(q))
      return TimeRange.lastMonth;
    if (RegExp(r'this month|month').hasMatch(q)) return TimeRange.thisMonth;
    if (RegExp(r'all time|ever|history').hasMatch(q)) return TimeRange.allTime;
    return TimeRange.thisMonth;
  }

  QueryType _detectQueryType(String q) {
    if (RegExp(r'how much|total|balance|amount').hasMatch(q))
      return QueryType.specific;
    if (RegExp(r'compare|vs|versus|difference|between').hasMatch(q))
      return QueryType.comparison;
    if (RegExp(
      r'suggest|recommend|should i|what if|tip|advice|help me',
    ).hasMatch(q))
      return QueryType.suggestion;
    if (RegExp(r'will|predict|forecast|next month|future').hasMatch(q))
      return QueryType.prediction;
    if (RegExp(r'summarise|summary|overview|all|report').hasMatch(q))
      return QueryType.summary;
    return QueryType.specific;
  }
}
