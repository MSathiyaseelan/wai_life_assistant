import 'package:flutter/material.dart';
import '../../../data/models/pantry/groceryitem.dart';
import 'grocerycontroller.dart';
import '../../../data/enum/storagetype.dart';
import '../../../data/enum/grocerycategory.dart';

class BuyNowDetailsSheet extends StatelessWidget {
  final List<GroceryItem> items;
  final GroceryController controller;

  const BuyNowDetailsSheet({
    super.key,
    required this.items,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    //final controller = context.read<GroceryController>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 12),

        // Header with actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Items to Buy (${items.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),

              // Add item
              IconButton(
                tooltip: 'Add Item',
                icon: const Icon(Icons.add),
                onPressed: () {
                  _openAddItemSheet(context, controller);
                },
              ),

              // Export
              IconButton(
                tooltip: 'Download',
                icon: const Icon(Icons.download),
                onPressed: () {
                  // TODO: Export PDF / CSV
                },
              ),

              // Share
              IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.share),
                onPressed: () {
                  // TODO: Share list to WhatsApp / other apps
                },
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // List of items
        Flexible(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final item = items[index];
              return CheckboxListTile(
                value: items[index].isOut,
                title: Text(item.name),
                subtitle: Text('${item.quantity} ${item.unit}'),
                secondary: Icon(
                  item.isOut ? Icons.remove_shopping_cart : Icons.warning_amber,
                  color: item.isOut ? Colors.red : Colors.orange,
                ),
                onChanged: (checked) {
                  if (checked == true) {
                    controller.markAsBought(item);
                    // ScaffoldMessenger.of(context).showSnackBar(
                    //   SnackBar(
                    //     content: Text('${item.name} marked as bought'),
                    //     action: SnackBarAction(
                    //       label: 'UNDO',
                    //       onPressed: () {
                    //         // rollback logic
                    //       },
                    //     ),
                    //   ),
                    // );
                    //Navigator.pop(context); // optional: close sheet
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _openAddItemSheet(BuildContext context, GroceryController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        final nameCtrl = TextEditingController();
        final quantityCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Add New Grocery Item',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Item Name'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  controller: quantityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final qty = double.tryParse(quantityCtrl.text) ?? 1;

                  if (name.isNotEmpty) {
                    controller.markAsBought(
                      GroceryItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        category: GroceryCategory.others,
                        quantity: qty,
                        unit: 'pcs',
                        storage: StorageType.pantry,
                      ),
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$name added to pantry')),
                    );
                  }
                },
                child: const Text('Add Item'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// class BuyNowDetailsSheet extends StatelessWidget {
//   final List<GroceryItem> items;

//   const BuyNowDetailsSheet({required this.items});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         // Drag handle
//         const SizedBox(height: 8),
//         Container(
//           width: 40,
//           height: 4,
//           decoration: BoxDecoration(
//             color: Colors.grey.shade400,
//             borderRadius: BorderRadius.circular(8),
//           ),
//         ),
//         const SizedBox(height: 12),

//         // Header
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16),
//           child: Row(
//             children: [
//               Expanded(
//                 child: Text(
//                   'Items to Buy (${items.length})',
//                   style: Theme.of(context).textTheme.titleMedium,
//                 ),
//               ),

//               IconButton(
//                 tooltip: 'Add Item',
//                 icon: const Icon(Icons.add),
//                 onPressed: () {
//                   _openAddItemSheet(context);
//                 },
//               ),

//               IconButton(
//                 tooltip: 'Download',
//                 icon: const Icon(Icons.download),
//                 onPressed: () {
//                   // TODO: Export PDF / CSV
//                 },
//               ),

//               IconButton(
//                 tooltip: 'Share',
//                 icon: const Icon(Icons.share),
//                 onPressed: () {
//                   // TODO: Share list
//                 },
//               ),
//             ],
//           ),
//         ),

//         const Divider(),

//         // List
//         Expanded(
//           child: ListView.separated(
//             padding: const EdgeInsets.all(16),
//             itemCount: items.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 8),
//             itemBuilder: (_, index) {
//               final item = items[index];
//               return CheckboxListTile(
//                 value: false,
//                 title: Text(item.name),
//                 subtitle: Text('${item.quantity} ${item.unit}'),
//                 secondary: const Icon(Icons.shopping_bag),
//                 onChanged: (checked) {
//                   if (checked == true) {
//                     controller.markAsBought(item);
//                     Navigator.pop(context); // optional auto close
//                   }
//                 },
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }

// void _openAddItemSheet(BuildContext context) {
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     shape: const RoundedRectangleBorder(
//       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//     ),
//     builder: (_) => const _AddBuyItemSheet(),
//   );
// }

// class _AddBuyItemSheet extends StatelessWidget {
//   const _AddBuyItemSheet();

//   @override
//   Widget build(BuildContext context) {
//     final nameCtrl = TextEditingController();
//     final qtyCtrl = TextEditingController();

//     return Padding(
//       padding: EdgeInsets.only(
//         left: 16,
//         right: 16,
//         top: 16,
//         bottom: MediaQuery.of(context).viewInsets.bottom + 16,
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const Text(
//             'Add Item to Buy',
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 16),

//           TextField(
//             controller: nameCtrl,
//             decoration: const InputDecoration(
//               labelText: 'Item name',
//               border: OutlineInputBorder(),
//             ),
//           ),
//           const SizedBox(height: 12),

//           TextField(
//             controller: qtyCtrl,
//             keyboardType: TextInputType.number,
//             decoration: const InputDecoration(
//               labelText: 'Quantity (optional)',
//               border: OutlineInputBorder(),
//             ),
//           ),
//           const SizedBox(height: 16),

//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: const Text('Cancel'),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: () {
//                     if (nameCtrl.text.trim().isEmpty) return;

//                     // TODO: Add item to BuyNow list / state
//                     Navigator.pop(context);
//                   },
//                   child: const Text('Add'),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
