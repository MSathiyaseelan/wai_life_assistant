enum AiIntentType {
  addExpense,
  addIncome,
  lend,
  borrow,
  requestMoney,
  createGroup,
  addToGroup,
}

enum SplitType { equal, custom }

enum PaymentMode {
  cash,
  upi,
  card,
  online,
  gpay,
  phonepe,
  paytm,
  bhim,
  amazonpay,
  unknown,
  bankTransfer,
  wallet,
}

enum ExpenseCategory {
  food,
  travel,
  shopping,
  fuel,
  entertainment,
  groceries,
  rent,
  utilities,
  medical,
  others,
}

class AiIntent {
  final AiIntentType type;
  final double amount;
  final String? groupName;
  final PaymentMode? paymentMode;
  final List<String> participants;
  final String? paidBy;
  final SplitType? splitType;
  final String? purpose;
  final ExpenseCategory? category;

  AiIntent({
    required this.type,
    required this.amount,
    this.groupName,
    this.participants = const [],
    this.paymentMode,
    this.paidBy,
    this.splitType,
    this.purpose,
    this.category,
  });

  /// Temporary mock for UI testing
  factory AiIntent.mock(String input) {
    return AiIntent(
      type: AiIntentType.addExpense,
      amount: 800,
      groupName: "Goa Trip",
      participants: ["You", "Ravi", "Arun"],
      paidBy: "Ravi",
      splitType: SplitType.equal,
    );
  }
}
