import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyleItem.dart';
import 'package:wai_life_assistant/data/enum/lifestyleCategory.dart';
import 'package:wai_life_assistant/features/lifestyle/vehicle/VehicleDetailScreen.dart';
import 'package:wai_life_assistant/features/lifestyle/Dress/DressDetailScreen.dart';

class LifestyleItemCard extends StatelessWidget {
  final LifestyleItem item;

  const LifestyleItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openDetail(context),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: textTheme.titleMedium),

              if (item.brand != null) ...[
                const SizedBox(height: 4),
                Text(item.brand!, style: textTheme.bodySmall),
              ],

              const SizedBox(height: 8),

              Row(
                children: [
                  if (item.price != null)
                    Text('₹${item.price!.toStringAsFixed(0)}'),

                  if (item.purchaseDate != null) ...[
                    const SizedBox(width: 12),
                    Text(_dateLabel(), style: textTheme.bodySmall),
                  ],
                ],
              ),

              if (item.notes != null) ...[
                const SizedBox(height: 8),
                Text(item.notes!, style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 🔀 Category-based navigation
  void _openDetail(BuildContext context) {
    Widget screen;

    switch (item.category) {
      case LifestyleCategory.vehicle:
        screen = VehicleDetailScreen(vehicle: item);
        break;

      case LifestyleCategory.dresses:
        screen = DressDetailScreen(item: item);
        break;

      case LifestyleCategory.gadgets:
        //screen = GadgetDetailScreen(item: item);
        screen = DressDetailScreen(item: item);
        break;

      case LifestyleCategory.appliances:
        //screen = ApplianceDetailScreen(item: item);
        screen = DressDetailScreen(item: item);
        break;

      case LifestyleCategory.collections:
        //screen = CollectionDetailScreen(item: item);
        screen = DressDetailScreen(item: item);
        break;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  String _dateLabel() {
    final date = item.purchaseDate!.toLocal().toString().split(' ')[0];

    return item.category == LifestyleCategory.vehicle
        ? 'Registered: $date'
        : 'Bought: $date';
  }
}

// class LifestyleItemCard extends StatelessWidget {
//   final LifestyleItem item;

//   const LifestyleItemCard({super.key, required this.item});

//   @override
//   Widget build(BuildContext context) {
//     final textTheme = Theme.of(context).textTheme;

//     return Card(
//       elevation: 1,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(item.name, style: textTheme.titleMedium),

//             if (item.brand != null) ...[
//               const SizedBox(height: 4),
//               Text(item.brand!, style: textTheme.bodySmall),
//             ],

//             const SizedBox(height: 8),

//             Row(
//               children: [
//                 if (item.price != null)
//                   Text('₹${item.price!.toStringAsFixed(0)}'),

//                 if (item.purchaseDate != null) ...[
//                   const SizedBox(width: 12),
//                   Text(
//                     'Bought: ${item.purchaseDate!.toLocal().toString().split(' ')[0]}',
//                     style: textTheme.bodySmall,
//                   ),
//                 ],
//               ],
//             ),

//             if (item.notes != null) ...[
//               const SizedBox(height: 8),
//               Text(item.notes!, style: textTheme.bodySmall),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }
