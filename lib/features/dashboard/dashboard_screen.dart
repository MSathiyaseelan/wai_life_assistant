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
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/features/AppStateNotifier.dart';
import 'package:wai_life_assistant/data/models/wallet/split_group_models.dart';
import 'package:wai_life_assistant/features/wallet/splits/split_group_detail_screen.dart';
import 'package:wai_life_assistant/features/wallet/services/sms_parser_service.dart';
import 'package:wai_life_assistant/features/wallet/ai/IntentConfirmSheet.dart';
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
import 'package:wai_life_assistant/features/dashboard/widgets/about_wai_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/report_issue_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/privacy_security_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/recycle_bin_sheet.dart';
import 'package:wai_life_assistant/routes/app_routes.dart';
import 'package:wai_life_assistant/shared/widgets/emoji_or_image.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/language_voice_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/currency_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/date_time_prefs_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/default_scope_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/ai_parser_sheet.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/subscription_sheet.dart';
import 'package:wai_life_assistant/core/services/shortcut_service.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/ai_assistant_widget.dart';
import 'package:wai_life_assistant/data/services/health_service.dart';
import 'package:wai_life_assistant/core/services/dash_nav_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/features/dashboard/widgets/my_list_section.dart';

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

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  String _userName = '';
  String _userPhone = '';
  String _userDob = '';
  String _userPlan = 'personal_free';
  String _userPhotoUrl = '';
  bool _balanceHidden = true;
  // Today's meals — merged list from all loaded wallets
  List<MealEntry> _todayMeals = [];
  final Set<String> _loadedMealWalletIds = {};

  // Page controller for swipeable plate cards
  final PageController _pulsePageController = PageController();
  late final PageController _platePageController;

  // Transactions — merged list from all loaded wallets
  List<TxModel> _transactions = [];
  final Set<String> _loadedWalletIds = {};

  // Page controller for swipeable shopping list cards
  late final PageController _listPageController;

  // PlanIt data — merged from all loaded wallets, keyed by walletId
  final Map<String, List<ReminderModel>> _remindersMap = {};
  final Map<String, List<TaskModel>> _tasksMap = {};
  final Map<String, List<SpecialDayModel>> _specialDaysMap = {};
  final Map<String, List<WishModel>> _wishesMap = {};
  final Map<String, List<FunctionModel>> _functionsMap = {};
  final Map<String, List<UpcomingFunction>> _upcomingAttendingMap = {};
  final Set<String> _loadedPlanItWalletIds = {};

  // Health nudge data — keyed by walletId
  final Map<String, List<Map<String, dynamic>>> _healthApptsMap = {};
  final Map<String, List<Map<String, dynamic>>> _healthMedsMap = {};
  final Map<String, List<Map<String, dynamic>>> _healthVaccsMap = {};
  final Set<String> _loadedHealthWalletIds = {};

  // My List — merged to-buy items (grocery + quick-list) keyed by walletId
  final Map<String, List<GroceryItem>> _myListMap = {};
  final Set<String> _loadedMyListWalletIds = {};

  List<TxModel> _todayTx(String wid) => _transactions
      .where((t) => t.walletId == wid && _isToday(t.date))
      .toList();

  bool _wasOnline = true;
  int _unreadNotifCount = 0;

  void _onNetworkChange() {
    final online = NetworkService.instance.isOnline.value;
    if (online && !_wasOnline) _refresh();
    _wasOnline = online;
  }

  @override
  void initState() {
    super.initState();
    _platePageController = PageController();
    _listPageController = PageController();
    _wasOnline = NetworkService.instance.isOnline.value;
    WidgetsBinding.instance.addObserver(this);
    NetworkService.instance.isOnline.addListener(_onNetworkChange);
    PantryService.mealChangeSignal.addListener(_onMealChange);
    PantryService.listChangeSignal.addListener(_onListChange);
    WalletService.txChangeSignal.addListener(_onTxChange);
    HealthService.changeSignal.addListener(_onHealthChange);
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pasteSmsShortcut(AppStateScope.of(context).activeWalletId);
      });
    }
  }

  Future<void> _pasteSmsShortcut(String walletId) async {
    final clip = await Clipboard.getData('text/plain');
    final text = clip?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Clipboard is empty — copy your bank SMS first.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final parsed = await SMSParserService.parseSMSText(text);
    if (!mounted) return;
    if (parsed == null || !parsed.isTransaction) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not read a transaction from the clipboard text.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    await IntentConfirmSheet.show(
      context,
      intent: parsed.toParsedIntent(),
      walletId: walletId,
      onSave: (tx) {
        setState(() => _transactions.insert(0, tx));
        WalletService.txChangeSignal.value++;
        WalletService.instance.ensureCategory(tx.category, tx.type.name)
            .catchError((e) => ErrorLogger.warning(e, action: 'ensure_category'));
      },
      onOpenFlow: () {},
    );
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
          _userPlan = (profile['plan'] as String?) ?? 'personal_free';
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
    } catch (e, stack) {
      debugPrint('[Dashboard] _loadProfile error: $e');
      ErrorLogger.log(e, stackTrace: stack, action: 'load_profile');
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
    } catch (e, stack) {
      debugPrint('[Dashboard] photo upload error: $e');
      ErrorLogger.log(e, stackTrace: stack, action: 'upload_profile_photo');
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

  void _ensureHealthLoaded(List<WalletModel> wallets) {
    for (final w in wallets) {
      if (_isPlaceholder(w.id) || _loadedHealthWalletIds.contains(w.id)) continue;
      _loadedHealthWalletIds.add(w.id);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadHealthData(w.id),
      );
    }
  }

  void _ensureMyListLoaded(List<WalletModel> wallets) {
    for (final w in wallets) {
      if (_isPlaceholder(w.id) || _loadedMyListWalletIds.contains(w.id)) continue;
      _loadedMyListWalletIds.add(w.id);
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMyList(w.id));
    }
  }

  Future<void> _loadMyList(String walletId) async {
    if (!AuthCoordinator.instance.isLoggedIn || _isPlaceholder(walletId)) return;
    _loadedMyListWalletIds.add(walletId);
    try {
      final rows = await PantryService.instance.fetchToBuyItems(walletId);
      if (!mounted) return;
      setState(() {
        _myListMap[walletId] = rows.map(GroceryItem.fromMap).toList();
      });
    } catch (e, stack) {
      debugPrint('[Dashboard] _loadMyList error: $e');
      ErrorLogger.log(e, stackTrace: stack, action: 'load_my_list');
    }
  }

  Future<void> _refresh() async {
    final txToReload = List<String>.from(_loadedWalletIds);
    final mealToReload = List<String>.from(_loadedMealWalletIds);
    final planItToReload = List<String>.from(_loadedPlanItWalletIds);
    final healthToReload = List<String>.from(_loadedHealthWalletIds);
    final listToReload   = List<String>.from(_loadedMyListWalletIds);
    _loadedWalletIds.clear();
    _loadedMealWalletIds.clear();
    _loadedPlanItWalletIds.clear();
    _loadedHealthWalletIds.clear();
    _loadedMyListWalletIds.clear();
    await Future.wait([
      _loadPinnedGroups(),
      ...txToReload.map(_loadTransactions),
      ...mealToReload.map(_loadTodayMeals),
      ...planItToReload.map(_loadPlanItData),
      ...healthToReload.map(_loadHealthData),
      ...listToReload.map(_loadMyList),
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
    } catch (e, stack) {
      debugPrint('[Dashboard] fetchTransactions error: $e');
      ErrorLogger.log(e, stackTrace: stack, action: 'fetch_transactions');
    }
  }

  Future<void> _loadPinnedGroups() async {
    if (!AuthCoordinator.instance.isLoggedIn) return;
    try {
      final groups = await WalletService.instance.fetchPinnedSplitGroups();
      pinnedSplitGroupsNotifier.value = groups;
    } catch (e, stack) {
      debugPrint('[Dashboard] fetchPinnedSplitGroups failed: $e');
      ErrorLogger.log(e, stackTrace: stack, action: 'fetch_pinned_split_groups');
    }
  }

  @override
  void dispose() {
    _pulsePageController.dispose();
    _platePageController.dispose();
    _listPageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    NetworkService.instance.isOnline.removeListener(_onNetworkChange);
    PantryService.mealChangeSignal.removeListener(_onMealChange);
    PantryService.listChangeSignal.removeListener(_onListChange);
    WalletService.txChangeSignal.removeListener(_onTxChange);
    HealthService.changeSignal.removeListener(_onHealthChange);
    pinnedSplitGroupsNotifier.removeListener(_onSplitGroupsChanged);
    NotificationService.changeSignal.removeListener(_onNotifChange);
    NotificationService.instance.unsubscribe();
    ShortcutService.pending.removeListener(_onShortcut);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onHealthChange();
  }

  void _onMealChange() {
    for (final wid in List<String>.from(_loadedMealWalletIds)) {
      _loadTodayMeals(wid);
    }
  }

  void _onListChange() {
    for (final wid in List<String>.from(_loadedMyListWalletIds)) {
      _loadMyList(wid);
    }
  }

  void _onTxChange() {
    for (final wid in List<String>.from(_loadedWalletIds)) {
      _loadTransactions(wid);
    }
  }

  void _onHealthChange() {
    final wids = List<String>.from(_loadedHealthWalletIds);
    _loadedHealthWalletIds.clear();
    for (final wid in wids) {
      _loadHealthData(wid);
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
        FunctionsService.instance.fetchUpcoming(walletId),
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
        _upcomingAttendingMap[walletId] = results[5]
            .map(UpcomingFunction.fromJson)
            .toList();
      });
    } catch (e, stack) {
      debugPrint('[Dashboard] _loadPlanItData error: $e');
      ErrorLogger.log(e, stackTrace: stack, action: 'load_planit_data');
    }
  }

  Future<void> _loadHealthData(String walletId) async {
    if (_isPlaceholder(walletId)) return;
    _loadedHealthWalletIds.add(walletId);
    try {
      final results = await Future.wait([
        HealthService.instance.fetchAppointments(walletId),
        HealthService.instance.fetchMedications(walletId),
        HealthService.instance.fetchVaccinations(walletId),
      ]);
      if (!mounted) return;
      setState(() {
        _healthApptsMap[walletId] = List<Map<String, dynamic>>.from(results[0] as List);
        _healthMedsMap[walletId] = List<Map<String, dynamic>>.from(results[1] as List);
        _healthVaccsMap[walletId] = List<Map<String, dynamic>>.from(results[2] as List);
      });
    } catch (e, stack) {
      debugPrint('[Dashboard] _loadHealthData error: $e');
      ErrorLogger.log(e, stackTrace: stack, action: 'load_health_data');
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
    } catch (e) {
      ErrorLogger.warning(e, action: 'load_today_meals');
    }
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
        } catch (e) {
          ErrorLogger.warning(e, action: 'meal_add_reaction');
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
        } catch (e) {
          ErrorLogger.warning(e, action: 'meal_update_reaction');
        }
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
        } catch (e) {
          ErrorLogger.warning(e, action: 'meal_delete_reaction');
        }
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
              onTap: () { DashNavService.planIt.value = 'alerts'; widget.onTabSwitch?.call(4); },
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
              onTap: () { DashNavService.planIt.value = 'tasks'; widget.onTabSwitch?.call(4); },
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
              onTap: () { DashNavService.planIt.value = 'special_days'; widget.onTabSwitch?.call(4); },
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
              onTap: () { DashNavService.planIt.value = 'wishes'; widget.onTabSwitch?.call(4); },
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
              onTap: () { DashNavService.myHub.value = 'functions'; widget.onTabSwitch?.call(3); },
            ),
          );
        }
      }
    }

    // ── Health nudges ─────────────────────────────────────────────────────────

    // Upcoming appointments within 7 days
    for (final entry in _healthApptsMap.entries) {
      final wLabel = _walletLabel(entry.key);
      for (final appt in entry.value) {
        final raw = appt['appt_date'] as String?;
        if (raw == null) continue;
        final apptDate = DateTime.tryParse(raw);
        if (apptDate == null) continue;
        final apptDay = DateTime(apptDate.year, apptDate.month, apptDate.day);
        final daysLeft = apptDay.difference(today).inDays;
        if (daysLeft >= 0 && daysLeft <= 7) {
          final doctor = appt['doctor_name'] as String? ?? 'Doctor';
          list.add(_PlanNudge(
            emoji: '🏥',
            title: 'Appointment: $doctor',
            subtitle: daysLeft == 0 ? 'Today' : 'In ${daysLeft}d',
            urgency: daysLeft == 0 ? 3 : daysLeft <= 2 ? 2 : 1,
            color: const Color(0xFF00BFA5),
            tag: 'Appointment',
            walletLabel: wLabel,
            onTap: () { DashNavService.myHub.value = 'health:appointments'; widget.onTabSwitch?.call(3); },
          ));
        }
      }
    }

    // Active medications within their course window
    for (final entry in _healthMedsMap.entries) {
      final wLabel = _walletLabel(entry.key);
      final activeMeds = entry.value.where((m) {
        if (m['is_active'] != true) return false;
        final rawEnd = m['end_date'] as String?;
        if (rawEnd == null) return true;
        final endDate = DateTime.tryParse(rawEnd);
        if (endDate == null) return true;
        final endDay = DateTime(endDate.year, endDate.month, endDate.day);
        return !endDay.isBefore(today);
      }).toList();
      if (activeMeds.isNotEmpty) {
        list.add(_PlanNudge(
          emoji: '💊',
          title: '${activeMeds.length} active medication${activeMeds.length == 1 ? '' : 's'} today',
          subtitle: activeMeds.map((m) => m['name'] as String? ?? '').where((n) => n.isNotEmpty).take(2).join(', '),
          urgency: 1,
          color: const Color(0xFF00BFA5),
          tag: 'Medicine',
          walletLabel: wLabel,
          onTap: () { DashNavService.myHub.value = 'health:meds'; widget.onTabSwitch?.call(3); },
        ));
      }
    }

    // Overdue or due-soon vaccinations
    for (final entry in _healthVaccsMap.entries) {
      final wLabel = _walletLabel(entry.key);
      for (final vacc in entry.value) {
        final rawDue = vacc['next_due'] as String?;
        if (rawDue == null) continue;
        final dueDate = DateTime.tryParse(rawDue);
        if (dueDate == null) continue;
        final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
        final daysLeft = dueDay.difference(today).inDays;
        if (daysLeft <= 30) {
          final name = vacc['vaccine_name'] as String? ?? 'Vaccine';
          final isOverdue = daysLeft < 0;
          list.add(_PlanNudge(
            emoji: '💉',
            title: '$name due',
            subtitle: isOverdue ? 'Overdue by ${daysLeft.abs()}d' : daysLeft == 0 ? 'Due today' : 'Due in ${daysLeft}d',
            urgency: isOverdue || daysLeft == 0 ? 3 : daysLeft <= 7 ? 2 : 1,
            color: isOverdue ? Colors.red : daysLeft <= 7 ? Colors.orange : const Color(0xFF00BFA5),
            tag: 'Vaccine',
            walletLabel: wLabel,
            onTap: () { DashNavService.myHub.value = 'health:vaccines'; widget.onTabSwitch?.call(3); },
          ));
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

  List<UpcomingFunction> get _upcomingAttending {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(const Duration(days: 7));
    return _upcomingAttendingMap.values
        .expand((l) => l)
        .where((u) {
          if (u.date == null) return false;
          final d = DateTime(u.date!.year, u.date!.month, u.date!.day);
          return !d.isBefore(today) && !d.isAfter(end);
        })
        .toList();
  }

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
    _ensureHealthLoaded(appState.wallets);
    _ensureMyListLoaded(appState.wallets);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Scaffold(
      backgroundColor: bg,
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
                        onTransactionSaved: (tx) {
                          setState(() => _transactions.insert(0, tx));
                          WalletService.txChangeSignal.value++;
                          WalletService.instance.ensureCategory(tx.category, tx.type.name)
                              .catchError((e) => ErrorLogger.warning(e, action: 'ensure_category'));
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Needs Attention ───────────────────────────────────────
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

                      // ── Upcoming Functions ────────────────────────────────────
                      if (_upcomingFunctions.isNotEmpty || _upcomingAttending.isNotEmpty) ...[
                        _SectionHeader(
                          emoji: '🎊',
                          title: 'Upcoming Functions',
                          sub: sub,
                          action: 'Functions →',
                          onAction: () { DashNavService.myHub.value = 'functions'; widget.onTabSwitch?.call(3); },
                        ),
                        const SizedBox(height: 8),
                        _UpcomingFunctionsCard(
                          myFunctions: _upcomingFunctions,
                          attending: _upcomingAttending,
                          isDark: isDark,
                          cardBg: cardBg,
                          onTap: () {
                            DashNavService.myHub.value = 'functions';
                            widget.onTabSwitch?.call(3);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ①  TODAY ───────────────────────────────────────────────
                      _SectionHeader(
                        emoji: '💳',
                        title: 'Today',
                        sub: sub,
                        action: 'Wallet →',
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
                          final allWallets = [personalW, ...familyWs];

                          String labelFor(WalletModel w) => w.isPersonal
                              ? 'Personal'
                              : (appState.families
                                        .where((f) => f.walletId == w.id)
                                        .firstOrNull
                                        ?.name ??
                                    w.name);

                          // Compact height when all wallets have no transactions today
                          final hasAnyTx = allWallets.any((w) => _todayTx(w.id).isNotEmpty);
                          final cardH = hasAnyTx ? 290.0 : 118.0;

                          return Column(
                            children: [
                              SizedBox(
                                height: cardH,
                                child: PageView.builder(
                                controller: _pulsePageController,
                                itemCount: allWallets.length,
                                physics: allWallets.length > 1
                                    ? const PageScrollPhysics()
                                    : const NeverScrollableScrollPhysics(),
                                onPageChanged: (idx) => AppStateScope.read(
                                  context,
                                ).switchWallet(allWallets[idx].id),
                                itemBuilder: (ctx, idx) {
                                  final w = allWallets[idx];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: idx < allWallets.length - 1
                                          ? 8.0
                                          : 0,
                                    ),
                                    child: _SpendingPulseCard(
                                      walletLabel: labelFor(w),
                                      txToday: _todayTx(w.id),
                                      hidden: _balanceHidden,
                                      onToggleHide: () => setState(
                                        () => _balanceHidden = !_balanceHidden,
                                      ),
                                      isDark: isDark,
                                      cardBg: cardBg,
                                      tc: tc,
                                      sub: sub,
                                    ),
                                  );
                                },
                              ),
                            ),
                              if (allWallets.length > 1) ...[
                                const SizedBox(height: 8),
                                AnimatedBuilder(
                                  animation: _pulsePageController,
                                  builder: (ctx, _) {
                                    final page = _pulsePageController.hasClients
                                        ? (_pulsePageController.page ?? 0)
                                              .round()
                                        : 0;
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        allWallets.length,
                                        (i) {
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
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                          );
                                        },
                                      ),
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
                        onAction: () {
                          DashNavService.pantry.value = 'meal_map';
                          widget.onTabSwitch?.call(2);
                        },
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
                                      child: GestureDetector(
                                        onTap: () {
                                          DashNavService.pantry.value = 'meal_map:${w.id}';
                                          widget.onTabSwitch?.call(2);
                                        },
                                        child: _TodaysPlateCard(
                                          label: label,
                                          meals: meals,
                                          isDark: isDark,
                                          cardBg: cardBg,
                                          onMealTap: _showMealDetail,
                                        ),
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

                      // ④  SHOPPING LIST ────────────────────────────────────────
                      Builder(builder: (ctx) {
                        final personalW = appState.wallets.firstWhere(
                          (w) => w.isPersonal,
                          orElse: () => personalWallet,
                        );
                        final familyWs = appState.wallets
                            .where((w) => !w.isPersonal)
                            .toList();
                        final allCards = [personalW, ...familyWs];

                        // header(38) + subheader(43) + row(42) + addBtn(49) + empty(88)
                        double listCardHeight(String wid) {
                          final its = _myListMap[wid] ?? [];
                          final g = its.where((i) => i.isGrocery).length;
                          final q = its.where((i) => !i.isGrocery).length;
                          if (g == 0 && q == 0) return 38 + 88 + 49;
                          double h = 38; // section header
                          if (g > 0) {
                            h += 43 + g.clamp(0, 3) * 42;
                            if (g > 3) h += 25;
                          }
                          if (q > 0) {
                            if (g > 0) h += 1;
                            h += 43 + q * 42;
                          }
                          return h + 49; // add button
                        }

                        final listH = allCards
                            .map((w) => listCardHeight(w.id))
                            .fold<double>(0, (a, b) => a > b ? a : b)
                            .clamp(156.0, 600.0);

                        return Column(
                          children: [
                            SizedBox(
                              height: listH,
                              child: PageView.builder(
                                controller: _listPageController,
                                itemCount: allCards.length,
                                physics: allCards.length > 1
                                    ? const PageScrollPhysics()
                                    : const NeverScrollableScrollPhysics(),
                                itemBuilder: (ctx, idx) {
                                  final w = allCards[idx];
                                  final allItems = _myListMap[w.id] ?? [];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: idx < allCards.length - 1 ? 8.0 : 0,
                                    ),
                                    child: MyListSection(
                                      items: allItems,
                                      walletId: w.id,
                                      isDark: isDark,
                                      cardBg: cardBg,
                                      sub: sub,
                                      isPersonal: w.isPersonal,
                                      onItemsChanged: () => _loadMyList(w.id),
                                      onGoToPantry: () {
                                        DashNavService.pantry.value = 'basket:tobuy:${w.id}';
                                        widget.onTabSwitch?.call(2);
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (allCards.length > 1) ...[
                              const SizedBox(height: 8),
                              AnimatedBuilder(
                                animation: _listPageController,
                                builder: (ctx, _) {
                                  final page = _listPageController.hasClients
                                      ? (_listPageController.page ?? 0).round()
                                      : 0;
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(allCards.length, (i) {
                                      final active = page == i;
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.symmetric(horizontal: 3),
                                        width: active ? 16 : 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: active
                                              ? AppColors.primary
                                              : sub.withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      );
                                    }),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        );
                      }),

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
                        AppPrefs.cs,
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
                        WalletService.instance.ensureCategory(cat.isEmpty ? 'Expense' : cat, txType.name)
                            .catchError((e) => ErrorLogger.warning(e, action: 'ensure_category'));
                      } catch (e, stack) {
                        debugPrint('[Dashboard] quickAdd error: $e');
                        ErrorLogger.log(e, stackTrace: stack, action: 'quick_add_transaction');
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
      case 'Recycle Bin':
        sheet = RecycleBinSheet(isDark: isDark);
      case 'Privacy & Security':
        sheet = PrivacySecuritySheet(isDark: isDark);
      case 'Language & Voice':
        sheet = LanguageVoiceSheet(isDark: isDark);
      case 'Currency':
        sheet = CurrencySheet(isDark: isDark);
      case 'Date & Time':
        sheet = DateTimePrefsSheet(isDark: isDark);
      case 'Default Scope':
        sheet = DefaultScopeSheet(isDark: isDark, hasFamily: AppStateScope.of(ctx).families.isNotEmpty);
      case 'AI Parser Settings':
        sheet = AiParserSheet(isDark: isDark);
      case 'Subscription':
        sheet = SubscriptionSheet(isDark: isDark, currentPlan: _userPlan);
      case 'About':
        sheet = AboutWaiSheet(isDark: isDark);
      case 'Report Issue':
        sheet = ReportIssueSheet(isDark: isDark);
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
  Future<void> _confirmLogout(BuildContext sheetCtx, {required bool allDevices}) async {
    final confirmed = await showDialog<bool>(
      context: sheetCtx,
      builder: (dCtx) => AlertDialog(
        title: Text(allDevices ? 'Logout from all devices?' : 'Logout?'),
        content: Text(allDevices
            ? 'This will sign you out on all devices. You will need to verify your phone number again to log back in.'
            : 'You will be signed out of this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await AuthCoordinator.instance.signOut(allDevices: allDevices);
    } catch (e) {
      debugPrint('[Dashboard] signOut error: $e');
    }

    // Use root navigator to clear entire stack (including the settings sheet)
    // and land on the login screen.
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext sheetCtx) async {
    final ctrl = TextEditingController();
    bool confirmed = false;

    final rootNav   = Navigator.of(sheetCtx, rootNavigator: true);
    final localNav  = Navigator.of(sheetCtx);
    final messenger = ScaffoldMessenger.of(sheetCtx);

    await showDialog<void>(
      context: sheetCtx,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Account',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently erase all your data — wallets, expenses, notes, pantry, reminders, and more.\n\nThis cannot be undone.',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text('Type DELETE to confirm:',
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(fontFamily: 'Nunito'),
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                onChanged: (_) => ss(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel',
                  style: TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
            ),
            TextButton(
              onPressed: ctrl.text.trim().toUpperCase() == 'DELETE'
                  ? () {
                      confirmed = true;
                      Navigator.pop(dCtx);
                    }
                  : null,
              child: const Text('Delete Forever',
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (!confirmed) return;

    showDialog(
      context: sheetCtx,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await Supabase.instance.client.functions.invoke('delete-account');
      await AuthCoordinator.instance.signOut(allDevices: true);
      rootNav.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    } catch (e, s) {
      ErrorLogger.log(e, stackTrace: s, action: 'delete_account');
      localNav.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Failed to delete account. Please try again.\n$e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ));
    }
  }

  void _showSettings(BuildContext ctx, bool isDark) {
    // Load fresh profile in the background — don't block opening the sheet.
    _loadProfile();

    final appState = AppStateScope.read(ctx);
    final nameCtrl = TextEditingController(text: _userName);
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    bool profileExpanded = false;
    bool appearanceExpanded = false;
    bool featuresExpanded = false;
    bool privacyExpanded = false;
    bool dangerExpanded = false;
    final themeLabel = switch (widget.themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };

    final tc  = isDark ? AppColors.textDark  : AppColors.textLight;
    final sub = isDark ? AppColors.subDark   : AppColors.subLight;

    // Section label (static)
    Widget sLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
          letterSpacing: 1.1, fontFamily: 'Nunito', color: sub),
      ),
    );

    // Collapsible section label with chevron
    Widget sToggleLabel(String text, bool expanded, VoidCallback onToggle) =>
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Text(text,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                    letterSpacing: 1.1, fontFamily: 'Nunito', color: sub)),
                const Spacer(),
                Icon(
                  expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18, color: sub),
              ],
            ),
          ),
        );

    // A single row inside a settings card
    Widget sRow({
      required String emoji,
      required Color bg,
      required String title,
      String subtitle = '',
      String value = '',
      required VoidCallback? onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito', color: tc)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(subtitle, style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: sub)),
                    ],
                  ],
                ),
              ),
              if (value.isNotEmpty) ...[
                Text(value, style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub)),
                const SizedBox(width: 4),
              ],
              Icon(Icons.chevron_right_rounded, size: 18, color: sub),
            ],
          ),
        ),
      );
    }

    // A card containing multiple sRows with dividers between them
    Widget sCard(List<Widget> rows) => Container(
      decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: rows.asMap().entries.expand((e) {
          final widgets = <Widget>[e.value];
          if (e.key < rows.length - 1) {
            widgets.add(Divider(height: 1, indent: 64, endIndent: 0,
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)));
          }
          return widgets;
        }).toList(),
      ),
    );

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
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      16, 8, 16,
                      36 + MediaQuery.of(ctx2).viewInsets.bottom,
                    ),
                    children: [
                      // ── PROFILE CARD ──────────────────────────────────────
                      sLabel('PROFILE'),
                      Container(
                        decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(18)),
                        clipBehavior: Clip.hardEdge,
                        child: Column(
                          children: [
                            // Always-visible profile header — tap to expand edit
                            InkWell(
                              onTap: () => ss(() => profileExpanded = !profileExpanded),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _pickProfilePhoto(ss),
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: 56, height: 56,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: _userPhotoUrl.isEmpty
                                              ? Text(_initials(_userName),
                                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                                                    color: AppColors.primary, fontFamily: 'Nunito'))
                                              : ClipOval(child: Image.network(_userPhotoUrl,
                                                  width: 56, height: 56, fit: BoxFit.cover)),
                                          ),
                                          Positioned(
                                            bottom: 0, right: 0,
                                            child: Container(
                                              width: 20, height: 20,
                                              decoration: const BoxDecoration(
                                                color: AppColors.primary, shape: BoxShape.circle),
                                              child: const Icon(Icons.camera_alt_rounded,
                                                size: 11, color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _userName.isEmpty ? 'Set your name' : _userName,
                                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                                              fontFamily: 'Nunito', color: tc),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(children: [
                                            Icon(Icons.phone_rounded, size: 11, color: sub),
                                            const SizedBox(width: 4),
                                            Text(_userPhone.isEmpty ? 'No phone' : _userPhone,
                                              style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                                          ]),
                                        ],
                                      ),
                                    ),
                                    // Plan badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _userPlan == 'family_pro'   ? 'Family Pro'  :
                                        _userPlan == 'family_plus'  ? 'Family+'     : 'Personal',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                                          fontFamily: 'Nunito', color: AppColors.primary)),
                                    ),
                                    const SizedBox(width: 8),
                                    AnimatedRotation(
                                      duration: const Duration(milliseconds: 200),
                                      turns: profileExpanded ? 0.5 : 0,
                                      child: Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: sub),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Expandable edit section
                            if (profileExpanded) ...[
                              Divider(height: 1,
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                                  color: AppColors.primary.withValues(alpha: 0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                alignment: Alignment.center,
                                                child: _userPhotoUrl.isEmpty
                                                    ? Text(
                                                        _initials(_userName),
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.w900,
                                                          color: AppColors.primary,
                                                          fontFamily: 'Nunito',
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
                                                  decoration: const BoxDecoration(
                                                    color: AppColors.primary,
                                                    shape: BoxShape.circle,
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
                                            ? Colors.white.withValues(alpha: 0.06)
                                            : Colors.black.withValues(alpha: 0.04),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.person_outline_rounded,
                                          size: 16,
                                        ),
                                        hintText: 'Full name',
                                        contentPadding: const EdgeInsets.symmetric(
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
                                            ? Colors.white.withValues(alpha: 0.06)
                                            : Colors.black.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(10),
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
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _userPhone.isNotEmpty ? _userPhone : '—',
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
                                              : DateTime.tryParse(_userDob) ?? DateTime(1995),
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
                                          ProfileService.instance.updateProfile(dob: iso);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.06)
                                              : Colors.black.withValues(alpha: 0.04),
                                          borderRadius: BorderRadius.circular(10),
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
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _userDob.isEmpty
                                                        ? 'Date of birth'
                                                        : _fmtDob(_userDob),
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontFamily: 'Nunito',
                                                      color: _userDob.isEmpty
                                                          ? (isDark ? AppColors.subDark : AppColors.subLight)
                                                          : (isDark ? AppColors.textDark : AppColors.textLight),
                                                    ),
                                                  ),
                                                  Text(
                                                    'For birthday reminders',
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
                                            } catch (e, stack) {
                                              debugPrint('[Dashboard] save: $e');
                                              ErrorLogger.log(e, stackTrace: stack, action: 'save_profile_name');
                                            }
                                          }
                                          ss(() => profileExpanded = false);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
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
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),
                      // Change Phone Number
                      sCard([
                        sRow(
                          emoji: '📱', bg: const Color(0xFFE0EEFF),
                          title: 'Change Phone Number', subtitle: 'OTP verification required',
                          onTap: () {},
                        ),
                      ]),

                      // ── FAMILY ────────────────────────────────────────────
                      const SizedBox(height: 24),
                      FamilySettingsSection(appState: appState, isDark: isDark),

                      // ── APPEARANCE ────────────────────────────────────────
                      const SizedBox(height: 24),
                      sToggleLabel('APPEARANCE', appearanceExpanded,
                          () => ss(() => appearanceExpanded = !appearanceExpanded)),
                      if (appearanceExpanded) sCard([
                        sRow(emoji: '🎨', bg: const Color(0xFFFFE0E0), title: 'Theme',
                          subtitle: 'App colour scheme', value: themeLabel,
                          onTap: _prefsTap(ctx, isDark, 'Theme')),
                        sRow(emoji: '🌐', bg: const Color(0xFFE0EEFF), title: 'Language & Voice',
                          subtitle: 'Input & speech language', value: 'English',
                          onTap: _prefsTap(ctx, isDark, 'Language & Voice')),
                        sRow(emoji: AppPrefs.cs, bg: const Color(0xFFE0F0FF), title: 'Currency',
                          subtitle: 'Display currency', value: 'INR',
                          onTap: _prefsTap(ctx, isDark, 'Currency')),
                        sRow(emoji: '📅', bg: const Color(0xFFE0F8EC), title: 'Date & Time',
                          subtitle: 'Format & timezone', value: 'DD/MM/YYYY',
                          onTap: _prefsTap(ctx, isDark, 'Date & Time')),
                      ]),

                      // ── FEATURES ──────────────────────────────────────────
                      const SizedBox(height: 24),
                      sToggleLabel('FEATURES', featuresExpanded,
                          () => ss(() => featuresExpanded = !featuresExpanded)),
                      if (featuresExpanded) sCard([
                        sRow(emoji: '🏠', bg: const Color(0xFFFFEDD5), title: 'Default Scope',
                          subtitle: 'Personal or Family on tab open', value: 'Per tab',
                          onTap: _prefsTap(ctx, isDark, 'Default Scope')),
                        sRow(emoji: '✦', bg: const Color(0xFFE8E0FF), title: 'AI Parser',
                          subtitle: 'Receipt & SMS auto-fill behaviour', value: 'Always confirm',
                          onTap: _prefsTap(ctx, isDark, 'AI Parser Settings')),
                        sRow(emoji: '🔔', bg: const Color(0xFFE0F8EC), title: 'Notifications',
                          subtitle: 'Alerts & reminders', value: 'On',
                          onTap: _prefsTap(ctx, isDark, 'Notifications')),
                      ]),

                      // ── PRIVACY & ABOUT ───────────────────────────────────
                      const SizedBox(height: 24),
                      sToggleLabel('PRIVACY & ABOUT', privacyExpanded,
                          () => ss(() => privacyExpanded = !privacyExpanded)),
                      if (privacyExpanded) sCard([
                        sRow(emoji: '🔒', bg: const Color(0xFFFFF0E0), title: 'Privacy & Security',
                          subtitle: 'PIN lock, policy & data', value: '',
                          onTap: _prefsTap(ctx, isDark, 'Privacy & Security')),
                        sRow(emoji: '🗑️', bg: const Color(0xFFF5F5F5), title: 'Recycle Bin',
                          subtitle: 'Restore recently deleted items', value: '',
                          onTap: _prefsTap(ctx, isDark, 'Recycle Bin')),
                        sRow(emoji: 'ℹ️', bg: const Color(0xFFF0F0F0), title: 'About WAI',
                          subtitle: 'Version, licences & credits', value: 'v1.0.0',
                          onTap: _prefsTap(ctx, isDark, 'About')),
                      ]),

                      // ── REPORT ISSUE ──────────────────────────────────────
                      const SizedBox(height: 16),
                      sCard([
                        sRow(emoji: '🐛', bg: const Color(0xFFFFE8E8), title: 'Report Issue',
                          subtitle: 'Report bugs, crashes or suggestions', value: '',
                          onTap: _prefsTap(ctx, isDark, 'Report Issue')),
                      ]),

                      // ── ACCOUNT SESSION ───────────────────────────────────
                      const SizedBox(height: 24),
                      sLabel('ACCOUNT'),
                      sCard([
                        sRow(
                          emoji: '🚪', bg: const Color(0xFFFFEDD5),
                          title: 'Logout',
                          subtitle: 'Sign out from this device',
                          onTap: () => _confirmLogout(ctx2, allDevices: false),
                        ),
                        sRow(
                          emoji: '📵', bg: const Color(0xFFFFE0E0),
                          title: 'Logout from all devices',
                          subtitle: 'Revoke all active sessions',
                          onTap: () => _confirmLogout(ctx2, allDevices: true),
                        ),
                      ]),

                      // ── SUBSCRIPTION ──────────────────────────────────────
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _prefsTap(context, isDark, 'Subscription'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _userPlan == 'family_pro'
                                  ? const [Color(0xFF6C63FF), Color(0xFF3D35CC)]
                                  : _userPlan == 'family_plus'
                                  ? const [Color(0xFFD97706), Color(0xFFB45309)]
                                  : const [Color(0xFF8E8EA0), Color(0xFF6E6E90)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _userPlan == 'family_pro'
                                    ? '👑'
                                    : _userPlan == 'family_plus'
                                    ? '👨‍👩‍👧'
                                    : '👤',
                                style: const TextStyle(fontSize: 26),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _userPlan == 'family_pro'
                                          ? 'WAI Family Pro'
                                          : _userPlan == 'family_plus'
                                          ? 'WAI Family Plus'
                                          : 'WAI Personal',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        fontFamily: 'Nunito',
                                      ),
                                    ),
                                    Text(
                                      _userPlan == 'personal_free'
                                          ? 'Upgrade to Family Plus or Pro'
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
                                  _userPlan == 'personal_free' ? 'UPGRADE' : 'ACTIVE',
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

                      // ── DANGER ZONE ───────────────────────────────────────
                      const SizedBox(height: 24),
                      sToggleLabel('DANGER ZONE', dangerExpanded,
                          () => ss(() => dangerExpanded = !dangerExpanded)),
                      if (dangerExpanded) Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                        ),
                        child: InkWell(
                          onTap: () => _confirmDeleteAccount(ctx2),
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            child: Row(
                              children: [
                                Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Delete Account',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                                          fontFamily: 'Nunito', color: Colors.red)),
                                      Text('Permanent — requires OTP confirmation',
                                        style: TextStyle(fontSize: 10, fontFamily: 'Nunito',
                                          color: Colors.red.withValues(alpha: 0.7))),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.red),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),
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
