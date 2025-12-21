import 'package:flutter/material.dart';

class LoggedInUser extends StatefulWidget {
  const LoggedInUser({super.key});

  @override
  State<LoggedInUser> createState() => _LoggedInUserState();
}

class _LoggedInUserState extends State<LoggedInUser> {
  String? selectedCategory;

  // Static values (replace with API later)
  final List<String> categories = [
    'Food',
    'Travel',
    'Shopping',
    'Bills',
    'Entertainment',
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedCategory,
      hint: const Text('Select Category'),
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      items: categories.map((category) {
        return DropdownMenuItem<String>(value: category, child: Text(category));
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedCategory = value;
        });
      },
    );
  }
}
