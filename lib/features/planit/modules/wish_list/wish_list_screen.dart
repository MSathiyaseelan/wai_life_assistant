import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import '../../widgets/plan_widgets.dart';

class WishListScreen extends StatefulWidget {
  final String walletId;
  const WishListScreen({super.key, required this.walletId});
  @override
  State<WishListScreen> createState() => _WishListScreenState();
}

class _WishListScreenState extends State<WishListScreen> {
  final List<WishModel> _wishes = List.from(mockWishes);
  WishCategory? _filter;

  List<WishModel> get _filtered {
    var list = _wishes.where((w) => w.walletId == widget.walletId).toList();
    if (_filter != null)
      list = list.where((w) => w.category == _filter).toList();
    return list;
  }

  List<WishModel> get _pending => _filtered.where((w) => !w.purchased).toList();
  List<WishModel> get _achieved => _filtered.where((w) => w.purchased).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;

    // Summary stats
    final totalTarget = _pending.fold<double>(
      0,
      (s, w) => s + (w.targetPrice ?? 0),
    );
    final totalSaved = _pending.fold<double>(0, (s, w) => s + w.savedAmount);

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
            Text('🎁', style: TextStyle(fontSize: 20)),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, isDark, surfBg),
        backgroundColor: AppColors.lend,
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
      body: CustomScrollView(
        slivers: [
          // Summary banner
          SliverToBoxAdapter(
            child: _SummaryBanner(
              total: _pending.length,
              targetTotal: totalTarget,
              savedTotal: totalSaved,
              achieved: _achieved.length,
              isDark: isDark,
            ),
          ),

          // Category filter
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                children: [
                  _CatChip(
                    label: 'All',
                    emoji: '🌟',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  ...WishCategory.values.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _CatChip(
                        label: c.label,
                        emoji: c.emoji,
                        selected: _filter == c,
                        onTap: () =>
                            setState(() => _filter = _filter == c ? null : c),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Active wishes
          if (_pending.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SwipeTile(
                      onDelete: () =>
                          setState(() => _wishes.remove(_pending[i])),
                      child: _WishCard(
                        wish: _pending[i],
                        isDark: isDark,
                        onTap: () => _showDetailSheet(
                          context,
                          _pending[i],
                          isDark,
                          surfBg,
                        ),
                        onMarkDone: () =>
                            setState(() => _pending[i].purchased = true),
                      ),
                    ),
                  ),
                  childCount: _pending.length,
                ),
              ),
            ),
          ],

          // Achieved section
          if (_achieved.isNotEmpty) ...[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '🏆 Achieved',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: AppColors.income,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AchievedChip(wish: _achieved[i], isDark: isDark),
                  ),
                  childCount: _achieved.length,
                ),
              ),
            ),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, bool isDark, Color surfBg) {
    showPlanSheet(
      context,
      child: _AddWishSheet(
        isDark: isDark,
        surfBg: surfBg,
        walletId: widget.walletId,
        onSave: (w) {
          setState(() => _wishes.add(w));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context,
    WishModel w,
    bool isDark,
    Color surfBg,
  ) {
    showPlanSheet(
      context,
      child: _WishDetailSheet(
        wish: w,
        isDark: isDark,
        surfBg: surfBg,
        onAddSavings: (amount) {
          setState(() => w.savedAmount += amount);
          Navigator.pop(context);
        },
        onMarkDone: () {
          setState(() => w.purchased = true);
          Navigator.pop(context);
        },
        onDelete: () {
          setState(() => _wishes.remove(w));
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  final int total, achieved;
  final double targetTotal, savedTotal;
  final bool isDark;
  const _SummaryBanner({
    required this.total,
    required this.achieved,
    required this.targetTotal,
    required this.savedTotal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final progress = targetTotal > 0
        ? (savedTotal / targetTotal).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.lend, AppColors.lend.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatChip(
                label: '$total Wishes',
                icon: '🎁',
                color: Colors.white70,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: '$achieved Done',
                icon: '🏆',
                color: Colors.white70,
              ),
            ],
          ),
          if (targetTotal > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${_fmt(savedTotal)} saved',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                  ),
                ),
                Text(
                  'of ₹${_fmt(targetTotal)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white24,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _fmt(double v) =>
    v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);

class _StatChip extends StatelessWidget {
  final String label, icon;
  final Color color;
  const _StatChip({
    required this.label,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(icon, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
          color: color,
        ),
      ),
    ],
  );
}

class _CatChip extends StatelessWidget {
  final String label, emoji;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? AppColors.lend.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? AppColors.lend
              : Theme.of(context).brightness == Brightness.dark
              ? AppColors.surfDark
              : const Color(0xFFE0E0EC),
        ),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
          color: selected
              ? AppColors.lend
              : Theme.of(context).brightness == Brightness.dark
              ? AppColors.subDark
              : AppColors.subLight,
        ),
      ),
    ),
  );
}

class _WishCard extends StatelessWidget {
  final WishModel wish;
  final bool isDark;
  final VoidCallback onTap, onMarkDone;
  const _WishCard({
    required this.wish,
    required this.isDark,
    required this.onTap,
    required this.onMarkDone,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.lend.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(wish.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
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
                        ),
                      ),
                      Text(
                        wish.category.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (wish.targetPrice != null)
                      Text(
                        '₹${_fmt(wish.targetPrice!)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'DM Mono',
                          color: AppColors.lend,
                        ),
                      ),
                    PriorityBadge(priority: wish.priority),
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
                        value: wish.progress,
                        minHeight: 6,
                        backgroundColor: AppColors.lend.withOpacity(0.12),
                        color: wish.progress >= 1
                            ? AppColors.income
                            : AppColors.lend,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(wish.progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: wish.progress >= 1
                          ? AppColors.income
                          : AppColors.lend,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '₹${_fmt(wish.savedAmount)} saved of ₹${_fmt(wish.targetPrice!)}',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Nunito',
                  color: sub,
                ),
              ),
            ],
            if (wish.targetDate != null) ...[
              const SizedBox(height: 6),
              Text(
                '🎯 By ${fmtDateShort(wish.targetDate!)} · ${daysUntil(wish.targetDate!)}',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Nunito',
                  color: daysUntilColor(wish.targetDate!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AchievedChip extends StatelessWidget {
  final WishModel wish;
  final bool isDark;
  const _AchievedChip({required this.wish, required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.income.withOpacity(isDark ? 0.1 : 0.07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.income.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Text(wish.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            wish.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
              color: AppColors.income,
            ),
          ),
        ),
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.income,
          size: 18,
        ),
      ],
    ),
  );
}

class _WishDetailSheet extends StatefulWidget {
  final WishModel wish;
  final bool isDark;
  final Color surfBg;
  final void Function(double) onAddSavings;
  final VoidCallback onMarkDone, onDelete;
  const _WishDetailSheet({
    required this.wish,
    required this.isDark,
    required this.surfBg,
    required this.onAddSavings,
    required this.onMarkDone,
    required this.onDelete,
  });
  @override
  State<_WishDetailSheet> createState() => _WishDetailSheetState();
}

class _WishDetailSheetState extends State<_WishDetailSheet> {
  final _savingsCtrl = TextEditingController();
  @override
  void dispose() {
    _savingsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;
    final w = widget.wish;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(w.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    Text(
                      '${w.category.emoji} ${w.category.label}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                  ],
                ),
              ),
              PriorityBadge(priority: w.priority),
            ],
          ),
          if (w.targetPrice != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${_fmt(w.savedAmount)} / ₹${_fmt(w.targetPrice!)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'DM Mono',
                    color: AppColors.lend,
                  ),
                ),
                Text(
                  '${(w.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: AppColors.lend,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: w.progress,
                minHeight: 10,
                backgroundColor: AppColors.lend.withOpacity(0.15),
                color: AppColors.lend,
              ),
            ),
          ],
          if (w.targetDate != null) ...[
            const SizedBox(height: 8),
            InfoRow(
              icon: Icons.flag_rounded,
              label:
                  'Target: ${fmtDate(w.targetDate!)} · ${daysUntil(w.targetDate!)}',
              iconColor: daysUntilColor(w.targetDate!),
            ),
          ],
          if (w.link != null) InfoRow(icon: Icons.link_rounded, label: w.link!),
          if (w.note != null)
            InfoRow(icon: Icons.notes_rounded, label: w.note!),

          const SizedBox(height: 16),
          // Add savings
          const SheetLabel(text: 'ADD SAVINGS'),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.surfBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: TextField(
                    controller: _savingsCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 14,
                      color: tc,
                      fontFamily: 'Nunito',
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Amount to add (₹)',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: sub,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final amt = double.tryParse(_savingsCtrl.text.trim()) ?? 0;
                  if (amt > 0) widget.onAddSavings(amt);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lend,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '+ Add',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onMarkDone,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.income.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.income.withOpacity(0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '🏆 Mark Purchased',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: AppColors.income,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.expense.withOpacity(0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.expense,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddWishSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final void Function(WishModel) onSave;
  const _AddWishSheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    required this.onSave,
  });
  @override
  State<_AddWishSheet> createState() => _AddWishSheetState();
}

class _AddWishSheetState extends State<_AddWishSheet> {
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _savedCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  WishCategory _cat = WishCategory.other;
  Priority _prio = Priority.medium;
  DateTime? _date;
  String _emoji = '🎁';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _savedCtrl.dispose();
    _linkCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'New Wish',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 16),
          PlanInputField(
            controller: _titleCtrl,
            hint: 'What do you wish for? *',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PlanInputField(
                  controller: _priceCtrl,
                  hint: 'Target price (₹)',
                  inputType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PlanInputField(
                  controller: _savedCtrl,
                  hint: 'Already saved (₹)',
                  inputType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PlanInputField(
            controller: _linkCtrl,
            hint: 'Product link (optional)',
          ),
          const SizedBox(height: 16),

          const SheetLabel(text: 'CATEGORY'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: WishCategory.values
                .map(
                  (c) => GestureDetector(
                    onTap: () => setState(() {
                      _cat = c;
                      _emoji = c.emoji;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _cat == c
                            ? AppColors.lend.withOpacity(0.15)
                            : widget.surfBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _cat == c
                              ? AppColors.lend
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '${c.emoji} ${c.label}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: _cat == c ? AppColors.lend : sub,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),

          const SheetLabel(text: 'PRIORITY'),
          Row(
            children: Priority.values
                .map(
                  (p) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: p.index > 0 ? 6 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _prio = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _prio == p
                                ? p.color
                                : p.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _prio == p ? p.color : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            p.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: _prio == p ? Colors.white : p.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),

          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _date = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: widget.surfBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag_rounded,
                    size: 16,
                    color: AppColors.lend,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _date != null
                        ? 'Target: ${fmtDate(_date!)}'
                        : 'Set target date (optional)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: AppColors.lend,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          SaveButton(
            label: 'Add to Wish List',
            color: AppColors.lend,
            onTap: () {
              if (_titleCtrl.text.trim().isEmpty) return;
              widget.onSave(
                WishModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: _titleCtrl.text.trim(),
                  emoji: _emoji,
                  category: _cat,
                  priority: _prio,
                  walletId: widget.walletId,
                  targetPrice: double.tryParse(_priceCtrl.text.trim()),
                  savedAmount: double.tryParse(_savedCtrl.text.trim()) ?? 0,
                  link: _linkCtrl.text.trim().isEmpty
                      ? null
                      : _linkCtrl.text.trim(),
                  targetDate: _date,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
