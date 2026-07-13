import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import 'package:wai_life_assistant/core/utils/amount_format.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/data/services/wallet_service.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BUDGET SHEET
// Set, edit, and delete monthly spending limits per expense category.
// ─────────────────────────────────────────────────────────────────────────────

class BudgetSheet extends StatefulWidget {
  final String walletId;
  final List<TxModel> transactions; // current wallet transactions for spent calc
  final bool isDark;
  /// Budgets already loaded by the caller (e.g. WalletScreen's cache).
  /// When provided, the sheet skips its own fetch and uses these directly —
  /// avoids a redundant `fetchBudgets` round-trip every time the sheet opens.
  final List<BudgetModel>? initialBudgets;

  const BudgetSheet({
    super.key,
    required this.walletId,
    required this.transactions,
    required this.isDark,
    this.initialBudgets,
  });

  static Future<void> show(
    BuildContext context, {
    required String walletId,
    required List<TxModel> transactions,
    required bool isDark,
    List<BudgetModel>? initialBudgets,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BudgetSheet(
        walletId: walletId,
        transactions: transactions,
        isDark: isDark,
        initialBudgets: initialBudgets,
      ),
    );
  }

  @override
  State<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<BudgetSheet> {
  List<BudgetModel> _budgets = [];
  Map<String, double> _spentMap = {};
  List<String> _allCategories = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _loadError = null; });
    try {
      // Reuse budgets the caller already fetched instead of re-querying —
      // BudgetModel is cloned per-instance below so editing here can't
      // silently mutate the caller's cached list.
      final budgets = widget.initialBudgets != null
          ? widget.initialBudgets!
              .map((b) => BudgetModel(
                    id: b.id,
                    walletId: b.walletId,
                    category: b.category,
                    limitAmount: b.limitAmount,
                    last80AlertMonth: b.last80AlertMonth,
                    last100AlertMonth: b.last100AlertMonth,
                  ))
              .toList()
          : await WalletService.instance.fetchBudgets(widget.walletId);
      final spent = WalletService.computeMonthlySpent(widget.transactions);
      for (final b in budgets) {
        b.spent = spent[b.category] ?? 0;
      }
      final cats = WalletService.instance.categoriesFor('expense');
      if (!mounted) return;
      setState(() {
        _budgets = budgets;
        _spentMap = spent;
        _allCategories = cats;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[BudgetSheet] _load error: $e');
      if (!mounted) return;
      // Fallback: show categories from local cache so UI is still usable
      final spent = WalletService.computeMonthlySpent(widget.transactions);
      final cats = WalletService.instance.categoriesFor('expense');
      setState(() {
        _spentMap = spent;
        _allCategories = cats;
        _loading = false;
        _loadError = 'Could not load saved budgets. Check your connection.';
      });
    }
  }

  // Returns categories that have NO budget yet
  List<String> get _unbudgetedCategories {
    final budgeted = _budgets.map((b) => b.category).toSet();
    return _allCategories.where((c) => !budgeted.contains(c)).toList();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _openSetDialog({BudgetModel? existing, String? category}) async {
    final name = existing?.category ?? category ?? '';
    final ctrl = TextEditingController(
      text: existing != null ? existing.limitAmount.toStringAsFixed(0) : '',
    );
    final isDark = widget.isDark;
    final bg   = isDark ? AppColors.cardDark  : AppColors.cardLight;
    final tc   = isDark ? AppColors.textDark  : AppColors.textLight;
    final sub  = isDark ? AppColors.subDark   : AppColors.subLight;

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          existing != null ? 'Edit budget' : 'Set budget',
          style: TextStyle(
            fontFamily: 'Nunito', fontWeight: FontWeight.w800,
            fontSize: 17, color: tc,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(walletCategoryEmoji(name), style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                    fontSize: 15, color: tc,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Monthly limit (${AppPrefs.cs})',
              style: TextStyle(fontSize: 12, fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600, color: sub),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                fontSize: 22, color: tc,
              ),
              decoration: InputDecoration(
                prefixText: '${AppPrefs.cs} ',
                prefixStyle: TextStyle(
                  fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                  fontSize: 20, color: sub,
                ),
                hintText: '0',
                hintStyle: TextStyle(color: sub),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: sub.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: sub, fontFamily: 'Nunito')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;
    try {
      final saved = await WalletService.instance.setBudget(
        walletId: widget.walletId,
        category: name,
        limitAmount: result,
      );
      saved.spent = _spentMap[name] ?? 0;
      setState(() {
        final idx = _budgets.indexWhere((b) => b.category == name);
        if (idx >= 0) {
          _budgets[idx] = saved;
        } else {
          _budgets.add(saved);
          _budgets.sort((a, b) => a.category.compareTo(b.category));
        }
      });
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'set_budget');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save budget: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteBudget(BudgetModel b) async {
    try {
      await WalletService.instance.deleteBudget(b.id);
      setState(() => _budgets.removeWhere((x) => x.id == b.id));
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'delete_budget');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete budget. Please try again.')),
      );
    }
  }

  Future<void> _addCategory() async {
    final isDark = widget.isDark;
    final ctrl = TextEditingController();
    final tc   = isDark ? AppColors.textDark : AppColors.textLight;
    final sub  = isDark ? AppColors.subDark  : AppColors.subLight;
    final bg   = isDark ? AppColors.cardDark : AppColors.cardLight;

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('New category',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 17, color: tc)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 16, color: tc),
          decoration: InputDecoration(
            hintText: 'e.g. Dining Out',
            hintStyle: TextStyle(color: sub),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: sub.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: sub, fontFamily: 'Nunito')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('Add', style: TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (name == null || !mounted) return;
    try {
      final canonical = await WalletService.instance.addExpenseCategory(name);
      setState(() {
        if (!_allCategories.contains(canonical)) _allCategories.add(canonical);
      });
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'add_category');
    }
  }

  Future<void> _deleteCategory(String name) async {
    if (WalletService.defaultExpenseCategories.contains(name)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default categories cannot be deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    // Remove any budget set for this category too
    final budget = _budgets.where((b) => b.category == name).firstOrNull;
    if (budget != null) await _deleteBudget(budget);
    try {
      await WalletService.instance.deleteExpenseCategory(name);
      setState(() => _allCategories.remove(name));
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'delete_category');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg   = isDark ? AppColors.cardDark  : AppColors.cardLight;
    final tc   = isDark ? AppColors.textDark  : AppColors.textLight;
    final sub  = isDark ? AppColors.subDark   : AppColors.subLight;
    final surf = isDark ? AppColors.surfDark  : AppColors.bgLight;

    final now = DateTime.now();
    final monthLabel = _monthName(now.month);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: sub.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📊 Set Budget',
                          style: TextStyle(
                            fontSize: 18, fontFamily: 'Nunito',
                            fontWeight: FontWeight.w900, color: tc,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$monthLabel ${now.year} · monthly limits',
                          style: TextStyle(
                            fontSize: 12, fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600, color: sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Add new category button
                  GestureDetector(
                    onTap: _addCategory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, size: 15, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Category',
                            style: const TextStyle(
                              fontSize: 12, fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700, color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null && _budgets.isEmpty && _allCategories.isEmpty
                      ? _buildError(sub, tc)
                  : ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        if (_loadError != null && _budgets.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5C7A).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFFFF5C7A)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Could not load saved budgets. Showing default categories.',
                                      style: TextStyle(
                                        fontSize: 12, fontFamily: 'Nunito',
                                        fontWeight: FontWeight.w600, color: sub,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _load,
                                    child: const Text('Retry',
                                      style: TextStyle(
                                        fontSize: 12, fontFamily: 'Nunito',
                                        fontWeight: FontWeight.w700, color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // ── This month summary ────────────────────────────
                        _MonthSummaryCard(
                          spentMap: _spentMap,
                          budgets: _budgets,
                          month: monthLabel,
                          year: now.year,
                          isDark: isDark,
                          tc: tc,
                          sub: sub,
                          surf: surf,
                        ),
                        const SizedBox(height: 16),
                        if (_budgets.isNotEmpty) ...[
                          _sectionLabel('WITH BUDGET LIMIT', sub),
                          const SizedBox(height: 8),
                          ..._budgets.map((b) => _BudgetTile(
                            budget: b,
                            isDark: isDark,
                            tc: tc,
                            sub: sub,
                            surf: surf,
                            onEdit: () => _openSetDialog(existing: b),
                            onDelete: () => _deleteBudget(b),
                          )),
                          const SizedBox(height: 20),
                        ],
                        if (_unbudgetedCategories.isNotEmpty) ...[
                          _sectionLabel('OTHER CATEGORIES', sub),
                          const SizedBox(height: 8),
                          ..._unbudgetedCategories.map(
                            (cat) => _CategoryTile(
                              category: cat,
                              spent: _spentMap[cat] ?? 0,
                              isDark: isDark,
                              tc: tc,
                              sub: sub,
                              surf: surf,
                              isDefault: WalletService.defaultExpenseCategories.contains(cat),
                              onSetBudget: () => _openSetDialog(category: cat),
                              onDelete: () => _deleteCategory(cat),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Color sub, Color tc) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: sub.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontFamily: 'Nunito',
                fontWeight: FontWeight.w600, color: sub),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _load,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Retry', style: TextStyle(
                fontSize: 13, fontFamily: 'Nunito',
                fontWeight: FontWeight.w700, color: AppColors.primary,
              )),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sectionLabel(String text, Color sub) => Text(
        text,
        style: TextStyle(
          fontSize: 10, fontFamily: 'Nunito',
          fontWeight: FontWeight.w800, color: sub,
          letterSpacing: 1.0,
        ),
      );

  static String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m];
}

// ─────────────────────────────────────────────────────────────────────────────
// Budget tile — category with progress bar + spent/limit
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetTile extends StatelessWidget {
  final BudgetModel budget;
  final bool isDark;
  final Color tc, sub, surf;
  final VoidCallback onEdit, onDelete;

  const _BudgetTile({
    required this.budget,
    required this.isDark,
    required this.tc,
    required this.sub,
    required this.surf,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _barColor {
    if (budget.isOver) return const Color(0xFFFF5C7A);
    if (budget.isNear) return const Color(0xFFFFAA2C);
    return const Color(0xFF00C897);
  }

  String _fmt(double v) {
    final large = formatLargeAmount(v);
    if (large != null) return large;
    if (v >= 1000) {
      final s = (v / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.?0+$'), '');
      return '${s}k';
    }
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final pct = budget.pct.clamp(0.0, 1.0);
    final pctLabel = '${(budget.pct * 100).toStringAsFixed(0)}%';

    return Dismissible(
      key: ValueKey(budget.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5C7A).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5C7A)),
      ),
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        return true;
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(walletCategoryEmoji(budget.category),
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    budget.category,
                    style: TextStyle(
                      fontSize: 14, fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800, color: tc,
                    ),
                  ),
                ),
                // pct badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _barColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pctLabel,
                    style: TextStyle(
                      fontSize: 11, fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800, color: _barColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () { HapticFeedback.lightImpact(); onEdit(); },
                  child: Icon(Icons.edit_rounded, size: 17, color: sub),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: sub.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(_barColor),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${AppPrefs.cs}${_fmt(budget.spent)} spent',
                  style: TextStyle(
                    fontSize: 12, fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700, color: _barColor,
                  ),
                ),
                const Spacer(),
                Text(
                  'of ${AppPrefs.cs}${_fmt(budget.limitAmount)}',
                  style: TextStyle(
                    fontSize: 12, fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600, color: sub,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category tile — unbudgeted category row
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final String category;
  final double spent;
  final bool isDark, isDefault;
  final Color tc, sub, surf;
  final VoidCallback onSetBudget, onDelete;

  const _CategoryTile({
    required this.category,
    required this.spent,
    required this.isDark,
    required this.isDefault,
    required this.tc,
    required this.sub,
    required this.surf,
    required this.onSetBudget,
    required this.onDelete,
  });

  static String _fmt(double v) {
    final large = formatLargeAmount(v);
    if (large != null) return large;
    if (v >= 1000) {
      final s = (v / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.?0+$'), '');
      return '${s}k';
    }
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final hasSpend = spent > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(walletCategoryEmoji(category), style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 14, fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700, color: tc,
                  ),
                ),
                if (hasSpend) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${AppPrefs.cs}${_fmt(spent)} this month',
                    style: TextStyle(
                      fontSize: 11, fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      color: sub,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Delete custom category
          if (!isDefault)
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); onDelete(); },
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.delete_outline_rounded, size: 17, color: sub),
              ),
            ),
          // Set budget
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); onSetBudget(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add_rounded, size: 13, color: AppColors.primary),
                  SizedBox(width: 3),
                  Text(
                    'Set limit',
                    style: TextStyle(
                      fontSize: 11, fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700, color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly summary card — total spend this month vs total budgeted
// ─────────────────────────────────────────────────────────────────────────────

class _MonthSummaryCard extends StatelessWidget {
  final Map<String, double> spentMap;
  final List<BudgetModel> budgets;
  final String month;
  final int year;
  final bool isDark;
  final Color tc, sub, surf;

  const _MonthSummaryCard({
    required this.spentMap,
    required this.budgets,
    required this.month,
    required this.year,
    required this.isDark,
    required this.tc,
    required this.sub,
    required this.surf,
  });

  static String _fmt(double v) {
    final large = formatLargeAmount(v);
    if (large != null) return large;
    if (v >= 1000) {
      final s = (v / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.?0+$'), '');
      return '${s}k';
    }
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    // Total expense spend this month across ALL categories (not just budgeted)
    final totalSpent = spentMap.values.fold(0.0, (s, v) => s + v);
    // Total budgeted (only categories that have a limit set)
    final totalBudgeted = budgets.fold(0.0, (s, b) => s + b.limitAmount);
    // Spend covered by budgets
    final budgetedSpend = budgets.fold(0.0, (s, b) => s + b.spent);
    // Unbudgeted spend
    final unbudgetedSpend = totalSpent - budgetedSpend;

    final hasBudgets = budgets.isNotEmpty;
    final overallPct = (hasBudgets && totalBudgeted > 0)
        ? (budgetedSpend / totalBudgeted).clamp(0.0, 1.0)
        : 0.0;
    final anyOver = hasBudgets && budgets.any((b) => b.isOver);
    final barColor = anyOver
        ? const Color(0xFFFF5C7A)
        : overallPct >= 0.8
            ? const Color(0xFFFFAA2C)
            : const Color(0xFF00C897);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1E35), const Color(0xFF252540)]
              : [const Color(0xFFEEEDFF), const Color(0xFFF5F5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(
            '$month $year · spending so far',
            style: TextStyle(
              fontSize: 11, fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              color: sub,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          // Main amount row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${AppPrefs.cs}${_fmt(totalSpent)}',
                style: TextStyle(
                  fontSize: 30, fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  color: tc,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'spent this month',
                  style: TextStyle(
                    fontSize: 12, fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600, color: sub,
                  ),
                ),
              ),
            ],
          ),
          // Budgeted vs unbudgeted breakdown
          if (totalSpent > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (budgetedSpend > 0) ...[
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${AppPrefs.cs}${_fmt(budgetedSpend)} in budgeted categories',
                    style: TextStyle(
                      fontSize: 11, fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600, color: sub,
                    ),
                  ),
                ],
                if (unbudgetedSpend > 0 && budgetedSpend > 0)
                  Text('  ·  ', style: TextStyle(color: sub, fontSize: 11)),
                if (unbudgetedSpend > 0) ...[
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: sub.withValues(alpha: 0.5), shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${AppPrefs.cs}${_fmt(unbudgetedSpend)} unbudgeted',
                    style: TextStyle(
                      fontSize: 11, fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600, color: sub,
                    ),
                  ),
                ],
              ],
            ),
          ],
          // Overall budget progress (only if budgets are set)
          if (hasBudgets) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budget coverage',
                  style: TextStyle(
                    fontSize: 11, fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600, color: sub,
                  ),
                ),
                Text(
                  '${AppPrefs.cs}${_fmt(budgetedSpend)} / ${AppPrefs.cs}${_fmt(totalBudgeted)}',
                  style: TextStyle(
                    fontSize: 11, fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700, color: barColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: overallPct,
                minHeight: 7,
                backgroundColor: sub.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
