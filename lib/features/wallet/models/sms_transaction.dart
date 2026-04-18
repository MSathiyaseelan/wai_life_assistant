import 'package:wai_life_assistant/data/models/wallet/flow_models.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/ai/nlp_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SMSTransaction — parsed result from a bank SMS
// ─────────────────────────────────────────────────────────────────────────────

class SMSTransaction {
  final bool isTransaction;
  final String transactionType; // 'debit' | 'credit'
  final double amount;
  final String? merchant;
  final String? accountLast4;
  final String? bankName;
  final double? availableBalance;
  final String transactionDate;
  final String? transactionTime;
  final String? referenceNumber;
  final String category;
  final String? paymentMode;
  final double confidence;

  const SMSTransaction({
    required this.isTransaction,
    required this.transactionType,
    required this.amount,
    this.merchant,
    this.accountLast4,
    this.bankName,
    this.availableBalance,
    required this.transactionDate,
    this.transactionTime,
    this.referenceNumber,
    required this.category,
    this.paymentMode,
    required this.confidence,
  });

  String get title => merchant ?? 'Unknown Transaction';
  bool get isExpense => transactionType == 'debit';
  bool get isIncome => transactionType == 'credit';
  bool get isHighConfidence => confidence >= 0.85;

  factory SMSTransaction.fromJson(Map<String, dynamic> json) {
    return SMSTransaction(
      isTransaction:    json['is_transaction'] as bool? ?? false,
      transactionType:  json['transaction_type'] as String? ?? 'debit',
      amount:           (json['amount'] as num?)?.toDouble() ?? 0.0,
      merchant:         json['merchant'] as String?,
      accountLast4:     json['account_last4'] as String?,
      bankName:         json['bank_name'] as String?,
      availableBalance: (json['available_balance'] as num?)?.toDouble(),
      transactionDate:  json['transaction_date'] as String? ??
          DateTime.now().toIso8601String().split('T')[0],
      transactionTime:  json['transaction_time'] as String?,
      referenceNumber:  json['reference_number'] as String?,
      category:         json['category'] as String? ?? 'Other',
      paymentMode:      json['payment_mode'] as String?,
      confidence:       (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'is_transaction':    isTransaction,
    'transaction_type':  transactionType,
    'amount':            amount,
    'merchant':          merchant,
    'account_last4':     accountLast4,
    'bank_name':         bankName,
    'available_balance': availableBalance,
    'transaction_date':  transactionDate,
    'transaction_time':  transactionTime,
    'reference_number':  referenceNumber,
    'category':          category,
    'payment_mode':      paymentMode,
    'confidence':        confidence,
  };

  /// Convert to ParsedIntent so IntentConfirmSheet can pre-fill the form.
  ParsedIntent toParsedIntent() {
    final flowType = isExpense ? FlowType.expense : FlowType.income;

    PayMode? payMode;
    final pm = paymentMode?.toLowerCase() ?? '';
    if (pm.contains('cash') || pm.contains('atm')) {
      payMode = PayMode.cash;
    } else if (pm.isNotEmpty) {
      payMode = PayMode.online;
    }

    DateTime? date;
    try {
      date = DateTime.parse(transactionDate);
    } catch (_) {}

    return ParsedIntent(
      flowType:   flowType,
      amount:     amount,
      category:   category,
      title:      merchant,
      payMode:    payMode,
      date:       date,
      confidence: confidence,
    );
  }
}
