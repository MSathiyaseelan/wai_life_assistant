import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/auth/auth_coordinator.dart';
import 'package:wai_life_assistant/data/services/profile_service.dart';
import 'package:wai_life_assistant/data/services/app_config_service.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/core/services/realtime_sync_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP STATE — single source of truth for active wallet across all tabs
// ─────────────────────────────────────────────────────────────────────────────

class AppStateNotifier extends ChangeNotifier {
  List<WalletModel> _wallets = [];
  List<FamilyModel> _families = [];
  bool _loading = false;
  String _activeWalletId = '';
  int _maxFamilyGroups = 1; // V1 safe default
  int _maxFamilyMembers = 0; // 0 = personal_free (no family allowed)

  List<WalletModel> get wallets => _wallets;
  List<FamilyModel> get families => _families;
  bool get loading => _loading;

  /// Server-controlled limit on how many family/group wallets a user can create.
  int get maxFamilyGroups => _maxFamilyGroups;

  /// Max members per family group from the user's subscription plan.
  /// 0 means the user's plan does not allow family groups.
  int get maxFamilyMembers => _maxFamilyMembers;

  String get activeWalletId => _activeWalletId;

  WalletModel get activeWallet {
    if (_wallets.isEmpty) {
      return WalletModel(
        id: '',
        name: 'Loading...',
        emoji: '⏳',
        isPersonal: true,
        cashIn: 0,
        cashOut: 0,
        onlineIn: 0,
        onlineOut: 0,
        gradient: AppColors.personalGrad,
      );
    }
    return _wallets.firstWhere(
      (w) => w.id == _activeWalletId,
      orElse: () => _wallets.first,
    );
  }

  bool get isPersonal => activeWallet.isPersonal;

  /// Load wallets and families from Supabase (or fall back to mock data).
  Future<void> init() async {
    _loading = true;
    notifyListeners();

    try {
      final loggedIn = AuthCoordinator.instance.isLoggedIn;
      debugPrint('[AppState] init — isLoggedIn=$loggedIn');

      // Fetch config and profile data in parallel — they are independent calls.
      final fetched = await Future.wait([
        AppConfigService.instance.fetchMaxFamilyGroups(),
        if (loggedIn) ProfileService.instance.fetchSwitcherData()
        else Future.value(null),
        if (loggedIn) ProfileService.instance.fetchMaxFamilyMembers()
        else Future.value(0),
      ]);
      _maxFamilyGroups = fetched[0] as int;
      if (loggedIn) _maxFamilyMembers = fetched[2] as int;

      if (!loggedIn) {
        RealtimeSyncService.instance.unsubscribeAll();
        _wallets = [personalWallet];
        _families = [];
        if (_activeWalletId.isEmpty || !_wallets.any((w) => w.id == _activeWalletId)) {
          _activeWalletId = personalWallet.id;
        }
      } else {
        final row = fetched[1] as Map<String, dynamic>?;
        debugPrint('[AppState] fetchSwitcherData row=${row != null ? 'found' : 'null'}');
        if (row != null) {
          final parsed = ProfileService.instance.parseSwitcherData(row);
          _wallets = [parsed.personal, ...parsed.familyWallets];
          _families = parsed.families;
          debugPrint('[AppState] wallets=${_wallets.length} families=${_families.length}');
          if (_activeWalletId.isEmpty ||
              !_wallets.any((w) => w.id == _activeWalletId)) {
            _activeWalletId = parsed.personal.id;
          }
          RealtimeSyncService.instance.subscribeAll(parsed.personal.id);
        } else {
          // Profile not set up yet (e.g. bypass login with cache-cleared state).
          // Fall back to a placeholder so screens don't hang on empty walletId.
          debugPrint('[AppState] fetchSwitcherData returned null — using placeholder wallet');
          if (_wallets.isEmpty) {
            _wallets = [personalWallet];
            _activeWalletId = personalWallet.id;
          }
        }
      }
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'app_state_init', severity: ErrorSeverity.critical);
      debugPrint('[AppState] init error: $e');
      if (_wallets.isEmpty) {
        _wallets = [personalWallet];
        _families = [];
        _activeWalletId = personalWallet.id;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Re-fetch data (e.g. after create/edit/delete family).
  Future<void> reload() => init();

  void switchWallet(String id) {
    if (_activeWalletId == id) return;
    _activeWalletId = id;
    notifyListeners();
  }

  // Called after adding/editing a family so wallet list rebuilds
  void refresh() => notifyListeners();
}

// ─────────────────────────────────────────────────────────────────────────────
// InheritedNotifier — makes AppStateNotifier accessible anywhere in the tree
// ─────────────────────────────────────────────────────────────────────────────

class AppStateScope extends InheritedNotifier<AppStateNotifier> {
  const AppStateScope({
    super.key,
    required AppStateNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppStateNotifier of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope found in widget tree');
    return scope!.notifier!;
  }

  /// Use this when you only want to READ without rebuilding on every change
  static AppStateNotifier read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope found in widget tree');
    return scope!.notifier!;
  }
}
