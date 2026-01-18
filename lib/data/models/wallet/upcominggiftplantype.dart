enum UpcomingGiftPlanType { money, jewel, gift, giftCard, undecided }

class UpcomingFunction {
  final String functionName;
  final String personName;
  final String location;
  final DateTime date;
  final UpcomingGiftPlanType planType;
  final String? notes;
  bool attended;

  UpcomingFunction({
    required this.functionName,
    required this.personName,
    required this.location,
    required this.date,
    required this.planType,
    this.notes,
    this.attended = false,
  });
}
