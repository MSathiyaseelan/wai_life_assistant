import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/supabase/task_service.dart';
import 'package:wai_life_assistant/core/supabase/pantry_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AiContextBuilder
// Classifies the user's question, pulls relevant data from Supabase,
// and builds a compact context block for the Gemini prompt.
// ─────────────────────────────────────────────────────────────────────────────

enum _Intent { wallet, pantry, planit }

class AiContextBuilder {
  AiContextBuilder._();
  static final AiContextBuilder instance = AiContextBuilder._();

  SupabaseClient get _db => Supabase.instance.client;

  // ── Intent classifier ─────────────────────────────────────────────────────

  Set<_Intent> _classify(String q) {
    final lower = q.toLowerCase();
    final intents = <_Intent>{};

    if (RegExp(
      r'spend|spent|expense|income|salary|balance|money|₹|paid|transaction|budget|earn|cash|transfer|lend|borrow|split',
    ).hasMatch(lower)) intents.add(_Intent.wallet);

    if (RegExp(
      r'pantry|grocery|groceries|food|cook|recipe|meal|ingredient|eat|basket|shopping list|buy',
    ).hasMatch(lower)) intents.add(_Intent.pantry);

    if (RegExp(
      r'task|todo|to-do|plan|bill|remind|schedule|appointment|upcoming|due|deadline|wish|note',
    ).hasMatch(lower)) intents.add(_Intent.planit);

    // Default: wallet + planit for general questions
    if (intents.isEmpty) {
      intents.add(_Intent.wallet);
      intents.add(_Intent.planit);
    }
    return intents;
  }

  // ── Main entry point ──────────────────────────────────────────────────────

  Future<String> build(String question, String walletId) async {
    final intents = _classify(question);
    final buf = StringBuffer();

    final futures = <Future<void>>[
      if (intents.contains(_Intent.wallet)) _addWallet(buf, walletId),
      if (intents.contains(_Intent.pantry)) _addPantry(buf, walletId),
      if (intents.contains(_Intent.planit)) _addPlanit(buf, walletId),
    ];
    await Future.wait(futures);

    return buf.toString();
  }

  // ── Wallet context ────────────────────────────────────────────────────────

  Future<void> _addWallet(StringBuffer buf, String walletId) async {
    try {
      final now = DateTime.now();
      final monthStart =
          DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);

      final rows = await _db
          .from('transactions')
          .select('type, amount, category, title, date')
          .eq('wallet_id', walletId)
          .gte('date', monthStart)
          .order('date', ascending: false)
          .limit(30);

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

      buf.writeln('=== WALLET (this month) ===');
      buf.writeln(
          'Income: ₹${income.toStringAsFixed(0)} | Expenses: ₹${expense.toStringAsFixed(0)} | Net: ₹${(income - expense).toStringAsFixed(0)}');
      if (lend > 0) buf.writeln('Outstanding lends: ₹${lend.toStringAsFixed(0)}');
      if (topCats.isNotEmpty) buf.writeln('Top spend categories: $topCats');
      if (recent.isNotEmpty) buf.writeln('Recent: ${recent.join(' | ')}');
      buf.writeln();
    } catch (_) {}
  }

  // ── Pantry context ────────────────────────────────────────────────────────

  Future<void> _addPantry(StringBuffer buf, String walletId) async {
    try {
      final rows =
          await PantryService.instance.fetchGroceryItems(walletId);

      final pending = rows
          .where((r) => r['is_purchased'] == false || r['is_purchased'] == null)
          .take(10)
          .map((r) {
        final name = r['name'] as String? ?? '';
        final qty = r['qty'] as num?;
        final unit = r['unit'] as String? ?? '';
        return qty != null ? '$name ${qty.toStringAsFixed(0)}$unit' : name;
      }).toList();

      buf.writeln('=== PANTRY / GROCERY ===');
      if (pending.isEmpty) {
        buf.writeln('Shopping list: empty');
      } else {
        buf.writeln('Shopping list (${pending.length} items): ${pending.join(', ')}');
      }

      // Recent meals
      final mealRows = await _db
          .from('meal_entries')
          .select('meal_name, meal_type, logged_at')
          .eq('wallet_id', walletId)
          .order('logged_at', ascending: false)
          .limit(5);

      if (mealRows.isNotEmpty) {
        final meals = (mealRows as List)
            .map((r) => '${r['meal_name']} (${r['meal_type']})')
            .join(', ');
        buf.writeln('Recent meals: $meals');
      }
      buf.writeln();
    } catch (_) {}
  }

  // ── PlanIt context ────────────────────────────────────────────────────────

  Future<void> _addPlanit(StringBuffer buf, String walletId) async {
    try {
      // Tasks
      final tasks = await TaskService.instance.fetchTasks(walletId);
      final pending = tasks
          .where((t) => t['is_done'] == false || t['is_done'] == null)
          .take(8)
          .map((t) => t['title'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      // Upcoming bills
      final now = DateTime.now();
      final billRows = await _db
          .from('bills')
          .select('name, amount, due_date')
          .eq('wallet_id', walletId)
          .gte('due_date', now.toIso8601String().substring(0, 10))
          .order('due_date')
          .limit(5);

      // Upcoming reminders
      final reminderRows = await _db
          .from('reminders')
          .select('title, due_date')
          .eq('wallet_id', walletId)
          .eq('is_done', false)
          .gte('due_date', now.toIso8601String().substring(0, 10))
          .order('due_date')
          .limit(5);

      buf.writeln('=== PLANIT ===');
      if (pending.isEmpty) {
        buf.writeln('Pending tasks: none');
      } else {
        buf.writeln('Pending tasks (${pending.length}): ${pending.join(', ')}');
      }

      if ((billRows as List).isNotEmpty) {
        final bills = billRows
            .map((r) =>
                '${r['name']} ₹${(r['amount'] as num?)?.toStringAsFixed(0) ?? '?'} due ${r['due_date']}')
            .join(', ');
        buf.writeln('Upcoming bills: $bills');
      }

      if ((reminderRows as List).isNotEmpty) {
        final reminders = reminderRows
            .map((r) => '${r['title']} on ${r['due_date']}')
            .join(', ');
        buf.writeln('Reminders: $reminders');
      }
      buf.writeln();
    } catch (_) {}
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
