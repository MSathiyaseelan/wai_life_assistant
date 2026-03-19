import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/widgets/family_switcher_sheet.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/features/planit/modules/alert_me/alert_me_screen.dart';
import 'package:wai_life_assistant/features/planit/modules/my_tasks/my_tasks_screen.dart';
import 'package:wai_life_assistant/features/planit/modules/special_days/special_days_screen.dart';
import 'package:wai_life_assistant/features/planit/modules/wish_list/wish_list_screen.dart';
import 'package:wai_life_assistant/features/planit/modules/bill_watch/bill_watch_screen.dart';
import 'package:wai_life_assistant/features/planit/modules/travel_board/travel_board_screen.dart';
import 'package:wai_life_assistant/features/planit/modules/plan_party/plan_party_screen.dart';
import 'package:wai_life_assistant/features/planit/modules/my_schedule/my_schedule_screen.dart';
import 'package:wai_life_assistant/features/planit/modules/health_vault/health_vault_screen.dart';

class PlanItScreen extends StatefulWidget {
  final String activeWalletId;
  final void Function(String) onWalletChange;
  const PlanItScreen({
    super.key,
    required this.activeWalletId,
    required this.onWalletChange,
  });
  @override
  State<PlanItScreen> createState() => _PlanItScreenState();
}

class _PlanItScreenState extends State<PlanItScreen> {
  List<WalletModel> get _allWallets => [personalWallet, ...familyWallets];
  WalletModel get _currentWallet => _allWallets.firstWhere(
    (w) => w.id == widget.activeWalletId,
    orElse: () => personalWallet,
  );

  void _switchWallet(String id) => widget.onWalletChange(id);

  // ── Lifted state — persists across navigation ─────────────────────────────
  final List<TaskModel> _tasksList = [];
  final List<SpecialDayModel> _days = List.from(mockSpecialDays);
  final List<WishModel> _wishes = List.from(mockWishes);
  final List<BillModel> _bills = List.from(mockBills);
  final List<TripModel> _trips = List.from(mockTrips);

  // ── Family members for current wallet — converted to PlanMember ───────────
  List<PlanMember> get _members {
    if (_currentWallet.isPersonal) return [];
    final family = mockFamilies.firstWhere(
      (f) => f.id == _currentWallet.id,
      orElse: () => FamilyModel(id: '', name: '', emoji: '', colorIndex: 0),
    );
    return family.members
        .map(
          (m) => PlanMember(
            id: m.id,
            name: m.name,
            emoji: m.emoji,
            phone: m.phone,
          ),
        )
        .toList();
  }

  // ── Derived stats ─────────────────────────────────────────────────────────
  int get _dueReminders => 0; // AlertMeScreen loads from DB independently

  int get _pendingTasks => _tasksList
      .where(
        (t) =>
            t.walletId == widget.activeWalletId && t.status != TaskStatus.done,
      )
      .length;

  int get _overdueBills => _bills
      .where((b) => b.walletId == widget.activeWalletId && b.isOverdue)
      .length;

  int get _upcomingDays => mockSpecialDays
      .where((d) => d.walletId == widget.activeWalletId)
      .where((d) {
        final thisYear = DateTime(
          DateTime.now().year,
          d.date.month,
          d.date.day,
        );
        return thisYear.difference(DateTime.now()).inDays.abs() <= 30;
      })
      .length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(isDark, textColor),
      body: CustomScrollView(
        slivers: [
          // ── Stats summary bar ─────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildStatsBar(isDark, cardBg, subColor)),

          // ── Module grid ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildModuleTile(context, isDark, _modules[i]),
                childCount: _modules.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(bool isDark, Color textColor) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return AppBar(
      backgroundColor: cardBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          const Text('📅', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PlanIt',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                  color: textColor,
                ),
              ),
              Text(
                'Plan · Track · Achieve',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Nunito',
                  color: isDark ? AppColors.subDark : AppColors.subLight,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () => FamilySwitcherSheet.show(
            context,
            currentWalletId: widget.activeWalletId,
            onSelect: widget.onWalletChange,
          ),
          child: Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _currentWallet.gradient),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentWallet.emoji,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(width: 5),
                Text(
                  _currentWallet.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Stats bar ─────────────────────────────────────────────────────────────
  Widget _buildStatsBar(bool isDark, Color cardBg, Color subColor) {
    final stats = [
      (
        emoji: '🔔',
        value: '$_dueReminders',
        label: 'Due\nSoon',
        color: AppColors.expense,
      ),
      (
        emoji: '✅',
        value: '$_pendingTasks',
        label: 'Pending\nTasks',
        color: AppColors.split,
      ),
      (
        emoji: '📅',
        value: '$_upcomingDays',
        label: 'Special\nDays',
        color: AppColors.primary,
      ),
      (
        emoji: '🧾',
        value: '$_overdueBills',
        label: 'Overdue\nBills',
        color: AppColors.lend,
      ),
    ];
    return Container(
      color: cardBg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: stats.asMap().entries.map((e) {
          final s = e.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: e.key > 0 ? 8 : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: s.color.withOpacity(isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: s.color.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(s.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 3),
                    Text(
                      s.value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'DM Mono',
                        color: s.color,
                      ),
                    ),
                    Text(
                      s.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: s.color.withOpacity(0.75),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Module tile ───────────────────────────────────────────────────────────
  Widget _buildModuleTile(BuildContext context, bool isDark, _ModuleInfo m) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, anim, __) =>
                m.builder(context, widget.activeWalletId),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                    ),
                child: child,
              ),
            ),
            transitionDuration: const Duration(milliseconds: 320),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: m.color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: m.color.withOpacity(isDark ? 0.08 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Subtle gradient top strip
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [m.color, m.color.withOpacity(0.5)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
              ),
            ),

            // Badge (if non-zero count)
            if (m.badge != null && m.badge! > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: m.color,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${m.badge}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: m.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(m.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const Spacer(),
                  Text(
                    m.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    m.subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'Nunito',
                      color: subColor,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Module definitions ────────────────────────────────────────────────────
  List<_ModuleInfo> get _modules => [
    _ModuleInfo(
      emoji: '🔔',
      title: 'Alert Me',
      subtitle: 'Reminders & snooze',
      color: AppColors.expense,
      badge: _dueReminders,
      builder: (ctx, wid) => AlertMeScreen(
        walletId: wid,
        walletName: _currentWallet.name,
        walletEmoji: _currentWallet.emoji,
        members: _members,
        isPersonal: _currentWallet.isPersonal,
      ),
    ),
    _ModuleInfo(
      emoji: '✅',
      title: 'My Tasks',
      subtitle: 'To-Do & projects',
      color: AppColors.split,
      badge: _pendingTasks,
      builder: (ctx, wid) => MyTasksScreen(
        walletId: wid,
        walletName: _currentWallet.name,
        walletEmoji: _currentWallet.emoji,
        members: _members,
        tasks: _tasksList,
      ),
    ),
    _ModuleInfo(
      emoji: '🎂',
      title: 'Special Days',
      subtitle: 'Birthdays & events',
      color: AppColors.primary,
      badge: _upcomingDays,
      builder: (ctx, wid) => SpecialDaysScreen(
        walletId: wid,
        walletName: _currentWallet.name,
        walletEmoji: _currentWallet.emoji,
        members: _members,
        days: _days,
      ),
    ),
    _ModuleInfo(
      emoji: '🎁',
      title: 'Wish List',
      subtitle: 'Save & track goals',
      color: AppColors.lend,
      badge: null,
      builder: (ctx, wid) => WishListScreen(
        walletId: wid,
        walletName: _currentWallet.name,
        walletEmoji: _currentWallet.emoji,
        wishes: _wishes,
      ),
    ),
    _ModuleInfo(
      emoji: '🧾',
      title: 'Bill Watch',
      subtitle: 'Never miss a bill',
      color: AppColors.borrow,
      badge: _overdueBills,
      builder: (ctx, wid) => BillWatchScreen(
        walletId: wid,
        walletName: _currentWallet.name,
        walletEmoji: _currentWallet.emoji,
        bills: _bills,
      ),
    ),
    _ModuleInfo(
      emoji: '✈️',
      title: 'Travel Board',
      subtitle: 'Trip planner & chat',
      color: const Color(0xFF4A9EFF),
      badge: null,
      builder: (ctx, wid) => TravelBoardScreen(
        walletId: wid,
        walletName: _currentWallet.name,
        walletEmoji: _currentWallet.emoji,
        members: _members,
        trips: _trips,
      ),
    ),
    _ModuleInfo(
      emoji: '🎉',
      title: 'Plan Party',
      subtitle: 'Event & contractors',
      color: AppColors.expense,
      badge: null,
      builder: (ctx, wid) => PlanPartyScreen(walletId: wid),
    ),
    _ModuleInfo(
      emoji: '🗓️',
      title: 'My Schedule',
      subtitle: 'Appointments',
      color: AppColors.income,
      badge: null,
      builder: (ctx, wid) => MyScheduleScreen(walletId: wid),
    ),
    _ModuleInfo(
      emoji: '🏥',
      title: 'Health Vault',
      subtitle: 'Family health records',
      color: const Color(0xFFFF7043),
      badge: null,
      builder: (ctx, wid) => HealthVaultScreen(walletId: wid),
    ),
  ];
}

// ── Module info data class ────────────────────────────────────────────────────

class _ModuleInfo {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final int? badge;
  final Widget Function(BuildContext, String) builder;

  const _ModuleInfo({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.badge,
    required this.builder,
  });
}
