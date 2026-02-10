import 'package:wai_life_assistant/data/enum/wallet_enums.dart';

class WalletTransaction {
  final WalletType walletType;
  final WalletAction action;
  final double amount;
  final String purpose;
  final String? category;
  final String? notes;

  WalletTransaction({
    required this.walletType,
    required this.action,
    required this.amount,
    required this.purpose,
    this.category,
    this.notes,
  });
}
