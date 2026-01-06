import 'package:flutter/material.dart';

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
    return DropdownMenu<String>(
      width: MediaQuery.of(context).size.width,
      label: const Text('Category'),
      hintText: 'Select category',
      dropdownMenuEntries: items
          .map((item) => DropdownMenuEntry<String>(value: item, label: item))
          .toList(),
      onSelected: (value) {
        setState(() {
          selectedValue = value;
        });
      },
    );
  }
}
