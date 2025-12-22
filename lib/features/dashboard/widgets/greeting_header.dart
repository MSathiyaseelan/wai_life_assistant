import 'package:flutter/material.dart';

class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("Good Morning 👋", style: TextStyle(fontSize: 14)),
            SizedBox(height: 4),
            Text(
              "Sathiya",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Spacer(),
        const CircleAvatar(radius: 22, backgroundImage: AssetImage('')),
      ],
    );
  }
}
