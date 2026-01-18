import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/wallet/upcominggiftplantype.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/gifttracker/showaddupcomingfunctionbottomsheet.dart';

class UpcomingFunctionsPage extends StatefulWidget {
  const UpcomingFunctionsPage({super.key});

  @override
  State<UpcomingFunctionsPage> createState() => _UpcomingFunctionsPageState();
}

class _UpcomingFunctionsPageState extends State<UpcomingFunctionsPage> {
  /// mock attendance state
  final List<bool> _attendance = List.generate(5, (_) => false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Functions')),

      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _UpcomingFunctionCard(
            functionName: 'Wedding',
            person: 'Ramesh',
            location: 'Chennai',
            date: DateTime.now().add(const Duration(days: 20)),
            planType: UpcomingGiftPlanType.money,
            attended: _attendance[index],
            onAttendanceChanged: (v) {
              setState(() => _attendance[index] = v);
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showAddUpcomingFunctionBottomSheet(context: context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _UpcomingFunctionCard extends StatelessWidget {
  final String functionName;
  final String person;
  final String location;
  final DateTime date;
  final UpcomingGiftPlanType planType;

  final bool attended;
  final ValueChanged<bool> onAttendanceChanged;

  const _UpcomingFunctionCard({
    required this.functionName,
    required this.person,
    required this.location,
    required this.date,
    required this.planType,
    required this.attended,
    required this.onAttendanceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(blurRadius: 6, color: Colors.black12, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Function name + attendance toggle
          Row(
            children: [
              Expanded(child: Text(functionName, style: textTheme.titleMedium)),
              Checkbox(
                value: attended,
                onChanged: (v) => onAttendanceChanged(v ?? false),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 4),

          /// Person
          Text(
            'For: $person',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 8),

          /// Info row
          Row(
            children: [
              Icon(Icons.place, size: 16, color: colors.primary),
              const SizedBox(width: 4),
              Expanded(child: Text(location)),

              const SizedBox(width: 12),

              Icon(Icons.calendar_today, size: 16, color: colors.primary),
              const SizedBox(width: 4),
              Text(_formatDate(date)),
            ],
          ),

          const SizedBox(height: 12),

          /// Plan + Attendance status
          Row(
            children: [
              _PlanChip(planType: planType),
              const SizedBox(width: 8),
              _AttendanceStatusChip(attended: attended),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _PlanChip extends StatelessWidget {
  final UpcomingGiftPlanType planType;

  const _PlanChip({required this.planType});

  @override
  Widget build(BuildContext context) {
    final label = switch (planType) {
      UpcomingGiftPlanType.money => 'Money',
      UpcomingGiftPlanType.jewel => 'Jewel',
      UpcomingGiftPlanType.gift => 'Gift',
      UpcomingGiftPlanType.giftCard => 'Gift Card',
      UpcomingGiftPlanType.undecided => 'Not decided',
    };

    return Chip(
      label: Text(label),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
    );
  }
}

class _AttendanceStatusChip extends StatelessWidget {
  final bool attended;

  const _AttendanceStatusChip({required this.attended});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Chip(
      label: Text(attended ? 'Attended' : 'Not Attended'),
      backgroundColor: attended
          ? colors.primaryContainer
          : colors.errorContainer,
      labelStyle: TextStyle(
        color: attended ? colors.onPrimaryContainer : colors.onErrorContainer,
      ),
    );
  }
}
