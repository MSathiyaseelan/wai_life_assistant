import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/planit/specialDay.dart';

class SpecialDaysController extends ChangeNotifier {
  final List<SpecialDay> _items = [];

  List<SpecialDay> get items => _items;

  void add(SpecialDay day) {
    _items.add(day);
    notifyListeners();
  }

  int daysRemaining(SpecialDay day) {
    final now = DateTime.now();
    final next = DateTime(now.year, day.date.month, day.date.day);

    final target = day.repeatYearly && next.isBefore(now)
        ? DateTime(now.year + 1, day.date.month, day.date.day)
        : next;

    return target.difference(now).inDays;
  }
}
