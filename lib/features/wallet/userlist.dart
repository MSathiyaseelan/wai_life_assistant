import 'package:flutter/material.dart';
import 'bottomsheet/userlist_bottomsheet_content.dart';
import 'package:wai_life_assistant/shared/bottom_sheets/app_bottom_sheet.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/arrowpicker.dart';

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
