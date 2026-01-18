import 'package:flutter/material.dart';
import 'package:wai_life_assistant/shared/bottom_sheets/app_bottom_sheet.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';

void showAddMembersBottomSheet({
  required BuildContext context,
  required List<String> selectedMembers,
  required ValueChanged<List<String>> onDone,
}) {
  showAppBottomSheet(
    context: context,
    child: _AddMembersContent(initialMembers: selectedMembers, onDone: onDone),
  );
}

class _AddMembersContent extends StatefulWidget {
  final List<String> initialMembers;
  final ValueChanged<List<String>> onDone;

  const _AddMembersContent({
    required this.initialMembers,
    required this.onDone,
  });

  @override
  State<_AddMembersContent> createState() => _AddMembersContentState();
}

class _AddMembersContentState extends State<_AddMembersContent> {
  late List<String> _members;

  /// MOCK – replace with contacts picker you already use
  final List<String> _allContacts = [
    'Sathiya',
    'Venis',
    'Sandriya',
    'Immandriya',
  ];

  @override
  void initState() {
    super.initState();
    _members = List.from(widget.initialMembers);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add Members', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.gapM),

        ..._allContacts.map(
          (c) => CheckboxListTile(
            value: _members.contains(c),
            title: Text(c),
            onChanged: (v) {
              setState(() {
                v == true ? _members.add(c) : _members.remove(c);
              });
            },
          ),
        ),

        const SizedBox(height: AppSpacing.gapM),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDone(_members);
            },
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}
