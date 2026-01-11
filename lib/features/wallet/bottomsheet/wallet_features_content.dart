import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import '../../../data/models/wallet/featurelist.dart';

class FeaturesBottomSheetContent extends StatelessWidget {
  final List<FeatureItem> features;

  const FeaturesBottomSheetContent({super.key, required this.features});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Features', style: textTheme.titleMedium),

        const SizedBox(height: AppSpacing.gapM),

        ...features.map(
          (item) => ListTile(
            leading: Icon(item.icon),
            title: Text(item.title, style: textTheme.bodyLarge),
            onTap: () {
              Navigator.pop(context); //Close bottom sheet
              debugPrint('Clicked: ${item.title}');

              //Navigate to new page
              WidgetsBinding.instance.addPostFrameCallback((_) {
                rootNavigator.push(
                  MaterialPageRoute(builder: item.pageBuilder),
                );
              });
            },
          ),
        ),
      ],
    );
  }
}
