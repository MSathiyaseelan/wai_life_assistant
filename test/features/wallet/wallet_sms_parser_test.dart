import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/data/models/wallet/flow_models.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/category_detector.dart';
import 'package:wai_life_assistant/features/wallet/models/sms_transaction.dart';
import 'package:wai_life_assistant/features/wallet/services/sms_parser_service.dart';
import 'package:wai_life_assistant/features/wallet/services/sms_regex_parser.dart';

// Use a fixed date so tests that call tryParse without extracting a date
// from the SMS text produce deterministic transactionDate values.
const _kFallback = '2025-06-15';
final _fallbackDate = DateTime(2025, 6, 15);

SMSTransaction? parse(String sms) =>
    SMSRegexParser.tryParse(sms, fallbackDate: _fallbackDate);

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. SMSTransaction — computed getters
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSTransaction — isExpense / isIncome', () {
    const debit = SMSTransaction(
      isTransaction: true,
      transactionType: 'debit',
      amount: 500,
      transactionDate: '2025-06-15',
      category: 'Other',
      confidence: 0.90,
    );
    const credit = SMSTransaction(
      isTransaction: true,
      transactionType: 'credit',
      amount: 500,
      transactionDate: '2025-06-15',
      category: 'Other',
      confidence: 0.90,
    );

    test('debit → isExpense true, isIncome false', () {
      expect(debit.isExpense, isTrue);
      expect(debit.isIncome, isFalse);
    });

    test('credit → isIncome true, isExpense false', () {
      expect(credit.isIncome, isTrue);
      expect(credit.isExpense, isFalse);
    });

    test('unknown type is neither isExpense nor isIncome', () {
      const tx = SMSTransaction(
        isTransaction: true,
        transactionType: 'unknown',
        amount: 100,
        transactionDate: '2025-06-15',
        category: 'Other',
        confidence: 0.5,
      );
      expect(tx.isExpense, isFalse);
      expect(tx.isIncome, isFalse);
    });
  });

  group('SMSTransaction — isHighConfidence', () {
    SMSTransaction withConf(double c) => SMSTransaction(
          isTransaction: true,
          transactionType: 'debit',
          amount: 100,
          transactionDate: '2025-06-15',
          category: 'Other',
          confidence: c,
        );

    test('0.92 → true', () => expect(withConf(0.92).isHighConfidence, isTrue));
    test('0.90 → true', () => expect(withConf(0.90).isHighConfidence, isTrue));
    test('0.88 → true', () => expect(withConf(0.88).isHighConfidence, isTrue));
    test('0.85 → true (boundary inclusive)', () => expect(withConf(0.85).isHighConfidence, isTrue));
    test('0.84 → false', () => expect(withConf(0.84).isHighConfidence, isFalse));
    test('0.65 → false', () => expect(withConf(0.65).isHighConfidence, isFalse));
    test('0.0 → false', () => expect(withConf(0.0).isHighConfidence, isFalse));
  });

  group('SMSTransaction — title getter', () {
    test('merchant present → title = merchant', () {
      const tx = SMSTransaction(
        isTransaction: true,
        transactionType: 'debit',
        amount: 500,
        merchant: 'SWIGGY',
        transactionDate: '2025-06-15',
        category: 'Other',
        confidence: 0.90,
      );
      expect(tx.title, 'SWIGGY');
    });

    test('merchant null → title = "Unknown Transaction"', () {
      const tx = SMSTransaction(
        isTransaction: true,
        transactionType: 'debit',
        amount: 500,
        transactionDate: '2025-06-15',
        category: 'Other',
        confidence: 0.90,
      );
      expect(tx.title, 'Unknown Transaction');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. SMSTransaction.fromJson — field mapping and defaults
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSTransaction.fromJson', () {
    test('all fields present', () {
      final tx = SMSTransaction.fromJson({
        'is_transaction': true,
        'transaction_type': 'credit',
        'amount': 75000.0,
        'merchant': 'TCS LIMITED',
        'account_last4': '7890',
        'bank_name': 'HDFC Bank',
        'available_balance': 120000.0,
        'transaction_date': '2025-03-17',
        'transaction_time': '10:30',
        'reference_number': 'REF123',
        'category': '💼 Salary',
        'payment_mode': 'NEFT',
        'confidence': 0.92,
      });

      expect(tx.isTransaction, isTrue);
      expect(tx.transactionType, 'credit');
      expect(tx.amount, 75000.0);
      expect(tx.merchant, 'TCS LIMITED');
      expect(tx.accountLast4, '7890');
      expect(tx.bankName, 'HDFC Bank');
      expect(tx.availableBalance, 120000.0);
      expect(tx.transactionDate, '2025-03-17');
      expect(tx.transactionTime, '10:30');
      expect(tx.referenceNumber, 'REF123');
      expect(tx.category, '💼 Salary');
      expect(tx.paymentMode, 'NEFT');
      expect(tx.confidence, 0.92);
    });

    test('amount as int → converted to double', () {
      final tx = SMSTransaction.fromJson({
        'is_transaction': true,
        'transaction_type': 'debit',
        'amount': 500,
        'transaction_date': '2025-06-15',
        'category': 'Other',
        'confidence': 0.0,
      });
      expect(tx.amount, 500.0);
      expect(tx.amount, isA<double>());
    });

    test('available_balance as int → converted to double', () {
      final tx = SMSTransaction.fromJson({
        'is_transaction': true,
        'transaction_type': 'debit',
        'amount': 100.0,
        'available_balance': 5000,
        'transaction_date': '2025-06-15',
        'category': 'Other',
        'confidence': 0.0,
      });
      expect(tx.availableBalance, 5000.0);
      expect(tx.availableBalance, isA<double>());
    });

    test('missing amount → defaults to 0.0', () {
      final tx = SMSTransaction.fromJson({
        'is_transaction': true,
        'transaction_type': 'debit',
        'transaction_date': '2025-06-15',
        'category': 'Other',
        'confidence': 0.5,
      });
      expect(tx.amount, 0.0);
    });

    test('missing is_transaction → defaults to false', () {
      final tx = SMSTransaction.fromJson({
        'transaction_type': 'debit',
        'amount': 100.0,
        'transaction_date': '2025-06-15',
        'category': 'Other',
        'confidence': 0.0,
      });
      expect(tx.isTransaction, isFalse);
    });

    test('missing transaction_type → defaults to "debit"', () {
      final tx = SMSTransaction.fromJson({
        'is_transaction': true,
        'amount': 100.0,
        'transaction_date': '2025-06-15',
        'category': 'Other',
        'confidence': 0.0,
      });
      expect(tx.transactionType, 'debit');
    });

    test('missing category → defaults to "Other"', () {
      final tx = SMSTransaction.fromJson({
        'is_transaction': true,
        'transaction_type': 'debit',
        'amount': 100.0,
        'transaction_date': '2025-06-15',
        'confidence': 0.0,
      });
      expect(tx.category, 'Other');
    });

    test('missing confidence → defaults to 0.0', () {
      final tx = SMSTransaction.fromJson({
        'is_transaction': true,
        'transaction_type': 'debit',
        'amount': 100.0,
        'transaction_date': '2025-06-15',
        'category': 'Other',
      });
      expect(tx.confidence, 0.0);
    });

    test('optional fields absent → all null', () {
      final tx = SMSTransaction.fromJson({
        'is_transaction': true,
        'transaction_type': 'debit',
        'amount': 100.0,
        'transaction_date': '2025-06-15',
        'category': 'Other',
        'confidence': 0.0,
      });
      expect(tx.merchant, isNull);
      expect(tx.accountLast4, isNull);
      expect(tx.bankName, isNull);
      expect(tx.availableBalance, isNull);
      expect(tx.transactionTime, isNull);
      expect(tx.referenceNumber, isNull);
      expect(tx.paymentMode, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. SMSTransaction.toJson — round-trip
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSTransaction.toJson', () {
    test('all fields serialised and round-trip via fromJson', () {
      const tx = SMSTransaction(
        isTransaction: true,
        transactionType: 'credit',
        amount: 50000.0,
        merchant: 'TCS LIMITED',
        accountLast4: '7890',
        bankName: 'HDFC Bank',
        availableBalance: 120000.0,
        transactionDate: '2025-03-17',
        transactionTime: '09:00',
        referenceNumber: 'REF456',
        category: '💼 Salary',
        paymentMode: 'NEFT',
        confidence: 0.92,
      );
      final json = tx.toJson();
      final back = SMSTransaction.fromJson(json);

      expect(back.isTransaction, tx.isTransaction);
      expect(back.transactionType, tx.transactionType);
      expect(back.amount, tx.amount);
      expect(back.merchant, tx.merchant);
      expect(back.accountLast4, tx.accountLast4);
      expect(back.bankName, tx.bankName);
      expect(back.availableBalance, tx.availableBalance);
      expect(back.transactionDate, tx.transactionDate);
      expect(back.transactionTime, tx.transactionTime);
      expect(back.referenceNumber, tx.referenceNumber);
      expect(back.category, tx.category);
      expect(back.paymentMode, tx.paymentMode);
      expect(back.confidence, tx.confidence);
    });

    test('null optional fields serialised as null', () {
      const tx = SMSTransaction(
        isTransaction: true,
        transactionType: 'debit',
        amount: 100.0,
        transactionDate: '2025-06-15',
        category: 'Other',
        confidence: 0.65,
      );
      final json = tx.toJson();
      expect(json['merchant'], isNull);
      expect(json['account_last4'], isNull);
      expect(json['bank_name'], isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. SMSTransaction.toParsedIntent
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSTransaction.toParsedIntent — flowType', () {
    test('debit → FlowType.expense', () {
      const tx = SMSTransaction(
        isTransaction: true,
        transactionType: 'debit',
        amount: 500,
        transactionDate: '2025-06-15',
        category: 'Other',
        confidence: 0.90,
      );
      expect(tx.toParsedIntent().flowType, FlowType.expense);
    });

    test('credit → FlowType.income', () {
      const tx = SMSTransaction(
        isTransaction: true,
        transactionType: 'credit',
        amount: 500,
        transactionDate: '2025-06-15',
        category: 'Other',
        confidence: 0.90,
      );
      expect(tx.toParsedIntent().flowType, FlowType.income);
    });
  });

  group('SMSTransaction.toParsedIntent — payMode mapping', () {
    SMSTransaction withPayMode(String? pm) => SMSTransaction(
          isTransaction: true,
          transactionType: 'debit',
          amount: 100,
          transactionDate: '2025-06-15',
          category: 'Other',
          paymentMode: pm,
          confidence: 0.90,
        );

    test('"cash" → PayMode.cash', () => expect(withPayMode('cash').toParsedIntent().payMode, PayMode.cash));
    test('"Cash" (title case) → PayMode.cash', () => expect(withPayMode('Cash').toParsedIntent().payMode, PayMode.cash));
    test('"ATM" → PayMode.cash', () => expect(withPayMode('ATM').toParsedIntent().payMode, PayMode.cash));
    test('"atm withdrawal" → PayMode.cash', () => expect(withPayMode('atm withdrawal').toParsedIntent().payMode, PayMode.cash));
    test('"UPI" (non-empty, not cash/atm) → PayMode.online', () => expect(withPayMode('UPI').toParsedIntent().payMode, PayMode.online));
    test('"NEFT" → PayMode.online', () => expect(withPayMode('NEFT').toParsedIntent().payMode, PayMode.online));
    test('"POS" → PayMode.online', () => expect(withPayMode('POS').toParsedIntent().payMode, PayMode.online));
    test('null → null', () => expect(withPayMode(null).toParsedIntent().payMode, isNull));
    test('empty string → null (isEmpty → pm is empty → else-if not entered)', () {
      expect(withPayMode('').toParsedIntent().payMode, isNull);
    });
  });

  group('SMSTransaction.toParsedIntent — date parsing', () {
    test('valid ISO date string → parsed DateTime', () {
      const tx = SMSTransaction(
        isTransaction: true,
        transactionType: 'debit',
        amount: 100,
        transactionDate: '2025-03-17',
        category: 'Other',
        confidence: 0.90,
      );
      final pi = tx.toParsedIntent();
      expect(pi.date, DateTime(2025, 3, 17));
    });

    test('invalid date string → date is null (parse throws, caught)', () {
      const tx = SMSTransaction(
        isTransaction: true,
        transactionType: 'debit',
        amount: 100,
        transactionDate: 'not-a-date',
        category: 'Other',
        confidence: 0.90,
      );
      expect(tx.toParsedIntent().date, isNull);
    });
  });

  group('SMSTransaction.toParsedIntent — other fields', () {
    const tx = SMSTransaction(
      isTransaction: true,
      transactionType: 'debit',
      amount: 500.0,
      merchant: 'SWIGGY',
      transactionDate: '2025-06-15',
      category: '🍕 Food',
      confidence: 0.92,
    );

    test('amount passed through', () => expect(tx.toParsedIntent().amount, 500.0));
    test('category passed through', () => expect(tx.toParsedIntent().category, '🍕 Food'));
    test('merchant becomes title', () => expect(tx.toParsedIntent().title, 'SWIGGY'));
    test('confidence passed through', () => expect(tx.toParsedIntent().confidence, 0.92));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. SMSRegexParser — HDFC debit pattern
  // "Dear Customer, INR 500.00 debited from A/c XX1234 on 17-03-26. Info: SWIGGY."
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSRegexParser — HDFC debit', () {
    const sms =
        'Dear Customer, INR 500.00 debited from A/c XX1234 on 17-03-26. Info: SWIGGY.';
    late SMSTransaction tx;

    setUpAll(() => tx = parse(sms)!);

    test('returns non-null', () => expect(parse(sms), isNotNull));
    test('isTransaction = true', () => expect(tx.isTransaction, isTrue));
    test('transactionType = debit', () => expect(tx.transactionType, 'debit'));
    test('amount = 500.0', () => expect(tx.amount, 500.0));
    test('merchant = "SWIGGY"', () => expect(tx.merchant, 'SWIGGY'));
    test('accountLast4 = "1234"', () => expect(tx.accountLast4, '1234'));
    test('bankName = "HDFC Bank"', () => expect(tx.bankName, 'HDFC Bank'));
    test('date extracted from SMS: "2026-03-17"', () => expect(tx.transactionDate, '2026-03-17'));
    test('paymentMode = "UPI"', () => expect(tx.paymentMode, 'UPI'));
    test('confidence = 0.92', () => expect(tx.confidence, closeTo(0.92, 0.001)));
    test('category → Food (swiggy keyword)', () => expect(tx.category, '🍕 Food'));
  });

  group('SMSRegexParser — HDFC debit with commas in amount', () {
    const sms =
        'Dear Customer, INR 1,500.00 debited from A/c XX5678. Info: AMAZON.';
    late SMSTransaction tx;
    setUpAll(() => tx = parse(sms)!);

    test('amount with comma: 1,500.00 → 1500.0', () => expect(tx.amount, 1500.0));
    test('merchant = "AMAZON"', () => expect(tx.merchant, 'AMAZON'));
    test('no date in SMS → fallback date used', () => expect(tx.transactionDate, _kFallback));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. SMSRegexParser — HDFC credit pattern
  // "INR 75,000.00 credited to your A/c XX7890 on 17-03-2026 by TCS LIMITED."
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSRegexParser — HDFC credit', () {
    const sms =
        'INR 75,000.00 credited to your A/c XX7890 on 17-03-2026 by TCS LIMITED.';
    late SMSTransaction tx;
    setUpAll(() => tx = parse(sms)!);

    test('returns non-null', () => expect(parse(sms), isNotNull));
    test('transactionType = credit', () => expect(tx.transactionType, 'credit'));
    test('amount with commas: 75,000.00 → 75000.0', () => expect(tx.amount, 75000.0));
    test('accountLast4 = "7890"', () => expect(tx.accountLast4, '7890'));
    test('bankName = "HDFC Bank"', () => expect(tx.bankName, 'HDFC Bank'));
    test('merchant = "TCS LIMITED"', () => expect(tx.merchant, 'TCS LIMITED'));
    test('date extracted: "2026-03-17"', () => expect(tx.transactionDate, '2026-03-17'));
    test('confidence = 0.90', () => expect(tx.confidence, closeTo(0.90, 0.001)));
    test('no paymentMode on credit', () => expect(tx.paymentMode, isNull));
    test('category = "Income" (no matching keyword for "TCS LIMITED")',
        () => expect(tx.category, 'Income'));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. SMSRegexParser — SBI debit pattern
  // "Your A/c no. XX5678 is debited for Rs.1000.00 on 17/03/26 by transfer to RAZORPAY."
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSRegexParser — SBI debit', () {
    const sms =
        'Your A/c no. XX5678 is debited for Rs.1000.00 on 17/03/26 by transfer to RAZORPAY.';
    late SMSTransaction tx;
    setUpAll(() => tx = parse(sms)!);

    test('returns non-null', () => expect(parse(sms), isNotNull));
    test('transactionType = debit', () => expect(tx.transactionType, 'debit'));
    test('amount = 1000.0', () => expect(tx.amount, 1000.0));
    test('accountLast4 = "5678"', () => expect(tx.accountLast4, '5678'));
    test('bankName = "SBI"', () => expect(tx.bankName, 'SBI'));
    test('date from dd/mm/yy: "2026-03-17"', () => expect(tx.transactionDate, '2026-03-17'));
    test('confidence = 0.90', () => expect(tx.confidence, closeTo(0.90, 0.001)));
    test('category = "Other" (RAZORPAY unrecognised)', () => expect(tx.category, 'Other'));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. SMSRegexParser — ICICI debit pattern
  // "ICICI Bank: Rs.850.00 debited from XX9012 on 17-Mar-26 towards ZOMATO ORDER."
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSRegexParser — ICICI debit', () {
    const sms =
        'ICICI Bank: Rs.850.00 debited from XX9012 on 17-Mar-26 towards ZOMATO ORDER.';
    late SMSTransaction tx;
    setUpAll(() => tx = parse(sms)!);

    test('returns non-null', () => expect(parse(sms), isNotNull));
    test('transactionType = debit', () => expect(tx.transactionType, 'debit'));
    test('amount = 850.0', () => expect(tx.amount, 850.0));
    test('accountLast4 = "9012"', () => expect(tx.accountLast4, '9012'));
    test('bankName = "ICICI Bank"', () => expect(tx.bankName, 'ICICI Bank'));
    test('date from dd-MMM-yy: "2026-03-17"', () => expect(tx.transactionDate, '2026-03-17'));
    test('merchant = "ZOMATO ORDER"', () => expect(tx.merchant, 'ZOMATO ORDER'));
    test('paymentMode = "UPI"', () => expect(tx.paymentMode, 'UPI'));
    test('confidence = 0.88', () => expect(tx.confidence, closeTo(0.88, 0.001)));
    test('category = "🍕 Food" (zomato keyword)', () => expect(tx.category, '🍕 Food'));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. SMSRegexParser — Axis debit pattern
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSRegexParser — Axis debit', () {
    // Simplified input so merchant capture doesn't span into the date string.
    const sms = 'Rs.500 debited from Axis Acct XX3456 at DMART.';
    late SMSTransaction tx;
    setUpAll(() => tx = parse(sms)!);

    test('returns non-null', () => expect(parse(sms), isNotNull));
    test('transactionType = debit', () => expect(tx.transactionType, 'debit'));
    test('amount = 500.0', () => expect(tx.amount, 500.0));
    test('accountLast4 = "3456"', () => expect(tx.accountLast4, '3456'));
    test('bankName = "Axis Bank"', () => expect(tx.bankName, 'Axis Bank'));
    test('merchant = "DMART"', () => expect(tx.merchant, 'DMART'));
    test('paymentMode = "POS"', () => expect(tx.paymentMode, 'POS'));
    test('confidence = 0.88', () => expect(tx.confidence, closeTo(0.88, 0.001)));
    test('no date in SMS → fallback', () => expect(tx.transactionDate, _kFallback));
  });

  group('SMSRegexParser — Axis debit merchant capture quirk', () {
    // When the SMS contains "at DMART on 17-03-2026.", [^\.\n]{1,30} captures
    // "DMART on 17-03-2026" (greedy — space is not excluded by [^\.\n]).
    // The date group is then null because the engine is at '.'.
    const sms =
        'Rs.500 debited from Axis Acct XX3456 for POS txn at DMART on 17-03-2026.';

    test('merchant greedily includes " on date" text', () {
      final tx = parse(sms)!;
      expect(tx.merchant, contains('DMART'));
    });

    test('date group is null → fallback date used when at keyword is followed by date', () {
      final tx = parse(sms)!;
      // The date is consumed into the merchant capture, so date group = null.
      expect(tx.transactionDate, _kFallback);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. SMSRegexParser — UPI paid pattern
  // "Rs.500.00 paid to Swiggy India Private Limited via PhonePe."
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSRegexParser — UPI paid', () {
    const sms = 'Rs.500.00 paid to Swiggy India Private Limited via PhonePe.';
    late SMSTransaction tx;
    setUpAll(() => tx = parse(sms)!);

    test('returns non-null', () => expect(parse(sms), isNotNull));
    test('transactionType = debit', () => expect(tx.transactionType, 'debit'));
    test('amount = 500.0', () => expect(tx.amount, 500.0));
    test('merchant = "Swiggy India Private Limited"', () => expect(tx.merchant, 'Swiggy India Private Limited'));
    test('paymentMode = "UPI"', () => expect(tx.paymentMode, 'UPI'));
    test('confidence = 0.90', () => expect(tx.confidence, closeTo(0.90, 0.001)));
    test('date = fallback (UPI paid never extracts date)', () => expect(tx.transactionDate, _kFallback));
    test('no accountLast4 or bankName', () {
      expect(tx.accountLast4, isNull);
      expect(tx.bankName, isNull);
    });
    test('category = "🍕 Food" (swiggy)', () => expect(tx.category, '🍕 Food'));
  });

  group('SMSRegexParser — UPI paid with GPay', () {
    const sms = 'Rs.300.00 paid to BIGBASKET via GPay.';
    test('GPay also matches via UPI paid pattern', () {
      final tx = parse(sms)!;
      expect(tx.transactionType, 'debit');
      expect(tx.amount, 300.0);
      expect(tx.paymentMode, 'UPI');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 11. SMSRegexParser — UPI received pattern
  // "Rs.1000.00 received from Ravi Kumar in your HDFC Bank A/c XX1234 on 17-Mar-26."
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSRegexParser — UPI received', () {
    const sms =
        'Rs.1000.00 received from Ravi Kumar in your HDFC Bank A/c XX1234.';
    late SMSTransaction tx;
    setUpAll(() => tx = parse(sms)!);

    test('returns non-null', () => expect(parse(sms), isNotNull));
    test('transactionType = credit', () => expect(tx.transactionType, 'credit'));
    test('amount = 1000.0', () => expect(tx.amount, 1000.0));
    test('merchant = "Ravi Kumar"', () => expect(tx.merchant, 'Ravi Kumar'));
    test('paymentMode = "UPI"', () => expect(tx.paymentMode, 'UPI'));
    test('category = "Transfer"', () => expect(tx.category, 'Transfer'));
    test('confidence = 0.88', () => expect(tx.confidence, closeTo(0.88, 0.001)));
    test('date = fallback', () => expect(tx.transactionDate, _kFallback));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 12. SMSRegexParser — Salary credit pattern
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSRegexParser — Salary credit', () {
    const sms =
        'Salary of INR 75,000.00 credited to your A/c XX7890 on 17-03-2026 by TCS LIMITED.';
    late SMSTransaction tx;
    setUpAll(() => tx = parse(sms)!);

    test('returns non-null', () => expect(parse(sms), isNotNull));
    test('transactionType = credit', () => expect(tx.transactionType, 'credit'));
    test('amount = 75000.0', () => expect(tx.amount, 75000.0));
    test('merchant = "TCS LIMITED"', () => expect(tx.merchant, 'TCS LIMITED'));
    test('category = "💼 Salary"', () => expect(tx.category, '💼 Salary'));
    test('confidence = 0.92', () => expect(tx.confidence, closeTo(0.92, 0.001)));
  });

  group('SMSRegexParser — Salary credit with payroll keyword', () {
    const sms = 'Payroll INR 50,000.00 credited by INFOSYS LTD.';
    test('payroll keyword also triggers salary pattern', () {
      final tx = parse(sms)!;
      expect(tx.category, '💼 Salary');
      expect(tx.transactionType, 'credit');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 13. SMSRegexParser — Generic debit pattern (fallback)
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSRegexParser — Generic debit', () {
    test('₹ prefix + debited → parsed', () {
      final tx = parse('₹500 debited from your wallet.')!;
      expect(tx.transactionType, 'debit');
      expect(tx.amount, 500.0);
      expect(tx.category, 'Other');
      expect(tx.confidence, closeTo(0.65, 0.001));
      expect(tx.transactionDate, _kFallback);
    });

    test('Rs. prefix + deducted → parsed', () {
      final tx = parse('Rs.300 deducted for recharge.')!;
      expect(tx.transactionType, 'debit');
      expect(tx.amount, 300.0);
    });

    test('INR prefix + withdrawn → parsed', () {
      final tx = parse('INR 2000 withdrawn from ATM.')!;
      expect(tx.transactionType, 'debit');
      expect(tx.amount, 2000.0);
    });

    test('generic debit has no merchant, bankName, accountLast4', () {
      final tx = parse('₹500 debited from your wallet.')!;
      expect(tx.merchant, isNull);
      expect(tx.bankName, isNull);
      expect(tx.accountLast4, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 14. SMSRegexParser — Generic credit pattern (fallback)
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSRegexParser — Generic credit', () {
    test('₹ prefix + credited → parsed', () {
      final tx = parse('₹1200 credited to your account.')!;
      expect(tx.transactionType, 'credit');
      expect(tx.amount, 1200.0);
      expect(tx.category, 'Other');
      expect(tx.confidence, closeTo(0.60, 0.001));
    });

    test('INR + received → parsed', () {
      final tx = parse('INR 500 received in your account.')!;
      expect(tx.transactionType, 'credit');
      expect(tx.amount, 500.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 15. SMSRegexParser — Pattern priority and no-match
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSRegexParser — No match / null', () {
    test('OTP SMS → null', () => expect(parse('Your OTP is 123456. Do not share.'), isNull));
    test('promotional SMS → null', () => expect(parse('Get 50% off on all orders today!'), isNull));
    test('empty string → null', () => expect(parse(''), isNull));
    test('plain text → null', () => expect(parse('Meeting at 3pm today.'), isNull));
  });

  group('SMSRegexParser — Pattern priority', () {
    // HDFC debit (conf=0.92) should win over generic debit (conf=0.65)
    // when both could match the same SMS.
    test('HDFC debit pattern wins over generic', () {
      const sms =
          'INR 500.00 debited from A/c XX1234 on 17-03-26. Info: GROCERY.';
      final tx = parse(sms)!;
      expect(tx.bankName, 'HDFC Bank');
      expect(tx.confidence, closeTo(0.92, 0.001));
    });

    // Salary credit (conf=0.92) should win over generic credit (conf=0.60)
    test('Salary pattern wins over generic credit', () {
      const sms = 'Salary INR 50,000.00 credited by ABC CORP.';
      final tx = parse(sms)!;
      expect(tx.category, '💼 Salary');
      expect(tx.confidence, closeTo(0.92, 0.001));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 16. SMSRegexParser — Date normalisation (via _date private helper)
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSRegexParser — date normalisation via pattern outputs', () {
    test('dd-mm-yy (17-03-26) → 2026-03-17', () {
      const sms = 'INR 100.00 debited from A/c XX1234 on 17-03-26. Info: TEST.';
      expect(parse(sms)!.transactionDate, '2026-03-17');
    });

    test('dd/mm/yy (17/03/26) → 2026-03-17', () {
      const sms = 'A/c no. XX1234 is debited for Rs.100.00 on 17/03/26.';
      expect(parse(sms)!.transactionDate, '2026-03-17');
    });

    test('dd-mm-yyyy (17-03-2026) → 2026-03-17', () {
      const sms =
          'INR 100.00 credited to your A/c XX1234 on 17-03-2026 by ABC CORP.';
      expect(parse(sms)!.transactionDate, '2026-03-17');
    });

    test('dd-MMM-yy (17-Mar-26) → 2026-03-17', () {
      const sms =
          'ICICI Bank: Rs.100.00 debited from XX1234 on 17-Mar-26 towards FOOD.';
      expect(parse(sms)!.transactionDate, '2026-03-17');
    });

    test('month padding: 1-Jan-26 → 2026-01-01', () {
      const sms = 'A/c no. XX1234 is debited for Rs.200.00 on 1/01/26.';
      expect(parse(sms)!.transactionDate, '2026-01-01');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 17. SMSRegexParser — fallbackDate parameter
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSRegexParser — fallbackDate', () {
    const noDateSms = '₹500 debited from account.';

    test('fallbackDate is used when SMS has no date', () {
      final tx = SMSRegexParser.tryParse(noDateSms,
          fallbackDate: DateTime(2024, 12, 31))!;
      expect(tx.transactionDate, '2024-12-31');
    });

    test('different fallbackDate gives different transactionDate', () {
      final tx1 = SMSRegexParser.tryParse(noDateSms,
          fallbackDate: DateTime(2025, 1, 1))!;
      final tx2 = SMSRegexParser.tryParse(noDateSms,
          fallbackDate: DateTime(2025, 6, 15))!;
      expect(tx1.transactionDate, '2025-01-01');
      expect(tx2.transactionDate, '2025-06-15');
    });

    test('extracted date from SMS overrides fallbackDate', () {
      const sms = 'INR 200.00 debited from A/c XX1234 on 05-01-25. Info: SHOP.';
      final tx = SMSRegexParser.tryParse(sms,
          fallbackDate: DateTime(2025, 6, 15))!;
      expect(tx.transactionDate, '2025-01-05');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 18. CategoryDetector.detect — income categories
  // CategoryDetector._learned starts empty (no SharedPreferences in tests).
  // detect() is synchronous and safe to call without setup.
  // ═══════════════════════════════════════════════════════════════════════════
  group('CategoryDetector.detect — income categories', () {
    String? inc(String title) => CategoryDetector.detect(title, isIncome: true);

    test('"salary" → 💼 Salary', () => expect(inc('salary'), '💼 Salary'));
    test('"payroll" → 💼 Salary', () => expect(inc('payroll'), '💼 Salary'));
    test('"wage" → 💼 Salary', () => expect(inc('wage'), '💼 Salary'));
    test('"freelance" → 💻 Freelance', () => expect(inc('freelance'), '💻 Freelance'));
    test('"client payment" → 💻 Freelance', () => expect(inc('client payment'), '💻 Freelance'));
    test('"consulting" → 💻 Freelance', () => expect(inc('consulting'), '💻 Freelance'));
    test('"dividend" → 📈 Investment', () => expect(inc('dividend'), '📈 Investment'));
    test('"mutual fund" → 📈 Investment', () => expect(inc('mutual fund'), '📈 Investment'));
    test('"sip returns" → 📈 Investment', () => expect(inc('sip returns'), '📈 Investment'));
    test('"rent received" → 🏠 Rent', () => expect(inc('rent received'), '🏠 Rent'));
    test('"bonus" → 💰 Bonus', () => expect(inc('bonus'), '💰 Bonus'));
    test('"incentive" → 💰 Bonus', () => expect(inc('incentive'), '💰 Bonus'));
    test('"refund" → 🔁 Refund', () => expect(inc('refund'), '🔁 Refund'));
    test('"cashback" → 🔁 Refund', () => expect(inc('cashback'), '🔁 Refund'));
    test('"birthday gift" → 🎁 Gift', () => expect(inc('birthday gift'), '🎁 Gift'));
    test('"diwali money" → 🎁 Gift', () => expect(inc('diwali money'), '🎁 Gift'));
    test('"business revenue" → 📦 Business', () => expect(inc('business revenue'), '📦 Business'));
    test('"selling old items" → 📦 Business', () => expect(inc('selling old items'), '📦 Business'));
    test('no keyword → null', () => expect(inc('TCS LIMITED'), isNull));
    test('empty string → null', () => expect(inc(''), isNull));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 19. CategoryDetector.detect — expense categories
  // ═══════════════════════════════════════════════════════════════════════════
  group('CategoryDetector.detect — expense categories', () {
    String? exp(String title) => CategoryDetector.detect(title, isIncome: false);

    test('"swiggy" → 🍕 Food', () => expect(exp('swiggy'), '🍕 Food'));
    test('"zomato order" → 🍕 Food', () => expect(exp('zomato order'), '🍕 Food'));
    test('"lunch" → 🍕 Food', () => expect(exp('lunch'), '🍕 Food'));
    test('"grocery store" → 🍕 Food', () => expect(exp('grocery store'), '🍕 Food'));
    test('"coffee" → 🍕 Food', () => expect(exp('coffee'), '🍕 Food'));
    test('"uber ride" → 🚗 Travel', () => expect(exp('uber ride'), '🚗 Travel'));
    test('"petrol" → 🚗 Travel', () => expect(exp('petrol'), '🚗 Travel'));
    test('"metro" → 🚗 Travel', () => expect(exp('metro'), '🚗 Travel'));
    test('"toll" → 🚗 Travel', () => expect(exp('toll'), '🚗 Travel'));
    test('"amazon" → 🛒 Shopping', () => expect(exp('amazon'), '🛒 Shopping'));
    test('"flipkart order" → 🛒 Shopping', () => expect(exp('flipkart order'), '🛒 Shopping'));
    test('"medicine" → 💊 Health', () => expect(exp('medicine'), '💊 Health'));
    test('"doctor visit" → 💊 Health', () => expect(exp('doctor visit'), '💊 Health'));
    test('"hospital" → 💊 Health', () => expect(exp('hospital'), '💊 Health'));
    test('"netflix" → 🎬 Entertainment', () => expect(exp('netflix'), '🎬 Entertainment'));
    test('"movie ticket" → 🎬 Entertainment', () => expect(exp('movie ticket'), '🎬 Entertainment'));
    test('"rent" → 🏠 Housing', () => expect(exp('rent'), '🏠 Housing'));
    test('"maintenance" → 🏠 Housing', () => expect(exp('maintenance'), '🏠 Housing'));
    test('"school fee" → 📚 Education', () => expect(exp('school fee'), '📚 Education'));
    test('"course" → 📚 Education', () => expect(exp('course'), '📚 Education'));
    test('"wifi recharge" → 💡 Utilities', () => expect(exp('wifi recharge'), '💡 Utilities'));
    test('"electricity" → 💡 Utilities', () => expect(exp('electricity'), '💡 Utilities'));
    test('"shirt" → 👕 Clothing', () => expect(exp('shirt'), '👕 Clothing'));
    test('"shoes" → 👕 Clothing', () => expect(exp('shoes'), '👕 Clothing'));
    test('"gym" → 🏋️ Fitness', () => expect(exp('gym'), '🏋️ Fitness'));
    test('"yoga class" → 🏋️ Fitness', () => expect(exp('yoga class'), '🏋️ Fitness'));
    test('"vacation hotel" → ✈️ Vacation', () => expect(exp('vacation hotel'), '✈️ Vacation'));
    test('"trip" → ✈️ Vacation', () => expect(exp('trip'), '✈️ Vacation'));
    test('no keyword → null', () => expect(exp('RAZORPAY'), isNull));
    test('empty string → null', () => expect(exp(''), isNull));
  });

  group('CategoryDetector.detect — case insensitivity', () {
    test('"SWIGGY" (uppercase) → 🍕 Food', () {
      expect(CategoryDetector.detect('SWIGGY', isIncome: false), '🍕 Food');
    });
    test('"SALARY" (uppercase) → 💼 Salary', () {
      expect(CategoryDetector.detect('SALARY', isIncome: true), '💼 Salary');
    });
    test('"Freelance Project" (mixed) → 💻 Freelance', () {
      expect(CategoryDetector.detect('Freelance Project', isIncome: true), '💻 Freelance');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 20. SMSParserService.isBankSMS
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSParserService.isBankSMS — sender keywords', () {
    bool check(String sender, {String body = ''}) =>
        SMSParserService.isBankSMS(sender, body);

    test('"hdfcbk" sender → true', () => expect(check('hdfcbk'), isTrue));
    test('"icicib" sender → true', () => expect(check('icicib'), isTrue));
    test('"sbiinb" sender → true', () => expect(check('sbiinb'), isTrue));
    test('"axisbk" sender → true', () => expect(check('axisbk'), isTrue));
    test('"kotakb" sender → true', () => expect(check('kotakb'), isTrue));
    test('"gpay" sender → true', () => expect(check('gpay'), isTrue));
    test('"phonepe" sender → true', () => expect(check('phonepe'), isTrue));
    test('"paytm" sender → true', () => expect(check('paytm'), isTrue));
    test('sender match is case-insensitive: "HDFCBK" → true',
        () => expect(check('HDFCBK'), isTrue));
    test('unknown sender + no body keywords → false',
        () => expect(check('MYFRIEND'), isFalse));
    test('empty sender and body → false', () => expect(check('', body: ''), isFalse));
  });

  group('SMSParserService.isBankSMS — body keywords', () {
    bool check(String body) => SMSParserService.isBankSMS('UNKNOWNSDR', body);

    test('"debited" in body → true', () => expect(check('Your account debited.'), isTrue));
    test('"credited" in body → true', () => expect(check('Amount credited today.'), isTrue));
    test('"debit" in body → true', () => expect(check('Debit of Rs.500.'), isTrue));
    test('"credit" in body → true', () => expect(check('Credit of INR 1000.'), isTrue));
    test('"withdrawn" in body → true', () => expect(check('Rs.500 withdrawn.'), isTrue));
    test('"inr " in body (with space) → true', () => expect(check('INR 500 paid.'), isTrue));
    test('"rs." in body → true', () => expect(check('Rs.200 spent.'), isTrue));
    test('"₹" in body → true', () => expect(check('₹500 debited.'), isTrue));
    test('body keywords are case-insensitive: "DEBITED" → true',
        () => expect(check('DEBITED 500.'), isTrue));
    test('promotional text with no keywords → false',
        () => expect(check('Get 50% off today!'), isFalse));
    test('"inr" without trailing space does NOT match the "inr " keyword',
        () => expect(check('ZINR500 payment'), isFalse));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 21. SMSParserService.handleNotificationPayload
  // ═══════════════════════════════════════════════════════════════════════════
  group('SMSParserService.handleNotificationPayload', () {
    setUp(() => SMSParserService.pendingSmsBody.value = null);

    test('payload with sms: prefix → sets pendingSmsBody to body text', () {
      SMSParserService.handleNotificationPayload('sms:INR 500 debited.');
      expect(SMSParserService.pendingSmsBody.value, 'INR 500 debited.');
    });

    test('wrong prefix → no-op, pendingSmsBody stays null', () {
      SMSParserService.handleNotificationPayload('other:INR 500 debited.');
      expect(SMSParserService.pendingSmsBody.value, isNull);
    });

    test('empty payload → no-op', () {
      SMSParserService.handleNotificationPayload('');
      expect(SMSParserService.pendingSmsBody.value, isNull);
    });

    test('payload is exactly prefix → body is empty string', () {
      SMSParserService.handleNotificationPayload(
          SMSParserService.kSmsPayloadPrefix);
      expect(SMSParserService.pendingSmsBody.value, '');
    });

    test('kSmsPayloadPrefix constant = "sms:"', () {
      expect(SMSParserService.kSmsPayloadPrefix, 'sms:');
    });

    test('kPendingKey constant is defined', () {
      expect(SMSParserService.kPendingKey, isNotEmpty);
    });
  });
}
