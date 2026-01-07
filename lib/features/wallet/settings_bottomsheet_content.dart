import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';

class SettingsContent extends StatelessWidget {
  const SettingsContent();

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
          title: Text('Profile', style: textTheme.bodyLarge),
          onTap: () => Navigator.pop(context),
        ),

        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text('Notifications', style: textTheme.bodyLarge),
          onTap: () => Navigator.pop(context),
        ),

        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text('App Settings', style: textTheme.bodyLarge),
          onTap: () => Navigator.pop(context),
        ),

        const Divider(),

        ListTile(
          leading: const Icon(Icons.logout),
          title: Text('Logout', style: textTheme.bodyLarge),
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
