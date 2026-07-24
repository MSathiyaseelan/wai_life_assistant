part of 'dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ① SPENDING PULSE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SpendingPulseCard extends StatelessWidget {
  final String walletLabel;
  final List<TxModel> txToday;
  final bool hidden;
  final VoidCallback onToggleHide;
  final bool isDark;
  final Color cardBg, tc, sub;

  const _SpendingPulseCard({
    required this.walletLabel,
    required this.txToday,
    required this.hidden,
    required this.onToggleHide,
    required this.isDark,
    required this.cardBg,
    required this.tc,
    required this.sub,
  });

  String _fmt(double v) {
    if (hidden) return '••••';
    final cs = AppPrefs.cs;
    if (v >= 100000) return '$cs${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) {
      final s = (v / 1000).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      return '$cs${s}k';
    }
    return '$cs${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final spent = txToday.fold(0.0, (s, t) =>
        (t.type == TxType.expense || t.type == TxType.lend || t.type == TxType.split)
            ? s + t.amount
            : s);
    final received = txToday.fold(0.0, (s, t) => t.type.isPositive ? s + t.amount : s);
    final recent = txToday.take(3).toList();
    final extra = txToday.length - recent.length;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.withValues(alpha: 0.07)),
      ),
      // SingleChildScrollView (not ClipRRect) so the Column gets an unbounded
      // height and never trips the RenderFlex overflow assertion during the
      // one-frame gap while the parent AnimatedContainer is still tweening
      // toward _pulseCardHeight()'s new (taller) target.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stat row ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Spent today',
                          style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                      const SizedBox(height: 3),
                      Text(_fmt(spent),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'DM Mono',
                            color: tc,
                          )),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: tc.withValues(alpha: 0.1),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Received',
                          style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                      const SizedBox(height: 3),
                      Text(_fmt(received),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'DM Mono',
                            color: Color(0xFF2ECC71),
                          )),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: onToggleHide,
                      child: Icon(
                        hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 16,
                        color: sub,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        walletLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: tc.withValues(alpha: 0.08)),

          // ── Transaction rows ───────────────────────────────────────────────
          if (txToday.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'No transactions today',
                style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
              ),
            )
          else ...[
            ...recent.map((tx) => _TxRow(tx: tx, hidden: hidden, tc: tc, sub: sub)),
            if (extra > 0)
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => _TodayTxSheet(
                    label: walletLabel,
                    transactions: txToday,
                    hidden: hidden,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'See all ${txToday.length} →',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(height: 12),
          ],
        ],
        ),
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final TxModel tx;
  final bool hidden;
  final Color tc, sub;

  const _TxRow({
    required this.tx,
    required this.hidden,
    required this.tc,
    required this.sub,
  });

  String _fmtAmt() {
    if (hidden) return '••••';
    final cs = AppPrefs.cs;
    final prefix = tx.type.isPositive ? '+$cs' : '-$cs';
    final v = tx.amount;
    if (v >= 100000) return '$prefix${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) {
      final s = (v / 1000).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      return '$prefix${s}k';
    }
    return '$prefix${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = tx.type.isPositive;
    final amtColor = isPositive ? const Color(0xFF2ECC71) : const Color(0xFFFF6B81);
    final label = tx.title?.isNotEmpty == true ? tx.title! : tx.category;
    final detail = tx.title?.isNotEmpty == true ? tx.category : (tx.note ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Text(tx.type.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtAmt(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: 'DM Mono',
              color: amtColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Today payment section (Cash / Online) ────────────────────────────────────
// ── Today's transactions bottom sheet ────────────────────────────────────────
class _TodayTxSheet extends StatelessWidget {
  final String label;
  final List<TxModel> transactions;
  final bool hidden;

  const _TodayTxSheet({
    required this.label,
    required this.transactions,
    required this.hidden,
  });

  String _fmtAmt(TxModel tx) {
    if (hidden) return '••••';
    final cs = AppPrefs.cs;
    final prefix = tx.type.isPositive ? '+$cs' : '-$cs';
    final v = tx.amount;
    if (v >= 100000) return '$prefix${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) {
      final s = (v / 1000).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      return '$prefix${s}k';
    }
    return '$prefix${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle + header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Text('🗓️', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Transactions",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Nunito',
                              color: tc,
                            ),
                          ),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${transactions.length} item${transactions.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.07),
                  ),
                ],
              ),
            ),
            // Transaction list
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: transactions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final tx = transactions[i];
                  final isPositive = tx.type.isPositive;
                  final amtColor = isPositive
                      ? AppColors.income
                      : AppColors.expense;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: surfBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        // Emoji badge
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: amtColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(tx.type.emoji,
                              style: const TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(width: 10),
                        // Title + category
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.title?.isNotEmpty == true
                                    ? tx.title!
                                    : tx.category,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Nunito',
                                  color: tc,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Text(
                                    tx.category,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                  ),
                                  if (tx.payMode != null) ...[
                                    Text(' · ',
                                        style: TextStyle(
                                            fontSize: 10, color: sub)),
                                    Text(
                                      tx.payMode == PayMode.cash
                                          ? '💵 Cash'
                                          : '📲 Online',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'Nunito',
                                        color: sub,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Amount
                        Text(
                          _fmtAmt(tx),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'DM Mono',
                            color: amtColor,
                          ),
                        ),
                      ],
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
// ① SPLIT NUDGE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SplitNudgeCard extends StatelessWidget {
  final TxModel tx;
  final bool isDark;
  final VoidCallback onAddMyShare;
  const _SplitNudgeCard({
    required this.tx,
    required this.isDark,
    required this.onAddMyShare,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.split.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.split.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text('⚖️', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.category,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                Text(
                  '${tx.persons?.join(', ') ?? ''} · ${tx.status ?? ''}',
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
              Text(
                '${AppPrefs.cs}${tx.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'DM Mono',
                  color: AppColors.split,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onAddMyShare,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.split,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Add share',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: Colors.white,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// ①c PINNED SPLIT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _PinnedSplitCard extends StatelessWidget {
  final SplitGroup group;
  final bool isDark;
  final Color cardBg;
  final VoidCallback onTap;
  final VoidCallback onAddExpense;
  const _PinnedSplitCard({
    required this.group,
    required this.isDark,
    required this.cardBg,
    required this.onTap,
    required this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final pending = group.pendingCount;
    final me = group.participants.firstWhere(
      (p) => p.isMe,
      orElse: () => group.participants.first,
    );
    final myBalance = group.netBalances[me.id] ?? 0.0;
    final balanceColor = myBalance >= 0 ? AppColors.income : AppColors.expense;
    final cs = AppPrefs.cs;
    final balanceLabel = myBalance >= 0
        ? '+$cs${myBalance.abs().toStringAsFixed(0)} owed to you'
        : '$cs${myBalance.abs().toStringAsFixed(0)} you owe';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.split.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            // Group icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.split.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: EmojiOrImage(value: group.emoji, size: 26, borderRadius: 13),
            ),
            const SizedBox(width: 12),
            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (pending > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lend.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$pending pending',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: AppColors.lend,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        balanceLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          color: balanceColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Participant avatars
                  Row(
                    children: group.participants.take(5).map((p) {
                      return Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: AppColors.split.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.split.withValues(alpha: 0.25),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          p.emoji,
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            // Add Expense button
            GestureDetector(
              onTap: onAddExpense,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.split,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: Colors.white,
                      ),
                    ),
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
// ② TODAY'S PLATE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TodaysPlateCard extends StatelessWidget {
  final String label;
  final List<MealEntry> meals;
  final bool isDark;
  final Color cardBg;
  final void Function(MealEntry)? onMealTap;
  const _TodaysPlateCard({
    required this.label,
    required this.meals,
    required this.isDark,
    required this.cardBg,
    this.onMealTap,
  });

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;

    final mealsMap = <MealTime, List<MealEntry>>{};
    for (final m in meals) {
      mealsMap.putIfAbsent(m.mealTime, () => []).add(m);
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                const Text('🗓️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                    Text(
                      _todayLabel(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  meals.isEmpty
                      ? 'Nothing planned'
                      : '${meals.length} meal${meals.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                ),
              ],
            ),
          ),
          // Meal timeline
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: MealTime.values.map((mt) {
                final entries = mealsMap[mt] ?? [];
                return Expanded(
                  child: Column(
                    children: [
                      // Meal time icon + label
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: mt.color.withValues(
                            alpha: entries.isEmpty ? 0.06 : 0.15,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          mt.emoji,
                          style: TextStyle(
                            fontSize: 18,
                            color: entries.isEmpty ? sub : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        mt.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          color: entries.isEmpty ? sub : mt.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...entries.map(
                        (e) => GestureDetector(
                          onTap: onMealTap != null ? () => onMealTap!(e) : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: mt.color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: onMealTap != null
                                  ? Border.all(
                                      color: mt.color.withValues(alpha: 0.2),
                                    )
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '${e.emoji} ${e.name}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontFamily: 'Nunito',
                                    color: tc,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      e.mealStatus.emoji,
                                      style: const TextStyle(fontSize: 8),
                                    ),
                                    if (e.reactions.isNotEmpty) ...[
                                      const SizedBox(width: 3),
                                      Text(
                                        '💬${e.reactions.length}',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontFamily: 'Nunito',
                                          color: sub,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (entries.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: sub.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sub.withValues(alpha: 0.15),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Text(
                            '—',
                            style: TextStyle(
                              fontSize: 10,
                              color: sub,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _todayLabel() {
    final d = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      '',
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
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ③ NUDGES CARD (PlanIt)
// ─────────────────────────────────────────────────────────────────────────────

class _NudgesCard extends StatelessWidget {
  final List<_PlanNudge> nudges;
  final bool isDark;
  final Color cardBg;
  const _NudgesCard({
    required this.nudges,
    required this.isDark,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lend.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ...nudges.take(5).map((n) {
            final isLast = nudges.indexOf(n) == nudges.take(5).length - 1;
            return Column(
              children: [
                GestureDetector(
                  onTap: n.onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      // Urgency dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: n.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(n.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: tc,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              n.subtitle,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color: sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: n.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: n.color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              n.tag,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: n.color,
                              ),
                            ),
                          ),
                          if (n.walletLabel != 'Personal') ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                n.walletLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 42,
                    endIndent: 14,
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.05,
                    ),
                  ),
              ],
            );
          }),
          if (nudges.length > 5)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: AppColors.lend.withValues(alpha: 0.06),
              child: Text(
                '+${nudges.length - 5} more in PlanIt',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Nunito',
                  color: AppColors.lend,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ④ UPCOMING FUNCTIONS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _UpcomingFunctionsCard extends StatelessWidget {
  final List<FunctionModel> myFunctions;
  final List<UpcomingFunction> attending;
  final bool isDark;
  final Color cardBg;
  final VoidCallback? onTap;
  const _UpcomingFunctionsCard({
    required this.myFunctions,
    required this.attending,
    required this.isDark,
    required this.cardBg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    const months = [
      '',
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

    final all = [
      ...myFunctions.map(
        (f) => (
          emoji: f.type.emoji,
          title: f.title,
          who: 'Our function',
          date: f.functionDate,
          isMine: true,
          moiPending: f.moiPending,
        ),
      ),
      ...attending.map(
        (u) => (
          emoji: u.type.emoji,
          title: '${u.personName}\'s ${u.type.label}',
          who: u.functionTitle,
          date: u.date,
          isMine: false,
          moiPending: 0,
        ),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: all.map((f) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final daysLeft = f.date != null
              ? DateTime(f.date!.year, f.date!.month, f.date!.day)
                  .difference(today)
                  .inDays
              : null;
          final isLast = all.indexOf(f) == all.length - 1;

          return Column(
            children: [
              GestureDetector(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Date block
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: f.isMine
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.lend.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: f.date != null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${f.date!.day}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'DM Mono',
                                    color: f.isMine
                                        ? AppColors.primary
                                        : AppColors.lend,
                                  ),
                                ),
                                Text(
                                  months[f.date!.month],
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w700,
                                    color: f.isMine
                                        ? AppColors.primary
                                        : AppColors.lend,
                                  ),
                                ),
                              ],
                            )
                          : Text(f.emoji, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                f.emoji,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  f.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                    color: tc,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                f.isMine ? '🏠 Our event' : '👥 Attending',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Nunito',
                                  color: sub,
                                ),
                              ),
                              if (f.moiPending > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFF9800,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${f.moiPending} moi pending',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontFamily: 'Nunito',
                                      color: Color(0xFFFF9800),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (daysLeft != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: daysLeft == 0
                              ? AppColors.expense.withValues(alpha: 0.12)
                              : daysLeft <= 7
                              ? AppColors.lend.withValues(alpha: 0.12)
                              : AppColors.split.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          daysLeft == 0 ? 'Today!' : 'in ${daysLeft}d',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            color: daysLeft == 0
                                ? AppColors.expense
                                : daysLeft <= 7
                                ? AppColors.lend
                                : AppColors.split,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 14,
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.05,
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS & SMALL MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String emoji, title;
  final Color sub;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader({
    required this.emoji,
    required this.title,
    required this.sub,
    this.action,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textDark
        : AppColors.textLight;
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
            color: tc,
          ),
        ),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Nunito',
                color: sub,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _PlanNudge {
  final String emoji, title, subtitle, tag, walletLabel;
  final int urgency;
  final Color color;
  final VoidCallback? onTap;
  const _PlanNudge({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.urgency,
    required this.color,
    required this.tag,
    required this.walletLabel,
    this.onTap,
  });
}
