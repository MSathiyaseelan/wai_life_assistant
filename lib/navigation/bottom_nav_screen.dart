import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/features/wallet/wallet_screen.dart';
import 'package:wai_life_assistant/features/wallet/placeholder_screens.dart';
import 'package:wai_life_assistant/features/pantry/pantry_screen.dart';
import 'package:wai_life_assistant/features/planit/planit_screen.dart';
//import 'package:wai_life_assistant/features/dashboard/dashboard_screen.dart';

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
  int _idx = 1; // Start on Wallet tab

  static const _tabs = [
    (icon: '🏠', label: 'Dashboard'),
    (icon: '💰', label: 'Wallet'),
    (icon: '🛒', label: 'Pantry'),
    (icon: '📅', label: 'PlanIt'),
    (icon: '✨', label: 'LifeStyle'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screens = [
      const DashboardScreen(),
      const WalletScreen(),
      const PantryScreen(),
      const PlanItScreen(),
      const LifeStyleScreen(),
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
  }
}

// import 'package:flutter/material.dart';
// import 'package:wai_life_assistant/features/Wallet/wallet_screen.dart';
// import 'package:wai_life_assistant/features/pantry/pantry_screen.dart';
// import 'package:wai_life_assistant/features/dashboard/dashboard_screen.dart';
// import 'package:wai_life_assistant/features/planit/planit_screen.dart';
// import 'package:wai_life_assistant/features/lifestyle/lifestyle_screen.dart';
// import 'package:wai_life_assistant/shared/responsive_layout.dart';
// import 'package:wai_life_assistant/core/theme/app_text.dart';

// class BottomNavScreen extends StatefulWidget {
//   const BottomNavScreen({super.key});

//   @override
//   State<BottomNavScreen> createState() => _BottomNavScreenState();
// }

// class _BottomNavScreenState extends State<BottomNavScreen> {
//   int _currentIndex = 0;

//   static const List<Widget> _screens = [
//     DashboardScreen(),
//     WalletScreen(),
//     PantryScreen(),
//     PlanItScreen(),
//     LifeStyleScreen(),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return ResponsiveLayout(
//       child: WillPopScope(
//         onWillPop: () async {
//           if (_currentIndex != 0) {
//             setState(() => _currentIndex = 0);
//             return false;
//           }
//           return true;
//         },
//         child: Scaffold(
//           body: SafeArea(
//             child: IndexedStack(index: _currentIndex, children: _screens),
//           ),
//           bottomNavigationBar: BottomNavigationBar(
//             currentIndex: _currentIndex,
//             type: BottomNavigationBarType.fixed,
//             selectedItemColor: Theme.of(context).primaryColor,
//             unselectedItemColor: Colors.grey,
//             onTap: (index) {
//               if (_currentIndex != index) {
//                 setState(() => _currentIndex = index);
//               }
//             },
//             items: const [
//               BottomNavigationBarItem(
//                 icon: Icon(Icons.dashboard_outlined),
//                 activeIcon: Icon(Icons.dashboard),
//                 label: AppText.dashboardTitle,
//               ),
//               BottomNavigationBarItem(
//                 icon: Icon(Icons.wallet_outlined),
//                 activeIcon: Icon(Icons.wallet),
//                 label: AppText.walletTitle,
//               ),
//               BottomNavigationBarItem(
//                 icon: Icon(Icons.food_bank_outlined),
//                 activeIcon: Icon(Icons.food_bank),
//                 label: AppText.pantryTitle,
//               ),
//               BottomNavigationBarItem(
//                 icon: Icon(Icons.list_alt_outlined),
//                 activeIcon: Icon(Icons.list_alt),
//                 label: AppText.planItTitle,
//               ),
//               BottomNavigationBarItem(
//                 icon: Icon(Icons.people_outlined),
//                 activeIcon: Icon(Icons.people),
//                 label: AppText.lifeStyleTitle,
//               ),
//             ],
//           ),
//           bottomSheet: _bottomActionsForIndex(_currentIndex, context),
//         ),
//       ),
//     );
//   }
// }

// //Method to decide actions per tab
// Widget? _bottomActionsForIndex(int index, BuildContext context) {
//   switch (index) {
//     case 0: // Dashboard
//       return null;

//     case 1: // Wallet
//       //return _chipBar(['Cash', 'UPI', 'Features'], context);
//       //return _walletChipBar(context);
//       //return WalletChipBar();
//       return null;

//     case 2: // Pantry
//       return null;
//     // return ChipBar(
//     //   labels: const ['Meal', 'Groceries', 'Features'],
//     //   onChipPressed: (label) {
//     //     if (label == 'Features') {
//     //       showFeaturesBottomSheet(
//     //         context: context,
//     //         features: featuresByTab[2] ?? [],
//     //       );
//     //     } else {
//     //       debugPrint('Clicked: $label');
//     //     }
//     //   },
//     // );

//     case 3: // PlanIt
//       return null;
//     // return ChipBar(
//     //   labels: const ['Reminders', 'ToDo', 'Features'],
//     //   onChipPressed: (label) {
//     //     if (label == 'Features') {
//     //       showFeaturesBottomSheet(
//     //         context: context,
//     //         features: featuresByTab[3] ?? [],
//     //       );
//     //     } else if (label == 'ToDo') {
//     //       Navigator.of(
//     //         context,
//     //       ).push(MaterialPageRoute(builder: (_) => const TodoPage()));
//     //     } else {
//     //       debugPrint('Clicked: $label');
//     //     }
//     //   },
//     // );

//     case 4: // LifeStyle
//       return null;
//     // return ChipBar(
//     //   labels: const ['Vehicle', 'Dresses', 'Gadgets', 'Features'],
//     //   onChipPressed: (label) {
//     //     if (label == 'Features') {
//     //       showFeaturesBottomSheet(
//     //         context: context,
//     //         features: featuresByTab[4] ?? [],
//     //       );
//     //     } else {
//     //       debugPrint('Clicked: $label');
//     //     }
//     //   },
//     // );

//     default:
//       return null;
//   }
// }
