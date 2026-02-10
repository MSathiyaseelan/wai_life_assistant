import 'package:flutter/material.dart';

class CashFields extends StatelessWidget {
  final TextEditingController amountController;
  final TextEditingController purposeController;
  final TextEditingController notesController;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;

  const CashFields({
    super.key,
    required this.amountController,
    required this.purposeController,
    required this.notesController,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Amount
        TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '₹ ',
          ),
        ),

        const SizedBox(height: 12),

        // Purpose
        TextField(
          controller: purposeController,
          decoration: const InputDecoration(
            labelText: 'Purpose',
            hintText: 'Tea, Taxi, Dinner...',
          ),
        ),

        const SizedBox(height: 12),

        // Category
        DropdownButtonFormField<String>(
          value: selectedCategory,
          decoration: const InputDecoration(labelText: 'Category'),
          items: const [
            DropdownMenuItem(value: 'Food', child: Text('Food')),
            DropdownMenuItem(value: 'Transport', child: Text('Transport')),
            DropdownMenuItem(value: 'Shopping', child: Text('Shopping')),
            DropdownMenuItem(value: 'Bills', child: Text('Bills')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: onCategoryChanged,
        ),

        const SizedBox(height: 12),

        // Notes
        TextField(
          controller: notesController,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
      ],
    );
  }
}
