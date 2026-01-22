import '../../enum/grocerycategory.dart';
import '../../enum/storagetype.dart';

class GroceryItem {
  final String id;
  final String name;
  final GroceryCategory category;
  final double quantity;
  final String unit; // kg, litre, pcs
  final StorageType storage;
  final DateTime? expiryDate;

  GroceryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.storage,
    this.expiryDate,
  });

  bool get isOut => quantity <= 0;
  bool get isLow => quantity > 0 && quantity <= 1;
  bool get isExpiringSoon =>
      expiryDate != null && expiryDate!.difference(DateTime.now()).inDays <= 2;
}
