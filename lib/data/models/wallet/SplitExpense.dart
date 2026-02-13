class SplitExpense {
  final String title;
  final double amount;
  final String description;
  final String paidBy;
  final String? category;
  final DateTime createdAt;
  final Map<String, double> splitMap;

  SplitExpense({
    required this.amount,
    this.title = '',
    required this.description,
    required this.paidBy,
    this.category,
    required this.createdAt,
    required this.splitMap,
  });

  SplitExpense copyWith({String? title, double? amount}) {
    return SplitExpense(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      description: this.description,
      paidBy: this.paidBy,
      category: this.category,
      createdAt: this.createdAt,
      splitMap: this.splitMap,
    );
  }
}
