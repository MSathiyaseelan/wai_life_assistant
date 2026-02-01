import 'package:wai_life_assistant/data/enum/lifestyleCategory.dart';

class LifestyleItem {
  final String id;
  final String name;
  final LifestyleCategory category;
  final String? brand;
  final DateTime? purchaseDate;
  final double? price;
  final String? notes;
  final String? imageUrl;

  LifestyleItem({
    required this.id,
    required this.name,
    required this.category,
    this.brand,
    this.purchaseDate,
    this.price,
    this.notes,
    this.imageUrl,
  });
}
