import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';
import 'package:wai_life_assistant/features/planit/bottomSheet/showPlanItBottomSheet.dart';
import 'package:wai_life_assistant/features/planit/Reminder/showBillReminderSheet.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/features/planit/categoryGridSheet.dart';
import 'package:wai_life_assistant/features/planit/Reminder/reminderListPage.dart';

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
      body: Column(
        children: [
          const _AIInputSection(),
          const _QuickActionChips(),
          const Divider(height: 1),
          const Expanded(child: _TimelineView()),
        ],
      ),
      // body: ListView.builder(
      //   padding: const EdgeInsets.all(16),
      //   itemCount: 15,
      //   itemBuilder: (_, index) {
      //     return Card(
      //       margin: const EdgeInsets.only(bottom: 12),
      //       child: ListTile(
      //         leading: const Icon(Icons.check_circle_outline),
      //         title: Text("Task ${index + 1}"),
      //         subtitle: const Text("Plan description"),
      //         trailing: const Icon(Icons.more_vert),
      //       ),
      //     );
      //   },
      // ),
    );
  }
}

class _AIInputSection extends StatelessWidget {
  const _AIInputSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Plan anything… e.g. Pay school fees every 3 months',
          prefixIcon: const Icon(Icons.auto_awesome),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (value) {
          HapticFeedback.selectionClick();
          // TODO: Send text to AI → parse → open confirmation sheet
          debugPrint('AI Input: $value');
        },
      ),
    );
  }
}

class _QuickActionChips extends StatelessWidget {
  const _QuickActionChips();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(
            context,
            'Reminder',
            Icons.alarm,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReminderListPage()),
            ),
          ),
          _chip(context, 'ToDo', Icons.insert_emoticon, () {}),
          _chip(context, 'Birthday/Wedding Day', Icons.insert_emoticon, () {}),
          _chip(context, 'To-Buy List', Icons.shopping_cart, () {}),
          _chip(
            context,
            'Pay Bills',
            Icons.payments,
            () => showBillReminderSheet(context),
          ),
          _chip(context, 'School', Icons.school, () {}),
          _chip(context, 'Health', Icons.local_hospital, () {}),
          _chip(context, 'Routine', Icons.repeat, () {}),
          _chip(context, 'More', Icons.apps, () => showCategoryGrid(context)),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );
  }
}

class _TimelineView extends StatelessWidget {
  const _TimelineView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _TimelineSection(
          title: 'Today',
          items: [
            _PlanItem(
              icon: Icons.medication,
              title: 'Mom’s medicine',
              subtitle: '8:00 AM · Assigned to Dad',
            ),
          ],
        ),
        _TimelineSection(
          title: 'Tomorrow',
          items: [
            _PlanItem(
              icon: Icons.school,
              title: 'School project submission',
              subtitle: 'Assigned to Rahul',
            ),
          ],
        ),
        _TimelineSection(
          title: 'This Week',
          items: [
            _PlanItem(
              icon: Icons.payments,
              title: 'Electricity bill',
              subtitle: 'Due Friday',
            ),
          ],
        ),
      ],
    );
  }
}

class _TimelineSection extends StatelessWidget {
  final String title;
  final List<_PlanItem> items;

  const _TimelineSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...items,
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PlanItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlanItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.check_circle_outline),
        onTap: () {
          // Open reminder detail
        },
      ),
    );
  }
}
