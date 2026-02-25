import 'package:flutter/material.dart';

// class DashboardScreen extends StatelessWidget {
//   const DashboardScreen({super.key});
//   @override
//   Widget build(BuildContext context) => _PlaceholderScreen(
//     icon: '🏠',
//     label: 'Dashboard',
//     desc: 'Your financial overview will live here.',
//     color: const Color(0xFF6C63FF),
//   );
// }

// class PantryScreen extends StatelessWidget {
//   const PantryScreen({super.key});
//   @override
//   Widget build(BuildContext context) => _PlaceholderScreen(
//     icon: '🛒',
//     label: 'Pantry',
//     desc: 'Track groceries & household inventory.',
//     color: const Color(0xFF00C897),
//   );
// }

// class PlanItScreen extends StatelessWidget {
//   const PlanItScreen({super.key});
//   @override
//   Widget build(BuildContext context) => _PlaceholderScreen(
//     icon: '📅',
//     label: 'PlanIt',
//     desc: 'Plan your goals, budgets & events.',
//     color: const Color(0xFF4A9EFF),
//   );
// }

// class LifeStyleScreen extends StatelessWidget {
//   const LifeStyleScreen({super.key});
//   @override
//   Widget build(BuildContext context) => _PlaceholderScreen(
//     icon: '✨',
//     label: 'LifeStyle',
//     desc: 'Track health, habits & lifestyle goals.',
//     color: const Color(0xFFFF5C7A),
//   );
// }

class _PlaceholderScreen extends StatelessWidget {
  final String icon, label, desc;
  final Color color;
  const _PlaceholderScreen({
    required this.icon,
    required this.label,
    required this.desc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 24),
              Text(
                label,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                  color: color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'Nunito',
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
