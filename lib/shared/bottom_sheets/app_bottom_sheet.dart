import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget child,
}) {
  final width = MediaQuery.of(context).size.width;

  double maxWidth;
  if (width >= AppSpacing.maxDesktopMaxWidth) {
    maxWidth = AppSpacing.desktopMaxWidth;
  } else if (width >= AppSpacing.maxTabletMaxWidth) {
    maxWidth = AppSpacing.tabletMaxWidth;
  } else {
    maxWidth = width;
  }

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.transparent,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(maxWidth: maxWidth),
    builder: (ctx) {
      return Container(
        width: double.infinity,
        padding: AppSpacing.screenPadding,
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(0.15)),
          ],
        ),
        child: child,
      );
    },
  );
}
