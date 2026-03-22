import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/widgets/family_switcher_sheet.dart';
import 'package:wai_life_assistant/core/widgets/wallet_switcher_pill.dart';
import 'package:wai_life_assistant/features/AppStateNotifier.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/features/planit/modules/alert_me/alert_me_screen.dart';
import 'package:wai_life_assistant/features/planit/modules/my_tasks/my_tasks_screen.dart';
import 'package:wai_life_assistant/features/planit/modules/special_days/special_days_screen.dart';
import 'package:wai_life_assistant/features/planit/modules/wish_list/wish_list_screen.dart';
import 'package:wai_life_assistant/features/planit/modules/travel_board/travel_board_screen.dart';
import 'package:wai_life_assistant/features/planit/modules/notes/notes_screen.dart';
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
  late AppStateNotifier _appState;
  List<WalletModel> _allWallets = [];

  WalletModel get _currentWallet => _allWallets.firstWhere(
    (w) => w.id == widget.activeWalletId,
    orElse: () => _allWallets.isNotEmpty ? _allWallets.first : personalWallet,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = AppStateScope.of(context);
    final newWallets = _appState.wallets;
    if (newWallets != _allWallets) {
      _allWallets = newWallets;
    }
  }

  void _switchWallet(String id) => widget.onWalletChange(id);

  // ── Lifted state — persists across navigation ─────────────────────────────
  final List<ReminderModel> _reminders = [];
  final List<TaskModel> _tasksList = [];
  final List<SpecialDayModel> _days = [];
  final List<WishModel> _wishes = [];
  final List<NoteModel> _notes = [];
  final List<TripModel> _trips = List.from(mockTrips);

  // ── Family members for current wallet — converted to PlanMember ───────────
  List<PlanMember> get _members {
    if (_currentWallet.isPersonal) return [];
    final family = _appState.families.firstWhere(
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
  int get _dueReminders => _reminders
      .where((r) => r.walletId == widget.activeWalletId && !r.done)
      .length;

  int get _pendingTasks => _tasksList
      .where(
        (t) =>
            t.walletId == widget.activeWalletId && t.status != TaskStatus.done,
      )
      .length;

  int get _upcomingDays => _days
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

          // ── Module list ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList.separated(
              itemCount: _modules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) =>
                  _buildModuleRow(ctx, isDark, _modules[i]),
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
        WalletSwitcherPill(
          wallet: _currentWallet,
          onTap: () => FamilySwitcherSheet.show(
            context,
            currentWalletId: widget.activeWalletId,
            onSelect: widget.onWalletChange,
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
        emoji: '🗒️',
        value: '${_notes.length}',
        label: 'Notes',
        color: const Color(0xFFF9A825),
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

  // ── Module row (full-width card with summary + quick-add) ────────────────
  Widget _buildModuleRow(BuildContext context, bool isDark, _ModuleInfo m) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;
    final summary = _getSummary(m);
    final count = _getCount(m);

    return GestureDetector(
      onTap: () => _navigate(context, m.builder),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: m.color.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
              color: m.color.withOpacity(isDark ? 0.07 : 0.09),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left colour bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: m.color,
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(20)),
                ),
              ),
              const SizedBox(width: 14),
              // Icon
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: m.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(m.emoji,
                      style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + count chip
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: textColor,
                              ),
                            ),
                          ),
                          if (count > 0)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: m.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Nunito',
                                  color: m.color,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: subColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(
                          height: 1,
                          color: m.color.withOpacity(0.15)),
                      const SizedBox(height: 6),
                      if (summary.isNotEmpty)
                        ...summary.take(2).map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.only(
                                          right: 7, top: 1),
                                      decoration: BoxDecoration(
                                        color: m.color.withOpacity(0.55),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        s,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'Nunito',
                                          color: textColor,
                                          height: 1.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                      else
                        Text(
                          _emptyLabel(m),
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: subColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Quick-add button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () =>
                        _navigate(context, m.quickAddBuilder ?? m.builder),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: m.color.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child:
                          Icon(Icons.add_rounded, color: m.color, size: 20),
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

  void _navigate(
      BuildContext context, Widget Function(BuildContext, String) builder) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => builder(context, widget.activeWalletId),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(
                parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  // ── Summary helpers ───────────────────────────────────────────────────────
  List<String> _getSummary(_ModuleInfo m) {
    final wid = widget.activeWalletId;
    switch (m.title) {
      case 'Alert Me':
        return _reminders
            .where((r) => r.walletId == wid && !r.done)
            .take(2)
            .map((r) {
          final days = r.dueDate.difference(DateTime.now()).inDays;
          final when =
              days <= 0 ? 'Today' : days == 1 ? 'Tomorrow' : 'in $days days';
          return '${r.emoji} ${r.title} · $when';
        }).toList();
      case 'My Tasks':
        return _tasksList
            .where((t) =>
                t.walletId == wid && t.status != TaskStatus.done)
            .take(2)
            .map((t) => t.title)
            .toList();
      case 'Special Days':
        final now = DateTime.now();
        final flat = DateTime(now.year, now.month, now.day);
        final pairs = _days
            .where((d) => d.walletId == wid)
            .map((d) {
              DateTime next =
                  DateTime(now.year, d.date.month, d.date.day);
              if (next.isBefore(flat)) {
                next = DateTime(now.year + 1, d.date.month, d.date.day);
              }
              return (d, next);
            })
            .where((p) => p.$2.difference(flat).inDays <= 90)
            .toList()
          ..sort((a, b) => a.$2.compareTo(b.$2));
        return pairs.take(2).map((p) {
          final days = p.$2.difference(flat).inDays;
          final when = days == 0
              ? 'Today!'
              : days == 1
                  ? 'Tomorrow'
                  : 'in $days days';
          return '${p.$1.emoji} ${p.$1.title} · $when';
        }).toList();
      case 'Wish List':
        return _wishes
            .where((w) => w.walletId == wid && !w.purchased)
            .take(2)
            .map((w) => '${w.emoji} ${w.title}')
            .toList();
      case 'Notes':
        return _notes
            .where((n) => n.walletId == wid)
            .take(2)
            .map((n) => n.title.isNotEmpty
                ? n.title
                : n.content.split('\n').first.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      default:
        return [];
    }
  }

  int _getCount(_ModuleInfo m) {
    final wid = widget.activeWalletId;
    switch (m.title) {
      case 'Alert Me':
        return _reminders
            .where((r) => r.walletId == wid && !r.done)
            .length;
      case 'My Tasks':
        return _tasksList
            .where(
                (t) => t.walletId == wid && t.status != TaskStatus.done)
            .length;
      case 'Special Days':
        return _days.where((d) => d.walletId == wid).length;
      case 'Wish List':
        return _wishes
            .where((w) => w.walletId == wid && !w.purchased)
            .length;
      case 'Notes':
        return _notes.where((n) => n.walletId == wid).length;
      default:
        return 0;
    }
  }

  String _emptyLabel(_ModuleInfo m) {
    switch (m.title) {
      case 'Alert Me':
        return 'No active reminders';
      case 'My Tasks':
        return 'No pending tasks';
      case 'Special Days':
        return 'No upcoming events';
      case 'Wish List':
        return 'No wishes yet';
      case 'Notes':
        return 'No notes yet';
      default:
        return 'No items yet';
    }
  }

  // ── V1 visible modules — others are defined below but hidden until V2 ──────
  static const _kV1Modules = {
    'Alert Me',
    'My Tasks',
    'Special Days',
    'Wish List',
    'Notes',
  };

  // ── Module definitions ────────────────────────────────────────────────────
  List<_ModuleInfo> get _modules =>
      _allModules.where((m) => _kV1Modules.contains(m.title)).toList();

  // TODO(v2): Rename back to _modules when all modules are ready for release.
  List<_ModuleInfo> get _allModules => [
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
        reminders: _reminders,
      ),
      quickAddBuilder: (ctx, wid) => AlertMeScreen(
        walletId: wid,
        walletName: _currentWallet.name,
        walletEmoji: _currentWallet.emoji,
        members: _members,
        isPersonal: _currentWallet.isPersonal,
        reminders: _reminders,
        openAdd: true,
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
      quickAddBuilder: (ctx, wid) => MyTasksScreen(
        walletId: wid,
        walletName: _currentWallet.name,
        walletEmoji: _currentWallet.emoji,
        members: _members,
        tasks: _tasksList,
        openAdd: true,
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
      quickAddBuilder: (ctx, wid) => SpecialDaysScreen(
        walletId: wid,
        walletName: _currentWallet.name,
        walletEmoji: _currentWallet.emoji,
        members: _members,
        days: _days,
        openAdd: true,
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
      quickAddBuilder: (ctx, wid) => WishListScreen(
        walletId: wid,
        walletName: _currentWallet.name,
        walletEmoji: _currentWallet.emoji,
        wishes: _wishes,
        openAdd: true,
      ),
    ),
    _ModuleInfo(
      emoji: '🗒️',
      title: 'Notes',
      subtitle: 'Sticky notes & ideas',
      color: const Color(0xFFF9A825),
      badge: null,
      builder: (ctx, wid) => NotesScreen(
        walletId: wid,
        walletName: _currentWallet.name,
        walletEmoji: _currentWallet.emoji,
      ),
      quickAddBuilder: (ctx, wid) => NotesScreen(
        walletId: wid,
        walletName: _currentWallet.name,
        walletEmoji: _currentWallet.emoji,
        openAdd: true,
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
  // Opens the screen with the add sheet pre-triggered (V2 modules may omit this)
  final Widget Function(BuildContext, String)? quickAddBuilder;

  const _ModuleInfo({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.badge,
    required this.builder,
    this.quickAddBuilder,
  });
}
