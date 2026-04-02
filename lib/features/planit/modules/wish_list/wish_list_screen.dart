import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/core/supabase/wish_service.dart';
import 'package:wai_life_assistant/core/services/network_service.dart';
import 'package:wai_life_assistant/services/ai_parser.dart';
import '../../widgets/plan_widgets.dart';
import 'package:wai_life_assistant/core/widgets/emoji_or_image.dart';

class WishListScreen extends StatefulWidget {
  final String walletId;
  final String walletName;
  final String walletEmoji;
  final List<PlanMember> members;
  final List<WishModel> wishes;
  final bool openAdd;
  /// Family wallet ID → display label. Non-empty only in Personal view.
  final Map<String, String> familyWalletNames;
  const WishListScreen({
    super.key,
    required this.walletId,
    this.walletName = 'Personal',
    this.walletEmoji = '👤',
    this.members = const [],
    required this.wishes,
    this.openAdd = false,
    this.familyWalletNames = const {},
  });
  @override
  State<WishListScreen> createState() => _WishListScreenState();
}

class _WishListScreenState extends State<WishListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<WishModel> _wishes = [];
  bool _loading = false;
  bool _wasOnline = true;
  WishCategory? _filterCat;

  List<WishModel> get _filtered {
    var list = List<WishModel>.from(_wishes);
    if (_filterCat != null) {
      list = list.where((w) => w.category == _filterCat).toList();
    }
    return list;
  }

  List<WishModel> get _active =>
      _filtered.where((w) => !w.purchased).toList()
        ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
  List<WishModel> get _purchased =>
      _filtered.where((w) => w.purchased).toList();

  void _onNetworkChange() {
    final online = NetworkService.instance.isOnline.value;
    if (online && !_wasOnline) _loadWishes();
    _wasOnline = online;
  }

  @override
  void initState() {
    super.initState();
    _wasOnline = NetworkService.instance.isOnline.value;
    NetworkService.instance.isOnline.addListener(_onNetworkChange);
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
    _loadWishes();
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
        _openAddSheet(context, isDark, surfBg);
      });
    }
  }

  @override
  void dispose() {
    NetworkService.instance.isOnline.removeListener(_onNetworkChange);
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadWishes() async {
    if (widget.walletId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    if (widget.familyWalletNames.isNotEmpty) {
      // Personal view: fetch from personal wallet + all family wallets.
      setState(() => _loading = true);
      try {
        final allIds = [widget.walletId, ...widget.familyWalletNames.keys];
        final results = await Future.wait(
          allIds.map((id) => WishService.instance.fetchWishes(id)),
        );
        if (!mounted) return;
        final loaded = results.expand((rows) => rows.map(WishModel.fromRow)).toList();
        setState(() {
          _wishes = loaded;
          widget.wishes..clear()..addAll(loaded);
          _loading = false;
        });
      } catch (e) {
        debugPrint('[WishList] personal load error: $e');
        if (mounted) setState(() => _loading = false);
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await WishService.instance.fetchWishes(widget.walletId);
      if (!mounted) return;
      final loaded = rows.map(WishModel.fromRow).toList();
      setState(() {
        _wishes = loaded;
        widget.wishes
          ..clear()
          ..addAll(loaded);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[WishList] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(WishModel w) async {
    try {
      final row = await WishService.instance.addWish(w.toRow());
      final saved = WishModel.fromRow(row);
      if (mounted) setState(() => _wishes.add(saved));
    } catch (e) {
      debugPrint('[WishList] add error: $e');
      if (mounted) setState(() => _wishes.add(w));
    }
  }

  Future<void> _delete(WishModel w) async {
    setState(() => _wishes.remove(w));
    try {
      await WishService.instance.deleteWish(w.id);
    } catch (_) {}
  }

  Future<void> _update(WishModel u) async {
    setState(() {
      final i = _wishes.indexWhere((w) => w.id == u.id);
      if (i >= 0) _wishes[i] = u;
    });
    try {
      await WishService.instance.updateWish(u.id, u.toRow());
    } catch (_) {}
  }

  Future<void> _addSaving(WishModel w, double amount, String? note) async {
    w.savedAmount += amount;
    w.savingsHistory.add(
      SavingsEntry(amount: amount, date: DateTime.now(), note: note),
    );
    setState(() {});
    try {
      await WishService.instance.updateWish(w.id, w.toRow());
    } catch (_) {}
  }

  void _togglePurchased(WishModel w) {
    final prev = w.purchased;
    setState(() => w.purchased = !w.purchased);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !prev ? '🎉 Marked as purchased!' : '↩️ Moved back to wishlist',
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: !prev ? AppColors.income : AppColors.lend,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () => setState(() => w.purchased = prev),
        ),
      ),
    );
  }

  /// Toggle purchased without closing the sheet — sheet updates in-place.
  void _togglePurchasedInSheet(WishModel w, BuildContext sheetCtx) {
    w.purchased = !w.purchased;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;
    final active = _active;
    final totalTarget = active.fold<double>(
      0,
      (s, w) => s + (w.targetPrice ?? 0),
    );
    final totalSaved = active.fold<double>(0, (s, w) => s + w.savedAmount);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('🌟', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Wish List',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
        actions: [
          if (widget.walletName != 'Personal')
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmojiOrImage(value: widget.walletEmoji, size: 18, borderRadius: 4),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 75,
                    child: Text(
                      widget.walletName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            fontSize: 12,
          ),
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: subColor,
          tabs: [
            Tab(text: 'Wishlist (${_active.length})'),
            Tab(text: 'Purchased (${_purchased.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, isDark, surfBg),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Wish',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: Column(
        children: [
          if (_tab.index == 0 && active.isNotEmpty)
            _SummaryBar(
              totalTarget: totalTarget,
              totalSaved: totalSaved,
              isDark: isDark,
              surfBg: surfBg,
            ),
          _CategoryFilter(
            selected: _filterCat,
            subColor: subColor,
            onSelect: (c) => setState(() => _filterCat = c),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                RefreshIndicator(
                  onRefresh: _loadWishes,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _WishList(
                          key: ValueKey('active-${_active.length}'),
                          wishes: _active,
                          isDark: isDark,
                          onDelete: _delete,
                          onTap: (w) =>
                              _openDetailSheet(context, w, isDark, surfBg),
                          familyWalletNames: widget.familyWalletNames,
                        ),
                ),
                RefreshIndicator(
                  onRefresh: _loadWishes,
                  child: _WishList(
                    key: ValueKey('purchased-${_purchased.length}'),
                    wishes: _purchased,
                    isDark: isDark,
                    showPurchasedBadge: true,
                    onDelete: _delete,
                    onTap: (w) => _openDetailSheet(context, w, isDark, surfBg),
                    familyWalletNames: widget.familyWalletNames,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAddSheet(BuildContext ctx, bool isDark, Color surfBg) =>
      showModalBottomSheet(
        context: ctx,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _WishSheetHost(
          isDark: isDark,
          surfBg: surfBg,
          walletId: widget.walletId,
          onSave: _add,
        ),
      );

  void _openDetailSheet(
    BuildContext ctx,
    WishModel w,
    bool isDark,
    Color surfBg,
  ) {
    showPlanSheet(
      ctx,
      child: _WishDetailSheet(
        wish: w,
        isDark: isDark,
        surfBg: surfBg,
        onAddSaving: (amt, note) => setState(() => _addSaving(w, amt, note)),
        onTogglePurchased: () =>
            setState(() => _togglePurchasedInSheet(w, ctx)),
        onEdit: () {
          Navigator.pop(ctx);
          _openEditSheet(ctx, w, isDark, surfBg);
        },
        onDelete: () {
          _delete(w);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _openEditSheet(
    BuildContext ctx,
    WishModel existing,
    bool isDark,
    Color surfBg,
  ) => showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _WishSheetHost(
      isDark: isDark,
      surfBg: surfBg,
      walletId: widget.walletId,
      existing: existing,
      onSave: _update,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final double totalTarget, totalSaved;
  final bool isDark;
  final Color surfBg;
  const _SummaryBar({
    required this.totalTarget,
    required this.totalSaved,
    required this.isDark,
    required this.surfBg,
  });

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final prog = totalTarget > 0
        ? (totalSaved / totalTarget).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StatBox(
                label: 'Total Goal',
                value: _fmt(totalTarget),
                color: AppColors.primary,
                isDark: isDark,
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.grey.withOpacity(0.2),
              ),
              _StatBox(
                label: 'Saved',
                value: _fmt(totalSaved),
                color: AppColors.income,
                isDark: isDark,
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.grey.withOpacity(0.2),
              ),
              _StatBox(
                label: 'Remaining',
                value: _fmt(
                  (totalTarget - totalSaved).clamp(0, double.infinity),
                ),
                color: AppColors.expense,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: prog,
              minHeight: 6,
              backgroundColor: Colors.grey.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.income),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(prog * 100).toStringAsFixed(0)}% saved',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: sub,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark;
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });
  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: sub),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY FILTER
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryFilter extends StatelessWidget {
  final WishCategory? selected;
  final Color subColor;
  final void Function(WishCategory?) onSelect;
  const _CategoryFilter({
    required this.selected,
    required this.subColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        children: [
          _Pill(
            label: '🌟 All',
            selected: selected == null,
            color: AppColors.primary,
            onTap: () => onSelect(null),
          ),
          ...WishCategory.values.map(
            (c) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _Pill(
                label: '${c.emoji} ${c.label}',
                selected: selected == c,
                color: AppColors.split,
                onTap: () => onSelect(selected == c ? null : c),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Pill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color
                : (isDark ? AppColors.surfDark : const Color(0xFFE0E0EC)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
            color: selected
                ? color
                : (isDark ? AppColors.subDark : AppColors.subLight),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WISH LIST
// ─────────────────────────────────────────────────────────────────────────────

class _WishList extends StatelessWidget {
  final List<WishModel> wishes;
  final bool isDark, showPurchasedBadge;
  final void Function(WishModel) onDelete, onTap;
  final Map<String, String> familyWalletNames;
  const _WishList({
    super.key,
    required this.wishes,
    required this.isDark,
    this.showPurchasedBadge = false,
    required this.onDelete,
    required this.onTap,
    this.familyWalletNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (wishes.isEmpty) {
      return PlanEmptyState(
        emoji: showPurchasedBadge ? '🛍️' : '🌟',
        title: showPurchasedBadge ? 'No purchases yet' : 'No wishes yet',
        subtitle: showPurchasedBadge
            ? 'Mark items as purchased'
            : 'Add things you want to save for',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: wishes.length,
      itemBuilder: (_, i) {
        final w = wishes[i];
        final familyLabel = familyWalletNames[w.walletId];
        final card = _WishCard(
          wish: w,
          isDark: isDark,
          showPurchasedBadge: showPurchasedBadge,
          familyLabel: familyLabel,
          onTap: familyLabel == null ? () => onTap(w) : () {},
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: familyLabel != null
              ? card
              : SwipeTile(onDelete: () => onDelete(w), child: card),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WISH CARD
// ─────────────────────────────────────────────────────────────────────────────

class _WishCard extends StatelessWidget {
  final WishModel wish;
  final bool isDark, showPurchasedBadge;
  final VoidCallback onTap;
  final String? familyLabel;
  const _WishCard({
    required this.wish,
    required this.isDark,
    this.showPurchasedBadge = false,
    required this.onTap,
    this.familyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final color = wish.priority.color;
    final prog = wish.progress;

    return GestureDetector(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            wish.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                wish.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Nunito',
                                  color: tc,
                                  decoration: showPurchasedBadge
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 6,
                                children: [
                                  _Badge(
                                    label: wish.priority.label,
                                    color: color,
                                  ),
                                  Text(
                                    '${wish.category.emoji} ${wish.category.label}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                  ),
                                  if (showPurchasedBadge)
                                    _Badge(
                                      label: '✅ Purchased',
                                      color: AppColors.income,
                                    ),
                                  if (familyLabel != null)
                                    FamilyBadge(label: familyLabel!),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (wish.targetPrice != null)
                              Text(
                                _fmt(wish.targetPrice!),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Nunito',
                                  color: tc,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              '${_fmt(wish.savedAmount)} saved',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color: AppColors.income,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (wish.targetPrice != null && wish.targetPrice! > 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: prog.toDouble(),
                                minHeight: 5,
                                backgroundColor: Colors.grey.withOpacity(0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  prog >= 1 ? AppColors.income : color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(prog * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: prog >= 1 ? AppColors.income : sub,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (wish.targetDate != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.event_outlined, size: 12, color: sub),
                          const SizedBox(width: 4),
                          Text(
                            'By ${_fmtDate(wish.targetDate!)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _WishDetailSheet extends StatefulWidget {
  final WishModel wish;
  final bool isDark;
  final Color surfBg;
  final void Function(double, String?) onAddSaving;
  final VoidCallback onTogglePurchased, onEdit, onDelete;
  const _WishDetailSheet({
    required this.wish,
    required this.isDark,
    required this.surfBg,
    required this.onAddSaving,
    required this.onTogglePurchased,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  State<_WishDetailSheet> createState() => _WishDetailSheetState();
}

class _WishDetailSheetState extends State<_WishDetailSheet> {
  final _amtCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _showForm = false;

  // Local mirrors — update instantly on interaction without waiting for parent rebuild
  late bool _purchased;
  late double _savedAmount;
  late List<SavingsEntry> _history;

  @override
  void initState() {
    super.initState();
    _purchased = widget.wish.purchased;
    _savedAmount = widget.wish.savedAmount;
    _history = List.from(widget.wish.savingsHistory);
  }

  @override
  void didUpdateWidget(_WishDetailSheet old) {
    super.didUpdateWidget(old);
    // Sync if parent pushed a change (e.g. external edit)
    _purchased = widget.wish.purchased;
    _savedAmount = widget.wish.savedAmount;
    _history = List.from(widget.wish.savingsHistory);
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submitSaving() {
    final amount = double.tryParse(_amtCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) return;
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final entry = SavingsEntry(
      amount: amount,
      date: DateTime.now(),
      note: note,
    );
    setState(() {
      _savedAmount += amount;
      _history.add(entry);
      _amtCtrl.clear();
      _noteCtrl.clear();
      _showForm = false;
    });
    widget.onAddSaving(amount, note);
  }

  void _togglePurchased() {
    setState(() => _purchased = !_purchased);
    widget.onTogglePurchased();
  }

  @override
  Widget build(BuildContext context) {
    final wish = widget.wish;
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;
    final color = wish.priority.color;
    final target = wish.targetPrice;
    final prog = (target != null && target > 0)
        ? (_savedAmount / target).clamp(0.0, 1.0)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(wish.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wish.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(label: wish.priority.label, color: color),
                        _Badge(
                          label:
                              '${wish.category.emoji} ${wish.category.label}',
                          color: AppColors.split,
                        ),
                        if (_purchased)
                          _Badge(label: '✅ Purchased', color: AppColors.income),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress card
          if (target != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fmt(_savedAmount),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Nunito',
                                color: AppColors.income,
                              ),
                            ),
                            Text(
                              'saved of ${_fmt(target)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Nunito',
                                color: sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${(prog * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                          color: prog >= 1 ? AppColors.income : color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: prog,
                      minHeight: 8,
                      backgroundColor: Colors.grey.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        prog >= 1 ? AppColors.income : color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Remaining: ${_fmt((target - _savedAmount).clamp(0, double.infinity))}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: sub,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (wish.targetDate != null)
                        Text(
                          'By ${_fmtDate(wish.targetDate!)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (wish.note != null && wish.note!.isNotEmpty) ...[
            Text(
              wish.note!,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Nunito',
                color: sub,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Savings history
          if (_history.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Savings History',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.income.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_history.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.income,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._history.reversed.map(
              (e) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.income.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.income.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.income.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('💰', style: TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '+${_fmt(e.amount)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Nunito',
                              color: AppColors.income,
                            ),
                          ),
                          if (e.note != null && e.note!.isNotEmpty)
                            Text(
                              e.note!,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color: sub,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Date — show day + time
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _fmtDate(e.date),
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Nunito',
                            color: sub,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _fmtTime(e.date),
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Add saving toggle
          if (!_purchased) ...[
            GestureDetector(
              onTap: () => setState(() => _showForm = !_showForm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _showForm
                      ? AppColors.income.withOpacity(0.1)
                      : widget.surfBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _showForm
                        ? AppColors.income.withOpacity(0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Text(
                      'Add Saving',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: _showForm ? AppColors.income : tc,
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: _showForm ? 0.5 : 0,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _showForm ? AppColors.income : sub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.income.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.income.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    PlanInputField(
                      controller: _amtCtrl,
                      hint: 'Amount (e.g. 5000)',
                      inputType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PlanInputField(
                      controller: _noteCtrl,
                      hint: 'Note (optional)',
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _submitSaving,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.income, Color(0xFF00A67E)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Add Saving',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _showForm
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
            const SizedBox(height: 10),
          ],

          // Purchased banner (when purchased)
          if (_purchased) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.income.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.income.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchased!',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            color: AppColors.income,
                          ),
                        ),
                        Text(
                          'Tap "Undo Purchase" to move back to wishlist',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: AppColors.income.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _togglePurchased,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _purchased
                            ? [AppColors.lend, const Color(0xFFE8921C)]
                            : [AppColors.income, const Color(0xFF00A67E)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _purchased ? '↩️' : '✅',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _purchased ? 'Undo Purchase' : 'Mark Purchased',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: widget.onDelete,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.expense.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.expense.withOpacity(0.3)),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Delete Wish',
                style: TextStyle(
                  color: AppColors.expense,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET HOST
// ─────────────────────────────────────────────────────────────────────────────

class _WishSheetHost extends StatelessWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final WishModel? existing;
  final void Function(WishModel) onSave;
  const _WishSheetHost({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    this.existing,
    required this.onSave,
  });

  @override
  Widget build(BuildContext hostCtx) {
    final isEdit = existing != null;
    final mq = MediaQuery.of(hostCtx);
    final kb = mq.viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: _AddWishSheet(
                isDark: isDark,
                surfBg: surfBg,
                walletId: walletId,
                existing: existing,
                onSave: (w) {
                  Navigator.pop(hostCtx);
                  onSave(w);
                  ScaffoldMessenger.of(hostCtx).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? '${w.emoji} "${w.title}" updated!'
                            : '${w.emoji} "${w.title}" added!',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: AppColors.income,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD / EDIT SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _AddWishSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final WishModel? existing;
  final void Function(WishModel) onSave;
  const _AddWishSheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    this.existing,
    required this.onSave,
  });
  @override
  State<_AddWishSheet> createState() => _AddWishSheetState();
}

class _AddWishSheetState extends State<_AddWishSheet>
    with SingleTickerProviderStateMixin {
  late TabController _mode;
  final _aiCtrl = TextEditingController();
  bool _aiParsing = false;
  _ParsedWish? _aiPreview;
  String? _aiError;
  bool _usingClaude = false;

  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  WishCategory _cat = WishCategory.other;
  Priority _priority = Priority.medium;
  String _emoji = '🎁';
  DateTime? _targetDate;
  bool _titleError = false;

  static const _catEmojis = <WishCategory, List<String>>{
    WishCategory.electronics: ['💻', '📱', '🎧', '📷', '🖥️', '⌚', '🎮', '🔌'],
    WishCategory.fashion: ['👗', '👟', '👜', '🕶️', '💍', '🧥', '👒', '💄'],
    WishCategory.home: ['🛋️', '🛏️', '🍳', '🖼️', '🌿', '💡', '🪴', '🧹'],
    WishCategory.travel: ['✈️', '🏖️', '🏕️', '🗺️', '🎒', '🏨', '🚢', '🚂'],
    WishCategory.food: ['🍽️', '☕', '🍷', '🍣', '🍕', '🎂', '🥗', '🍜'],
    WishCategory.experience: ['🎭', '🎪', '🎓', '🏆', '🎵', '🎨', '🎯', '🎢'],
    WishCategory.other: ['🎁', '⭐', '💫', '🌈', '🔖', '🎀', '🗓️', '💡'],
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _mode = TabController(
      length: 2,
      vsync: this,
      initialIndex: e != null ? 1 : 0,
    );
    _mode.addListener(() => setState(() {}));
    if (e != null) {
      _titleCtrl.text = e.title;
      _noteCtrl.text = e.note ?? '';
      _linkCtrl.text = e.link ?? '';
      _priceCtrl.text = e.targetPrice != null
          ? e.targetPrice!.toStringAsFixed(0)
          : '';
      _cat = e.category;
      _priority = e.priority;
      _emoji = e.emoji;
      _targetDate = e.targetDate;
    }
  }

  @override
  void dispose() {
    _mode.dispose();
    _aiCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _linkCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _parseAI(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _aiParsing = true;
      _aiError = null;
      _aiPreview = null;
      _usingClaude = false;
    });
    _ParsedWish? result;
    try {
      final aiResult = await AIParser.parseText(
        feature: 'planit',
        subFeature: 'wishlist',
        text: text.trim(),
      );
      if (aiResult.success && aiResult.data != null) {
        result = _parsedWishFromAI(aiResult.data!);
        _usingClaude = true;
      } else {
        throw Exception(aiResult.error);
      }
    } catch (_) {
      result = _WishNlpParser.parse(text.trim());
    }
    debugPrint('[WishList] parse result: title=${result.title} price=${result.targetPrice} usingAI=$_usingClaude');
    if (!mounted) return;
    setState(() {
      _aiParsing = false;
      _aiPreview = result;
      _titleCtrl.text = result!.title;
      _noteCtrl.text = result.note ?? '';
      _linkCtrl.text = result.link ?? '';
      _priceCtrl.text = result.targetPrice != null
          ? result.targetPrice!.toStringAsFixed(0)
          : '';
      _cat = result.category;
      _priority = result.priority;
      _emoji = result.emoji;
      _targetDate = result.targetDate;
    });
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    setState(() => _titleError = false);
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', ''));
    final e = widget.existing;
    widget.onSave(
      WishModel(
        id: e?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        emoji: _emoji,
        category: _cat,
        priority: _priority,
        walletId: widget.walletId,
        targetPrice: price,
        savedAmount: e?.savedAmount ?? 0,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        link: _linkCtrl.text.trim().isEmpty ? null : _linkCtrl.text.trim(),
        targetDate: _targetDate,
        purchased: e?.purchased ?? false,
        savingsHistory: e?.savingsHistory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      children: [
        Row(
          children: [
            const Text('🌟', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(
              widget.existing != null ? 'Edit Wish' : 'New Wish',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Tab switcher
        Container(
          decoration: BoxDecoration(
            color: widget.surfBg,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(3),
          child: TabBar(
            controller: _mode,
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF9C6DFF)],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: sub,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              fontFamily: 'Nunito',
            ),
            padding: EdgeInsets.zero,
            tabs: const [
              Tab(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('✨', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('AI Parse'),
                  ],
                ),
              ),
              Tab(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_outlined, size: 14),
                    SizedBox(width: 6),
                    Text('Manual'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // AI TAB
        if (_mode.index == 0) ...[
          _AiHint(isDark: widget.isDark),
          const SizedBox(height: 12),
          _AiInputBox(
            ctrl: _aiCtrl,
            surfBg: widget.surfBg,
            isDark: widget.isDark,
            isParsing: _aiParsing,
            onParse: () => _parseAI(_aiCtrl.text),
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 10),
            _ErrorBanner(message: _aiError!),
          ],
          if (_aiPreview != null) ...[
            const SizedBox(height: 12),
            _AiPreviewCard(
              preview: _aiPreview!,
              isDark: widget.isDark,
              surfBg: widget.surfBg,
              usedClaude: _usingClaude,
              onEdit: () => _mode.animateTo(1),
            ),
            const SizedBox(height: 16),
            SaveButton(
              label: widget.existing != null ? 'Update Wish →' : 'Save Wish →',
              color: AppColors.primary,
              onTap: _save,
            ),
          ],
          if (_aiPreview == null && !_aiParsing) ...[
            const SizedBox(height: 12),
            _AiExamples(
              surfBg: widget.surfBg,
              sub: sub,
              onTap: (s) {
                _aiCtrl.text = s;
              },
            ),
          ],
        ],

        // MANUAL TAB
        if (_mode.index == 1) ...[
          _ManualForm(
            isDark: widget.isDark,
            surfBg: widget.surfBg,
            titleCtrl: _titleCtrl,
            noteCtrl: _noteCtrl,
            linkCtrl: _linkCtrl,
            priceCtrl: _priceCtrl,
            category: _cat,
            priority: _priority,
            emoji: _emoji,
            targetDate: _targetDate,
            titleError: _titleError,
            categoryEmojis: _catEmojis,
            onCategoryChanged: (c) => setState(() {
              _cat = c;
              _emoji = (_catEmojis[c] ?? ['🎁']).first;
            }),
            onPriorityChanged: (p) => setState(() => _priority = p),
            onEmojiChanged: (e) => setState(() => _emoji = e),
            onDateChanged: (d) => setState(() => _targetDate = d),
          ),
          const SizedBox(height: 16),
          SaveButton(
            label: widget.existing != null ? 'Update Wish →' : 'Save Wish →',
            color: AppColors.primary,
            onTap: _save,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MANUAL FORM
// ─────────────────────────────────────────────────────────────────────────────

class _ManualForm extends StatelessWidget {
  final bool isDark;
  final Color surfBg;
  final TextEditingController titleCtrl, noteCtrl, linkCtrl, priceCtrl;
  final WishCategory category;
  final Priority priority;
  final String emoji;
  final DateTime? targetDate;
  final bool titleError;
  final Map<WishCategory, List<String>> categoryEmojis;
  final void Function(WishCategory) onCategoryChanged;
  final void Function(Priority) onPriorityChanged;
  final void Function(String) onEmojiChanged;
  final void Function(DateTime?) onDateChanged;

  const _ManualForm({
    required this.isDark,
    required this.surfBg,
    required this.titleCtrl,
    required this.noteCtrl,
    required this.linkCtrl,
    required this.priceCtrl,
    required this.category,
    required this.priority,
    required this.emoji,
    required this.targetDate,
    required this.titleError,
    required this.categoryEmojis,
    required this.onCategoryChanged,
    required this.onPriorityChanged,
    required this.onEmojiChanged,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final emojis = categoryEmojis[category] ?? ['🎁'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetLabel(text: 'CATEGORY'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: WishCategory.values
              .map(
                (c) => GestureDetector(
                  onTap: () => onCategoryChanged(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: category == c
                          ? AppColors.primary.withOpacity(0.15)
                          : surfBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: category == c
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      '${c.emoji} ${c.label}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: category == c ? AppColors.primary : sub,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: emojis
                .map(
                  (e) => GestureDetector(
                    onTap: () => onEmojiChanged(e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: emoji == e
                            ? AppColors.primary.withOpacity(0.15)
                            : surfBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: emoji == e
                              ? AppColors.primary
                              : Colors.transparent,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Title
        Container(
          decoration: BoxDecoration(
            color: surfBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: titleError ? AppColors.expense : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleCtrl,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
                decoration: InputDecoration.collapsed(
                  hintText: 'What do you wish for? *',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: titleError ? AppColors.expense : sub,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
              if (titleError) ...[
                const SizedBox(height: 4),
                const Text(
                  'Title is required',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.expense,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Price
        Container(
          decoration: BoxDecoration(
            color: surfBg,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Text(
                'Rs.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.income,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: tc,
                    fontFamily: 'Nunito',
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: 'Target price (optional)',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: sub,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        PlanInputField(
          controller: noteCtrl,
          hint: 'Note (optional)',
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        PlanInputField(controller: linkCtrl, hint: 'Link (optional)'),
        const SizedBox(height: 14),

        const SheetLabel(text: 'PRIORITY'),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: Priority.values
              .map(
                (p) => GestureDetector(
                  onTap: () => onPriorityChanged(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: priority == p ? p.color.withOpacity(0.15) : surfBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: priority == p ? p.color : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: priority == p ? p.color : sub,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),

        const SheetLabel(text: 'TARGET DATE (OPTIONAL)'),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate:
                  targetDate ?? DateTime.now().add(const Duration(days: 30)),
              firstDate: DateTime.now(),
              lastDate: DateTime(2100),
            );
            if (d != null) onDateChanged(d);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: targetDate != null ? AppColors.primary : sub,
                ),
                const SizedBox(width: 10),
                Text(
                  targetDate != null
                      ? 'By ${_fmtDate(targetDate!)}'
                      : 'Set a target date',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                    color: targetDate != null ? tc : sub,
                  ),
                ),
                const Spacer(),
                if (targetDate != null)
                  GestureDetector(
                    onTap: () => onDateChanged(null),
                    child: Icon(Icons.close_rounded, size: 16, color: sub),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _AiHint extends StatelessWidget {
  final bool isDark;
  const _AiHint({required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('✨', style: TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Describe what you want — AI will fill in category, price, priority and more.',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Nunito',
              color: isDark ? AppColors.textDark : AppColors.textLight,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AiInputBox extends StatelessWidget {
  final TextEditingController ctrl;
  final Color surfBg;
  final bool isDark, isParsing;
  final VoidCallback onParse;
  const _AiInputBox({
    required this.ctrl,
    required this.surfBg,
    required this.isDark,
    required this.isParsing,
    required this.onParse,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Container(
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: TextField(
              controller: ctrl,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
              decoration: InputDecoration.collapsed(
                hintText:
                    '"MacBook Pro for Rs. 1,80,000 by December" or "Trip to Goa medium priority Rs. 50k"',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: sub,
                  fontFamily: 'Nunito',
                  height: 1.4,
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: AppColors.primary.withOpacity(0.15),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Plain text → AI fills all fields',
                    style: TextStyle(
                      fontSize: 11,
                      color: sub,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: isParsing ? null : onParse,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      gradient: isParsing
                          ? null
                          : const LinearGradient(
                              colors: [AppColors.primary, Color(0xFF9C6DFF)],
                            ),
                      color: isParsing
                          ? AppColors.primary.withOpacity(0.3)
                          : null,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: isParsing
                        ? const SizedBox(
                            width: 64,
                            height: 16,
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.transparent,
                              color: Colors.white,
                              minHeight: 2,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('✨', style: TextStyle(fontSize: 13)),
                              SizedBox(width: 5),
                              Text(
                                'Parse',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.expense.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.expense.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.expense,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Nunito',
              color: AppColors.expense,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AiPreviewCard extends StatelessWidget {
  final _ParsedWish preview;
  final bool isDark, usedClaude;
  final Color surfBg;
  final VoidCallback onEdit;
  const _AiPreviewCard({
    required this.preview,
    required this.isDark,
    required this.surfBg,
    required this.usedClaude,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final color = preview.priority.color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.income.withOpacity(isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.income.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  preview.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.income.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        usedClaude ? '🤖 AI Parsed' : '✨ AI Parsed',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.income,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.income.withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 12,
                        color: AppColors.income,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.income,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ChipBadge(
                label: '${preview.category.emoji} ${preview.category.label}',
                color: AppColors.split,
              ),
              _ChipBadge(label: preview.priority.label, color: color),
              if (preview.targetPrice != null)
                _ChipBadge(
                  label: _fmt(preview.targetPrice!),
                  color: AppColors.income,
                ),
              if (preview.targetDate != null)
                _ChipBadge(
                  label: 'By ${_fmtDate(preview.targetDate!)}',
                  color: AppColors.primary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _ChipBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
          color: color,
        ),
      ),
    );
  }
}

class _AiExamples extends StatelessWidget {
  final Color surfBg, sub;
  final void Function(String) onTap;
  const _AiExamples({
    required this.surfBg,
    required this.sub,
    required this.onTap,
  });
  static const _examples = [
    'MacBook Pro M3 for Rs. 1,80,000 by December high priority',
    'Family trip to Bali Rs. 1,50,000 medium priority',
    'Sony headphones Rs. 28,000 low priority',
    'New sofa for home Rs. 35,000',
    'Cooking class experience Rs. 5,000 next month',
  ];
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Try an example',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
          color: sub,
        ),
      ),
      const SizedBox(height: 8),
      ..._examples.map(
        (e) => GestureDetector(
          onTap: () => onTap(e),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Text('💬', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                ),
                Icon(
                  Icons.north_west_rounded,
                  size: 12,
                  color: AppColors.primary.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CLAUDE PARSER
// ─────────────────────────────────────────────────────────────────────────────

class _ParsedWish {
  final String title, emoji;
  final WishCategory category;
  final Priority priority;
  final double? targetPrice;
  final DateTime? targetDate;
  final String? note, link;
  const _ParsedWish({
    required this.title,
    required this.emoji,
    required this.category,
    required this.priority,
    this.targetPrice,
    this.targetDate,
    this.note,
    this.link,
  });
}

/// Maps AI edge-function response to [_ParsedWish].
_ParsedWish _parsedWishFromAI(Map<String, dynamic> data) {
  const cm = {
    'electronics': WishCategory.electronics,
    'gadget': WishCategory.electronics,
    'gadgets': WishCategory.electronics,
    'tech': WishCategory.electronics,
    'fashion': WishCategory.fashion,
    'clothing': WishCategory.fashion,
    'apparel': WishCategory.fashion,
    'home': WishCategory.home,
    'furniture': WishCategory.home,
    'appliance': WishCategory.home,
    'travel': WishCategory.travel,
    'trip': WishCategory.travel,
    'vacation': WishCategory.travel,
    'food': WishCategory.food,
    'dining': WishCategory.food,
    'experience': WishCategory.experience,
    'entertainment': WishCategory.experience,
    'other': WishCategory.other,
  };
  const pm = {
    'low': Priority.low,
    'medium': Priority.medium,
    'high': Priority.high,
    'urgent': Priority.urgent,
  };
  DateTime? date;
  try {
    final rawDate = data['targetDate'] ?? data['target_date'];
    if (rawDate != null) date = DateTime.parse(rawDate as String);
  } catch (_) {}
  // Accept any common price key the AI might return
  final rawPrice = data['targetPrice'] ??
      data['target_price'] ??
      data['target_amount'] ??
      data['price'] ??
      data['amount'] ??
      data['cost'];
  double? targetPrice;
  if (rawPrice is num) {
    targetPrice = rawPrice.toDouble();
  } else if (rawPrice is String && rawPrice.isNotEmpty) {
    targetPrice = double.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9.]'), ''));
  }
  debugPrint('[WishParse] raw=$rawPrice → targetPrice=$targetPrice data=$data');
  return _ParsedWish(
    title: data['title'] as String? ?? '',
    emoji: data['emoji'] as String? ?? '🎁',
    category: cm[data['category']] ?? WishCategory.other,
    priority: pm[data['priority']] ?? Priority.medium,
    targetPrice: targetPrice,
    targetDate: date,
    note: data['note'] as String?,
    link: data['link'] as String?,
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// NLP FALLBACK
// ─────────────────────────────────────────────────────────────────────────────

class _WishNlpParser {
  static _ParsedWish parse(String raw) {
    final lower = raw.toLowerCase();
    WishCategory cat = WishCategory.other;
    if (lower.contains('laptop') ||
        lower.contains('phone') ||
        lower.contains('macbook') ||
        lower.contains('headphone') ||
        lower.contains('camera') ||
        lower.contains('iphone') ||
        lower.contains('tablet')) {
      cat = WishCategory.electronics;
    } else if (lower.contains('trip') ||
        lower.contains('travel') ||
        lower.contains('goa') ||
        lower.contains('bali') ||
        lower.contains('vacation') ||
        lower.contains('flight'))
      cat = WishCategory.travel;
    else if (lower.contains('sofa') ||
        lower.contains('fridge') ||
        lower.contains('furniture') ||
        lower.contains(' tv') ||
        lower.contains('home'))
      cat = WishCategory.home;
    else if (lower.contains('shirt') ||
        lower.contains('shoe') ||
        lower.contains('dress') ||
        lower.contains('bag') ||
        lower.contains('clothes'))
      cat = WishCategory.fashion;
    else if (lower.contains('course') ||
        lower.contains('class') ||
        lower.contains('concert') ||
        lower.contains('experience') ||
        lower.contains('ticket'))
      cat = WishCategory.experience;
    else if (lower.contains('restaurant') ||
        lower.contains('food') ||
        lower.contains('dinner'))
      cat = WishCategory.food;

    const em = {
      WishCategory.electronics: '💻',
      WishCategory.travel: '✈️',
      WishCategory.home: '🛋️',
      WishCategory.fashion: '👗',
      WishCategory.experience: '🎭',
      WishCategory.food: '🍽️',
      WishCategory.other: '🎁',
    };
    String emoji = em[cat]!;
    if (lower.contains('macbook') || lower.contains('laptop')) {
      emoji = '💻';
    } else if (lower.contains('iphone') || lower.contains('phone'))
      emoji = '📱';
    else if (lower.contains('headphone'))
      emoji = '🎧';
    else if (lower.contains('goa') ||
        lower.contains('beach') ||
        lower.contains('trip'))
      emoji = '🏖️';
    else if (lower.contains('sofa'))
      emoji = '🛋️';

    Priority priority = Priority.medium;
    if (lower.contains('urgent')) {
      priority = Priority.urgent;
    } else if (lower.contains('high priority') || lower.contains('important'))
      priority = Priority.high;
    else if (lower.contains('low priority') || lower.contains('someday'))
      priority = Priority.low;

    double? price;
    // 1. "Rs. 1,80,000" or "₹180000" — with currency prefix
    final pm = RegExp(
      r'(?:rs\.?\s*|₹\s*)(\d[\d,]*)(?:\s*k)?',
      caseSensitive: false,
    ).firstMatch(raw);
    if (pm != null) {
      final n = pm.group(1)!.replaceAll(',', '');
      price = double.tryParse(n);
      if (price != null && pm.group(0)!.toLowerCase().contains('k')) {
        price *= 1000;
      }
    }
    // 2. "180k" or "50k" — shorthand thousands
    if (price == null) {
      final pm2 = RegExp(r'\b(\d[\d,]*)\s*k\b').firstMatch(lower);
      if (pm2 != null) {
        price = (double.tryParse(pm2.group(1)!.replaceAll(',', '')) ?? 0) * 1000;
      }
    }
    // 3. Plain large number like "180000" or "1,80,000" (≥1000)
    if (price == null) {
      final pm3 = RegExp(r'\b(\d{1,3}(?:,\d{2,3})+|\d{4,})\b').firstMatch(raw);
      if (pm3 != null) {
        final n = pm3.group(1)!.replaceAll(',', '');
        final v = double.tryParse(n);
        if (v != null && v >= 1000) price = v;
      }
    }

    DateTime? date;
    const months = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    for (int i = 0; i < months.length; i++) {
      if (lower.contains(months[i])) {
        date = DateTime(DateTime.now().year, i + 1, 1);
        break;
      }
    }
    if (date == null && lower.contains('next month')) {
      date = DateTime(DateTime.now().year, DateTime.now().month + 1, 1);
    } else if (date == null && lower.contains('next year'))
      date = DateTime(DateTime.now().year + 1, 1, 1);

    String title = raw
        .trim()
        .replaceAll(
          RegExp(
            r',?\s*(high|low|medium|urgent)\s*priority',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'(?:rs\.?\s*)[\d,]+(?:\s*k)?', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (title.isEmpty) title = raw.trim();
    if (title.isNotEmpty) title = title[0].toUpperCase() + title.substring(1);

    return _ParsedWish(
      title: title,
      emoji: emoji,
      category: cat,
      priority: priority,
      targetPrice: price,
      targetDate: date,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _fmt(double v) {
  if (v >= 100000) return 'Rs.${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return 'Rs.${(v / 1000).toStringAsFixed(1)}K';
  return 'Rs.${v.toStringAsFixed(0)}';
}

String _fmtDate(DateTime d) {
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${m[d.month - 1]} ${d.day}, ${d.year}';
}

String _fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final min = d.minute.toString().padLeft(2, '0');
  final period = d.hour < 12 ? 'AM' : 'PM';
  return '$h:$min $period';
}
