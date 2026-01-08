import 'package:flutter/material.dart';

class UpiFields extends StatelessWidget {
  const UpiFields();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Amount', prefixText: '₹ '),
        ),
        SizedBox(height: 10),
        TextField(decoration: InputDecoration(labelText: 'UPI Reference ID')),
        SizedBox(height: 10),
        TextField(decoration: InputDecoration(labelText: 'Notes (optional)')),
      ],
    );
  }
}
