import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import 'package:wai_life_assistant/data/services/pantry_service.dart';
import 'package:wai_life_assistant/data/services/wallet_service.dart';
import 'package:wai_life_assistant/data/services/reminder_service.dart';
import 'package:wai_life_assistant/data/services/task_service.dart';
import 'package:wai_life_assistant/data/services/special_day_service.dart';
import 'package:wai_life_assistant/data/services/wish_service.dart';
import 'package:wai_life_assistant/data/services/functions_service.dart';
import 'package:wai_life_assistant/features/auth/auth_coordinator.dart';
import 'package:wai_life_assistant/core/services/network_service.dart';
import 'package:wai_life_assistant/features/AppStateNotifier.dart';
import 'package:wai_life_assistant/data/models/wallet/split_group_models.dart';
import 'package:wai_life_assistant/features/wallet/splits/split_group_detail_screen.dart';
import 'package:wai_life_assistant/features/wallet/ai/SparkBottomSheet.dart';
import 'package:wai_life_assistant/features/wallet/category_detector.dart';
import 'package:wai_life_assistant/features/pantry/widgets/meal_detail_sheet.dart';
import 'package:wai_life_assistant/features/pantry/sheets/add_meal_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wai_life_assistant/data/services/profile_service.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import 'package:wai_life_assistant/features/dashboard/family_settings_section.dart';
import 'package:wai_life_assistant/data/services/notification_service.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/notification_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/notification_prefs_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/privacy_security_sheet.dart';
import 'package:wai_life_assistant/shared/widgets/emoji_or_image.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/language_voice_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/currency_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/date_time_prefs_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/default_scope_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/ai_parser_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/subscription_sheet.dart';
import 'package:wai_life_assistant/core/services/shortcut_service.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/ai_assistant_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  final int refreshCount;
  final ThemeMode themeMode;
  final void Function(ThemeMode)? onSetTheme;
  final void Function(int tabIndex)? onTabSwitch;
  const DashboardScreen({
    super.key,
    this.refreshCount = 0,
    this.themeMode = ThemeMode.system,
    this.onSetTheme,
    this.onTabSwitch,
  });
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = '';
  String _userPhone = '';
  String _userDob = '';
  String _userPlan = 'Free';
  String _userPhotoUrl = '';
  bool _balanceHidden = true;
  // Today's meals — merged list from all loaded wallets
  List<MealEntry> _todayMeals = [];
  final Set<String> _loadedMealWalletIds = {};

  // Page controller for swipeable plate cards
  late final PageController _platePageController;

  // Transactions — merged list from all loaded wallets
  List<TxModel> _transactions = [];
  final Set<String> _loadedWalletIds = {};

  // Page controller for swipeable wallet cards
  late final PageController _walletPageController;

  // PlanIt data — merged from all loaded wallets, keyed by walletId
  final Map<String, List<ReminderModel>> _remindersMap = {};
  final Map<String, List<TaskModel>> _tasksMap = {};
  final Map<String, List<SpecialDayModel>> _specialDaysMap = {};
  final Map<String, List<WishModel>> _wishesMap = {};
  final Map<String, List<FunctionModel>> _functionsMap = {};
  final Set<String> _loadedPlanItWalletIds = {};

  List<TxModel> _todayTx(String wid) => _transactions
      .where((t) => t.walletId == wid && _isToday(t.date))
      .toList();

  bool _wasOnline = true;
  int _unreadNotifCount = 0;
  bool _pendingPasteSms = false;

  void _onNetworkChange() {
    final online = NetworkService.instance.isOnline.value;
    if (online && !_wasOnline) _refresh();
    _wasOnline = online;
  }

  @override
  void initState() {
    super.initState();
    _walletPageController = PageController();
    _platePageController = PageController();
    _wasOnline = NetworkService.instance.isOnline.value;
    NetworkService.instance.isOnline.addListener(_onNetworkChange);
    PantryService.mealChangeSignal.addListener(_onMealChange);
    WalletService.txChangeSignal.addListener(_onTxChange);
    pinnedSplitGroupsNotifier.addListener(_onSplitGroupsChanged);
    NotificationService.changeSignal.addListener(_onNotifChange);
    NotificationService.instance.subscribe();
    _loadPinnedGroups();
    _loadProfile();
    _loadUnreadCount();
    ShortcutService.pending.addListener(_onShortcut);
    if (ShortcutService.pending.value == ShortcutService.pasteBankSms) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onShortcut());
    }
  }

  void _onShortcut() {
    final type = ShortcutService.pending.value;
    if (type == null || !mounted) return;
    ShortcutService.pending.value = null;
    if (type == ShortcutService.pasteBankSms) {
      setState(() => _pendingPasteSms = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = context;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surfBg = Theme.of(ctx).colorScheme.surface;
        final wallets = AppStateScope.of(ctx).wallets;
        final walletId = wallets.isNotEmpty ? wallets.first.id : '';
        _showFabSheet(ctx, isDark, surfBg, walletId, startPasteSms: true);
        setState(() => _pendingPasteSms = false);
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileService.instance.fetchProfile();
      if (profile != null && mounted) {
        setState(() {
          final name = (profile['name'] as String?)?.trim() ?? '';
          if (name.isNotEmpty) _userName = name;
          _userPhone = (profile['phone'] as String?) ?? '';
          _userDob = (profile['dob'] as String?) ?? '';
          _userPlan = (profile['plan'] as String?) ?? 'Free';
          _userPhotoUrl = (profile['photo_url'] as String?) ?? '';
        });
        // Sync default scope preferences from DB into local AppPrefs.
        final prefs = AppPrefs.instance;
        await prefs.init();
        final ws = (profile['wallet_scope'] as String?) ?? 'personal';
        final ps = (profile['pantry_scope'] as String?) ?? 'personal';
        final ls = (profile['planit_scope'] as String?) ?? 'personal';
        if (prefs.walletScope != ws) prefs.walletScope = ws;
        if (prefs.pantryScope != ps) prefs.pantryScope = ps;
        if (prefs.planItScope != ls) prefs.planItScope = ls;
      }
    } catch (e) {
      debugPrint('[Dashboard] _loadProfile error: $e');
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _fmtDob(String iso) {
    try {
      final d = DateTime.parse(iso);
      const months = [
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
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _pickProfilePhoto(void Function(void Function()) ss) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
    );
    if (picked == null || !mounted) return;
    try {
      final url = await ProfileService.instance.uploadPhoto(
        localPath: picked.path,
        folder: 'profiles',
        name: 'avatar',
      );
      await ProfileService.instance.updateProfile(photoUrl: url);
      if (mounted) {
        setState(() => _userPhotoUrl = url);
        ss(() {});
      }
    } catch (e) {
      debugPrint('[Dashboard] photo upload error: $e');
    }
  }

  /// Loads transactions for every wallet not yet fetched, merging into [_transactions].
  static bool _isPlaceholder(String id) => id.isEmpty || id == 'personal';

  void _ensureWalletsLoaded(List<WalletModel> wallets) {
    for (final w in wallets) {
      if (_isPlaceholder(w.id) || _loadedWalletIds.contains(w.id)) continue;
      _loadedWalletIds.add(w.id);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadTransactions(w.id),
      );
    }
  }

  void _ensurePlanItLoaded(List<WalletModel> wallets) {
    for (final w in wallets) {
      if (_isPlaceholder(w.id) || _loadedPlanItWalletIds.contains(w.id)) continue;
      _loadedPlanItWalletIds.add(w.id);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadPlanItData(w.id),
      );
    }
  }

  Future<void> _refresh() async {
    final txToReload = List<String>.from(_loadedWalletIds);
    final mealToReload = List<String>.from(_loadedMealWalletIds);
    final planItToReload = List<String>.from(_loadedPlanItWalletIds);
    _loadedWalletIds.clear();
    _loadedMealWalletIds.clear();
    _loadedPlanItWalletIds.clear();
    await Future.wait([
      _loadPinnedGroups(),
      ...txToReload.map(_loadTransactions),
      ...mealToReload.map(_loadTodayMeals),
      ...planItToReload.map(_loadPlanItData),
    ]);
  }

  /// Fetches transactions for [walletId] and merges them into [_transactions].
  Future<void> _loadTransactions(String walletId) async {
    if (!AuthCoordinator.instance.isLoggedIn || _isPlaceholder(walletId)) return;
    _loadedWalletIds.add(walletId);
    try {
      final rows = await WalletService.instance.fetchTransactions(walletId);
      if (!mounted) return;
      setState(() {
        _transactions.removeWhere((t) => t.walletId == walletId);
        _transactions.addAll(rows.map(TxModel.fromRow));
      });
    } catch (e) {
      debugPrint('[Dashboard] fetchTransactions error: $e');
    }
  }

  Future<void> _loadPinnedGroups() async {
    if (!AuthCoordinator.instance.isLoggedIn) return;
    try {
      final groups = await WalletService.instance.fetchPinnedSplitGroups();
      pinnedSplitGroupsNotifier.value = groups;
    } catch (e) {
      debugPrint('[Dashboard] fetchPinnedSplitGroups failed: $e');
    }
  }

  @override
  void dispose() {
    _walletPageController.dispose();
    _platePageController.dispose();
    NetworkService.instance.isOnline.removeListener(_onNetworkChange);
    PantryService.mealChangeSignal.removeListener(_onMealChange);
    WalletService.txChangeSignal.removeListener(_onTxChange);
    pinnedSplitGroupsNotifier.removeListener(_onSplitGroupsChanged);
    NotificationService.changeSignal.removeListener(_onNotifChange);
    NotificationService.instance.unsubscribe();
    super.dispose();
  }

  void _onMealChange() {
    for (final wid in List<String>.from(_loadedMealWalletIds)) {
      _loadTodayMeals(wid);
    }
  }

  void _onTxChange() {
    for (final wid in List<String>.from(_loadedWalletIds)) {
      _loadTransactions(wid);
    }
  }

  void _onNotifChange() => _loadUnreadCount();

  Future<void> _loadUnreadCount() async {
    final count = await NotificationService.instance.fetchUnreadCount();
    if (mounted) setState(() => _unreadNotifCount = count);
  }

  void _openNotifications(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => NotificationSheet(isDark: isDark),
    ).then((_) => _loadUnreadCount());
  }

  void _onSplitGroupsChanged() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onPinnedGroupUpdated(SplitGroup updated) {
    final current = List<SplitGroup>.from(pinnedSplitGroupsNotifier.value);
    final i = current.indexWhere((g) => g.id == updated.id);
    if (i != -1) current[i] = updated;
    // Remove if no longer active
    pinnedSplitGroupsNotifier.value = current
        .where((g) => !g.isFullySettled)
        .toList();
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshCount != widget.refreshCount) {
      for (final wid in List<String>.from(_loadedMealWalletIds)) {
        _loadTodayMeals(wid);
      }
      for (final wid in List<String>.from(_loadedPlanItWalletIds)) {
        _loadPlanItData(wid);
      }
    }
  }

  Future<void> _loadPlanItData(String walletId) async {
    if (_isPlaceholder(walletId)) return;
    _loadedPlanItWalletIds.add(walletId);
    try {
      final results = await Future.wait([
        ReminderService.instance.fetchReminders(walletId),
        TaskService.instance.fetchTasks(walletId),
        SpecialDayService.instance.fetchDays(walletId),
        WishService.instance.fetchWishes(walletId),
        FunctionsService.instance.fetchMyFunctions(walletId),
      ]);
      if (!mounted) return;
      setState(() {
        _remindersMap[walletId] = (results[0])
            .map(ReminderModel.fromRow)
            .toList();
        _tasksMap[walletId] = (results[1]).map(TaskModel.fromRow).toList();
        _specialDaysMap[walletId] = (results[2])
            .map(SpecialDayModel.fromRow)
            .toList();
        _wishesMap[walletId] = (results[3]).map(WishModel.fromRow).toList();
        _functionsMap[walletId] = (results[4])
            .map(FunctionModel.fromJson)
            .toList();
      });
    } catch (e) {
      debugPrint('[Dashboard] _loadPlanItData error: $e');
    }
  }

  void _ensureMealsLoaded(List<WalletModel> wallets) {
    for (final w in wallets) {
      if (w.id.isEmpty || _loadedMealWalletIds.contains(w.id)) continue;
      _loadedMealWalletIds.add(w.id);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadTodayMeals(w.id),
      );
    }
  }

  Future<void> _updateMeal(MealEntry updated) async {
    setState(() {
      final idx = _todayMeals.indexWhere((e) => e.id == updated.id);
      if (idx >= 0) _todayMeals[idx] = updated;
    });
    try {
      await PantryService.instance.updateMealEntry(updated.id, {
        'name': updated.name,
        'emoji': updated.emoji,
        'meal_time': updated.mealTime.name,
        'date': '${updated.date.year}-${updated.date.month.toString().padLeft(2, '0')}-${updated.date.day.toString().padLeft(2, '0')}',
        'recipe_id': updated.recipeId,
        'recipe_ids': updated.recipeIds,
        'note': updated.note,
        'ingredients': updated.ingredients,
      });
    } catch (_) {
      _loadTodayMeals(updated.walletId); // revert by reloading on error
    }
  }

  Future<void> _loadTodayMeals(String walletId) async {
    if (walletId.isEmpty) return;
    _loadedMealWalletIds.add(walletId);
    try {
      final rows = await PantryService.instance.fetchMealEntriesForDay(
        walletId,
        DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _todayMeals.removeWhere((e) => e.walletId == walletId);
        _todayMeals.addAll(rows.map(MealEntry.fromMap));
      });
    } catch (_) {} // non-critical
  }

  void _showMealDetail(MealEntry m) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showMealDetailSheet(
      context,
      meal: m,
      isDark: isDark,
      currentUserName: _userName,
      onEdit: () async {
        Navigator.pop(context);
        // Fetch the wallet's recipes on-demand so the edit sheet has them.
        List<RecipeModel> recipes = [];
        try {
          final rows = await PantryService.instance.fetchRecipes(m.walletId);
          recipes = rows.map(RecipeModel.fromMap).toList();
        } catch (_) {}
        if (!mounted) return;
        AddMealSheet.show(
          context,
          date: m.date,
          walletId: m.walletId,
          recipes: recipes,
          existing: m,
          onSave: (entry) async {
            // Not called in edit mode, but required by the API.
          },
          onUpdate: _updateMeal,
          dayMeals: _todayMeals
              .where((e) => e.walletId == m.walletId)
              .toList(),
        );
      },
      onDelete: () async {
        Navigator.pop(context);
        setState(() => _todayMeals.removeWhere((e) => e.id == m.id));
        try {
          await PantryService.instance.deleteMealEntry(m.id);
          PantryService.mealChangeSignal.value++;
        } catch (_) {
          _loadTodayMeals(m.walletId); // revert by reloading
        }
      },
      onReactionAdded: (reaction) async {
        setState(() {
          final idx = _todayMeals.indexWhere((e) => e.id == m.id);
          if (idx >= 0) {
            _todayMeals[idx] = _todayMeals[idx].copyWith(
              reactions: [..._todayMeals[idx].reactions, reaction],
            );
          }
        });
        try {
          final row = await PantryService.instance.addReaction(
            mealId: m.id,
            memberName: reaction.memberName,
            reactionEmoji: reaction.reactionEmoji,
            comment: reaction.comment,
            replyTo: reaction.replyTo,
          );
          if (!mounted) return;
          final saved = MealReaction.fromMap(row);
          setState(() {
            final idx = _todayMeals.indexWhere((e) => e.id == m.id);
            if (idx >= 0) {
              final list = List<MealReaction>.from(_todayMeals[idx].reactions);
              final ri = list.lastIndexWhere(
                (r) =>
                    r.id == null &&
                    r.memberName == reaction.memberName &&
                    r.reactionEmoji == reaction.reactionEmoji,
              );
              if (ri >= 0) list[ri] = saved;
              _todayMeals[idx] = _todayMeals[idx].copyWith(reactions: list);
            }
          });
        } catch (_) {
          // non-critical
        }
      },
      onReactionUpdated: (reactionIndex, updated) async {
        final mealIdx = _todayMeals.indexWhere((e) => e.id == m.id);
        final dbId =
            mealIdx >= 0 &&
                reactionIndex < _todayMeals[mealIdx].reactions.length
            ? _todayMeals[mealIdx].reactions[reactionIndex].id
            : null;
        setState(() {
          if (mealIdx >= 0) {
            final list = List<MealReaction>.from(
              _todayMeals[mealIdx].reactions,
            );
            list[reactionIndex] = updated.copyWith(id: dbId ?? updated.id);
            _todayMeals[mealIdx] = _todayMeals[mealIdx].copyWith(
              reactions: list,
            );
          }
        });
        if (dbId == null) return;
        try {
          await PantryService.instance.updateReaction(dbId, {
            'member_name': updated.memberName,
            'reaction_emoji': updated.reactionEmoji,
            'comment': updated.comment,
          });
        } catch (_) {}
      },
      onReactionDeleted: (reactionIndex) async {
        final mealIdx = _todayMeals.indexWhere((e) => e.id == m.id);
        final dbId =
            mealIdx >= 0 &&
                reactionIndex < _todayMeals[mealIdx].reactions.length
            ? _todayMeals[mealIdx].reactions[reactionIndex].id
            : null;
        setState(() {
          if (mealIdx >= 0) {
            final list = List<MealReaction>.from(_todayMeals[mealIdx].reactions)
              ..removeAt(reactionIndex);
            _todayMeals[mealIdx] = _todayMeals[mealIdx].copyWith(
              reactions: list,
            );
          }
        });
        if (dbId == null) return;
        try {
          await PantryService.instance.deleteReaction(dbId);
        } catch (_) {}
      },
      onStatusChanged: (status, servingsCount) async {
        setState(() {
          final idx = _todayMeals.indexWhere((e) => e.id == m.id);
          if (idx >= 0) {
            _todayMeals[idx] = _todayMeals[idx].copyWith(
              mealStatus: status,
              servingsCount: servingsCount,
            );
          }
        });
        try {
          await PantryService.instance.updateMealStatus(
            m.id,
            status: status.name,
            servingsCount: servingsCount,
          );
        } catch (_) {
          _loadTodayMeals(m.walletId); // revert by reloading
        }
      },
    );
  }

  /// Label for a walletId: 'Personal' for personal, family name otherwise.
  String _walletLabel(String walletId) {
    final appState = AppStateScope.read(context);
    final wallet = appState.wallets.where((w) => w.id == walletId).firstOrNull;
    if (wallet == null || wallet.isPersonal) return 'Personal';
    return appState.families
            .where((f) => f.walletId == walletId)
            .firstOrNull
            ?.name ??
        wallet.name;
  }

  List<_PlanNudge> get _nudges {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = <_PlanNudge>[];

    for (final entry in _remindersMap.entries) {
      final wLabel = _walletLabel(entry.key);
      for (final r in entry.value) {
        if (r.done) continue;
        final due = DateTime(r.dueDate.year, r.dueDate.month, r.dueDate.day);
        final daysLeft = due.difference(today).inDays;
        if (daysLeft >= 0 && daysLeft <= 7) {
          list.add(
            _PlanNudge(
              emoji: r.emoji,
              title: r.title,
              subtitle: daysLeft == 0 ? 'Due today' : 'In ${daysLeft}d',
              urgency: daysLeft == 0
                  ? 3
                  : daysLeft <= 2
                  ? 2
                  : 1,
              color: r.priority.color,
              tag: 'Alert',
              walletLabel: wLabel,
            ),
          );
        }
      }
    }

    for (final entry in _tasksMap.entries) {
      final wLabel = _walletLabel(entry.key);
      for (final t in entry.value) {
        if (t.status == TaskStatus.done || t.dueDate == null) continue;
        final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        final daysLeft = due.difference(today).inDays;
        if (daysLeft >= 0 && daysLeft <= 7) {
          list.add(
            _PlanNudge(
              emoji: t.emoji,
              title: t.title,
              subtitle: daysLeft == 0 ? 'Due today' : 'Due in ${daysLeft}d',
              urgency: daysLeft == 0
                  ? 3
                  : t.priority.index >= 2
                  ? 2
                  : 1,
              color: t.priority.color,
              tag: 'Task',
              walletLabel: wLabel,
            ),
          );
        }
      }
    }

    for (final entry in _specialDaysMap.entries) {
      final wLabel = _walletLabel(entry.key);
      for (final sd in entry.value) {
        final projected = sd.yearlyRecur
            ? DateTime(now.year, sd.date.month, sd.date.day)
            : DateTime(sd.date.year, sd.date.month, sd.date.day);
        final daysLeft = projected.difference(today).inDays;
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
              walletLabel: wLabel,
            ),
          );
        }
      }
    }

    for (final entry in _wishesMap.entries) {
      final wLabel = _walletLabel(entry.key);
      for (final w in entry.value) {
        if (w.purchased || w.targetDate == null) continue;
        final due = DateTime(
          w.targetDate!.year,
          w.targetDate!.month,
          w.targetDate!.day,
        );
        final daysLeft = due.difference(today).inDays;
        if (daysLeft >= 0 && daysLeft <= 7) {
          list.add(
            _PlanNudge(
              emoji: w.emoji,
              title: w.title,
              subtitle: daysLeft == 0
                  ? 'Target today'
                  : 'Target in ${daysLeft}d',
              urgency: daysLeft == 0
                  ? 3
                  : daysLeft <= 2
                  ? 2
                  : 1,
              color: w.priority.color,
              tag: 'Wish',
              walletLabel: wLabel,
            ),
          );
        }
      }
    }

    for (final entry in _functionsMap.entries) {
      final wLabel = _walletLabel(entry.key);
      for (final f in entry.value) {
        if (f.functionDate == null) continue;
        final fDate = DateTime(
          f.functionDate!.year,
          f.functionDate!.month,
          f.functionDate!.day,
        );
        final daysLeft = fDate.difference(today).inDays;
        if (daysLeft >= 0 && daysLeft <= 7) {
          list.add(
            _PlanNudge(
              emoji: '🎉',
              title: f.title,
              subtitle: daysLeft == 0 ? 'Today!' : 'In ${daysLeft}d',
              urgency: daysLeft == 0
                  ? 3
                  : daysLeft <= 2
                  ? 2
                  : 1,
              color: AppColors.primary,
              tag: 'Function',
              walletLabel: wLabel,
            ),
          );
        }
      }
    }

    list.sort((a, b) => b.urgency.compareTo(a.urgency));
    return list;
  }

  // Upcoming functions within 7 days (for the Functions card)
  List<FunctionModel> get _upcomingFunctions {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(const Duration(days: 7));
    final allFunctions = _functionsMap.values.expand((l) => l);
    return allFunctions.where((f) {
      if (f.functionDate == null) return false;
      final fDate = DateTime(
        f.functionDate!.year,
        f.functionDate!.month,
        f.functionDate!.day,
      );
      return !fDate.isBefore(today) && !fDate.isAfter(end);
    }).toList();
  }

  List<UpcomingFunction> get _upcomingAttending => const [];

  // Active split transactions
  List<TxModel> _activeSplits(String wid) => mockTransactions
      .where((t) => t.type == TxType.split && t.walletId == wid)
      .toList();

  // Split groups pinned to dashboard — fed by the wallet screen via pinnedSplitGroupsNotifier.
  List<SplitGroup> get _pinnedGroups => pinnedSplitGroupsNotifier.value;

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    // Read walletId from global state — updates whenever any tab switches view
    final appState = AppStateScope.of(context);
    final walletId = appState.activeWalletId;
    _ensureWalletsLoaded(appState.wallets);
    _ensureMealsLoaded(appState.wallets);
    _ensurePlanItLoaded(appState.wallets);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: _buildFab(context, isDark, surfBg, walletId),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                    // Notifications
                    GestureDetector(
                      onTap: () => _openNotifications(isDark),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: surfBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _unreadNotifCount > 0
                                  ? Icons.notifications_rounded
                                  : Icons.notifications_outlined,
                              size: 20,
                              color: isDark
                                  ? AppColors.subDark
                                  : AppColors.subLight,
                            ),
                          ),
                          if (_unreadNotifCount > 0)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.expense,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  _unreadNotifCount > 99
                                      ? '99+'
                                      : '$_unreadNotifCount',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
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
                          color: isDark
                              ? AppColors.subDark
                              : AppColors.subLight,
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
                      // ── AI Assistant ──────────────────────────────────────────
                      AIAssistantWidget(
                        walletId: appState.activeWalletId,
                        onNavigate: widget.onTabSwitch,
                      ),
                      const SizedBox(height: 16),

                      // ①  TODAY ───────────────────────────────────────────────
                      _SectionHeader(
                        emoji: '💳',
                        title: 'Today',
                        sub: sub,
                        action: 'Wallet →',
                        onAction: () {},
                      ),
                      const SizedBox(height: 10),
                      // Swipeable wallet summary cards (personal + family)
                      Builder(
                        builder: (ctx) {
                          final personalW = appState.wallets.firstWhere(
                            (w) => w.isPersonal,
                            orElse: () => personalWallet,
                          );
                          final familyWs = appState.wallets
                              .where((w) => !w.isPersonal)
                              .toList();
                          final allCards = [personalW, ...familyWs];

                          const height = 220.0;

                          return Column(
                            children: [
                              SizedBox(
                                height: height,
                                child: PageView.builder(
                                  controller: _walletPageController,
                                  itemCount: allCards.length,
                                  onPageChanged: (idx) {
                                    AppStateScope.read(
                                      context,
                                    ).switchWallet(allCards[idx].id);
                                  },
                                  itemBuilder: (ctx, idx) {
                                    final w = allCards[idx];
                                    final label = w.isPersonal
                                        ? 'Personal'
                                        : (appState.families
                                                  .where(
                                                    (f) => f.walletId == w.id,
                                                  )
                                                  .firstOrNull
                                                  ?.name ??
                                              w.name);
                                    final txToday = _todayTx(w.id);
                                    final bal = txToday.fold<double>(
                                      0.0,
                                      (s, t) => t.type.isPositive
                                          ? s + t.amount
                                          : (t.type == TxType.expense ||
                                                t.type == TxType.lend ||
                                                t.type == TxType.split)
                                          ? s - t.amount
                                          : s,
                                    );
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: idx < allCards.length - 1
                                            ? 8.0
                                            : 0,
                                      ),
                                      child: _MoneyPulseCard(
                                        label: label,
                                        wallet: w,
                                        todayTx: txToday,
                                        balance: bal,
                                        hidden: _balanceHidden,
                                        onToggleHide: () => setState(
                                          () =>
                                              _balanceHidden = !_balanceHidden,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (allCards.length > 1) ...[
                                const SizedBox(height: 8),
                                AnimatedBuilder(
                                  animation: _walletPageController,
                                  builder: (ctx, _) {
                                    final page =
                                        _walletPageController.hasClients
                                        ? (_walletPageController.page ?? 0)
                                              .round()
                                        : 0;
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(allCards.length, (
                                        i,
                                      ) {
                                        final active = page == i;
                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          width: active ? 16 : 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: active
                                                ? AppColors.primary
                                                : sub.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                        );
                                      }),
                                    );
                                  },
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      // ①b  SPLIT ACTIVITY (if any active splits) ─────────────
                      if (_activeSplits(walletId).isNotEmpty) ...[
                        _SectionHeader(
                          emoji: '⚖️',
                          title: 'Split Activity',
                          sub: sub,
                          action: 'View all →',
                          onAction: () {},
                        ),
                        const SizedBox(height: 8),
                        ..._activeSplits(walletId).map(
                          (s) => _SplitNudgeCard(
                            tx: s,
                            isDark: isDark,
                            onAddMyShare: () =>
                                _showQuickAdd(context, isDark, surfBg, s),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // ①c  PINNED SPLIT GROUPS ──────────────────────────────────
                      if (_pinnedGroups.isNotEmpty) ...[
                        _SectionHeader(
                          emoji: '📌',
                          title: 'Active Splits',
                          sub: sub,
                          action: 'Wallet →',
                          onAction: () {},
                        ),
                        const SizedBox(height: 8),
                        ..._pinnedGroups.map(
                          (g) => _PinnedSplitCard(
                            group: g,
                            isDark: isDark,
                            cardBg: cardBg,
                            onAddExpense: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SplitGroupDetailScreen(
                                  group: g,
                                  onGroupUpdated: _onPinnedGroupUpdated,
                                  autoOpenAddExpense: true,
                                ),
                              ),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SplitGroupDetailScreen(
                                  group: g,
                                  onGroupUpdated: _onPinnedGroupUpdated,
                                ),
                              ),
                            ),
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
                      Builder(
                        builder: (ctx) {
                          final personalW = appState.wallets.firstWhere(
                            (w) => w.isPersonal,
                            orElse: () => personalWallet,
                          );
                          final familyWs = appState.wallets
                              .where((w) => !w.isPersonal)
                              .toList();
                          final allCards = [personalW, ...familyWs];

                          // Height: header(54) + content padding(28) + icon+label+dash col(58) + per meal(46)
                          double plateHeight(String wid) {
                            final meals = _todayMeals
                                .where((e) => e.walletId == wid)
                                .toList();
                            final byTime = <Object, int>{};
                            for (final m in meals) {
                              byTime[m.mealTime] =
                                  (byTime[m.mealTime] ?? 0) + 1;
                            }
                            final maxCol = byTime.values.fold(
                              0,
                              (a, b) => a > b ? a : b,
                            );
                            return 54.0 + 28.0 + 58.0 + maxCol * 46.0 + 32.0;
                          }

                          final plateH = allCards
                              .map((w) => plateHeight(w.id))
                              .fold<double>(0, (a, b) => a > b ? a : b)
                              .clamp(156.0, 500.0);

                          return Column(
                            children: [
                              SizedBox(
                                height: plateH,
                                child: PageView.builder(
                                  controller: _platePageController,
                                  itemCount: allCards.length,
                                  physics: allCards.length > 1
                                      ? const PageScrollPhysics()
                                      : const NeverScrollableScrollPhysics(),
                                  itemBuilder: (ctx, idx) {
                                    final w = allCards[idx];
                                    final label = w.isPersonal
                                        ? 'Personal'
                                        : (appState.families
                                                  .where(
                                                    (f) => f.walletId == w.id,
                                                  )
                                                  .firstOrNull
                                                  ?.name ??
                                              w.name);
                                    final meals = _todayMeals
                                        .where((e) => e.walletId == w.id)
                                        .toList();
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: idx < allCards.length - 1
                                            ? 8.0
                                            : 0,
                                      ),
                                      child: _TodaysPlateCard(
                                        label: label,
                                        meals: meals,
                                        isDark: isDark,
                                        cardBg: cardBg,
                                        onMealTap: _showMealDetail,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (allCards.length > 1) ...[
                                const SizedBox(height: 8),
                                AnimatedBuilder(
                                  animation: _platePageController,
                                  builder: (ctx, _) {
                                    final page = _platePageController.hasClients
                                        ? (_platePageController.page ?? 0)
                                              .round()
                                        : 0;
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(allCards.length, (
                                        i,
                                      ) {
                                        final active = page == i;
                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          width: active ? 16 : 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: active
                                                ? const Color(0xFF4CAF50)
                                                : sub.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                        );
                                      }),
                                    );
                                  },
                                ),
                              ],
                            ],
                          );
                        },
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

                      // ④  UPCOMING FUNCTIONS ───────────────────────────────────
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FAB ──────────────────────────────────────────────────────────────────────
  Widget _buildFab(
    BuildContext context,
    bool isDark,
    Color surfBg,
    String walletId,
  ) {
    return FloatingActionButton(
      onPressed: () => _showFabSheet(context, isDark, surfBg, walletId),
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.add_rounded, color: Colors.white),
    );
  }

  void _showFabSheet(
    BuildContext context,
    bool isDark,
    Color surfBg,
    String walletId, {
    bool startPasteSms = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DashFabSheet(
        isDark: isDark,
        surfBg: surfBg,
        walletId: walletId,
        startPasteSms: startPasteSms,
        // IntentConfirmSheet now persists directly — onAiSave is UI-only.
        onAiSave: (tx) {
          setState(() => _transactions.insert(0, tx));
          WalletService.txChangeSignal.value++;
          WalletService.instance.ensureCategory(tx.category, tx.type.name);
        },
        onQuickSave: (tx) {
          setState(() => _transactions.add(tx));
          WalletService.txChangeSignal.value++;
          WalletService.instance.ensureCategory(tx.category, tx.type.name);
        },
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
  // ── Edit existing transaction (tap from dashboard card) ────────────────────

  // ── Quick Add Transaction ───────────────────────────────────────────────────
  void _showQuickAdd(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    TxModel? splitRef,
  ) {
    final amtCtrl = TextEditingController();
    final titleCtrl = TextEditingController(text: splitRef?.title ?? '');
    final noteCtrl = TextEditingController(text: splitRef?.note ?? '');
    var txType = splitRef != null ? TxType.split : TxType.expense;
    var payMode = PayMode.online;
    var cat = splitRef?.category ?? '';
    var autoDetectedCat = ''; // tracks last auto-detected value
    CategoryDetector.ensureLoaded();

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
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
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (splitRef != null) ...[
                      Text(
                        //splitRef.giftType ?? '⚖️',
                        '⚖️',
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
                                TxType.lend,
                                TxType.borrow,
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
                                          ? t.color.withValues(alpha: 0.15)
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
                              color: txType.color.withValues(alpha: 0.3),
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
                                  ? AppColors.cash.withValues(alpha: 0.12)
                                  : AppColors.online.withValues(alpha: 0.12),
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

                // Title field
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
                    controller: titleCtrl,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Nunito',
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                    onChanged: (val) {
                      final isIncome = txType == TxType.income;
                      final detected = CategoryDetector.detect(val, isIncome: isIncome);
                      if (detected != null) {
                        ss(() { cat = detected; autoDetectedCat = detected; });
                      }
                    },
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Title',
                      prefixIcon: Icon(Icons.label_outline_rounded, size: 16),
                      prefixIconConstraints: BoxConstraints(minWidth: 28, minHeight: 0),
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

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
                      hintText: 'Add a note?',
                      prefixIcon: Icon(Icons.notes_rounded, size: 16),
                      prefixIconConstraints: BoxConstraints(minWidth: 28, minHeight: 0),
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
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
                      children: () {
                            final all = WalletService.instance.categoriesFor(
                              txType == TxType.income ? 'income' : 'expense',
                            );
                            final sorted = [
                              if (autoDetectedCat.isNotEmpty && all.contains(autoDetectedCat)) autoDetectedCat,
                              ...all.where((c) => c != autoDetectedCat),
                            ];
                            return sorted;
                          }()
                          .map(
                            (c) => GestureDetector(
                              onTap: () {
                                ss(() => cat = c);
                                final title = titleCtrl.text.trim();
                                if (title.isNotEmpty && c != autoDetectedCat) {
                                  CategoryDetector.learn(title, c);
                                  autoDetectedCat = c;
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
                                margin: const EdgeInsets.only(right: 7),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: cat == c
                                      ? AppColors.primary.withValues(
                                          alpha: 0.12,
                                        )
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
                    onPressed: () async {
                      final amt = double.tryParse(amtCtrl.text.trim());
                      if (amt == null || amt <= 0) return;
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                      final walletId = AppStateScope.of(context).activeWalletId;
                      try {
                        final row = await WalletService.instance.addTransaction(
                          walletId: walletId,
                          type: txType.name,
                          amount: amt,
                          category: cat.isEmpty ? 'Expense' : cat,
                          title: titleCtrl.text.trim().isEmpty
                              ? null
                              : titleCtrl.text.trim(),
                          note: noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim(),
                          payMode:
                              (txType == TxType.expense ||
                                  txType == TxType.income)
                              ? payMode.name
                              : null,
                        );
                        if (!mounted) return;
                        setState(() => _transactions.add(TxModel.fromRow(row)));
                        WalletService.txChangeSignal.value++;
                        WalletService.instance.ensureCategory(cat.isEmpty ? 'Expense' : cat, txType.name);
                      } catch (e) {
                        debugPrint('[Dashboard] quickAdd error: $e');
                      }
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

  // ── Theme picker ─────────────────────────────────────────────────────────────
  void _showThemePicker(BuildContext ctx, bool isDark) {
    final options = [
      (ThemeMode.light, Icons.light_mode_rounded, 'Light'),
      (ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
      (ThemeMode.system, Icons.brightness_auto_rounded, 'System default'),
    ];
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Appearance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 16),
            ...options.map((opt) {
              final (mode, icon, label) = opt;
              final selected = widget.themeMode == mode;
              return GestureDetector(
                onTap: () {
                  widget.onSetTheme?.call(mode);
                  Navigator.pop(ctx);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : (isDark
                              ? AppColors.surfDark
                              : const Color(0xFFEDEEF5)),
                    borderRadius: BorderRadius.circular(14),
                    border: selected
                        ? Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: selected
                            ? AppColors.primary
                            : (isDark ? AppColors.subDark : AppColors.subLight),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: selected
                                ? AppColors.primary
                                : (isDark
                                      ? AppColors.textDark
                                      : AppColors.textLight),
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Preferences tap dispatcher ───────────────────────────────────────────────
  VoidCallback _prefsTap(BuildContext ctx, bool isDark, String title) {
    Widget? sheet;
    switch (title) {
      case 'Theme':
        return () => _showThemePicker(ctx, isDark);
      case 'Notifications':
        sheet = NotificationPrefsSheet(isDark: isDark);
      case 'Privacy & Security':
        sheet = PrivacySecuritySheet(isDark: isDark);
      case 'Language & Voice':
        sheet = LanguageVoiceSheet(isDark: isDark);
      case 'Currency':
        sheet = CurrencySheet(isDark: isDark);
      case 'Date & Time':
        sheet = DateTimePrefsSheet(isDark: isDark);
      case 'Default Scope':
        sheet = DefaultScopeSheet(isDark: isDark);
      case 'AI Parser Settings':
        sheet = AiParserSheet(isDark: isDark);
      case 'Subscription':
        sheet = SubscriptionSheet(isDark: isDark, currentPlan: _userPlan);
      default:
        return () {};
    }
    return () => showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, _) => sheet!,
      ),
    );
  }

  // ── Settings ────────────────────────────────────────────────────────────────
  void _showSettings(BuildContext ctx, bool isDark) {
    // Load fresh profile in the background — don't block opening the sheet.
    _loadProfile();

    final appState = AppStateScope.read(ctx);
    final nameCtrl = TextEditingController(text: _userName);
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    bool profileExpanded = false;
    bool accountExpanded = false;
    bool preferencesExpanded = false;
    final themeLabel = switch (widget.themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };
    final settings = [
      _SettingItem('🎨', const Color(0xFFFFE0E0), 'Theme', themeLabel),
      _SettingItem(
        '🌐',
        const Color(0xFFE0EEFF),
        'Language & Voice',
        'English',
      ),
      _SettingItem('₹', const Color(0xFFE0F0FF), 'Currency', 'INR'),
      _SettingItem('📅', const Color(0xFFE0F8EC), 'Date & Time', 'DD/MM/YYYY'),
      _SettingItem('🏠', const Color(0xFFFFEDD5), 'Default Scope', 'Per tab'),
      _SettingItem(
        '✦',
        const Color(0xFFE8E0FF),
        'AI Parser Settings',
        'Always confirm',
      ),
      _SettingItem('🔔', const Color(0xFFE0F8EC), 'Notifications', 'On'),
      _SettingItem('🔒', const Color(0xFFFFF0E0), 'Privacy & Security', ''),
      _SettingItem('ℹ️', const Color(0xFFF0F0F0), 'About', 'v1.0.0'),
    ];

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, sc) => StatefulBuilder(
          builder: (ctx2, ss) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
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
                // ── Account + Settings ──────────────────────────────
                Expanded(
                  child: ListView(
                    controller: sc,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                    children: [
                      // ── ACCOUNT section ──────────────────────────────────
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            ss(() => accountExpanded = !accountExpanded),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                          child: Row(
                            children: [
                              Text(
                                'ACCOUNT',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  fontFamily: 'Nunito',
                                  color: isDark
                                      ? AppColors.subDark
                                      : AppColors.subLight,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                accountExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: isDark
                                    ? AppColors.subDark
                                    : AppColors.subLight,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (accountExpanded) ...[
                        // Profile (expandable)
                        Container(
                          decoration: BoxDecoration(
                            color: surfBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: const Text(
                                  'Profile',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                  ),
                                ),
                                subtitle: Text(
                                  'Name, photo, phone, date of birth',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'Nunito',
                                    color: isDark
                                        ? AppColors.subDark
                                        : AppColors.subLight,
                                  ),
                                ),
                                trailing: Icon(
                                  profileExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: isDark
                                      ? AppColors.subDark
                                      : AppColors.subLight,
                                ),
                                onTap: () => ss(
                                  () => profileExpanded = !profileExpanded,
                                ),
                              ),
                              if (profileExpanded)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    0,
                                    14,
                                    14,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Divider(
                                        height: 1,
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.black12,
                                      ),
                                      const SizedBox(height: 14),
                                      // Profile photo
                                      GestureDetector(
                                        onTap: () => _pickProfilePhoto(ss),
                                        child: Row(
                                          children: [
                                            Stack(
                                              children: [
                                                Container(
                                                  width: 54,
                                                  height: 54,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withValues(
                                                          alpha: 0.12,
                                                        ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: _userPhotoUrl.isEmpty
                                                      ? Text(
                                                          _initials(_userName),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                color: AppColors
                                                                    .primary,
                                                                fontFamily:
                                                                    'Nunito',
                                                              ),
                                                        )
                                                      : ClipOval(
                                                          child: Image.network(
                                                            _userPhotoUrl,
                                                            width: 54,
                                                            height: 54,
                                                            fit: BoxFit.cover,
                                                          ),
                                                        ),
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  child: Container(
                                                    width: 18,
                                                    height: 18,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color:
                                                              AppColors.primary,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                    child: const Icon(
                                                      Icons.camera_alt_rounded,
                                                      size: 10,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Tap to change photo',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontFamily: 'Nunito',
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Name field
                                      TextField(
                                        controller: nameCtrl,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontFamily: 'Nunito',
                                          color: isDark
                                              ? AppColors.textDark
                                              : AppColors.textLight,
                                        ),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.06,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.04,
                                                ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.person_outline_rounded,
                                            size: 16,
                                          ),
                                          hintText: 'Full name',
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Phone (read-only — used for login)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.06,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.04,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.phone_rounded,
                                              size: 16,
                                              color: isDark
                                                  ? AppColors.subDark
                                                  : AppColors.subLight,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _userPhone.isNotEmpty
                                                        ? _userPhone
                                                        : '—',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontFamily: 'Nunito',
                                                      color: isDark
                                                          ? AppColors.textDark
                                                          : AppColors.textLight,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Used for login',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontFamily: 'Nunito',
                                                      color: isDark
                                                          ? AppColors.subDark
                                                          : AppColors.subLight,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.lock_outline_rounded,
                                              size: 12,
                                              color: isDark
                                                  ? AppColors.subDark
                                                  : AppColors.subLight,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Date of birth (for birthday reminders)
                                      GestureDetector(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: ctx,
                                            initialDate: _userDob.isEmpty
                                                ? DateTime(1995)
                                                : DateTime.tryParse(_userDob) ??
                                                      DateTime(1995),
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime.now(),
                                          );
                                          if (picked != null && mounted) {
                                            final iso =
                                                '${picked.year.toString().padLeft(4, "0")}-'
                                                '${picked.month.toString().padLeft(2, "0")}-'
                                                '${picked.day.toString().padLeft(2, "0")}';
                                            setState(() => _userDob = iso);
                                            ss(() {});
                                            ProfileService.instance
                                                .updateProfile(dob: iso);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.06,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.04,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.cake_rounded,
                                                size: 16,
                                                color: isDark
                                                    ? AppColors.subDark
                                                    : AppColors.subLight,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _userDob.isEmpty
                                                          ? 'Date of birth'
                                                          : _fmtDob(_userDob),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontFamily: 'Nunito',
                                                        color: _userDob.isEmpty
                                                            ? (isDark
                                                                  ? AppColors
                                                                        .subDark
                                                                  : AppColors
                                                                        .subLight)
                                                            : (isDark
                                                                  ? AppColors
                                                                        .textDark
                                                                  : AppColors
                                                                        .textLight),
                                                      ),
                                                    ),
                                                    Text(
                                                      'For birthday reminders',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontFamily: 'Nunito',
                                                        color: isDark
                                                            ? AppColors.subDark
                                                            : AppColors
                                                                  .subLight,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                Icons.edit_calendar_rounded,
                                                size: 14,
                                                color: isDark
                                                    ? AppColors.subDark
                                                    : AppColors.subLight,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      // Save button
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            final name = nameCtrl.text.trim();
                                            if (name.isNotEmpty) {
                                              setState(() => _userName = name);
                                              try {
                                                await ProfileService.instance
                                                    .updateProfile(name: name);
                                              } catch (e) {
                                                debugPrint(
                                                  '[Dashboard] save: $e',
                                                );
                                              }
                                            }
                                            ss(() => profileExpanded = false);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text(
                                            'Save Changes',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              fontFamily: 'Nunito',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Change Phone Number
                        Container(
                          decoration: BoxDecoration(
                            color: surfBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.phone_forwarded_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                            title: const Text(
                              'Change Phone Number',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                              ),
                            ),
                            subtitle: Text(
                              'OTP verification required',
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
                        ),
                        const SizedBox(height: 8),
                        // Delete Account
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.delete_forever_rounded,
                                size: 18,
                                color: Colors.red,
                              ),
                            ),
                            title: const Text(
                              'Delete Account',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: Colors.red,
                              ),
                            ),
                            subtitle: Text(
                              'Permanent — requires OTP confirmation',
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Nunito',
                                color: Colors.red.withValues(alpha: 0.7),
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: Colors.red,
                            ),
                            onTap: () {},
                          ),
                        ),
                      ], // accountExpanded
                      const SizedBox(height: 16),
                      // ── FAMILY section ────────────────────────────────────
                      FamilySettingsSection(appState: appState, isDark: isDark),
                      const SizedBox(height: 16),
                      // ── PREFERENCES section ───────────────────────────────
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => ss(
                          () => preferencesExpanded = !preferencesExpanded,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                          child: Row(
                            children: [
                              Text(
                                'PREFERENCES',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  fontFamily: 'Nunito',
                                  color: isDark
                                      ? AppColors.subDark
                                      : AppColors.subLight,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                preferencesExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: isDark
                                    ? AppColors.subDark
                                    : AppColors.subLight,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (preferencesExpanded)
                        Container(
                          decoration: BoxDecoration(
                            color: surfBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: settings.asMap().entries.map((entry) {
                              final i = entry.key;
                              final s = entry.value;
                              final subColor = isDark
                                  ? AppColors.subDark
                                  : AppColors.subLight;
                              return Column(
                                children: [
                                  if (i > 0)
                                    Divider(
                                      height: 1,
                                      indent: 60,
                                      endIndent: 16,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : Colors.black.withValues(
                                              alpha: 0.06,
                                            ),
                                    ),
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 2,
                                    ),
                                    leading: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: s.iconBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        s.emoji,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    ),
                                    title: Text(
                                      s.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Nunito',
                                        color: isDark
                                            ? AppColors.textDark
                                            : AppColors.textLight,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (s.value.isNotEmpty)
                                          Text(
                                            s.value,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'Nunito',
                                              color: subColor,
                                            ),
                                          ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                          color: subColor,
                                        ),
                                      ],
                                    ),
                                    onTap: _prefsTap(ctx, isDark, s.title),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      // ── Subscription tile (last) ──────────────────────────
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _prefsTap(context, isDark, 'Subscription'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _userPlan == 'Free'
                                  ? const [Color(0xFFD97706), Color(0xFFB45309)]
                                  : _userPlan == 'Family'
                                  ? const [Color(0xFF6C63FF), Color(0xFF3D35CC)]
                                  : const [
                                      Color(0xFFD97706),
                                      Color(0xFFB45309),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _userPlan == 'Free'
                                    ? '⭐'
                                    : _userPlan == 'Family'
                                    ? '👨‍👩‍👧'
                                    : '⭐',
                                style: const TextStyle(fontSize: 26),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'WAI $_userPlan',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        fontFamily: 'Nunito',
                                      ),
                                    ),
                                    Text(
                                      _userPlan == 'Free'
                                          ? 'Upgrade to unlock all features'
                                          : 'Manage your subscription',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70,
                                        fontFamily: 'Nunito',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(40),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _userPlan == 'Free' ? 'UPGRADE' : 'MANAGE',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    fontFamily: 'Nunito',
                                  ),
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
  final String label;
  final WalletModel wallet;
  final bool hidden;
  final List<TxModel> todayTx;
  final double balance;
  final VoidCallback onToggleHide;

  const _MoneyPulseCard({
    required this.label,
    required this.wallet,
    required this.todayTx,
    required this.balance,
    required this.hidden,
    required this.onToggleHide,
  });

  String _fmt(double v) {
    if (hidden) return '••••';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) {
      final s = (v / 1000).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      return '₹${s}k';
    }
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final cashIn = todayTx
        .where((t) => t.payMode == PayMode.cash && t.type.isPositive)
        .fold(0.0, (s, t) => s + t.amount);
    final cashOut = todayTx
        .where(
          (t) =>
              t.payMode == PayMode.cash &&
              (t.type == TxType.expense ||
                  t.type == TxType.lend ||
                  t.type == TxType.split),
        )
        .fold(0.0, (s, t) => s + t.amount);
    final onlineIn = todayTx
        .where((t) => t.payMode == PayMode.online && t.type.isPositive)
        .fold(0.0, (s, t) => s + t.amount);
    final onlineOut = todayTx
        .where(
          (t) =>
              t.payMode == PayMode.online &&
              (t.type == TxType.expense ||
                  t.type == TxType.lend ||
                  t.type == TxType.split),
        )
        .fold(0.0, (s, t) => s + t.amount);

    return Container(
      clipBehavior: Clip.hardEdge,
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
          // Top — label + balance + hide toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fmt(balance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'DM Mono',
                      ),
                    ),
                  ],
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
              ],
            ),
          ),

          // Middle — today's Cash / Online summary
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _TodayPaySection(
                      icon: Icons.payments_rounded,
                      title: 'Cash',
                      inAmt: _fmt(cashIn),
                      outAmt: _fmt(cashOut),
                    ),
                  ),
                  Container(
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.25),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: _TodayPaySection(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Online',
                      inAmt: _fmt(onlineIn),
                      outAmt: _fmt(onlineOut),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom — most recent transaction + "+n more" link
          if (todayTx.isNotEmpty)
            GestureDetector(
              onTap: () => _showTodayTxSheet(context),
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    // Most recent transaction
                    Expanded(
                      child: _buildRecentTxRow(todayTx.first),
                    ),
                    // "+n more" badge
                    if (todayTx.length > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+${todayTx.length - 1} more',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        size: 14, color: Colors.white60),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentTxRow(TxModel tx) {
    final isPositive = tx.type.isPositive;
    final amt = hidden
        ? '••••'
        : isPositive
            ? '+₹${tx.amount.toStringAsFixed(0)}'
            : '-₹${tx.amount.toStringAsFixed(0)}';
    final amtColor = isPositive
        ? const Color(0xFF80FFD0)
        : const Color(0xFFFFB3BE);
    return Row(
      children: [
        Text(tx.type.emoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            tx.title?.isNotEmpty == true ? tx.title! : tx.category,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          amt,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            fontFamily: 'DM Mono',
            color: amtColor,
          ),
        ),
      ],
    );
  }

  void _showTodayTxSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TodayTxSheet(
        label: label,
        transactions: todayTx,
        hidden: hidden,
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
    final prefix = tx.type.isPositive ? '+₹' : '-₹';
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

// ── Today payment section (Cash / Online) ────────────────────────────────────
class _TodayPaySection extends StatelessWidget {
  final IconData icon;
  final String title, inAmt, outAmt;

  const _TodayPaySection({
    required this.icon,
    required this.title,
    required this.inAmt,
    required this.outAmt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 5),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _TodayAmtRow(label: 'In', amount: inAmt, isIn: true),
        const SizedBox(height: 4),
        _TodayAmtRow(label: 'Out', amount: outAmt, isIn: false),
      ],
    );
  }
}

class _TodayAmtRow extends StatelessWidget {
  final String label, amount;
  final bool isIn;

  const _TodayAmtRow({
    required this.label,
    required this.amount,
    required this.isIn,
  });

  @override
  Widget build(BuildContext context) {
    final color = isIn ? Colors.greenAccent : Colors.redAccent[100]!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
            ),
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: 'DM Mono',
          ),
        ),
      ],
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
    final balanceLabel = myBalance >= 0
        ? '+₹${myBalance.abs().toStringAsFixed(0)} owed to you'
        : '₹${myBalance.abs().toStringAsFixed(0)} you owe';

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
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: all.map((f) {
          final daysLeft = f.date?.difference(DateTime.now()).inDays;
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
  const _PlanNudge({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.urgency,
    required this.color,
    required this.tag,
    required this.walletLabel,
  });
}

// ── FAB tabbed sheet ──────────────────────────────────────────────────────────

class _DashFabSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final void Function(TxModel tx) onAiSave;
  final void Function(TxModel tx) onQuickSave;
  final bool startPasteSms;

  const _DashFabSheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    required this.onAiSave,
    required this.onQuickSave,
    this.startPasteSms = false,
  });

  @override
  State<_DashFabSheet> createState() => _DashFabSheetState();
}

class _DashFabSheetState extends State<_DashFabSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    final mq          = MediaQuery.of(context);
    final keyboardH   = mq.viewInsets.bottom;
    final safeH       = mq.size.height - mq.padding.top - mq.padding.bottom;
    // Overhead: top padding(12) + handle(4) + spacing(8) + tab bar(~48) + breathing room(8)
    const sheetOverhead = 80.0;
    final tabsH = (safeH - keyboardH - sheetOverhead).clamp(200.0, 380.0);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardH),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Tab bar
            TabBar(
              controller: _tabCtrl,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Nunito',
              ),
              labelColor: AppColors.primary,
              unselectedLabelColor: sub,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: '✨  AI Parse'),
                Tab(text: '⚡  Quick Add'),
              ],
            ),
            // Tab content — height shrinks when keyboard is visible
            SizedBox(
              height: tabsH,
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── AI Parse tab ──────────────────────────────────────
                  SparkBottomSheet(
                    embedded: true,
                    walletId: widget.walletId,
                    onSave: (tx) {
                      Navigator.pop(context);
                      widget.onAiSave(tx);
                    },
                    onOpenFlow: () => Navigator.pop(context),
                  ),
                  // ── Quick Add tab ─────────────────────────────────────
                  _QuickAddTab(
                    isDark: isDark,
                    surfBg: widget.surfBg,
                    walletId: widget.walletId,
                    onSaved: (tx) {
                      Navigator.pop(context);
                      widget.onQuickSave(tx);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Add tab content ─────────────────────────────────────────────────────

class _QuickAddTab extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final void Function(TxModel tx) onSaved;

  const _QuickAddTab({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    required this.onSaved,
  });

  @override
  State<_QuickAddTab> createState() => _QuickAddTabState();
}

class _QuickAddTabState extends State<_QuickAddTab> {
  final _amtCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  TxType _txType = TxType.expense;
  PayMode _payMode = PayMode.online;
  String _cat = '';
  String _autoDetectedCat = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    CategoryDetector.ensureLoaded();
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amtCtrl.text.trim());
    if (amt == null || amt <= 0) return;
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      final row = await WalletService.instance.addTransaction(
        walletId: widget.walletId,
        type: _txType.name,
        amount: amt,
        category: _cat.isEmpty ? 'Expense' : _cat,
        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        payMode: (_txType == TxType.expense || _txType == TxType.income)
            ? _payMode.name
            : null,
      );
      if (!mounted) return;
      widget.onSaved(TxModel.fromRow(row));
    } catch (e) {
      debugPrint('[Dashboard] quickAdd error: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surfBg = widget.surfBg;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type selector
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [TxType.expense, TxType.income, TxType.lend, TxType.borrow]
                  .map((t) => GestureDetector(
                        onTap: () => setState(() => _txType = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _txType == t
                                ? t.color.withValues(alpha: 0.15)
                                : surfBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _txType == t
                                  ? t.color
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(t.emoji,
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 5),
                              Text(
                                t.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                  color: _txType == t ? t.color : sub,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Amount input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    color: _txType.color,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _amtCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: false,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'DM Mono',
                      color: _txType.color,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: _txType.color.withValues(alpha: 0.3),
                        fontFamily: 'DM Mono',
                      ),
                    ),
                  ),
                ),
                if (_txType == TxType.expense || _txType == TxType.income)
                  GestureDetector(
                    onTap: () => setState(() => _payMode =
                        _payMode == PayMode.cash
                            ? PayMode.online
                            : PayMode.cash),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _payMode == PayMode.cash
                            ? AppColors.cash.withValues(alpha: 0.12)
                            : AppColors.online.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _payMode == PayMode.cash ? '💵 Cash' : '📲 Online',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: _payMode == PayMode.cash
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

          // Title
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _titleCtrl,
              style: TextStyle(
                  fontSize: 13, fontFamily: 'Nunito', color: tc),
              onChanged: (val) {
                final detected = CategoryDetector.detect(val,
                    isIncome: _txType == TxType.income);
                if (detected != null) {
                  setState(() {
                    _cat = detected;
                    _autoDetectedCat = detected;
                  });
                }
              },
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Title',
                prefixIcon:
                    Icon(Icons.label_outline_rounded, size: 16),
                prefixIconConstraints:
                    BoxConstraints(minWidth: 28, minHeight: 0),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Note
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _noteCtrl,
              style: TextStyle(
                  fontSize: 13, fontFamily: 'Nunito', color: tc),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Add a note?',
                prefixIcon: Icon(Icons.notes_rounded, size: 16),
                prefixIconConstraints:
                    BoxConstraints(minWidth: 28, minHeight: 0),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category chips
          if (_txType == TxType.expense || _txType == TxType.income)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: () {
                  final all = WalletService.instance.categoriesFor(
                      _txType == TxType.income ? 'income' : 'expense');
                  return [
                    if (_autoDetectedCat.isNotEmpty &&
                        all.contains(_autoDetectedCat))
                      _autoDetectedCat,
                    ...all.where((c) => c != _autoDetectedCat),
                  ];
                }()
                    .map((c) => GestureDetector(
                          onTap: () {
                            setState(() => _cat = c);
                            final title = _titleCtrl.text.trim();
                            if (title.isNotEmpty && c != _autoDetectedCat) {
                              CategoryDetector.learn(title, c);
                              setState(() => _autoDetectedCat = c);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            margin: const EdgeInsets.only(right: 7),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _cat == c
                                  ? AppColors.primary
                                      .withValues(alpha: 0.12)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _cat == c
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
                                color: _cat == c ? AppColors.primary : sub,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),

          const SizedBox(height: 16),

          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _txType.color,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Save ${_txType.label}',
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
    );
  }
}

class _SettingItem {
  final String emoji;
  final Color iconBg;
  final String title;
  final String value;
  const _SettingItem(this.emoji, this.iconBg, this.title, this.value);
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
