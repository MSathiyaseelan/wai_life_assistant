import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wai_life_assistant/data/models/planit/specialDay.dart';
import 'package:wai_life_assistant/data/enum/specialDayType.dart';
import 'package:intl/intl.dart';
import 'specialDaysController.dart';

class AddSpecialDaySheet extends StatefulWidget {
  const AddSpecialDaySheet({super.key});

  @override
  State<AddSpecialDaySheet> createState() => _AddSpecialDaySheetState();
}

class _AddSpecialDaySheetState extends State<AddSpecialDaySheet> {
  final titleCtrl = TextEditingController();
  DateTime date = DateTime.now();
  bool repeatYearly = true;
  int reminderDays = 3;
  SpecialDayType type = SpecialDayType.birthday;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SpecialDaysController>();

    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: 'Title'),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: SpecialDayType.values.map((t) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _SpecialDayTile(
                          type: t,
                          selected: type,
                          onTap: () {
                            setState(() => type = t);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          SwitchListTile(
            title: const Text('Repeat yearly'),
            value: repeatYearly,
            onChanged: (v) => setState(() => repeatYearly = v),
          ),

          DropdownButtonFormField<int>(
            value: reminderDays,
            items: const [
              DropdownMenuItem(value: 0, child: Text('On the day')),
              DropdownMenuItem(value: 1, child: Text('1 day before')),
              DropdownMenuItem(value: 3, child: Text('3 days before')),
            ],
            onChanged: (v) => setState(() => reminderDays = v!),
          ),

          ElevatedButton(
            child: const Text('Save'),
            onPressed: () {
              controller.add(
                SpecialDay(
                  id: DateTime.now().toString(),
                  title: titleCtrl.text,
                  date: date,
                  type: type,
                  repeatYearly: repeatYearly,
                  reminderDaysBefore: reminderDays,
                ),
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _SpecialDayTile extends StatelessWidget {
  final SpecialDayType type;
  final SpecialDayType selected;
  final VoidCallback onTap;

  const _SpecialDayTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = type == selected;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _iconForType(type),
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            ),
            const SizedBox(height: 6),
            Text(
              _labelForType(type),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(SpecialDayType type) {
    switch (type) {
      case SpecialDayType.birthday:
        return Icons.cake;
      case SpecialDayType.anniversary:
        return Icons.favorite;
      case SpecialDayType.wedding:
        return Icons.ring_volume;
      case SpecialDayType.appointment:
        return Icons.event;
      case SpecialDayType.event:
        return Icons.celebration;
      case SpecialDayType.school:
        return Icons.school;
    }
  }

  String _labelForType(SpecialDayType type) {
    switch (type) {
      case SpecialDayType.birthday:
        return 'Birthday';
      case SpecialDayType.anniversary:
        return 'Anniversary';
      case SpecialDayType.wedding:
        return 'Wedding';
      case SpecialDayType.appointment:
        return 'Appointment';
      case SpecialDayType.event:
        return 'Event';
      case SpecialDayType.school:
        return 'School';
    }
  }
}
