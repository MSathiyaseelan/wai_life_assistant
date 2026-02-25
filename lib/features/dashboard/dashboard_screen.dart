import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _walletId = 'personal'; // shared across tabs
  String _userName = 'Arjun';
  bool _balanceHidden = false;
  String? _outfitNote; // today's selfie / outfit note

  // derived data
  WalletModel get _wallet => _walletId == 'personal'
      ? personalWallet
      : familyWallets.firstWhere(
          (w) => w.id == _walletId,
          orElse: () => personalWallet,
        );

  List<TxModel> get _todayTx => mockTransactions
      .where((t) => t.walletId == _walletId && _isToday(t.date))
      .toList();

  List<MealEntry> get _todayMeals => mockMeals
      .where((m) => m.walletId == _walletId && _isToday(m.date))
      .toList();

  List<_PlanNudge> get _nudges {
    final now = DateTime.now();
    final week = now.add(const Duration(days: 7));
    final list = <_PlanNudge>[];

    // Overdue bills (show regardless of wallet)
    for (final b in mockBills) {
      final daysLeft = b.dueDate.difference(now).inDays;
      if (daysLeft <= 7) {
        list.add(
          _PlanNudge(
            emoji: b.category.emoji,
            title: b.name,
            subtitle: daysLeft < 0
                ? 'Overdue by ${-daysLeft}d  •  ₹${_fmtAmt(b.amount)}'
                : daysLeft == 0
                ? 'Due TODAY  •  ₹${_fmtAmt(b.amount)}'
                : 'Due in ${daysLeft}d  •  ₹${_fmtAmt(b.amount)}',
            urgency: daysLeft <= 0
                ? 3
                : daysLeft <= 3
                ? 2
                : 1,
            color: daysLeft < 0
                ? AppColors.expense
                : daysLeft <= 3
                ? AppColors.lend
                : AppColors.split,
            tag: 'Bill',
          ),
        );
      }
    }

    // Reminders due within 7 days
    for (final r in mockReminders) {
      if (r.dueDate.isBefore(week) && !r.done) {
        final daysLeft = r.dueDate.difference(now).inDays;
        list.add(
          _PlanNudge(
            emoji: r.emoji,
            title: r.title,
            subtitle: daysLeft <= 0 ? 'Due today' : 'In ${daysLeft}d',
            urgency: daysLeft <= 0
                ? 3
                : daysLeft <= 2
                ? 2
                : 1,
            color: r.priority.color,
            tag: 'Alert',
          ),
        );
      }
    }

    // Special days in next 7 days
    for (final sd in mockSpecialDays) {
      final thisYear = DateTime(now.year, sd.date.month, sd.date.day);
      final daysLeft = thisYear.difference(now).inDays;
      if (daysLeft >= 0 && daysLeft <= 7) {
        list.add(
          _PlanNudge(
            emoji: sd.emoji,
            title: sd.title,
            subtitle: daysLeft == 0 ? '🎉 Today!' : 'In ${daysLeft}d',
            urgency: daysLeft == 0
                ? 3
                : daysLeft <= 2
                ? 2
                : 1,
            color: sd.type.color,
            tag: 'Special Day',
          ),
        );
      }
    }

    // Parties within 7 days
    for (final p in mockParties) {
      if (p.eventDate != null && p.eventDate!.isBefore(week)) {
        final daysLeft = p.eventDate!.difference(now).inDays;
        if (daysLeft >= 0) {
          list.add(
            _PlanNudge(
              emoji: p.emoji,
              title: p.title,
              subtitle: daysLeft == 0 ? 'Today!' : 'In ${daysLeft}d',
              urgency: daysLeft == 0 ? 3 : 1,
              color: AppColors.primary,
              tag: 'Party',
            ),
          );
        }
      }
    }

    // Pending tasks (urgent / high priority)
    for (final t in mockTasks.where(
      (t) => t.status != TaskStatus.done && t.priority.index >= 2,
    )) {
      if (t.dueDate != null && t.dueDate!.isBefore(week)) {
        final daysLeft = t.dueDate!.difference(now).inDays;
        list.add(
          _PlanNudge(
            emoji: t.emoji,
            title: t.title,
            subtitle: daysLeft <= 0 ? 'Overdue' : 'Due in ${daysLeft}d',
            urgency: daysLeft <= 0 ? 3 : 2,
            color: t.priority.color,
            tag: 'Task',
          ),
        );
      }
    }

    list.sort((a, b) => b.urgency.compareTo(a.urgency));
    return list;
  }

  // Upcoming functions within 30 days
  List<FunctionModel> get _upcomingFunctions {
    final now = DateTime.now();
    final soon = now.add(const Duration(days: 30));
    return mockFunctions
        .where(
          (f) =>
              f.functionDate != null &&
              f.functionDate!.isAfter(now) &&
              f.functionDate!.isBefore(soon),
        )
        .toList();
  }

  List<UpcomingFunction> get _upcomingAttending {
    final now = DateTime.now();
    final soon = now.add(const Duration(days: 30));
    return mockUpcoming
        .where(
          (u) =>
              u.date != null && u.date!.isAfter(now) && u.date!.isBefore(soon),
        )
        .toList();
  }

  // Active split transactions
  List<TxModel> get _activeSplits => mockTransactions
      .where((t) => t.type == TxType.split && t.walletId == _walletId)
      .toList();

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _fmtAmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── Sliver App Bar ──────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: cardBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 64,
            title: Row(
              children: [
                // Greeting
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: sub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$_userName 👋',
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w900,
                          color: tc,
                        ),
                      ),
                    ],
                  ),
                ),
                // Wallet switcher pill
                GestureDetector(
                  onTap: () => _showWalletSwitcher(context, isDark, surfBg),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _wallet.emoji,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _walletId == 'personal' ? 'Personal' : _wallet.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.expand_more_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Settings
                GestureDetector(
                  onTap: () => _showSettings(context, isDark),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: surfBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: isDark ? AppColors.subDark : AppColors.subLight,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body Content ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ①  MONEY PULSE ─────────────────────────────────────────
                  _SectionHeader(
                    emoji: '💳',
                    title: 'Money Pulse',
                    sub: sub,
                    action: 'Wallet →',
                    onAction: () {},
                  ),
                  const SizedBox(height: 10),
                  _MoneyPulseCard(
                    wallet: _wallet,
                    isDark: isDark,
                    todayTx: _todayTx,
                    hidden: _balanceHidden,
                    onToggleHide: () =>
                        setState(() => _balanceHidden = !_balanceHidden),
                    onAddTx: () => _showQuickAdd(context, isDark, surfBg, null),
                  ),
                  const SizedBox(height: 10),

                  // ①b  SPLIT ACTIVITY (if any active splits) ─────────────
                  if (_activeSplits.isNotEmpty) ...[
                    _SectionHeader(
                      emoji: '⚖️',
                      title: 'Split Activity',
                      sub: sub,
                      action: 'View all →',
                      onAction: () {},
                    ),
                    const SizedBox(height: 8),
                    ..._activeSplits.map(
                      (s) => _SplitNudgeCard(
                        tx: s,
                        isDark: isDark,
                        onAddMyShare: () =>
                            _showQuickAdd(context, isDark, surfBg, s),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // ②  TODAY'S PLATE ────────────────────────────────────────
                  _SectionHeader(
                    emoji: '🍽️',
                    title: "Today's Plate",
                    sub: sub,
                    action: 'Pantry →',
                    onAction: () {},
                  ),
                  const SizedBox(height: 10),
                  _TodaysPlateCard(
                    meals: _todayMeals,
                    isDark: isDark,
                    cardBg: cardBg,
                  ),
                  const SizedBox(height: 16),

                  // ③  PLAN-IT NUDGES ───────────────────────────────────────
                  if (_nudges.isNotEmpty) ...[
                    _SectionHeader(
                      emoji: '📋',
                      title: 'Needs Attention',
                      sub: sub,
                      action: 'PlanIt →',
                      onAction: () {},
                    ),
                    const SizedBox(height: 8),
                    _NudgesCard(
                      nudges: _nudges,
                      isDark: isDark,
                      cardBg: cardBg,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ④  OUTFIT TODAY (LifeStyle) ─────────────────────────────
                  _SectionHeader(
                    emoji: '👗',
                    title: "Today's Look",
                    sub: sub,
                    action: 'Wardrobe →',
                    onAction: () {},
                  ),
                  const SizedBox(height: 8),
                  _OutfitTodayCard(
                    outfitNote: _outfitNote,
                    isDark: isDark,
                    cardBg: cardBg,
                    onCapture: () => _showOutfitCapture(context, isDark),
                  ),
                  const SizedBox(height: 16),

                  // ⑤  UPCOMING FUNCTIONS ───────────────────────────────────
                  if (_upcomingFunctions.isNotEmpty ||
                      _upcomingAttending.isNotEmpty) ...[
                    _SectionHeader(
                      emoji: '🎊',
                      title: 'Upcoming Functions',
                      sub: sub,
                      action: 'Functions →',
                      onAction: () {},
                    ),
                    const SizedBox(height: 8),
                    _UpcomingFunctionsCard(
                      myFunctions: _upcomingFunctions,
                      attending: _upcomingAttending,
                      isDark: isDark,
                      cardBg: cardBg,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ⑥  QUICK ACTIONS GRID ───────────────────────────────────
                  _SectionHeader(
                    emoji: '⚡',
                    title: 'Quick Actions',
                    sub: sub,
                    action: null,
                    onAction: null,
                  ),
                  const SizedBox(height: 10),
                  _QuickActionsGrid(
                    isDark: isDark,
                    surfBg: surfBg,
                    onAddExpense: () =>
                        _showQuickAdd(context, isDark, surfBg, null),
                    onOutfitSelfie: () => _showOutfitCapture(context, isDark),
                    onShopping: () {},
                    onAddMeal: () {},
                    onBillPay: () {},
                    onScanDoc: () {},
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Greeting ────────────────────────────────────────────────────────────────
  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    if (h < 21) return 'Good evening,';
    return 'Good night,';
  }

  // ── Wallet Switcher Sheet ───────────────────────────────────────────────────
  void _showWalletSwitcher(BuildContext ctx, bool isDark, Color surfBg) {
    final all = [personalWallet, ...familyWallets];
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Switch View',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 14),
            ...all.map(
              (w) => GestureDetector(
                onTap: () {
                  setState(() => _walletId = w.id);
                  Navigator.pop(ctx);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: _walletId == w.id
                        ? LinearGradient(colors: w.gradient)
                        : null,
                    color: _walletId == w.id ? null : surfBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(w.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              w.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: _walletId == w.id ? Colors.white : null,
                              ),
                            ),
                            Text(
                              w.isPersonal
                                  ? 'Personal wallet'
                                  : 'Family wallet',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color: _walletId == w.id
                                    ? Colors.white70
                                    : (isDark
                                          ? AppColors.subDark
                                          : AppColors.subLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_walletId == w.id)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Add Transaction ───────────────────────────────────────────────────
  void _showQuickAdd(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    TxModel? splitRef,
  ) {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: splitRef?.note ?? '');
    var txType = splitRef != null ? TxType.split : TxType.expense;
    var payMode = PayMode.online;
    final cats = ['Food', 'Transport', 'Shopping', 'Bills', 'Health', 'Other'];
    var cat = splitRef?.category ?? 'Food';

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
          child: StatefulBuilder(
            builder: (ctx2, ss) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (splitRef != null) ...[
                      Text(
                        splitRef.type.emoji,
                        //splitRef.giftType ?? '⚖️',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add to Split',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Nunito',
                            ),
                          ),
                          Text(
                            splitRef.category,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              color: isDark
                                  ? AppColors.subDark
                                  : AppColors.subLight,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      const Text(
                        'Quick Add',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Type selector (only if no split ref)
                if (splitRef == null) ...[
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children:
                          [
                                TxType.expense,
                                TxType.income,
                                TxType.lent,
                                TxType.borrowed,
                                TxType.split,
                              ]
                              .map(
                                (t) => GestureDetector(
                                  onTap: () => ss(() => txType = t),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: txType == t
                                          ? t.color.withOpacity(0.15)
                                          : surfBg,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: txType == t
                                            ? t.color
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          t.emoji,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          t.label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'Nunito',
                                            color: txType == t
                                                ? t.color
                                                : (isDark
                                                      ? AppColors.subDark
                                                      : AppColors.subLight),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Amount input — large
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '₹',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'DM Mono',
                          color: txType.color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: amtCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'DM Mono',
                            color: txType.color,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '0',
                            hintStyle: TextStyle(
                              color: txType.color.withOpacity(0.3),
                              fontFamily: 'DM Mono',
                            ),
                          ),
                        ),
                      ),
                      // Pay mode toggle (only for expense/income)
                      if (txType == TxType.expense || txType == TxType.income)
                        GestureDetector(
                          onTap: () => ss(
                            () => payMode = payMode == PayMode.cash
                                ? PayMode.online
                                : PayMode.cash,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: payMode == PayMode.cash
                                  ? AppColors.cash.withOpacity(0.12)
                                  : AppColors.online.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              payMode == PayMode.cash ? '💵 Cash' : '📲 Online',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: payMode == PayMode.cash
                                    ? AppColors.cash
                                    : AppColors.online,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Note field
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: noteCtrl,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Nunito',
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'What\'s this for?',
                      prefixIcon: Icon(Icons.notes_rounded, size: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Category chips (only for expense/income)
                if (splitRef == null &&
                    (txType == TxType.expense || txType == TxType.income))
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: cats
                          .map(
                            (c) => GestureDetector(
                              onTap: () => ss(() => cat = c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
                                margin: const EdgeInsets.only(right: 7),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: cat == c
                                      ? AppColors.primary.withOpacity(0.12)
                                      : surfBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: cat == c
                                        ? AppColors.primary
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: cat == c
                                        ? AppColors.primary
                                        : (isDark
                                              ? AppColors.subDark
                                              : AppColors.subLight),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                const SizedBox(height: 16),
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: txType.color,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Save ${txType.label}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Outfit Capture ──────────────────────────────────────────────────────────
  void _showOutfitCapture(BuildContext ctx, bool isDark) {
    final noteCtrl = TextEditingController(text: _outfitNote ?? '');
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Today's Look",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 16),

              // Photo placeholder
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: surfBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF5CA8).withOpacity(0.3),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5CA8).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 30,
                          color: Color(0xFFFF5CA8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tap to take selfie',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          color: Color(0xFFFF5CA8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'or choose from gallery',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: AppColors.subLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: surfBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: noteCtrl,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Nunito',
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        "What are you wearing today? (e.g. Blue kurta + jeans)",
                    prefixIcon: Icon(Icons.edit_note_rounded, size: 16),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (noteCtrl.text.isNotEmpty) {
                      setState(() => _outfitNote = noteCtrl.text.trim());
                    }
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5CA8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Save Today\'s Look',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Settings ────────────────────────────────────────────────────────────────
  void _showSettings(BuildContext ctx, bool isDark) {
    final nameCtrl = TextEditingController(text: _userName);
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final settings = [
      _SettingItem(
        Icons.notifications_rounded,
        'Notifications',
        'Manage alerts & reminders',
      ),
      _SettingItem(
        Icons.palette_rounded,
        'Appearance',
        'Theme, colors & font size',
      ),
      _SettingItem(
        Icons.currency_rupee_rounded,
        'Currency',
        'Currency & number format',
      ),
      _SettingItem(Icons.language_rounded, 'Language', 'App language'),
      _SettingItem(
        Icons.lock_rounded,
        'Privacy & Security',
        'PIN, biometrics, data',
      ),
      _SettingItem(
        Icons.cloud_sync_rounded,
        'Backup & Sync',
        'Cloud backup settings',
      ),
      _SettingItem(
        Icons.family_restroom_rounded,
        'Family & Wallets',
        'Manage family groups',
      ),
      _SettingItem(
        Icons.info_outline_rounded,
        'About',
        'Version, feedback, support',
      ),
    ];

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, sc) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Profile
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF4B44CC)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _userName.isNotEmpty ? _userName[0] : 'A',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Nunito',
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Personal & Family Account',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.edit_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              // Name field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: StatefulBuilder(
                    builder: (c2, ss) => TextField(
                      controller: nameCtrl,
                      onChanged: (v) => ss(() {}),
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Nunito',
                        color: isDark
                            ? AppColors.textDark
                            : AppColors.textLight,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Your name',
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                        ),
                        suffixIcon: nameCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.income,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _userName = nameCtrl.text.trim(),
                                  );
                                  Navigator.pop(ctx);
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
                  itemCount: settings.length,
                  itemBuilder: (_, i) {
                    final s = settings[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: surfBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            s.icon,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          s.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        subtitle: Text(
                          s.subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Nunito',
                            color: isDark
                                ? AppColors.subDark
                                : AppColors.subLight,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                        ),
                        onTap: () {},
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ① MONEY PULSE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _MoneyPulseCard extends StatelessWidget {
  final WalletModel wallet;
  final bool isDark, hidden;
  final List<TxModel> todayTx;
  final VoidCallback onToggleHide, onAddTx;

  const _MoneyPulseCard({
    required this.wallet,
    required this.isDark,
    required this.todayTx,
    required this.hidden,
    required this.onToggleHide,
    required this.onAddTx,
  });

  String _fmt(double v) {
    if (hidden) return '••••';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final todayIn = todayTx
        .where((t) => t.type.isPositive)
        .fold(0.0, (s, t) => s + t.amount);
    final todayOut = todayTx
        .where((t) => t.type == TxType.expense || t.type == TxType.lent)
        .fold(0.0, (s, t) => s + t.amount);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: wallet.gradient,
        ),
      ),
      child: Column(
        children: [
          // Top — balance
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${wallet.emoji}  ${wallet.name}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onToggleHide,
                      child: Icon(
                        hidden
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white60,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onAddTx,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Add',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Total Balance',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontFamily: 'Nunito',
                  ),
                ),
                Text(
                  _fmt(wallet.balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'DM Mono',
                  ),
                ),
              ],
            ),
          ),

          // Bottom — today's stats
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _PulseStat(
                    icon: Icons.arrow_downward_rounded,
                    label: 'In today',
                    value: _fmt(todayIn),
                    color: Colors.greenAccent,
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.2),
                ),
                Expanded(
                  child: _PulseStat(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Out today',
                    value: _fmt(todayOut),
                    color: Colors.redAccent[100]!,
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.2),
                ),
                Expanded(
                  child: _PulseStat(
                    icon: Icons.receipt_long_rounded,
                    label: 'Entries',
                    value: '${todayTx.length}',
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Today's transactions list (max 3, compact)
          if (todayTx.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: [
                  ...todayTx.take(3).map((t) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Text(
                            t.type.emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.category,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                  ),
                                ),
                                if (t.note != null)
                                  Text(
                                    t.note!,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 10,
                                      fontFamily: 'Nunito',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${t.type.isPositive ? '+' : '-'}${hidden ? '••' : '₹${_fmtCompact(t.amount)}'}',
                            style: TextStyle(
                              color: t.type.isPositive
                                  ? Colors.greenAccent
                                  : Colors.redAccent[100],
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'DM Mono',
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  if (todayTx.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${todayTx.length - 3} more today',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontFamily: 'Nunito',
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

  String _fmtCompact(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _PulseStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _PulseStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          fontFamily: 'DM Mono',
          color: Colors.white,
        ),
      ),
      Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white60,
          fontFamily: 'Nunito',
        ),
      ),
    ],
  );
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
        border: Border.all(color: AppColors.split.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.split.withOpacity(0.12),
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
                '₹${tx.amount.toStringAsFixed(0)}',
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
// ② TODAY'S PLATE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TodaysPlateCard extends StatelessWidget {
  final List<MealEntry> meals;
  final bool isDark;
  final Color cardBg;
  const _TodaysPlateCard({
    required this.meals,
    required this.isDark,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;

    final mealsMap = <MealTime, List<MealEntry>>{};
    for (final m in meals) {
      mealsMap.putIfAbsent(m.mealTime, () => []).add(m);
    }

    if (meals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Text('🍽️', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Nothing planned yet",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                Text(
                  'Open Pantry to plan today\'s meals',
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
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.18)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                const Text('🗓️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  _todayLabel(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                const Spacer(),
                Text(
                  '${meals.length} meals',
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
                          color: mt.color.withOpacity(
                            entries.isEmpty ? 0.06 : 0.15,
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
                        (e) => Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: mt.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
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
                        ),
                      ),
                      if (entries.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: sub.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sub.withOpacity(0.15),
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
        border: Border.all(color: AppColors.lend.withOpacity(0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ...nudges.take(5).map((n) {
            final isLast = nudges.indexOf(n) == nudges.take(5).length - 1;
            return Column(
              children: [
                Padding(
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: n.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: n.color.withOpacity(0.3)),
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
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 42,
                    endIndent: 14,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(
                      0.05,
                    ),
                  ),
              ],
            );
          }).toList(),
          if (nudges.length > 5)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: AppColors.lend.withOpacity(0.06),
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
// ④ OUTFIT TODAY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _OutfitTodayCard extends StatelessWidget {
  final String? outfitNote;
  final bool isDark;
  final Color cardBg;
  final VoidCallback onCapture;
  const _OutfitTodayCard({
    this.outfitNote,
    required this.isDark,
    required this.cardBg,
    required this.onCapture,
  });

  static const _pink = Color(0xFFFF5CA8);

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    if (outfitNote == null) {
      return GestureDetector(
        onTap: onCapture,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _pink.withOpacity(0.25),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _pink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text('📸', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Capture today's look",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    Text(
                      "Take a selfie or note what you're wearing",
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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _pink,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Has outfit note
    return GestureDetector(
      onTap: onCapture,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _pink.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            // Photo placeholder
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _pink.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _pink.withOpacity(0.2)),
              ),
              alignment: Alignment.center,
              child: const Text('👗', style: TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Today's Look 🌟",
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      color: _pink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    outfitNote!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_rounded, size: 16, color: _pink),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ⑤ UPCOMING FUNCTIONS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _UpcomingFunctionsCard extends StatelessWidget {
  final List<FunctionModel> myFunctions;
  final List<UpcomingFunction> attending;
  final bool isDark;
  final Color cardBg;
  const _UpcomingFunctionsCard({
    required this.myFunctions,
    required this.attending,
    required this.isDark,
    required this.cardBg,
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
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: all.map((f) {
          final daysLeft = f.date != null
              ? f.date!.difference(DateTime.now()).inDays
              : null;
          final isLast = all.indexOf(f) == all.length - 1;

          return Column(
            children: [
              Padding(
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
                            ? AppColors.primary.withOpacity(0.12)
                            : AppColors.lend.withOpacity(0.12),
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
                                    ).withOpacity(0.15),
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
                              ? AppColors.expense.withOpacity(0.12)
                              : daysLeft <= 7
                              ? AppColors.lend.withOpacity(0.12)
                              : AppColors.split.withOpacity(0.1),
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
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 14,
                  color: (isDark ? Colors.white : Colors.black).withOpacity(
                    0.05,
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
// ⑥ QUICK ACTIONS GRID
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final bool isDark;
  final Color surfBg;
  final VoidCallback onAddExpense,
      onOutfitSelfie,
      onShopping,
      onAddMeal,
      onBillPay,
      onScanDoc;
  const _QuickActionsGrid({
    required this.isDark,
    required this.surfBg,
    required this.onAddExpense,
    required this.onOutfitSelfie,
    required this.onShopping,
    required this.onAddMeal,
    required this.onBillPay,
    required this.onScanDoc,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction('💸', 'Add Expense', AppColors.expense, onAddExpense),
      _QuickAction(
        '📸',
        'Outfit Selfie',
        const Color(0xFFFF5CA8),
        onOutfitSelfie,
      ),
      _QuickAction('🛒', 'Shopping List', AppColors.income, onShopping),
      _QuickAction('🍽️', 'Add Meal', const Color(0xFF4CAF50), onAddMeal),
      _QuickAction('💡', 'Pay Bill', AppColors.lend, onBillPay),
      _QuickAction('📄', 'Scan Doc', AppColors.split, onScanDoc),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: actions
          .map(
            (a) => GestureDetector(
              onTap: a.onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: a.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: a.color.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(a.emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 6),
                    Text(
                      a.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: a.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
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
  final String emoji, title, subtitle, tag;
  final int urgency;
  final Color color;
  const _PlanNudge({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.urgency,
    required this.color,
    required this.tag,
  });
}

class _QuickAction {
  final String emoji, label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.emoji, this.label, this.color, this.onTap);
}

class _SettingItem {
  final IconData icon;
  final String title, subtitle;
  const _SettingItem(this.icon, this.title, this.subtitle);
}

// import 'package:flutter/material.dart';
// import 'widgets/greeting_header.dart';
// import 'widgets/search_bar.dart';
// import 'widgets/feature_card.dart';
// import 'widgets/quick_stats.dart';

// class DashboardScreen extends StatelessWidget {
//   const DashboardScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F6FA),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const GreetingHeader(),
//               const SizedBox(height: 20),
//               const HomeSearchBar(),
//               const SizedBox(height: 20),
//               const QuickStats(),
//               const SizedBox(height: 24),
//               const Text(
//                 "Services",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 16),
//               Expanded(
//                 child: GridView.count(
//                   crossAxisCount: 2,
//                   mainAxisSpacing: 16,
//                   crossAxisSpacing: 16,
//                   children: [
//                     FeatureCard(
//                       title: "Health",
//                       icon: Icons.favorite,
//                       color: Colors.red,
//                       onTap: () {},
//                     ),
//                     FeatureCard(
//                       title: "Finance",
//                       icon: Icons.account_balance,
//                       color: Colors.green,
//                       onTap: () {},
//                     ),
//                     FeatureCard(
//                       title: "Tasks",
//                       icon: Icons.check_circle,
//                       color: Colors.blue,
//                       onTap: () {},
//                     ),
//                     FeatureCard(
//                       title: "Emergency",
//                       icon: Icons.warning,
//                       color: Colors.orange,
//                       onTap: () {},
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
