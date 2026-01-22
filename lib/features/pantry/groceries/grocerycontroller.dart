import 'package:flutter/material.dart';
import '../../../data/models/pandry/groceryitem.dart';
import '../../../data/enum/storagetype.dart';

class GroceryController extends ChangeNotifier {
  final List<GroceryItem> _items = [];

  List<GroceryItem> get items => _items;

  List<GroceryItem> get buyNow =>
      _items.where((e) => e.isOut || e.isLow).toList();

  void markAsBought(GroceryItem boughtItem) {
    final index = _items.indexWhere(
      (e) => e.name.toLowerCase() == boughtItem.name.toLowerCase(),
    );

    if (index != -1) {
      // Item exists → update quantity
      _items[index] = GroceryItem(
        id: _items[index].id,
        name: _items[index].name,
        category: _items[index].category,
        quantity: _items[index].quantity + boughtItem.quantity,
        unit: _items[index].unit,
        storage: _items[index].storage,
        expiryDate: boughtItem.expiryDate,
      );
    } else {
      // New item → add to pantry
      _items.add(
        GroceryItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: boughtItem.name,
          category: boughtItem.category,
          quantity: boughtItem.quantity,
          unit: boughtItem.unit,
          storage: StorageType.pantry,
          expiryDate: boughtItem.expiryDate,
        ),
      );
    }

    notifyListeners();
  }

  void consumeItem(GroceryItem item, double amountUsed) {
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      final current = _items[index];
      final newQuantity = (current.quantity - amountUsed).clamp(
        0.0,
        double.infinity,
      );

      // Replace the item with updated quantity
      _items[index] = GroceryItem(
        id: current.id,
        name: current.name,
        category: current.category,
        quantity: newQuantity,
        unit: current.unit,
        storage: current.storage,
        expiryDate: current.expiryDate,
      );

      // Notify UI listeners to rebuild
      notifyListeners();
    }
  }
}

//How to use ConsumeItemSheet in other pages
//From your Meal Planner (or any place you want the user to mark consumption):
// InkWell(
//   onTap: () {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (_) => ConsumeItemSheet(
//         item: groceryItem, // the item being consumed
//         controller: groceryController, // your instance of GroceryController
//       ),
//     );
//   },
//   child: ListTile(
//     title: Text(groceryItem.name),
//     subtitle: Text('${groceryItem.quantity} ${groceryItem.unit} left'),
//   ),
// ),
