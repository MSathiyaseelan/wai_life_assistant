import 'package:wai_life_assistant/data/enum/lifestyleCategory.dart';

class LifestyleItem {
  final String id;
  final String name;
  final LifestyleCategory category;

  final String? brand;
  final double? price;
  final DateTime? purchaseDate;
  final String? notes;

  // 🚗 Vehicle-only fields
  final String? vehicleType;
  final String? vehicleNumber;
  final String? owner;
  final String? model;

  LifestyleItem({
    required this.id,
    required this.name,
    required this.category,
    this.brand,
    this.price,
    this.purchaseDate,
    this.notes,
    this.vehicleType,
    this.vehicleNumber,
    this.owner,
    this.model,
  });
}
