import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wai_life_assistant/features/planit/specialDay/specialDaysController.dart';
import 'package:wai_life_assistant/data/enum/specialDayType.dart';
import 'package:wai_life_assistant/data/models/planit/specialDay.dart';
import 'package:intl/intl.dart';
import 'addSpecialDaySheet.dart';

class SpecialDaysPage extends StatelessWidget {
  const SpecialDaysPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SpecialDaysController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Special Days'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const AddSpecialDaySheet(),
              );
            },
          ),
        ],
      ),
      body: controller.items.isEmpty
          ? const Center(child: Text('No special days added'))
          : ListView.builder(
              itemCount: controller.items.length,
              itemBuilder: (_, index) {
                final item = controller.items[index];
                final days = controller.daysRemaining(item);

                return ListTile(
                  leading: const Icon(Icons.cake),
                  title: Text(item.title),
                  subtitle: Text(
                    days == 0 ? '🎉 Today!' : '⏳ $days days to go',
                  ),
                );
              },
            ),
    );
  }
}

// class _SpecialDayTile extends StatelessWidget {
//   final SpecialDay day;

//   const _SpecialDayTile({required this.day});

//   @override
//   Widget build(BuildContext context) {
//     final icon = switch (day.type) {
//       SpecialDayType.birthday => Icons.cake,
//       SpecialDayType.anniversary => Icons.favorite,
//       SpecialDayType.wedding => Icons.ring_volume,
//       SpecialDayType.event => Icons.event,
//     };

//     return Card(
//       child: ListTile(
//         leading: Icon(icon),
//         title: Text(day.title),
//         subtitle: Text(DateFormat('dd MMM yyyy').format(day.date)),
//         trailing: const Icon(Icons.chevron_right),
//       ),
//     );
//   }
// }

// class _EmptySpecialDays extends StatelessWidget {
//   const _EmptySpecialDays();

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: const [
//           Icon(Icons.cake_outlined, size: 48, color: Colors.grey),
//           SizedBox(height: 8),
//           Text('No special days added yet'),
//         ],
//       ),
//     );
//   }
// }
