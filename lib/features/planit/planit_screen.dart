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

  // ── Derived stats ─────────────────────────────────────────────────────────
  int get _dueReminders => mockReminders
      .where((r) => r.walletId == widget.activeWalletId && !r.done)
      .where((r) => r.dueDate.difference(DateTime.now()).inDays <= 3)
      .length;

  int get _pendingTasks => mockTasks
      .where(
        (t) =>
            t.walletId == widget.activeWalletId && t.status != TaskStatus.done,
      )
      .length;

  int get _overdueBills => mockBills
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
      builder: (ctx, wid) => AlertMeScreen(walletId: wid),
    ),
    _ModuleInfo(
      emoji: '✅',
      title: 'My Tasks',
      subtitle: 'To-Do & projects',
      color: AppColors.split,
      badge: _pendingTasks,
      builder: (ctx, wid) => MyTasksScreen(walletId: wid),
    ),
    _ModuleInfo(
      emoji: '🎂',
      title: 'Special Days',
      subtitle: 'Birthdays & events',
      color: AppColors.primary,
      badge: _upcomingDays,
      builder: (ctx, wid) => SpecialDaysScreen(walletId: wid),
    ),
    _ModuleInfo(
      emoji: '🎁',
      title: 'Wish List',
      subtitle: 'Save & track goals',
      color: AppColors.lend,
      badge: null,
      builder: (ctx, wid) => WishListScreen(walletId: wid),
    ),
    _ModuleInfo(
      emoji: '🧾',
      title: 'Bill Watch',
      subtitle: 'Never miss a bill',
      color: AppColors.borrow,
      badge: _overdueBills,
      builder: (ctx, wid) => BillWatchScreen(walletId: wid),
    ),
    _ModuleInfo(
      emoji: '✈️',
      title: 'Travel Board',
      subtitle: 'Trip planner & chat',
      color: const Color(0xFF4A9EFF),
      badge: null,
      builder: (ctx, wid) => TravelBoardScreen(walletId: wid),
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

// import 'package:flutter/material.dart';
// import 'package:wai_life_assistant/core/theme/app_text.dart';
// import 'package:wai_life_assistant/features/planit/bottomSheet/showPlanItBottomSheet.dart';
// import 'package:wai_life_assistant/features/planit/Reminder/showBillReminderSheet.dart';
// import 'package:flutter/services.dart';
// import 'package:wai_life_assistant/features/planit/categoryGridSheet.dart';
// import 'package:wai_life_assistant/features/planit/Reminder/reminderListPage.dart';
// import 'package:wai_life_assistant/features/planit/ToDo/todoPage.dart';
// import 'package:wai_life_assistant/features/planit/specialDay/specialDaysPage.dart';

// class PlanItScreen extends StatefulWidget {
//   const PlanItScreen({super.key});

//   @override
//   State<PlanItScreen> createState() => _PlanItScreenState();
// }

// class _PlanItScreenState extends State<PlanItScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(AppText.planItTitle),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.more_vert),
//             onPressed: () {
//               showPlanItBottomSheet(context);
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           const _AIInputSection(),
//           const _QuickActionChips(),
//           const Divider(height: 1),
//           const Expanded(child: _TimelineView()),
//         ],
//       ),
//       // body: ListView.builder(
//       //   padding: const EdgeInsets.all(16),
//       //   itemCount: 15,
//       //   itemBuilder: (_, index) {
//       //     return Card(
//       //       margin: const EdgeInsets.only(bottom: 12),
//       //       child: ListTile(
//       //         leading: const Icon(Icons.check_circle_outline),
//       //         title: Text("Task ${index + 1}"),
//       //         subtitle: const Text("Plan description"),
//       //         trailing: const Icon(Icons.more_vert),
//       //       ),
//       //     );
//       //   },
//       // ),
//     );
//   }
// }

// class _AIInputSection extends StatelessWidget {
//   const _AIInputSection();

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: TextField(
//         decoration: InputDecoration(
//           hintText: 'Plan anything… e.g. Pay school fees every 3 months',
//           prefixIcon: const Icon(Icons.auto_awesome),
//           filled: true,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(16),
//             borderSide: BorderSide.none,
//           ),
//         ),
//         onSubmitted: (value) {
//           HapticFeedback.selectionClick();
//           // TODO: Send text to AI → parse → open confirmation sheet
//           debugPrint('AI Input: $value');
//         },
//       ),
//     );
//   }
// }

// class _QuickActionChips extends StatelessWidget {
//   const _QuickActionChips();

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 52,
//       child: ListView(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         children: [
//           _chip(
//             context,
//             'Reminder',
//             Icons.alarm,
//             () => Navigator.push(
//               context,
//               MaterialPageRoute(builder: (context) => const ReminderListPage()),
//             ),
//           ),
//           _chip(
//             context,
//             'ToDo',
//             Icons.check_circle_outline,
//             () => Navigator.push(
//               context,
//               MaterialPageRoute(builder: (context) => const TodoPage()),
//             ),
//           ),
//           //_chip(context, 'ToDo', Icons.insert_emoticon, () {}),
//           _chip(
//             context,
//             'Birthday/Wedding Day',
//             Icons.insert_emoticon,
//             () => Navigator.push(
//               context,
//               MaterialPageRoute(builder: (context) => const SpecialDaysPage()),
//             ),
//           ),
//           _chip(context, 'To-Buy List', Icons.shopping_cart, () {}),
//           _chip(
//             context,
//             'Pay Bills',
//             Icons.payments,
//             () => showBillReminderSheet(context),
//           ),
//           _chip(context, 'School', Icons.school, () {}),
//           _chip(context, 'Health', Icons.local_hospital, () {}),
//           _chip(context, 'Routine', Icons.repeat, () {}),
//           _chip(context, 'More', Icons.apps, () => showCategoryGrid(context)),
//         ],
//       ),
//     );
//   }

//   Widget _chip(
//     BuildContext context,
//     String label,
//     IconData icon,
//     VoidCallback onTap,
//   ) {
//     return Padding(
//       padding: const EdgeInsets.only(right: 8),
//       child: ActionChip(
//         avatar: Icon(icon, size: 18),
//         label: Text(label),
//         onPressed: () {
//           HapticFeedback.selectionClick();
//           onTap();
//         },
//       ),
//     );
//   }
// }

// class _TimelineView extends StatelessWidget {
//   const _TimelineView();

//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: const [
//         _TimelineSection(
//           title: 'Today',
//           items: [
//             _PlanItem(
//               icon: Icons.medication,
//               title: 'Mom’s medicine',
//               subtitle: '8:00 AM · Assigned to Dad',
//             ),
//           ],
//         ),
//         _TimelineSection(
//           title: 'Tomorrow',
//           items: [
//             _PlanItem(
//               icon: Icons.school,
//               title: 'School project submission',
//               subtitle: 'Assigned to Rahul',
//             ),
//           ],
//         ),
//         _TimelineSection(
//           title: 'This Week',
//           items: [
//             _PlanItem(
//               icon: Icons.payments,
//               title: 'Electricity bill',
//               subtitle: 'Due Friday',
//             ),
//           ],
//         ),
//       ],
//     );
//   }
// }

// class _TimelineSection extends StatelessWidget {
//   final String title;
//   final List<_PlanItem> items;

//   const _TimelineSection({required this.title, required this.items});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(title, style: Theme.of(context).textTheme.titleMedium),
//         const SizedBox(height: 8),
//         ...items,
//         const SizedBox(height: 16),
//       ],
//     );
//   }
// }

// class _PlanItem extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   final String subtitle;

//   const _PlanItem({
//     required this.icon,
//     required this.title,
//     required this.subtitle,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       child: ListTile(
//         leading: Icon(icon),
//         title: Text(title),
//         subtitle: Text(subtitle),
//         trailing: const Icon(Icons.check_circle_outline),
//         onTap: () {
//           // Open reminder detail
//         },
//       ),
//     );
//   }
// }
