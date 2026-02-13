import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/wallet/SplitExpense.dart';

Future<SplitExpense?> showEditExpenseBottomSheet(
  BuildContext context,
  SplitExpense expense,
) {
  return showModalBottomSheet<SplitExpense>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EditExpenseBottomSheet(expense: expense),
  );
}

class EditExpenseBottomSheet extends StatefulWidget {
  final SplitExpense expense;

  const EditExpenseBottomSheet({super.key, required this.expense});

  @override
  State<EditExpenseBottomSheet> createState() => _EditExpenseBottomSheetState();
}

class _EditExpenseBottomSheetState extends State<EditExpenseBottomSheet> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense.title);
    _amountController = TextEditingController(
      text: widget.expense.amount.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Edit Expense",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Title"),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                final updated = widget.expense.copyWith(
                  title: _titleController.text.trim(),
                  amount:
                      double.tryParse(_amountController.text) ??
                      widget.expense.amount,
                );

                Navigator.pop(context, updated);
              },
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
