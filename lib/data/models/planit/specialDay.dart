import 'package:wai_life_assistant/data/enum/specialDayType.dart';

class SpecialDay {
  final String id;
  final String title;
  final DateTime date;
  final SpecialDayType type;
  final bool repeatYearly;
  final int reminderDaysBefore;

  SpecialDay({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    this.repeatYearly = false,
    this.reminderDaysBefore = 1,
  });
}
