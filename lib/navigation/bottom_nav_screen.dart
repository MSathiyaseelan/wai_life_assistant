import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/Wallet/wallet_screen.dart';
import 'package:wai_life_assistant/features/pantry/pantry_screen.dart';
import 'package:wai_life_assistant/features/dashboard/dashboard_screen.dart';
import 'package:wai_life_assistant/features/planit/planit_screen.dart';
import 'package:wai_life_assistant/features/lifestyle/lifestyle_screen.dart';
import 'package:wai_life_assistant/shared/responsive_layout.dart';
//import 'package:wai_life_assistant/features/wallet/counterchip.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/features/wallet/wallet_chip_bar.dart';
import 'package:wai_life_assistant/shared/widgets/chip_bar.dart';

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    DashboardScreen(),
    WalletScreen(),
    PantryScreen(),
    PlanItScreen(),
    LifeStyleScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      child: WillPopScope(
        onWillPop: () async {
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
            return false;
          }
          return true;
        },
        child: Scaffold(
          body: SafeArea(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Colors.grey,
            onTap: (index) {
              if (_currentIndex != index) {
                setState(() => _currentIndex = index);
              }
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: AppText.dashboardTitle,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.wallet_outlined),
                activeIcon: Icon(Icons.wallet),
                label: AppText.walletTitle,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.food_bank_outlined),
                activeIcon: Icon(Icons.food_bank),
                label: AppText.pantryTitle,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt_outlined),
                activeIcon: Icon(Icons.list_alt),
                label: AppText.planItTitle,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_outlined),
                activeIcon: Icon(Icons.people),
                label: AppText.lifeStyleTitle,
              ),
            ],
          ),
          bottomSheet: _bottomActionsForIndex(_currentIndex, context),
        ),
      ),
    );
  }
}

//Method to decide actions per tab
Widget? _bottomActionsForIndex(int index, BuildContext context) {
  switch (index) {
    case 0: // Dashboard
      return null;

    case 1: // Wallet
      //return _chipBar(['Cash', 'UPI', 'Features'], context);
      //return _walletChipBar(context);
      return WalletChipBar();

    case 2: // Pantry
      //return _chipBar(['Meal', 'Groceries', 'Features'], context);
      return ChipBar(
        labels: const ['Meal', 'Groceries', 'Features'],
        onChipPressed: (label) {
          debugPrint('Clicked: $label');
        },
      );

    case 3: // PlanIt
      // return _chipBar(['Remainders', 'ToDo', 'Features'], context);
      //return _buttonBar();
      return ChipBar(
        labels: const ['Remainders', 'ToDo', 'Features'],
        onChipPressed: (label) {
          debugPrint('Clicked: $label');
        },
      );

    case 4: // LifeStyle
      // return _chipBar([
      //   'Vehicle',
      //   'Dresses',
      //   'Gadgets',
      //   'Features',
      // ], context); // No bottom actions
      return ChipBar(
        labels: const ['Vehicle', 'Dresses', 'Gadgets', 'Features'],
        onChipPressed: (label) {
          debugPrint('Clicked: $label');
        },
      );

    default:
      return null;
  }
}

//Reusable ActionChip Bar
// Widget _chipBar(List<String> labels, BuildContext context) {
//   return SafeArea(
//     top: false,
//     child: Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       color: Theme.of(context).scaffoldBackgroundColor,
//       child: Wrap(
//         spacing: 8,
//         runSpacing: 8,
//         children: labels.map((label) {
//           return ActionChip(
//             label: Text(label),
//             elevation: 0,
//             pressElevation: 0,
//             shadowColor: Colors.transparent,
//             backgroundColor: Theme.of(context).colorScheme.surface,
//             onPressed: () {
//               debugPrint('$label pressed');
//             },
//           );
//         }).toList(),
//       ),
//     ),
//   );
// }

//Button Bar
Widget _buttonBar() {
  return SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black12)],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              child: const Text("Cancel"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(onPressed: () {}, child: const Text("Save")),
          ),
        ],
      ),
    ),
  );
}

// Widget _walletChipBar(BuildContext context) {
//   return SafeArea(
//     top: false,
//     child: Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       color: Theme.of(context).scaffoldBackgroundColor,
//       child: Wrap(
//         spacing: 8,
//         children: [
//           CounterChip(
//             label: 'UPI',
//             onIncrement: () => debugPrint('UPI +'),
//             onDecrement: () => debugPrint('UPI -'),
//           ),

//           CounterChip(
//             label: 'Cash',
//             onIncrement: () => debugPrint('Cash +'),
//             onDecrement: () => debugPrint('Cash -'),
//           ),

//           ActionChip(
//             label: const Text('Features'),
//             elevation: 0,
//             pressElevation: 0,
//             onPressed: () {
//               debugPrint('Features pressed');
//             },
//           ),
//         ],
//       ),
//     ),
//   );
// }
