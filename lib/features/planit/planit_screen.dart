import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';

class PlanItScreen extends StatelessWidget {
  const PlanItScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppText.planItTitle)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 15,
        itemBuilder: (_, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text("Task ${index + 1}"),
              subtitle: const Text("Plan description"),
              trailing: const Icon(Icons.more_vert),
            ),
          );
        },
      ),
    );
  }
}
