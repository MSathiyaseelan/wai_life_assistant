import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import 'package:wai_life_assistant/data/services/task_service.dart';
import 'package:wai_life_assistant/data/services/pantry_service.dart';
import 'package:wai_life_assistant/data/services/functions_service.dart';
import 'package:wai_life_assistant/data/services/special_day_service.dart';
import 'package:wai_life_assistant/data/services/item_locator_service.dart';
import 'intent_classifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashboardAiCache — data DashboardScreen already has in memory for the
// wallets it has loaded, keyed by walletId. When a wallet's entry is present
// (even if empty), ContextFetcher reuses it instead of re-querying Supabase
// for that data source. A missing key means "not loaded yet here" and falls
// back to a live fetch, so this can never hand the AI stale-empty data.
// ─────────────────────────────────────────────────────────────────────────────

class DashboardAiCache {
  /// All wallets' transactions, merged — filtered by walletId + date range
  /// per request. Unlike the other fields this isn't wallet-keyed because
  /// DashboardScreen already stores it as one merged list.
  final List<TxModel>? transactions;
  final Map<String, List<GroceryItem>>? toBuyByWallet;
  final Map<String, List<TaskModel>>? tasksByWallet;
  final Map<String, List<SpecialDayModel>>? specialDaysByWallet;
  final Map<String, List<ReminderModel>>? remindersByWallet;
  final Map<String, List<FunctionModel>>? myFunctionsByWallet;
  final Map<String, List<UpcomingFunction>>? upcomingFunctionsByWallet;
  final Map<String, List<Map<String, dynamic>>>? healthMedsByWallet;
  final Map<String, List<Map<String, dynamic>>>? healthApptsByWallet;
  final Map<String, List<Map<String, dynamic>>>? healthVaccsByWallet;

  const DashboardAiCache({
    this.transactions,
    this.toBuyByWallet,
    this.tasksByWallet,
    this.specialDaysByWallet,
    this.remindersByWallet,
    this.myFunctionsByWallet,
    this.upcomingFunctionsByWallet,
    this.healthMedsByWallet,
    this.healthApptsByWallet,
    this.healthVaccsByWallet,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// HouseholdContext — aggregated data passed to the AI
// ─────────────────────────────────────────────────────────────────────────────

class HouseholdContext {
  final Map<String, dynamic> wallet;
  final Map<String, dynamic> pantry;
  final Map<String, dynamic> planit;
  final Map<String, dynamic> functions;
  final Map<String, dynamic> family;
  final Map<String, dynamic> health;
  final Map<String, dynamic> myHub;

  const HouseholdContext({
    this.wallet = const {},
    this.pantry = const {},
    this.planit = const {},
    this.functions = const {},
    this.family = const {},
    this.health = const {},
    this.myHub = const {},
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
    if (health.isNotEmpty) {
      buf.writeln('=== HEALTH ===');
      health.forEach((k, v) => buf.writeln('$k: $v'));
      buf.writeln();
    }
    if (myHub.isNotEmpty) {
      buf.writeln('=== MYHUB (ITEM LOCATOR) ===');
      myHub.forEach((k, v) => buf.writeln('$k: $v'));
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
    String walletId, {
    DashboardAiCache? cache,
  }) async {
    final sources = intent.dataSources;
    final isCrossTab = sources.contains(DataSource.crossTab);

    final fetchWallet    = sources.contains(DataSource.wallet)    || isCrossTab;
    final fetchPantry    = sources.contains(DataSource.pantry)    || isCrossTab;
    final fetchPlanit    = sources.contains(DataSource.planit)    || isCrossTab;
    final fetchFunctions = sources.contains(DataSource.functions) || isCrossTab;
    final fetchFamily    = sources.contains(DataSource.family);
    final fetchHealth    = sources.contains(DataSource.health)    || isCrossTab;
    final fetchMyHub     = sources.contains(DataSource.myHub)     || isCrossTab;

    final results = await Future.wait([
      fetchWallet    ? _fetchWallet(walletId, intent.timeRange, cache) : Future.value(<String, dynamic>{}),
      fetchPantry    ? _fetchPantry(walletId, cache)    : Future.value(<String, dynamic>{}),
      fetchPlanit    ? _fetchPlanit(walletId, cache)    : Future.value(<String, dynamic>{}),
      fetchFunctions ? _fetchFunctions(walletId, cache) : Future.value(<String, dynamic>{}),
      fetchFamily    ? _fetchFamily(walletId)    : Future.value(<String, dynamic>{}),
      fetchHealth    ? _fetchHealth(walletId, cache)    : Future.value(<String, dynamic>{}),
      fetchMyHub     ? _fetchMyHub(walletId)     : Future.value(<String, dynamic>{}),
    ]);

    return HouseholdContext(
      wallet:    results[0],
      pantry:    results[1],
      planit:    results[2],
      functions: results[3],
      family:    results[4],
      health:    results[5],
      myHub:     results[6],
    );
  }

  Future<Map<String, dynamic>> _fetchWallet(
    String walletId,
    TimeRange range,
    DashboardAiCache? cache,
  ) async {
    if (walletId.isEmpty) return {};
    try {
      final now = DateTime.now();
      final DateTime fromDateTime;
      final String fromDate;
      switch (range) {
        case TimeRange.today:
          fromDateTime = DateTime(now.year, now.month, now.day);
        case TimeRange.thisWeek:
          fromDateTime = now.subtract(const Duration(days: 7));
        case TimeRange.lastMonth:
          fromDateTime = DateTime(now.year, now.month - 1, 1);
        default:
          fromDateTime = DateTime(now.year, now.month, 1);
      }
      fromDate = fromDateTime.toIso8601String().substring(0, 10);

      // DashboardScreen already holds this wallet's full transaction history
      // (merged across all its loaded wallets) — reuse it instead of a fresh
      // query when available, filtering/limiting in-memory the same way the
      // live query does.
      final List<Map<String, dynamic>> rows;
      final cached = cache?.transactions;
      if (cached != null) {
        final filtered = cached
            .where((t) => t.walletId == walletId && !t.date.isBefore(fromDateTime))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        rows = filtered
            .take(50)
            .map((t) => {
                  'type': t.type.name,
                  'amount': t.amount,
                  'category': t.category,
                  'title': t.title,
                })
            .toList();
      } else {
        rows = await _db
            .from('transactions')
            .select('type, amount, category, title, date')
            .eq('wallet_id', walletId)
            .isFilter('deleted_at', null)
            .gte('date', fromDate)
            .order('date', ascending: false)
            .limit(50);
      }

      double income = 0, expense = 0, lend = 0, borrow = 0, split = 0, returned = 0;
      final catTotals = <String, double>{};
      final recent = <String>[];

      for (final r in rows) {
        final type = r['type'] as String? ?? '';
        final amount = (r['amount'] as num?)?.toDouble() ?? 0;
        final cat = r['category'] as String? ?? '';
        final title = r['title'] as String? ?? cat;

        switch (type) {
          case 'income':   income += amount;
          case 'expense':
            expense += amount;
            catTotals[cat] = (catTotals[cat] ?? 0) + amount;
          case 'lend':     lend += amount;
          case 'borrow':   borrow += amount;
          case 'split':    split += amount;
          case 'returned': returned += amount;
        }
        if (recent.length < 5) {
          recent.add('${_cap(title)} ${AppPrefs.cs}${amount.toStringAsFixed(0)} ($type)');
        }
      }

      // total_spent = all money that left your pocket this period
      final totalOut = expense + lend + split;
      // total_received = all money that came in this period
      final totalIn = income + borrow + returned;

      final topCats = (catTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(3)
          .map((e) => '${_cap(e.key)} ${AppPrefs.cs}${e.value.toStringAsFixed(0)}')
          .join(', ');

      return {
        'expenses': '${AppPrefs.cs}${expense.toStringAsFixed(0)}',
        'income': '${AppPrefs.cs}${income.toStringAsFixed(0)}',
        if (lend > 0)     'lent_out': '${AppPrefs.cs}${lend.toStringAsFixed(0)}',
        if (borrow > 0)   'borrowed': '${AppPrefs.cs}${borrow.toStringAsFixed(0)}',
        if (split > 0)    'split_expenses': '${AppPrefs.cs}${split.toStringAsFixed(0)}',
        if (returned > 0) 'returned': '${AppPrefs.cs}${returned.toStringAsFixed(0)}',
        'total_money_out': '${AppPrefs.cs}${totalOut.toStringAsFixed(0)}',
        'total_money_in': '${AppPrefs.cs}${totalIn.toStringAsFixed(0)}',
        'net_flow': '${AppPrefs.cs}${(totalIn - totalOut).toStringAsFixed(0)}',
        if (topCats.isNotEmpty) 'top_expense_categories': topCats,
        if (recent.isNotEmpty) 'recent_transactions': recent.join(' | '),
      };
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'context_fetch_wallet');
      debugPrint('[ContextFetcher] _fetchWallet error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchPantry(String walletId, DashboardAiCache? cache) async {
    if (walletId.isEmpty) return {};
    try {
      // Use to_buy items only — matches what the Pantry "To Buy" tab shows.
      // fetchGroceryItems returns ALL items (including in-stock) which over-counts.
      final cachedToBuy = cache?.toBuyByWallet?[walletId];
      final List<String> pending;
      if (cachedToBuy != null) {
        pending = cachedToBuy
            .where((g) => g.isGrocery)
            .map((g) => g.name.isEmpty
                ? ''
                : '${g.name} ${g.quantity.toStringAsFixed(0)}${g.unit}')
            .where((s) => s.isNotEmpty)
            .toList();
      } else {
        final rows = await PantryService.instance.fetchToBuyItems(walletId);
        pending = rows
            .where((r) => r['is_grocery'] != false) // grocery items only (exclude quick-add non-grocery)
            .map((r) {
          final name = r['name'] as String? ?? '';
          // Column is 'quantity' in the DB — was previously read as 'qty'
          // (always null), so shopping-list context never showed amounts.
          final qty = r['quantity'] as num?;
          final unit = r['unit'] as String? ?? '';
          return qty != null ? '$name ${qty.toStringAsFixed(0)}$unit' : name;
        }).where((s) => s.isNotEmpty).toList();
      }

      List<Map<String, dynamic>> mealRows = [];
      try {
        final raw = await _db
            .from('meal_entries')
            .select('meal_name, meal_type, logged_at')
            .eq('wallet_id', walletId)
            .order('logged_at', ascending: false)
            .limit(5);
        mealRows = List<Map<String, dynamic>>.from(raw);
      } catch (e, stack) {
        ErrorLogger.log(e, stackTrace: stack, action: 'context_fetch_meal_entries');
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
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'context_fetch_pantry');
      debugPrint('[ContextFetcher] _fetchPantry error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchPlanit(String walletId, DashboardAiCache? cache) async {
    if (walletId.isEmpty) return {};
    try {
      final cachedTasks = cache?.tasksByWallet?[walletId];
      final List<String> pending;
      if (cachedTasks != null) {
        pending = cachedTasks
            .where((t) => t.status != TaskStatus.done)
            .take(8)
            .map((t) => t.title)
            .where((s) => s.isNotEmpty)
            .toList();
      } else {
        final tasks = await TaskService.instance.fetchTasks(walletId);
        pending = tasks
            .where((t) => t['is_done'] != true)
            .take(8)
            .map((t) => t['title'] as String? ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }

      final now = DateTime.now();
      final today = now.toIso8601String().substring(0, 10);
      final todayDate = DateTime(now.year, now.month, now.day);

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
      } catch (e, stack) {
        ErrorLogger.log(e, stackTrace: stack, action: 'context_fetch_bills');
        debugPrint('[ContextFetcher] bills error: $e');
      }

      // Reminders — reuse Dashboard's cached list (reapplying the same
      // "not done, due today or later" filter) when available.
      final cachedReminders = cache?.remindersByWallet?[walletId];
      List<String> reminders;
      if (cachedReminders != null) {
        reminders = (cachedReminders
                .where((r) => !r.done && !r.dueDate.isBefore(todayDate))
                .toList()
              ..sort((a, b) => a.dueDate.compareTo(b.dueDate)))
            .take(5)
            .map((r) => '${r.title} on ${r.dueDate.toIso8601String().substring(0, 10)}')
            .toList();
      } else {
        try {
          final raw = await _db
              .from('reminders')
              .select('title, due_date')
              .eq('wallet_id', walletId)
              .eq('done', false)
              .gte('due_date', today)
              .order('due_date')
              .limit(5);
          reminderRows = List<Map<String, dynamic>>.from(raw);
        } catch (e, stack) {
          ErrorLogger.log(e, stackTrace: stack, action: 'context_fetch_reminders');
          debugPrint('[ContextFetcher] reminders error: $e');
        }
        reminders = reminderRows
            .map((r) => '${r['title']} on ${r['due_date']}')
            .toList();
      }

      // Special days — reuse Dashboard's cache (already unfiltered, same as
      // the live fetch) so the AI can answer birthday/anniversary queries by name.
      final cachedDays = cache?.specialDaysByWallet?[walletId];
      final List<String> specialDays;
      if (cachedDays != null) {
        specialDays = cachedDays
            .map((d) =>
                '${d.title} (${d.type.name}) — ${d.date.toIso8601String().substring(0, 10)}')
            .where((s) => s.isNotEmpty)
            .toList();
      } else {
        List<Map<String, dynamic>> specialDayRows = [];
        try {
          specialDayRows = await SpecialDayService.instance.fetchDays(walletId);
        } catch (e, stack) {
          ErrorLogger.log(e, stackTrace: stack, action: 'context_fetch_special_days');
          debugPrint('[ContextFetcher] special_days error: $e');
        }
        specialDays = specialDayRows
            .map((r) {
              final title = r['title'] as String? ?? '';
              final date  = r['date']  as String? ?? '';
              final type  = r['type']  as String? ?? '';
              return '$title ($type) — $date';
            })
            .where((s) => s.isNotEmpty)
            .toList();
      }

      final bills = billRows
          .map((r) =>
              '${r['name']} ${AppPrefs.cs}${(r['amount'] as num?)?.toStringAsFixed(0) ?? '?'} due ${r['due_date']}')
          .toList();

      return {
        'pending_tasks': pending.isEmpty ? 'none' : pending.join(', '),
        'task_count': pending.length,
        if (bills.isNotEmpty)       'upcoming_bills': bills.join(', '),
        if (reminders.isNotEmpty)   'reminders':      reminders.join(', '),
        if (specialDays.isNotEmpty) 'special_days':   specialDays.join(' | '),
      };
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'context_fetch_planit');
      debugPrint('[ContextFetcher] _fetchPlanit error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchFunctions(String walletId, DashboardAiCache? cache) async {
    if (walletId.isEmpty) return {};
    try {
      final cachedUpcoming = cache?.upcomingFunctionsByWallet?[walletId];
      final List<String> upcomingList;
      if (cachedUpcoming != null) {
        upcomingList = cachedUpcoming.take(5).map((u) {
          final title = u.functionTitle;
          final person = u.personName;
          final date = u.date?.toIso8601String().substring(0, 10) ?? '';
          final type = u.type.name;
          final label = [
            if (title.isNotEmpty) title,
            if (person.isNotEmpty) 'for $person',
            if (type.isNotEmpty && type != 'other') '($type)',
            if (date.isNotEmpty) 'on $date',
          ].join(' ');
          return label;
        }).where((s) => s.isNotEmpty).toList();
      } else {
        final upcoming = await FunctionsService.instance.fetchUpcoming(walletId);
        upcomingList = upcoming
            .take(5)
            .map((r) {
              final title = r['function_title'] as String? ?? '';
              final person = r['person_name'] as String? ?? '';
              final date = r['date'] as String? ?? '';
              final type = r['type'] as String? ?? '';
              final label = [
                if (title.isNotEmpty) title,
                if (person.isNotEmpty) 'for $person',
                if (type.isNotEmpty && type != 'other') '($type)',
                if (date.isNotEmpty) 'on $date',
              ].join(' ');
              return label;
            })
            .where((s) => s.isNotEmpty)
            .toList();
      }

      final cachedMy = cache?.myFunctionsByWallet?[walletId];
      final List<String> myList;
      if (cachedMy != null) {
        myList = cachedMy.take(3).map((f) {
          final date = f.functionDate?.toIso8601String().substring(0, 10) ?? '';
          return date.isNotEmpty ? '${f.title} on $date' : f.title;
        }).where((s) => s.isNotEmpty).toList();
      } else {
        final my = await FunctionsService.instance.fetchMyFunctions(walletId);
        myList = my
            .take(3)
            .map((r) {
              final title = r['title'] as String? ?? '';
              final date = r['function_date'] as String? ?? '';
              return date.isNotEmpty ? '$title on $date' : title;
            })
            .where((s) => s.isNotEmpty)
            .toList();
      }

      return {
        if (upcomingList.isNotEmpty) 'upcoming_functions': upcomingList.join(', '),
        if (myList.isNotEmpty) 'my_functions': myList.join(', '),
      };
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'context_fetch_functions');
      debugPrint('[ContextFetcher] _fetchFunctions error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchFamily(String walletId) async {
    if (walletId.isEmpty) return {};
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
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'context_fetch_family');
      debugPrint('[ContextFetcher] _fetchFamily error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchHealth(String walletId, DashboardAiCache? cache) async {
    if (walletId.isEmpty) return {};
    try {
      final now = DateTime.now();
      final today = now.toIso8601String().substring(0, 10);
      final in30d = now.add(const Duration(days: 30)).toIso8601String().substring(0, 10);

      // Vitals/doctors/insurance aren't cached anywhere in Dashboard — always live.
      final liveResults = await Future.wait([
        _db
            .from('health_vitals')
            .select('vital_type, value, value2, sub_type, recorded_at')
            .eq('wallet_id', walletId)
            .order('recorded_at', ascending: false)
            .limit(5),
        _db
            .from('health_doctors')
            .select('name, specialty')
            .eq('wallet_id', walletId)
            .limit(10),
        _db
            .from('health_insurance')
            .select('policy_name, provider, coverage_amount, expiry_date')
            .eq('wallet_id', walletId)
            .limit(5),
      ]);

      // Meds/appointments/vaccinations — reuse Dashboard's cache (which holds
      // the unfiltered table) when available, reapplying the same filters
      // the live query below would otherwise apply server-side.
      final cachedMeds = cache?.healthMedsByWallet?[walletId];
      final List<String> meds;
      if (cachedMeds != null) {
        meds = cachedMeds
            .where((r) => r['is_active'] == true)
            .take(10)
            .map((r) {
          final name   = r['name']      as String? ?? '';
          final dosage = r['dosage']    as String? ?? '';
          final freq   = r['frequency'] as String? ?? '';
          return '$name${dosage.isNotEmpty ? ' $dosage' : ''}${freq.isNotEmpty ? ' ($freq)' : ''}';
        }).where((s) => s.isNotEmpty).toList();
      } else {
        final rows = await _db
            .from('health_medications')
            .select('name, dosage, frequency')
            .eq('wallet_id', walletId)
            .eq('is_active', true)
            .limit(10);
        meds = (rows as List).map((r) {
          final name   = r['name']      as String? ?? '';
          final dosage = r['dosage']    as String? ?? '';
          final freq   = r['frequency'] as String? ?? '';
          return '$name${dosage.isNotEmpty ? ' $dosage' : ''}${freq.isNotEmpty ? ' ($freq)' : ''}';
        }).where((s) => s.isNotEmpty).toList();
      }

      final cachedAppts = cache?.healthApptsByWallet?[walletId];
      final List<String> appts;
      if (cachedAppts != null) {
        appts = (cachedAppts
                .where((r) => ((r['appt_date'] as String?) ?? '').compareTo(today) >= 0)
                .toList()
              ..sort((a, b) => ((a['appt_date'] as String?) ?? '')
                  .compareTo((b['appt_date'] as String?) ?? '')))
            .take(5)
            .map((r) {
          final doc  = r['doctor_name'] as String? ?? '';
          final date = r['appt_date']   as String? ?? '';
          return '$doc on $date';
        }).where((s) => s.isNotEmpty).toList();
      } else {
        final rows = await _db
            .from('health_appointments')
            .select('doctor_name, appt_date')
            .eq('wallet_id', walletId)
            .gte('appt_date', today)
            .order('appt_date')
            .limit(5);
        appts = (rows as List).map((r) {
          final doc  = r['doctor_name'] as String? ?? '';
          final date = r['appt_date']   as String? ?? '';
          return '$doc on $date';
        }).where((s) => s.isNotEmpty).toList();
      }

      final cachedVaccs = cache?.healthVaccsByWallet?[walletId];
      final List<String> vaccines;
      if (cachedVaccs != null) {
        vaccines = (cachedVaccs
                .where((r) {
                  final due = (r['next_due_date'] as String?) ?? '';
                  return due.compareTo(today) >= 0 && due.compareTo(in30d) <= 0;
                })
                .toList()
              ..sort((a, b) => ((a['next_due_date'] as String?) ?? '')
                  .compareTo((b['next_due_date'] as String?) ?? '')))
            .take(5)
            .map((r) {
          final name = r['vaccine_name']  as String? ?? '';
          final due  = r['next_due_date'] as String? ?? '';
          return '$name due $due';
        }).where((s) => s.isNotEmpty).toList();
      } else {
        final rows = await _db
            .from('health_vaccinations')
            .select('vaccine_name, next_due_date')
            .eq('wallet_id', walletId)
            .gte('next_due_date', today)
            .lte('next_due_date', in30d)
            .order('next_due_date')
            .limit(5);
        vaccines = (rows as List).map((r) {
          final name = r['vaccine_name']  as String? ?? '';
          final due  = r['next_due_date'] as String? ?? '';
          return '$name due $due';
        }).where((s) => s.isNotEmpty).toList();
      }

      final vitals = (liveResults[0] as List).map((r) {
        final type  = r['vital_type'] as String? ?? '';
        final val   = r['value']      as num?;
        final val2  = r['value2']     as num?;
        final sub   = r['sub_type']   as String? ?? '';
        final date  = (r['recorded_at'] as String? ?? '').substring(0, 10);
        final reading = val2 != null
            ? '${val?.toStringAsFixed(0)}/${val2.toStringAsFixed(0)}'
            : val?.toString() ?? '';
        return '$type: $reading${sub.isNotEmpty ? ' $sub' : ''} (on $date)';
      }).where((s) => s.isNotEmpty).toList();

      final doctors = (liveResults[1] as List).map((r) {
        final name = r['name']     as String? ?? '';
        final spec = r['specialty'] as String? ?? '';
        return '$name${spec.isNotEmpty ? ' ($spec)' : ''}';
      }).where((s) => s.isNotEmpty).toList();

      final insurance = (liveResults[2] as List).map((r) {
        final policy   = r['policy_name']     as String? ?? '';
        final provider = r['provider']        as String? ?? '';
        final coverage = r['coverage_amount'] as num?;
        final expiry   = r['expiry_date']     as String? ?? '';
        return '$policy${provider.isNotEmpty ? ' by $provider' : ''}'
            '${coverage != null ? ' ${AppPrefs.cs}${coverage.toStringAsFixed(0)} coverage' : ''}'
            '${expiry.isNotEmpty ? ' (expires $expiry)' : ''}';
      }).where((s) => s.isNotEmpty).toList();

      return {
        if (meds.isNotEmpty)      'active_medications':    meds.join(', '),
        'medication_count':                                 meds.length,
        if (appts.isNotEmpty)     'upcoming_appointments': appts.join(', '),
        if (vaccines.isNotEmpty)  'due_vaccines':          vaccines.join(', '),
        if (vitals.isNotEmpty)    'recent_vitals':         vitals.join(' | '),
        if (doctors.isNotEmpty)   'doctors':               doctors.join(', '),
        if (insurance.isNotEmpty) 'insurance_policies':    insurance.join(' | '),
      };
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'context_fetch_health');
      debugPrint('[ContextFetcher] _fetchHealth error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchMyHub(String walletId) async {
    if (walletId.isEmpty) return {};
    try {
      // Fetch containers and items in parallel, then join in-memory
      final results = await Future.wait([
        ItemLocatorService.instance.fetchContainers(walletId),
        ItemLocatorService.instance.fetchItems(walletId),
      ]);

      final containers = results[0];
      final items      = results[1];

      if (items.isEmpty) return {};

      // Build a map of container_id → container info for fast lookup
      final containerMap = <String, Map<String, dynamic>>{
        for (final c in containers) c['id'] as String: c,
      };

      // Join each item with its container to produce "item → container (location)"
      final entries = items.map((item) {
        final name      = item['name']        as String? ?? '';
        final desc      = item['description'] as String? ?? '';
        final cId       = item['container_id'] as String? ?? '';
        final container = containerMap[cId];
        final cName     = container?['name']     as String? ?? '';
        final cLocation = container?['location'] as String? ?? '';

        final where = [
          if (cName.isNotEmpty)     cName,
          if (cLocation.isNotEmpty) cLocation,
        ].join(', ');

        return '$name${desc.isNotEmpty ? ' ($desc)' : ''} → ${where.isNotEmpty ? where : 'unknown location'}';
      }).toList();

      return {
        'stored_items': entries.join(' | '),
        'item_count':   items.length,
      };
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'context_fetch_myhub');
      debugPrint('[ContextFetcher] _fetchMyHub error: $e');
      return {};
    }
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
