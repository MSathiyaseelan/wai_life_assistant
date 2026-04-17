import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/supabase/task_service.dart';
import 'package:wai_life_assistant/core/supabase/pantry_service.dart';
import 'package:wai_life_assistant/core/supabase/functions_service.dart';
import 'intent_classifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HouseholdContext — aggregated data passed to the AI
// ─────────────────────────────────────────────────────────────────────────────

class HouseholdContext {
  final Map<String, dynamic> wallet;
  final Map<String, dynamic> pantry;
  final Map<String, dynamic> planit;
  final Map<String, dynamic> functions;
  final Map<String, dynamic> family;

  const HouseholdContext({
    this.wallet = const {},
    this.pantry = const {},
    this.planit = const {},
    this.functions = const {},
    this.family = const {},
  });

  String toPromptBlock() {
    final buf = StringBuffer();
    if (wallet.isNotEmpty) {
      buf.writeln('=== WALLET ===');
      wallet.forEach((k, v) => buf.writeln('$k: $v'));
      buf.writeln();
    }
    if (pantry.isNotEmpty) {
      buf.writeln('=== PANTRY ===');
      pantry.forEach((k, v) => buf.writeln('$k: $v'));
      buf.writeln();
    }
    if (planit.isNotEmpty) {
      buf.writeln('=== PLANIT ===');
      planit.forEach((k, v) => buf.writeln('$k: $v'));
      buf.writeln();
    }
    if (functions.isNotEmpty) {
      buf.writeln('=== FUNCTIONS ===');
      functions.forEach((k, v) => buf.writeln('$k: $v'));
      buf.writeln();
    }
    if (family.isNotEmpty) {
      buf.writeln('=== FAMILY ===');
      family.forEach((k, v) => buf.writeln('$k: $v'));
      buf.writeln();
    }
    return buf.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ContextFetcher — pulls data from Supabase based on detected intents
// ─────────────────────────────────────────────────────────────────────────────

class ContextFetcher {
  ContextFetcher._();
  static final ContextFetcher instance = ContextFetcher._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<HouseholdContext> fetch(
    QuestionIntent intent,
    String walletId,
  ) async {
    final sources = intent.dataSources;
    final isCrossTab = sources.contains(DataSource.crossTab);

    final fetchWallet = sources.contains(DataSource.wallet) || isCrossTab;
    final fetchPantry = sources.contains(DataSource.pantry) || isCrossTab;
    final fetchPlanit = sources.contains(DataSource.planit) || isCrossTab;
    final fetchFunctions = sources.contains(DataSource.functions) || isCrossTab;
    final fetchFamily = sources.contains(DataSource.family);

    final results = await Future.wait([
      fetchWallet ? _fetchWallet(walletId, intent.timeRange) : Future.value(<String, dynamic>{}),
      fetchPantry ? _fetchPantry(walletId) : Future.value(<String, dynamic>{}),
      fetchPlanit ? _fetchPlanit(walletId) : Future.value(<String, dynamic>{}),
      fetchFunctions ? _fetchFunctions(walletId) : Future.value(<String, dynamic>{}),
      fetchFamily ? _fetchFamily(walletId) : Future.value(<String, dynamic>{}),
    ]);

    return HouseholdContext(
      wallet: results[0],
      pantry: results[1],
      planit: results[2],
      functions: results[3],
      family: results[4],
    );
  }

  Future<Map<String, dynamic>> _fetchWallet(String walletId, TimeRange range) async {
    try {
      final now = DateTime.now();
      final String fromDate;
      switch (range) {
        case TimeRange.today:
          fromDate = now.toIso8601String().substring(0, 10);
        case TimeRange.thisWeek:
          fromDate = now.subtract(const Duration(days: 7)).toIso8601String().substring(0, 10);
        case TimeRange.lastMonth:
          fromDate = DateTime(now.year, now.month - 1, 1).toIso8601String().substring(0, 10);
        default:
          fromDate = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
      }

      final rows = await _db
          .from('transactions')
          .select('type, amount, category, title, date')
          .eq('wallet_id', walletId)
          .gte('date', fromDate)
          .order('date', ascending: false)
          .limit(50);

      double income = 0, expense = 0, lend = 0;
      final catTotals = <String, double>{};
      final recent = <String>[];

      for (final r in rows) {
        final type = r['type'] as String? ?? '';
        final amount = (r['amount'] as num?)?.toDouble() ?? 0;
        final cat = r['category'] as String? ?? '';
        final title = r['title'] as String? ?? cat;

        if (type == 'income') income += amount;
        if (type == 'expense') {
          expense += amount;
          catTotals[cat] = (catTotals[cat] ?? 0) + amount;
        }
        if (type == 'lend') lend += amount;
        if (recent.length < 5) {
          recent.add('${_cap(title)} ₹${amount.toStringAsFixed(0)} ($type)');
        }
      }

      final topCats = (catTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(3)
          .map((e) => '${_cap(e.key)} ₹${e.value.toStringAsFixed(0)}')
          .join(', ');

      return {
        'income': '₹${income.toStringAsFixed(0)}',
        'expenses': '₹${expense.toStringAsFixed(0)}',
        'net': '₹${(income - expense).toStringAsFixed(0)}',
        if (lend > 0) 'outstanding_lends': '₹${lend.toStringAsFixed(0)}',
        if (topCats.isNotEmpty) 'top_categories': topCats,
        if (recent.isNotEmpty) 'recent_transactions': recent.join(' | '),
      };
    } catch (e) {
      debugPrint('[ContextFetcher] _fetchWallet error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchPantry(String walletId) async {
    try {
      final rows = await PantryService.instance.fetchGroceryItems(walletId);

      final pending = rows
          .where((r) => r['is_purchased'] != true)
          .take(15)
          .map((r) {
        final name = r['name'] as String? ?? '';
        final qty = r['qty'] as num?;
        final unit = r['unit'] as String? ?? '';
        return qty != null ? '$name ${qty.toStringAsFixed(0)}$unit' : name;
      }).where((s) => s.isNotEmpty).toList();

      List<Map<String, dynamic>> mealRows = [];
      try {
        final raw = await _db
            .from('meal_entries')
            .select('meal_name, meal_type, logged_at')
            .eq('wallet_id', walletId)
            .order('logged_at', ascending: false)
            .limit(5);
        mealRows = List<Map<String, dynamic>>.from(raw);
      } catch (e) {
        debugPrint('[ContextFetcher] meal_entries error: $e');
      }

      final meals = mealRows
          .map((r) => '${r['meal_name']} (${r['meal_type']})')
          .toList();

      return {
        'shopping_list': pending.isEmpty ? 'empty' : pending.join(', '),
        'shopping_count': pending.length,
        if (meals.isNotEmpty) 'recent_meals': meals.join(', '),
      };
    } catch (e) {
      debugPrint('[ContextFetcher] _fetchPantry error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchPlanit(String walletId) async {
    try {
      final tasks = await TaskService.instance.fetchTasks(walletId);
      final pending = tasks
          .where((t) => t['is_done'] != true)
          .take(8)
          .map((t) => t['title'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      final now = DateTime.now();
      final today = now.toIso8601String().substring(0, 10);

      List<Map<String, dynamic>> billRows = [];
      List<Map<String, dynamic>> reminderRows = [];

      try {
        final raw = await _db
            .from('bills')
            .select('name, amount, due_date')
            .eq('wallet_id', walletId)
            .gte('due_date', today)
            .order('due_date')
            .limit(5);
        billRows = List<Map<String, dynamic>>.from(raw);
      } catch (e) {
        debugPrint('[ContextFetcher] bills error: $e');
      }

      try {
        final raw = await _db
            .from('reminders')
            .select('title, due_date')
            .eq('wallet_id', walletId)
            .eq('is_done', false)
            .gte('due_date', today)
            .order('due_date')
            .limit(5);
        reminderRows = List<Map<String, dynamic>>.from(raw);
      } catch (e) {
        debugPrint('[ContextFetcher] reminders error: $e');
      }

      final bills = billRows
          .map((r) =>
              '${r['name']} ₹${(r['amount'] as num?)?.toStringAsFixed(0) ?? '?'} due ${r['due_date']}')
          .toList();

      final reminders = reminderRows
          .map((r) => '${r['title']} on ${r['due_date']}')
          .toList();

      return {
        'pending_tasks': pending.isEmpty ? 'none' : pending.join(', '),
        'task_count': pending.length,
        if (bills.isNotEmpty) 'upcoming_bills': bills.join(', '),
        if (reminders.isNotEmpty) 'reminders': reminders.join(', '),
      };
    } catch (e) {
      debugPrint('[ContextFetcher] _fetchPlanit error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchFunctions(String walletId) async {
    try {
      final upcoming = await FunctionsService.instance.fetchUpcoming(walletId);
      final my = await FunctionsService.instance.fetchMyFunctions(walletId);

      final upcomingList = upcoming
          .take(5)
          .map((r) {
            final name = r['name'] as String? ?? '';
            final date = r['event_date'] as String? ?? '';
            final budget = (r['budget'] as num?)?.toStringAsFixed(0) ?? '';
            return '$name${date.isNotEmpty ? ' on $date' : ''}${budget.isNotEmpty ? ' (₹$budget)' : ''}';
          })
          .toList();

      final myList = my
          .take(3)
          .map((r) => r['name'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      return {
        if (upcomingList.isNotEmpty) 'upcoming_functions': upcomingList.join(', '),
        if (myList.isNotEmpty) 'my_functions': myList.join(', '),
      };
    } catch (e) {
      debugPrint('[ContextFetcher] _fetchFunctions error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchFamily(String walletId) async {
    try {
      final raw = await _db
          .from('family_members')
          .select('name, role')
          .eq('wallet_id', walletId)
          .limit(10);

      final members = List<Map<String, dynamic>>.from(raw)
          .map((r) => '${r['name']} (${r['role']})')
          .toList();

      return {
        if (members.isNotEmpty) 'members': members.join(', '),
        'count': members.length,
      };
    } catch (e) {
      debugPrint('[ContextFetcher] _fetchFamily error: $e');
      return {};
    }
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
