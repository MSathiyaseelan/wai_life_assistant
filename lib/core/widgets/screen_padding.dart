import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';

class ScreenPadding extends StatelessWidget {
  final Widget child;

  const ScreenPadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(padding: AppSpacing.screenPadding, child: child),
    );
  }
}
