import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/wallet_features_bottomsheet.dart';
import 'package:wai_life_assistant/features/wallet/featurelistdata.dart';

class PantryBottomSheetContent extends StatelessWidget {
  const PantryBottomSheetContent();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Settings', style: textTheme.titleMedium),

        const SizedBox(height: AppSpacing.gapM),

        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text('Meal', style: textTheme.bodyLarge),
          onTap: () => Navigator.pop(context),
        ),

        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text('Groceries', style: textTheme.bodyLarge),
          onTap: () => Navigator.pop(context),
        ),

        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text('Features', style: textTheme.bodyLarge),
          //onTap: () => Navigator.pop(context),
          onTap: () => {
            showFeaturesBottomSheet(
              context: context,
              features: featuresByTab[2] ?? [],
            ),
          },
        ),

        // const Divider(),

        // ListTile(
        //   leading: const Icon(Icons.logout),
        //   title: Text('Logout', style: textTheme.bodyLarge),
        //   onTap: () => Navigator.pop(context),
        // ),
      ],
    );
  }
}
