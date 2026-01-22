enum GroceryCategory {
  all,
  vegetables,
  fruits,
  dairy,
  staples,
  snacks,
  spices,
  grains,
  others,
}

extension GroceryCategoryX on GroceryCategory {
  String get label {
    switch (this) {
      case GroceryCategory.all:
        return 'All';
      case GroceryCategory.vegetables:
        return 'Vegetables';
      case GroceryCategory.fruits:
        return 'Fruits';
      case GroceryCategory.dairy:
        return 'Dairy';
      case GroceryCategory.grains:
        return 'Grains';
      case GroceryCategory.spices:
        return 'Spices';
      case GroceryCategory.staples:
        return 'Staples';
      case GroceryCategory.snacks:
        return 'Snacks';
      case GroceryCategory.others:
        return 'Others';
    }
  }
}
