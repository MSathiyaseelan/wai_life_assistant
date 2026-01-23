import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';
import 'package:wai_life_assistant/features/planit/bottomSheet/showPlanItBottomSheet.dart';

class PlanItScreen extends StatefulWidget {
  const PlanItScreen({super.key});

  @override
  State<PlanItScreen> createState() => _PlanItScreenState();
}

class _PlanItScreenState extends State<PlanItScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppText.planItTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showPlanItBottomSheet(context);
            },
          ),
        ],
      ),
      //appBar: AppBar(title: const Text(AppText.planItTitle)),
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
