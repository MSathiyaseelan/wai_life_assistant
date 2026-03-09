import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/auth/auth_service.dart';
import 'package:wai_life_assistant/core/supabase/profile_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP STATE — single source of truth for active wallet across all tabs
// ─────────────────────────────────────────────────────────────────────────────

class AppStateNotifier extends ChangeNotifier {
  List<WalletModel> _wallets = [];
  List<FamilyModel> _families = [];
  bool _loading = false;
  String _activeWalletId = '';

  List<WalletModel> get wallets => _wallets;
  List<FamilyModel> get families => _families;
  bool get loading => _loading;

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
      if (!AuthService.instance.isLoggedIn) {
        // OTP bypassed — use mock data
        _wallets = [personalWallet, ...familyWallets];
        _families = mockFamilies;
        // Preserve valid active wallet (e.g. newly added family); reset to personal only if missing
        if (_activeWalletId.isEmpty || !_wallets.any((w) => w.id == _activeWalletId)) {
          _activeWalletId = personalWallet.id;
        }
      } else {
        final row = await ProfileService.instance.fetchSwitcherData();
        if (row != null) {
          final parsed = ProfileService.instance.parseSwitcherData(row);
          _wallets = [parsed.personal, ...parsed.familyWallets];
          _families = parsed.families;
          // Keep active wallet if still valid, else default to personal
          if (_activeWalletId.isEmpty ||
              !_wallets.any((w) => w.id == _activeWalletId)) {
            _activeWalletId = parsed.personal.id;
          }
        }
      }
    } catch (_) {
      // Fall back to mock data on any error
      if (_wallets.isEmpty) {
        _wallets = [personalWallet, ...familyWallets];
        _families = mockFamilies;
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
