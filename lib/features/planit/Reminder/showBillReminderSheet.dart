// sheets/bill_reminder_sheet.dart
import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/planit/familyAssigneeSelector.dart';

void showBillReminderSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Pay Bill',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),

            Text('Assign to'),
            FamilyAssigneeSelector(members: ['Dad', 'Mom', 'Rahul']),

            SizedBox(height: 24),
            // TODO: Due date, recurrence, amount, save button
          ],
        ),
      );
    },
  );
}
