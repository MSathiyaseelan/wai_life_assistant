import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FamilyAssigneeSelector extends StatefulWidget {
  final List<String> members;
  final ValueChanged<String>? onSelected;

  const FamilyAssigneeSelector({
    super.key,
    required this.members,
    this.onSelected,
  });

  @override
  State<FamilyAssigneeSelector> createState() => _FamilyAssigneeSelectorState();
}

class _FamilyAssigneeSelectorState extends State<FamilyAssigneeSelector> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: widget.members.map((name) {
        final isSelected = selected == name;

        return ChoiceChip(
          label: Text(name),
          avatar: CircleAvatar(child: Text(name[0])),
          selected: isSelected,
          onSelected: (_) {
            HapticFeedback.selectionClick();
            setState(() => selected = name);
            widget.onSelected?.call(name);
          },
        );
      }).toList(),
    );
  }
}
