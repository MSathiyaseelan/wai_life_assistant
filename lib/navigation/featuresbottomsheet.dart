import 'package:flutter/material.dart';
import '../data/models/wallet/featurelist.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';

void showFeaturesBottomSheet(BuildContext context, List<FeatureItem> features) {
  final width = MediaQuery.of(context).size.width;

  double maxWidth;
  if (width >= AppSpacing.maxDesktopMaxWidth) {
    maxWidth = AppSpacing.desktopMaxWidth; // desktop
  } else if (width >= AppSpacing.maxTabletMaxWidth) {
    maxWidth = AppSpacing.tabletMaxWidth; // tablet
  } else {
    maxWidth = width; // mobile
  }

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.transparent,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,

    constraints: BoxConstraints(maxWidth: maxWidth),

    builder: (ctx) {
      return Container(
        width: double.infinity, // important
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(0.15)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Features',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 12),

            // Dynamic ListTiles
            ...features.map(
              (item) => ListTile(
                leading: Icon(item.icon),
                title: Text(item.title),
                onTap: () {
                  Navigator.pop(ctx);
                  debugPrint('Clicked: ${item.title}');
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
