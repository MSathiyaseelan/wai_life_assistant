import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/features/pantry/mealmasterpage.dart';
import 'package:wai_life_assistant/features/pantry/groceries/groceriespage.dart';

class PlanItBottomSheetContent extends StatelessWidget {
  const PlanItBottomSheetContent();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Settings', style: textTheme.titleMedium),

        const SizedBox(height: AppSpacing.gapM),

        ListTile(
          leading: const Icon(Icons.restaurant_menu),
          title: Text('Reminders', style: textTheme.bodyLarge),
          onTap: () {
            Navigator.pop(context); // close drawer first

            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MealMasterPage()),
            );
          },
        ),

        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text('Todo', style: textTheme.bodyLarge),
          onTap: () {
            Navigator.pop(context); // Close the drawer / bottom sheet first
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const GroceriesPage(), // Your groceries page widget
              ),
            );
          },
        ),

        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text('Event Planner', style: textTheme.bodyLarge),
          onTap: () => Navigator.pop(context),
        ),

        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text('Trip Planner', style: textTheme.bodyLarge),
          onTap: () => Navigator.pop(context),
        ),

        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text('Item Locator', style: textTheme.bodyLarge),
          onTap: () => Navigator.pop(context),
        ),

        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text('To-Buy List', style: textTheme.bodyLarge),
          onTap: () => Navigator.pop(context),
        ),

        // ListTile(
        //   leading: const Icon(Icons.settings_outlined),
        //   title: Text('Features', style: textTheme.bodyLarge),
        //   //onTap: () => Navigator.pop(context),
        //   onTap: () => {
        //     showFeaturesBottomSheet(
        //       context: context,
        //       features: featuresByTab[2] ?? [],
        //     ),
        //   },
        // ),

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
