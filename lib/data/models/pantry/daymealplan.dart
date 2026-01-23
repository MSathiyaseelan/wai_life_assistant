class DayMealPlan {
  final String? breakfast;
  final String? lunch;
  final String? dinner;
  final String? snacks;

  const DayMealPlan({this.breakfast, this.lunch, this.dinner, this.snacks});

  bool get isEmpty =>
      breakfast == null && lunch == null && dinner == null && snacks == null;
}
