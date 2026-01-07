import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/core/theme/app_radius.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.summaryCardPadding,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.walletSummaryRadius,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
