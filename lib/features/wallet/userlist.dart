import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';

class UsersList extends StatefulWidget {
  const UsersList({super.key});

  @override
  State<UsersList> createState() => _UsersListState();
}

class _UsersListState extends State<UsersList> {
  final List<String> items = ['Sathiya', 'Venis', 'Sandriya', 'Immandriya'];

  String? selectedValue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Selected user text
        Expanded(
          child: Text(
            selectedValue ?? 'Select user',
            style: textTheme.bodyLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Arrow button
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () {
            showUsersBottomSheet(
              context: context,
              users: items,
              selectedValue: selectedValue,
              onSelected: (value) {
                setState(() => selectedValue = value);
              },
            );
          },
        ),
      ],
    );
  }
}

void showUsersBottomSheet({
  required BuildContext context,
  required List<String> users,
  String? selectedValue,
  required ValueChanged<String> onSelected,
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

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.transparent,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(maxWidth: maxWidth),
    builder: (ctx) {
      final textTheme = Theme.of(ctx).textTheme;

      return Container(
        width: double.infinity,
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
            Text('Select User', style: textTheme.titleMedium),

            const SizedBox(height: AppSpacing.gapM),

            ...users.map((user) {
              final isSelected = user == selectedValue;

              return ListTile(
                title: Text(
                  user,
                  style: isSelected
                      ? textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        )
                      : textTheme.bodyLarge,
                ),
                trailing: isSelected ? const Icon(Icons.check) : null,
                tileColor: Colors.transparent,
                onTap: () {
                  Navigator.pop(ctx);
                  onSelected(user);
                },
              );
            }),
          ],
        ),
      );
    },
  );
}

// class UsersList extends StatefulWidget {
//   const UsersList({super.key});

//   @override
//   State<UsersList> createState() => _UsersListState();
// }

// class _UsersListState extends State<UsersList> {
//   final List<String> items = ['Sathiya', 'Venis', 'Sandriya', 'Immandriya'];

//   String? selectedValue;

//   @override
//   Widget build(BuildContext context) {
//     return DropdownMenu<String>(
//       width: MediaQuery.of(context).size.width,
//       label: const Text('Category'),
//       hintText: 'Select category',
//       dropdownMenuEntries: items
//           .map((item) => DropdownMenuEntry<String>(value: item, label: item))
//           .toList(),
//       onSelected: (value) {
//         setState(() {
//           selectedValue = value;
//         });
//       },
//     );
//   }
// }
