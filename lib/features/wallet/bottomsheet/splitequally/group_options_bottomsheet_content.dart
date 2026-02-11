import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/data/models/wallet/SplitGroup.dart';

class GroupOptionsBottomSheetContent extends StatelessWidget {
  final SplitGroup group;

  const GroupOptionsBottomSheetContent({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Group options', style: textTheme.titleMedium),

        const SizedBox(height: AppSpacing.gapM),

        _OptionTile(
          icon: Icons.person_add_alt,
          label: 'Add Member',
          onTap: () {
            Navigator.pop(context);
            debugPrint('Add Member');
          },
        ),

        _OptionTile(
          icon: Icons.currency_exchange,
          label: 'Currency',
          onTap: () {
            Navigator.pop(context);
            debugPrint('Currency');
          },
        ),

        _OptionTile(
          icon: Icons.visibility_off,
          label: 'Inactive',
          onTap: () {
            Navigator.pop(context);
            debugPrint('Inactive');
          },
        ),

        _OptionTile(
          icon: Icons.check_circle_outline,
          label: 'Settled',
          onTap: () {
            Navigator.pop(context);
            debugPrint('Settled');
          },
        ),

        const Divider(height: AppSpacing.gapL),

        _OptionTile(
          icon: Icons.delete_outline,
          label: 'Delete',
          color: colors.error,
          onTap: () {
            Navigator.pop(context);
            debugPrint('Delete group');
          },
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: effectiveColor),
      title: Text(
        label,
        style: textTheme.bodyLarge?.copyWith(color: effectiveColor),
      ),
      onTap: onTap,
    );
  }
}
