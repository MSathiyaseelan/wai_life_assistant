import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/features/wallet/wallet_screen.dart';
import 'package:wai_life_assistant/features/wallet/placeholder_screens.dart';
import 'package:wai_life_assistant/features/pantry/pantry_screen.dart';
import 'package:wai_life_assistant/features/planit/planit_screen.dart';
import 'package:wai_life_assistant/features/lifestyle/lifestyle_screen.dart';
import 'package:wai_life_assistant/features/dashboard/dashboard_screen.dart';
import 'package:wai_life_assistant/features/AppStateNotifier.dart';

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});
  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() => setState(() {
    _themeMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: AppShell(onToggleTheme: _toggleTheme, themeMode: _themeMode),
    );
  }
}

class AppShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  const AppShell({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
  });
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _idx = 0;
  final _appState = AppStateNotifier();

  @override
  void initState() {
    super.initState();
    _appState.init();
  }

  static const _tabs = [
    (icon: '🏠', label: 'Dashboard'),
    (icon: '💰', label: 'Wallet'),
    (icon: '🥗', label: 'Pantry'),
    (icon: '📅', label: 'PlanIt'),
    (icon: '✨', label: 'MyLife'),
  ];

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppStateScope(
      notifier: _appState,
      child: ListenableBuilder(
        listenable: _appState,
        builder: (context, _) {
          final walletId = _appState.activeWalletId;
          final screens = [
            const DashboardScreen(),
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
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
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
                    children: List.generate(_tabs.length, (i) {
                      final tab = _tabs[i];
                      final active = i == _idx;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _idx = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(fontSize: active ? 24 : 20),
                                  child: Text(tab.icon),
                                ),
                                const SizedBox(height: 3),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'Nunito',
                                    fontWeight: active
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: active
                                        ? AppColors.primary
                                        : (isDark
                                              ? AppColors.subDark
                                              : AppColors.subLight),
                                  ),
                                  child: Text(tab.label),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
