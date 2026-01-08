import 'package:flutter/material.dart';

class CashFields extends StatelessWidget {
  const CashFields();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Amount', prefixText: '₹ '),
        ),
        SizedBox(height: 12),
        // DropdownButtonFormField<String>(
        //   decoration: InputDecoration(labelText: 'Cash Source'),
        //   items: [
        //     DropdownMenuItem(value: 'counter', child: Text('Counter')),
        //     DropdownMenuItem(value: 'hand', child: Text('In Hand')),
        //   ],
        //   onChanged: null,
        // ),
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Price', prefixText: '₹ '),
        ),
        SizedBox(height: 12),
        TextField(decoration: InputDecoration(labelText: 'Notes (optional)')),
      ],
    );
  }
}
