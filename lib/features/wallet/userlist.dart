import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'userlist_bottomsheet_content.dart';
import 'package:wai_life_assistant/shared/bottom_sheets/app_bottom_sheet.dart';
import 'package:wai_life_assistant/shared/bottom_sheets/arrowpicker.dart';

class UsersList extends StatefulWidget {
  const UsersList({super.key});

  @override
  State<UsersList> createState() => _UsersListState();
}

class _UsersListState extends State<UsersList> {
  final items = ['Sathiya', 'Venis', 'Sandriya', 'Immandriya'];
  String? selectedValue;

  @override
  Widget build(BuildContext context) {
    return ArrowPicker(
      placeholder: 'Select user',
      value: selectedValue,
      onTap: () {
        showUsersBottomSheet(
          context: context,
          users: items,
          selectedValue: selectedValue,
          onSelected: (v) => setState(() => selectedValue = v),
        );
      },
    );
  }
}

void showUsersBottomSheet({
  required BuildContext context,
  required List<String> users,
  String? selectedValue,
  required ValueChanged<String> onSelected,
}) {
  showAppBottomSheet(
    context: context,
    child: UsersBottomSheetContent(
      users: users,
      selectedValue: selectedValue,
      onSelected: onSelected,
    ),
  );
}


// void showUsersBottomSheet({
//   required BuildContext context,
//   required List<String> users,
//   String? selectedValue,
//   required ValueChanged<String> onSelected,
// }) {
//   final width = MediaQuery.of(context).size.width;

//   double maxWidth;
//   if (width >= AppSpacing.maxDesktopMaxWidth) {
//     maxWidth = AppSpacing.desktopMaxWidth;
//   } else if (width >= AppSpacing.maxTabletMaxWidth) {
//     maxWidth = AppSpacing.tabletMaxWidth;
//   } else {
//     maxWidth = width;
//   }

//   showModalBottomSheet(
//     context: context,
//     useRootNavigator: true,
//     barrierColor: Colors.transparent,
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     constraints: BoxConstraints(maxWidth: maxWidth),
//     builder: (ctx) {
//       final textTheme = Theme.of(ctx).textTheme;

//       return Container(
//         width: double.infinity,
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: Theme.of(ctx).colorScheme.surface,
//           borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
//           boxShadow: [
//             BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(0.15)),
//           ],
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Select User', style: textTheme.titleMedium),

//             const SizedBox(height: AppSpacing.gapM),

//             ...users.map((user) {
//               final isSelected = user == selectedValue;

//               return ListTile(
//                 title: Text(
//                   user,
//                   style: isSelected
//                       ? textTheme.bodyLarge?.copyWith(
//                           fontWeight: FontWeight.w600,
//                         )
//                       : textTheme.bodyLarge,
//                 ),
//                 trailing: isSelected ? const Icon(Icons.check) : null,
//                 tileColor: Colors.transparent,
//                 onTap: () {
//                   Navigator.pop(ctx);
//                   onSelected(user);
//                 },
//               );
//             }),
//           ],
//         ),
//       );
//     },
//   );
// }