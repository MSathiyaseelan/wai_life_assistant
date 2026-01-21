import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MealPlannerDetailPage extends StatefulWidget {
  final DateTime date;

  const MealPlannerDetailPage({super.key, required this.date});

  @override
  State<MealPlannerDetailPage> createState() => _MealPlannerDetailPageState();
}

class _MealPlannerDetailPageState extends State<MealPlannerDetailPage> {
  bool isEditing = false;

  late TextEditingController breakfastCtrl;
  late TextEditingController lunchCtrl;
  late TextEditingController snacksCtrl;
  late TextEditingController dinnerCtrl;

  @override
  void initState() {
    super.initState();

    // Later replace with DB values
    breakfastCtrl = TextEditingController(text: 'Idli');
    lunchCtrl = TextEditingController(text: 'Rice & Curry');
    snacksCtrl = TextEditingController(text: 'Fruits');
    dinnerCtrl = TextEditingController(text: 'Chapati');
  }

  @override
  void dispose() {
    breakfastCtrl.dispose();
    lunchCtrl.dispose();
    snacksCtrl.dispose();
    dinnerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEEE, dd MMM').format(widget.date)),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              setState(() {
                if (isEditing) {
                  // 🔥 Save logic (DB / API later)
                }
                isEditing = !isEditing;
              });
            },
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MealField(
            label: 'Breakfast',
            controller: breakfastCtrl,
            isEditing: isEditing,
          ),
          _MealField(
            label: 'Lunch',
            controller: lunchCtrl,
            isEditing: isEditing,
          ),
          _MealField(
            label: 'Snacks',
            controller: snacksCtrl,
            isEditing: isEditing,
          ),
          _MealField(
            label: 'Dinner',
            controller: dinnerCtrl,
            isEditing: isEditing,
          ),
        ],
      ),
    );
  }
}

class _MealField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isEditing;

  const _MealField({
    required this.label,
    required this.controller,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),

          isEditing
              ? TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                )
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(controller.text),
                ),
        ],
      ),
    );
  }
}
