import 'package:flutter/material.dart';

class Reminder {
  final String id;
  String title;
  DateTime dateTime;
  String repeat;

  Reminder({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.repeat,
  });

  //String timeLabel(BuildContext context) => time.format(context);
  /// Localized readable label
  String timeLabel(BuildContext context) {
    final time = TimeOfDay.fromDateTime(dateTime).format(context);
    final date = MaterialLocalizations.of(context).formatMediumDate(dateTime);
    return '$date • $time';
  }

  bool get isToday {
    final now = DateTime.now();
    return now.year == dateTime.year &&
        now.month == dateTime.month &&
        now.day == dateTime.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return tomorrow.year == dateTime.year &&
        tomorrow.month == dateTime.month &&
        tomorrow.day == dateTime.day;
  }
}
