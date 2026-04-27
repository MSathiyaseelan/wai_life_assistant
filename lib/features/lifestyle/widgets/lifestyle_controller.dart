import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyleItem.dart';
import 'package:wai_life_assistant/data/enum/lifestyleCategory.dart';

class LifestyleController extends ChangeNotifier {
  LifestyleCategory selectedCategory = LifestyleCategory.vehicle;

  final List<LifestyleItem> _items = [];

  List<LifestyleItem> get filteredItems =>
      _items.where((e) => e.category == selectedCategory).toList();

  void changeCategory(LifestyleCategory category) {
    selectedCategory = category;
    notifyListeners();
  }

  void addItem(LifestyleItem item) {
    _items.add(item);
    notifyListeners();
  }
}
