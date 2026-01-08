import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';

class UsersBottomSheetContent extends StatelessWidget {
  final List<String> users;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  const UsersBottomSheetContent({
    required this.users,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Select User', style: textTheme.titleMedium),

        const SizedBox(height: AppSpacing.gapM),

        ...users.map((user) {
          final isSelected = user == selectedValue;

          return ListTile(
            title: Text(
              user,
              style: isSelected
                  ? textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
                  : textTheme.bodyLarge,
            ),
            trailing: isSelected ? const Icon(Icons.check) : null,
            onTap: () {
              Navigator.pop(context);
              onSelected(user);
            },
          );
        }),
      ],
    );
  }
}
