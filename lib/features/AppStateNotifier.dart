import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP STATE — single source of truth for active wallet across all tabs
// ─────────────────────────────────────────────────────────────────────────────

class AppStateNotifier extends ChangeNotifier {
  String _activeWalletId = 'personal';

  String get activeWalletId => _activeWalletId;

  WalletModel get activeWallet {
    if (_activeWalletId == 'personal') return personalWallet;
    return familyWallets.firstWhere(
      (w) => w.id == _activeWalletId,
      orElse: () => personalWallet,
    );
  }

  bool get isPersonal => _activeWalletId == 'personal';

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
