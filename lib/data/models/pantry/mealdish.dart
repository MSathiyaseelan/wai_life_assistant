enum MealType { breakfast, lunch, dinner, snacks }

class MealDish {
  final String id;
  final String name;
  final List<String> ingredients;
  final Set<MealType> suitableFor;
  final String cuisine; // Indian, Chettinad, Kerala, etc.
  final String? referenceLink;

  MealDish({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.suitableFor,
    required this.cuisine,
    this.referenceLink,
  });
}
