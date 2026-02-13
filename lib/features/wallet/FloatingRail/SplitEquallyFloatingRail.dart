import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplitFloatingRail extends StatelessWidget {
  final VoidCallback onSparkTap;
  final VoidCallback onNewGroupTap;

  const SplitFloatingRail({
    super.key,
    required this.onSparkTap,
    required this.onNewGroupTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ----------- AI ------------
          _RailAction(
            icon: Icons.auto_awesome_rounded,
            label: 'Spark',
            color: Colors.deepPurple,
            onTap: () {
              HapticFeedback.lightImpact();
              onSparkTap();
            },
          ),

          const SizedBox(height: 28),

          // ----------- NEW GROUP ------------
          _RailAction(
            icon: Icons.add,
            label: 'Group',
            color: Colors.grey,
            onTap: () {
              HapticFeedback.lightImpact();
              onNewGroupTap();
            },
          ),
        ],
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _RailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 30, color: color),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
