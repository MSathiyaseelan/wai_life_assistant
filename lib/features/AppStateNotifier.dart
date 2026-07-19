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

  /// userId → "emoji name" for ALL family members, including removed ones.
  /// Used so past transactions/entries still show the correct name after
  /// a member leaves the group.
  Map<String, String> _allMemberNames = {};

  List<WalletModel> get wallets => _wallets;
  List<FamilyModel> get families => _families;
  bool get loading => _loading;

  /// Full member name map including removed members — use this for display,
  /// not [families] members, to handle left members gracefully.
  Map<String, String> get allMemberNames => _allMemberNames;

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
  ///
  /// Retries a few times before falling back to the placeholder wallet: a
  /// logged-in user reaching this point always has a profile row already
  /// (login/onboarding only hands off to the app shell after that's set up),
  /// so a null/failed fetch here is most likely a transient hiccup — e.g.
  /// cold DNS/TLS on a brand-new install, or a race with Firebase/Supabase
  /// still finishing initialization — not a genuinely missing account. Without
  /// this, a single bad first request left every screen stuck on the
  /// 'personal' placeholder wallet id for the rest of the session (surfacing
  /// as "Failed to load PlanIt data" / "Account still loading" everywhere).
  Future<void> init() async {
    _loading = true;
    notifyListeners();

    const maxAttempts = 3;
    var repairAttempted = false;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final isLastAttempt = attempt == maxAttempts;
      try {
        final loggedIn = AuthCoordinator.instance.isLoggedIn;
        debugPrint('[AppState] init (attempt $attempt) — isLoggedIn=$loggedIn');

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
          break;
        }

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
          // Load all members (incl. removed) for name display — fire and forget
          _loadAllMemberNames(parsed.families);
          break;
        }

        debugPrint('[AppState] fetchSwitcherData returned null (attempt $attempt)');
        if (!repairAttempted) {
          // A logged-in user with a profile but no matching wallet row means
          // bootstrap never finished (e.g. a profile created during a
          // migration gap before the wallets table/RLS was in sync) — the
          // client only calls bootstrapNewUser once, when the profile row is
          // first created, so this account would otherwise be stuck forever.
          // Self-heal by re-running the idempotent RPC: it only creates the
          // personal wallet if one doesn't already exist and preserves the
          // existing profile fields.
          repairAttempted = true;
          try {
            await ProfileService.instance.bootstrapNewUser();
            debugPrint('[AppState] bootstrapNewUser repair attempted');
          } catch (e) {
            debugPrint('[AppState] bootstrapNewUser repair failed: $e');
          }
          continue;
        }
        if (isLastAttempt) {
          // Fall back to a placeholder so screens don't hang on empty walletId.
          if (_wallets.isEmpty) {
            _wallets = [personalWallet];
            _activeWalletId = personalWallet.id;
          }
        } else {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }
      } catch (e, stack) {
        debugPrint('[AppState] init error (attempt $attempt): $e');
        if (isLastAttempt) {
          ErrorLogger.log(e, stackTrace: stack, action: 'app_state_init', severity: ErrorSeverity.critical);
          if (_wallets.isEmpty) {
            _wallets = [personalWallet];
            _families = [];
            _activeWalletId = personalWallet.id;
          }
        } else {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }
      }
      break;
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> _loadAllMemberNames(List<FamilyModel> families) async {
    try {
      final map = <String, String>{};
      for (final family in families) {
        final rows = await ProfileService.instance.fetchAllMembers(family.id);
        for (final m in rows) {
          final uid = m['user_id'] as String?;
          if (uid == null) continue;
          final emoji = m['emoji'] as String? ?? '👤';
          final name  = m['name']  as String? ?? '';
          map[uid] = '$emoji $name';
        }
      }
      _allMemberNames = map;
      notifyListeners();
    } catch (e) {
      debugPrint('[AppState] _loadAllMemberNames error: $e');
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
