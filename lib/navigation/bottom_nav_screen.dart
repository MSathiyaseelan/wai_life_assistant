import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/fcm_service.dart';
import 'package:wai_life_assistant/features/wallet/ai/IntentConfirmSheet.dart';
import 'package:wai_life_assistant/features/wallet/services/sms_parser_service.dart';
import 'package:wai_life_assistant/features/wallet/wallet_screen.dart';
import 'package:wai_life_assistant/features/pantry/pantry_screen.dart';
import 'package:wai_life_assistant/features/planit/planit_screen.dart';
import 'package:wai_life_assistant/features/lifestyle/lifestyle_screen.dart';
import 'package:wai_life_assistant/features/dashboard/dashboard_screen.dart';
import 'package:wai_life_assistant/features/AppStateNotifier.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import 'package:wai_life_assistant/features/auth/app_lock_screen.dart';

const _kThemePrefKey = 'theme_mode';

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});
  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemePrefKey);
    if (!mounted) return;
    setState(() {
      _themeMode = switch (saved) {
        'light'  => ThemeMode.light,
        'dark'   => ThemeMode.dark,
        _        => ThemeMode.system,
      };
    });
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemePrefKey, switch (mode) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      ThemeMode.system => 'system',
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WAI Life Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: AppShell(themeMode: _themeMode, onSetTheme: _setTheme),
    );
  }
}

class AppShell extends StatefulWidget {
  final ThemeMode themeMode;
  final void Function(ThemeMode) onSetTheme;
  const AppShell({
    super.key,
    required this.themeMode,
    required this.onSetTheme,
  });
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _idx = 0;
  int _dashboardRefreshCount = 0;
  final _appState = AppStateNotifier();

  @override
  void initState() {
    super.initState();
    _appState.init();
    FcmService.pendingTab.addListener(_onFcmTab);
    final pending = FcmService.pendingTab.value;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onFcmTab());
    }
    SMSParserService.pendingSmsBody.addListener(_onPendingSms);
    final pendingSms = SMSParserService.pendingSmsBody.value;
    if (pendingSms != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onPendingSms());
    }
  }

  void _onFcmTab() {
    final tab = FcmService.pendingTab.value;
    if (tab == null) return;
    setState(() => _idx = tab);
    FcmService.pendingTab.value = null;
  }

  Future<void> _onPendingSms() async {
    final smsBody = SMSParserService.pendingSmsBody.value;
    if (smsBody == null || !mounted) return;
    SMSParserService.pendingSmsBody.value = null;

    // Switch to wallet tab
    setState(() => _idx = 1);

    // Parse (regex first, AI fallback) then show confirm sheet
    final parsed = await SMSParserService.parseSMSText(smsBody);
    if (!mounted || parsed == null) return;

    await IntentConfirmSheet.show(
      context,
      intent:     parsed.toParsedIntent(),
      walletId:   _appState.activeWalletId,
      onSave:     (_) => setState(() => _dashboardRefreshCount++),
      onOpenFlow: () {},
    );
  }

  static const _tabs = [
    (icon: '🏠', label: 'Dashboard'),
    (icon: '₹', label: 'Wallet'),
    (icon: '🥗', label: 'Pantry'),
    (icon: '📅', label: 'PlanIt'),
    (icon: '✨', label: 'MyLife'), // V2 — hidden from nav bar
  ];

  static const _hiddenTabIndices = {4}; // MyLife

  @override
  void dispose() {
    FcmService.pendingTab.removeListener(_onFcmTab);
    _appState.dispose();
    super.dispose();
  }

  // Tab index → which AppPrefs scope key to read.
  // 1 = Wallet, 2 = Pantry, 3 = PlanIt (Dashboard and LifeStyle have no scope pref).
  void _applyScope(int tabIndex) {
    final prefs = AppPrefs.instance;
    if (!prefs.ready) return;
    final scope = switch (tabIndex) {
      1 => prefs.walletScope,
      2 => prefs.pantryScope,
      3 => prefs.planItScope,
      _ => null,
    };
    if (scope == null) return;
    final wallets = _appState.wallets;
    if (wallets.isEmpty) return;
    final target = scope == 'family'
        ? wallets.firstWhere((w) => !w.isPersonal, orElse: () => wallets.first)
        : wallets.firstWhere((w) => w.isPersonal, orElse: () => wallets.first);
    _appState.switchWallet(target.id);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppLockGuard(
      child: AppStateScope(
      notifier: _appState,
      child: ListenableBuilder(
        listenable: _appState,
        builder: (context, _) {
          final walletId = _appState.activeWalletId;
          final screens = [
            DashboardScreen(
              refreshCount: _dashboardRefreshCount,
              themeMode: widget.themeMode,
              onSetTheme: widget.onSetTheme,
              onTabSwitch: (idx) => setState(() => _idx = idx),
            ),
            WalletScreen(
              activeWalletId: walletId,
              onWalletChange: _appState.switchWallet,
            ),
            PantryScreen(
              activeWalletId: walletId,
              onWalletChange: _appState.switchWallet,
            ),
            PlanItScreen(
              activeWalletId: walletId,
              onWalletChange: _appState.switchWallet,
            ),
            LifeStyleScreen(
              activeWalletId: walletId,
              onWalletChange: _appState.switchWallet,
            ),
          ];

          return Scaffold(
            body: IndexedStack(index: _idx, children: screens),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (int i = 0; i < _tabs.length; i++)
                        if (!_hiddenTabIndices.contains(i))
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                _applyScope(i);
                                setState(() {
                                  if (i == 0 && _idx != 0) _dashboardRefreshCount++;
                                  _idx = i;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutBack,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: i == _idx
                                      ? AppColors.primary.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (i == 1)
                                      AnimatedScale(
                                        duration: const Duration(milliseconds: 200),
                                        scale: i == _idx ? 1.2 : 1.0,
                                        child: Icon(
                                          Icons.currency_rupee_rounded,
                                          size: 22,
                                          color: i == _idx
                                              ? AppColors.primary
                                              : (isDark ? AppColors.subDark : AppColors.subLight),
                                        ),
                                      )
                                    else
                                      AnimatedDefaultTextStyle(
                                        duration: const Duration(milliseconds: 200),
                                        style: TextStyle(fontSize: i == _idx ? 24 : 20),
                                        child: Text(_tabs[i].icon),
                                      ),
                                    const SizedBox(height: 3),
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'Nunito',
                                        fontWeight: i == _idx
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: i == _idx
                                            ? AppColors.primary
                                            : (isDark
                                                ? AppColors.subDark
                                                : AppColors.subLight),
                                      ),
                                      child: Text(_tabs[i].label),
                                    ),
                                  ],
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
        },
      ),
    ),
    );
  }
}
