import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/data/models/wallet/flow_models.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/AI/nlp_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

ParsedIntent parse(String raw) => NlpParser.parse(raw);

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Amount extraction — k / L / plain number (priority: lakh > k > number)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Amount — k suffix', () {
    test('5k → 5000', () => expect(parse('paid 5k').amount, 5000));
    test('2.5k → 2500', () => expect(parse('paid 2.5k').amount, 2500));
    test('50k → 50000', () => expect(parse('spent 50k').amount, 50000));
    test('uppercase K → also works (5K → 5000)',
        () => expect(parse('paid 5K').amount, 5000));
    test('0.5k → 500', () => expect(parse('paid 0.5k').amount, 500));
  });

  group('Amount — L/lakh/lac suffix', () {
    test('1L → 100000', () => expect(parse('paid 1L').amount, 100000));
    test('1l (lowercase) → 100000', () => expect(parse('paid 1l').amount, 100000));
    test('1lakh → 100000', () => expect(parse('paid 1lakh').amount, 100000));
    test('1lac → 100000', () => expect(parse('paid 1lac').amount, 100000));
    test('1.5lakh → 150000', () => expect(parse('paid 1.5lakh').amount, 150000));
    test('2L → 200000', () => expect(parse('received 2L').amount, 200000));
  });

  group('Amount — lakh wins over k in priority', () {
    // lakhMatch is evaluated before shortMatch
    test('"2l" → lakhMatch (200000) not shortMatch', () {
      expect(parse('paid 2l').amount, 200000);
    });
  });

  group('Amount — plain number', () {
    test('integer: 500', () => expect(parse('paid 500').amount, 500));
    test('integer: 1500', () => expect(parse('paid 1500').amount, 1500));
    test('decimal: 2.50 → 2.5', () => expect(parse('paid 2.50').amount, 2.5));
    test('₹ symbol stripped before parse', () => expect(parse('paid ₹200').amount, 200));
    test('comma stripped: 1,500 → 1500', () => expect(parse('paid 1,500').amount, 1500));
    test('₹ and commas stripped: ₹1,00,000 → 100000',
        () => expect(parse('paid ₹1,00,000').amount, 100000));
  });

  group('Amount — word numbers', () {
    test('fifty → 50', () => expect(parse('spent fifty').amount, 50));
    test('hundred → 100', () => expect(parse('paid hundred').amount, 100));
    test('five hundred → 500', () => expect(parse('paid five hundred').amount, 500));
    test('two thousand → 2000', () => expect(parse('paid two thousand').amount, 2000));
    test('twenty five → 25', () => expect(parse('paid twenty five').amount, 25));
    test('one lakh → 100000', () => expect(parse('paid one lakh').amount, 100000));
  });

  group('Amount — none present', () {
    test('no number → amount is null', () => expect(parse('paid for lunch').amount, isNull));
    test('zero word → 0 (not returned — treated as null)', () {
      // _parseWordNumber returns null when total == 0
      expect(parse('zero').amount, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Flow type detection — priority: lend > borrow > split > request > income/expense
  // ═══════════════════════════════════════════════════════════════════════════
  group('FlowType — lend triggers (priority 1)', () {
    test('"lent 500 to Ram" → lend', () => expect(parse('lent 500 to Ram').flowType, FlowType.lend));
    test('"lend him 200" → lend', () => expect(parse('lend him 200').flowType, FlowType.lend));
    test('"gave 100 to friend" → lend', () => expect(parse('gave 100 to friend').flowType, FlowType.lend));
    test('"given money" → lend', () => expect(parse('given money').flowType, FlowType.lend));
    test('"loaned 500 to Priya" → lend', () => expect(parse('loaned 500 to Priya').flowType, FlowType.lend));
  });

  group('FlowType — borrow triggers (priority 2)', () {
    test('"borrowed 300 from Priya" → borrow',
        () => expect(parse('borrowed 300 from Priya').flowType, FlowType.borrow));
    test('"borrow 500 from bank" → borrow',
        () => expect(parse('borrow 500 from bank').flowType, FlowType.borrow));
    test('"took from friend 200" → borrow',
        () => expect(parse('took from friend 200').flowType, FlowType.borrow));
  });

  group('FlowType — split triggers (priority 3)', () {
    test('"split dinner 600" → split',
        () => expect(parse('split dinner 600').flowType, FlowType.split));
    test('"shared expense 300" → split',
        () => expect(parse('shared expense 300').flowType, FlowType.split));
    test('"dutch treat 500" → split',
        () => expect(parse('dutch treat 500').flowType, FlowType.split));
    test('"divided bill 400" → split',
        () => expect(parse('divided bill 400').flowType, FlowType.split));
  });

  group('FlowType — request triggers (priority 4)', () {
    test('"request 300 from Mom" → request',
        () => expect(parse('request 300 from Mom').flowType, FlowType.request));
    test('"he owes me 500" → request',
        () => expect(parse('he owes me 500').flowType, FlowType.request));
    test('"she owes 200" → request',
        () => expect(parse('she owes 200').flowType, FlowType.request));
  });

  group('FlowType — income triggers (checked only when score=0)', () {
    test('"received salary 50k" → income',
        () => expect(parse('received salary 50k').flowType, FlowType.income));
    test('"salary credited 30k" → income',
        () => expect(parse('salary credited 30k').flowType, FlowType.income));
    test('"got bonus 10k" → income',
        () => expect(parse('got bonus 10k').flowType, FlowType.income));
    test('"earned 5000" → income',
        () => expect(parse('earned 5000').flowType, FlowType.income));
    test('"refund received 200" → income',
        () => expect(parse('refund received 200').flowType, FlowType.income));
  });

  group('FlowType — expense triggers', () {
    test('"paid 200 for lunch" → expense',
        () => expect(parse('paid 200 for lunch').flowType, FlowType.expense));
    test('"spent 500 on shopping" → expense',
        () => expect(parse('spent 500 on shopping').flowType, FlowType.expense));
    test('"bought shoes 1k" → expense',
        () => expect(parse('bought shoes 1k').flowType, FlowType.expense));
    test('"debited 300" → expense',
        () => expect(parse('debited 300').flowType, FlowType.expense));
  });

  group('FlowType — default when no trigger found', () {
    test('no trigger → defaults to expense',
        () => expect(parse('lunch 200').flowType, FlowType.expense));
    test('number only → expense default',
        () => expect(parse('200').flowType, FlowType.expense));
  });

  group('FlowType — priority (lend beats all)', () {
    test('"lent and received" → lend beats income',
        () => expect(parse('lent 500 and received income').flowType, FlowType.lend));
    test('"lent and split" → lend beats split',
        () => expect(parse('lent 500 and split').flowType, FlowType.lend));
  });

  group('FlowType — income vs expense both match → expense wins', () {
    // Inside if(typeScore==0): income tryMatch runs first, then expense tryMatch also runs.
    // If both match, expense (last writer) wins.
    test('"got paid 500" → expense wins over income (both "got"=income and "paid"=expense)',
        () => expect(parse('got paid 500').flowType, FlowType.expense));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Category detection
  // ═══════════════════════════════════════════════════════════════════════════
  group('Category — catMap keyword matches', () {
    test('"lunch" → Food', () => expect(parse('paid 200 for lunch').category, 'Food'));
    test('"dinner" → Food', () => expect(parse('had dinner 300').category, 'Food'));
    test('"coffee" → Food', () => expect(parse('coffee 50').category, 'Food'));
    test('"zomato" → Food', () => expect(parse('zomato order 250').category, 'Food'));
    test('"grocery" → Groceries', () => expect(parse('grocery 500').category, 'Groceries'));
    test('"milk" → Groceries', () => expect(parse('bought milk 60').category, 'Groceries'));
    test('"uber" → Travel', () => expect(parse('uber cab 300').category, 'Travel'));
    test('"petrol" → Travel', () => expect(parse('petrol 1500').category, 'Travel'));
    test('"amazon" → Shopping', () => expect(parse('amazon order 999').category, 'Shopping'));
    test('"flipkart" → Shopping', () => expect(parse('flipkart 2k').category, 'Shopping'));
    test('"netflix" → Subscription', () => expect(parse('netflix 149').category, 'Subscription'));
    test('"electricity" → Bills', () => expect(parse('electricity 2000').category, 'Bills'));
    test('"wifi" → Bills', () => expect(parse('wifi bill 500').category, 'Bills'));
    test('"medicine" → Health', () => expect(parse('bought medicine 150').category, 'Health'));
    test('"doctor" → Health', () => expect(parse('doctor visit 500').category, 'Health'));
    test('"salary" in catMap → Salary', () => expect(parse('salary 50k').category, 'Salary'));
    test('"rent" → Rent', () => expect(parse('rent 15k').category, 'Rent'));
    test('"investment" → Investment', () => expect(parse('investment 10k').category, 'Investment'));
    test('"sip" → Investment', () => expect(parse('sip 5000').category, 'Investment'));
  });

  group('Category — income flow fallbacks (when catMap returns nothing)', () {
    test('income flow + no catMap keyword → "Income"',
        () => expect(parse('received 5000').category, 'Income'));
    test('income flow + "salary" → "Salary" (from catMap, not fallback)',
        () => expect(parse('received salary 50k').category, 'Salary'));
    test('income flow + "freelance" → "Freelance" (from catMap)',
        () => expect(parse('earned freelance 5k').category, 'Freelance'));
    test('income flow + "bonus" → "Salary" (from catMap)',
        () => expect(parse('received bonus 10k').category, 'Salary'));
  });

  group('Category — null when no keyword and not income flow', () {
    test('expense with no catMap keyword → category is null',
        () => expect(parse('paid 500').category, isNull));
    test('lend with no catMap keyword → category is null',
        () => expect(parse('lent 300 to Ram').category, isNull));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Person extraction
  // ═══════════════════════════════════════════════════════════════════════════
  group('Person extraction — preposition + name', () {
    test('"lent 500 to Ravi" → Ravi',
        () => expect(parse('lent 500 to Ravi').person, 'Ravi'));
    test('"borrowed 300 from Priya" → Priya',
        () => expect(parse('borrowed 300 from Priya').person, 'Priya'));
    test('"split 600 with John" → John',
        () => expect(parse('split 600 with John').person, 'John'));
    test('"gave money to Arjun" → Arjun',
        () => expect(parse('gave money to Arjun').person, 'Arjun'));
    test('preserves original casing of name',
        () => expect(parse('lent 100 to RAVI').person, 'RAVI'));
  });

  group('Person extraction — no match', () {
    test('no preposition → null', () => expect(parse('paid 300 online').person, isNull));
    test('preposition at end of string → null',
        () => expect(parse('paid 300 to').person, isNull));
    test('empty string → null', () => expect(parse('').person, isNull));
  });

  group('Person extraction — caseSensitive quirk', () {
    // RegExp has caseSensitive:false which makes [A-Z][a-z]+ match ANY word
    // with ≥2 letters — not just capitalised proper names.
    test('"for lunch" → person = "lunch" (lowercase word captured by caseSensitive:false regex)',
        () => expect(parse('paid 200 for lunch').person, 'lunch'));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. PayMode detection
  // ═══════════════════════════════════════════════════════════════════════════
  group('PayMode — online keywords', () {
    test('"gpay" → PayMode.online', () => expect(parse('paid via gpay').payMode, PayMode.online));
    test('"upi" → PayMode.online', () => expect(parse('upi payment 200').payMode, PayMode.online));
    test('"neft" → PayMode.online', () => expect(parse('neft transfer 5k').payMode, PayMode.online));
    test('"card" → PayMode.online', () => expect(parse('paid by card').payMode, PayMode.online));
    test('"bank" → PayMode.online', () => expect(parse('bank transfer 10k').payMode, PayMode.online));
    test('"paytm" → PayMode.online', () => expect(parse('paytm 300').payMode, PayMode.online));
    test('"phonepe" → PayMode.online', () => expect(parse('phonepe payment').payMode, PayMode.online));
    test('"netbanking" → PayMode.online',
        () => expect(parse('paid via netbanking').payMode, PayMode.online));
    test('"transfer" → PayMode.online',
        () => expect(parse('transfer 500').payMode, PayMode.online));
  });

  group('PayMode — cash keywords', () {
    test('"cash" → PayMode.cash', () => expect(parse('paid 200 cash').payMode, PayMode.cash));
    test('"in hand" → PayMode.cash (hand is cash word)',
        () => expect(parse('gave 500 in hand').payMode, PayMode.cash));
    test('"coin" → PayMode.cash', () => expect(parse('coin 50').payMode, PayMode.cash));
  });

  group('PayMode — online takes priority over cash', () {
    // _onlineWords checked first; if matched, cash check is skipped
    test('"cash via upi" → online (online checked first)',
        () => expect(parse('paid cash via upi 300').payMode, PayMode.online));
  });

  group('PayMode — null when no keyword', () {
    test('no payment keyword → null',
        () => expect(parse('paid 500 for lunch').payMode, isNull));
    test('empty input → null', () => expect(parse('').payMode, isNull));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. Confidence scoring
  // ═══════════════════════════════════════════════════════════════════════════
  group('Confidence scoring', () {
    test('nothing matched → 0.0', () {
      // "hi" — no amount (≤4 chars → note null too), no trigger, no cat, no paymode
      expect(parse('hi').confidence, closeTo(0.0, 0.001));
    });

    test('amount only → 0.5', () {
      // "paid 500" — amount(0.5) + type(0.25 from "paid") = 0.75 actually
      // Use a raw number with no trigger: "500" → expense default (typeScore=0)
      expect(parse('500').confidence, closeTo(0.5, 0.001));
    });

    test('amount + type trigger → 0.75', () {
      // "lent 300" → amount(0.5) + type lend(0.25) = 0.75; no category/paymode
      expect(parse('lent 300').confidence, closeTo(0.75, 0.001));
    });

    test('amount + type + category → 0.90', () {
      // "paid 200 for lunch" → amount(0.5) + type paid(0.25) + cat Food(0.15) = 0.90
      expect(parse('paid 200 for lunch').confidence, closeTo(0.90, 0.001));
    });

    test('amount + type + category + payMode → 1.0', () {
      // "paid 200 for lunch via gpay"
      expect(parse('paid 200 for lunch via gpay').confidence, closeTo(1.0, 0.001));
    });

    test('income with amount and default category → 0.90', () {
      // "received 5000" → amount(0.5) + type(0.25) + cat Income(0.15) = 0.90
      expect(parse('received 5000').confidence, closeTo(0.90, 0.001));
    });

    test('category only (no amount, no trigger) → 0.15', () {
      // "lunch" → no digit, no trigger (expense default, typeScore=0), cat Food → 0.15
      expect(parse('lunch').confidence, closeTo(0.15, 0.001));
    });

    test('payMode only → 0.10', () {
      // "upi" → no amount, no trigger, no category
      expect(parse('upi').confidence, closeTo(0.10, 0.001));
    });

    test('confidence is clamped to 1.0 at maximum', () {
      expect(parse('paid 200 for lunch via gpay').confidence, lessThanOrEqualTo(1.0));
    });

    test('confidence is never negative', () {
      expect(parse('').confidence, greaterThanOrEqualTo(0.0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. Note field
  // ═══════════════════════════════════════════════════════════════════════════
  group('Note field', () {
    test('text longer than 4 chars → note = original input', () {
      final r = parse('paid 500 for lunch');
      expect(r.note, 'paid 500 for lunch');
    });

    test('text exactly 4 chars → note is null', () {
      expect(parse('paid').note, isNull);
    });

    test('text less than 4 chars → note is null', () {
      expect(parse('hi').note, isNull);
      expect(parse('500').note, isNull); // "500" = 3 chars
    });

    test('text 5 chars → note is set', () {
      // "500 r" = 5 chars (just over threshold)
      expect(parse('lend5').note, 'lend5');
    });

    test('note preserves original casing and spacing', () {
      final r = parse('Paid ₹500 for Lunch via GPay');
      expect(r.note, 'Paid ₹500 for Lunch via GPay');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. Integration — full parse end-to-end
  // ═══════════════════════════════════════════════════════════════════════════
  group('Integration — full parse', () {
    test('"paid 500 for lunch" — full result', () {
      final r = parse('paid 500 for lunch');
      expect(r.flowType, FlowType.expense);
      expect(r.amount, 500);
      expect(r.category, 'Food');
      expect(r.payMode, isNull);
      expect(r.note, 'paid 500 for lunch');
      expect(r.confidence, closeTo(0.90, 0.001));
    });

    test('"lent 2k to Ravi" — full result', () {
      final r = parse('lent 2k to Ravi');
      expect(r.flowType, FlowType.lend);
      expect(r.amount, 2000);
      expect(r.person, 'Ravi');
      expect(r.category, isNull);
      expect(r.confidence, closeTo(0.75, 0.001));
    });

    test('"received salary 50k via bank" — full result', () {
      final r = parse('received salary 50k via bank');
      expect(r.flowType, FlowType.income);
      expect(r.amount, 50000);
      expect(r.category, 'Salary');
      expect(r.payMode, PayMode.online);
      expect(r.confidence, closeTo(1.0, 0.001));
    });

    test('"borrowed 300 from Priya cash" — full result', () {
      final r = parse('borrowed 300 from Priya cash');
      expect(r.flowType, FlowType.borrow);
      expect(r.amount, 300);
      expect(r.person, 'Priya');
      expect(r.payMode, PayMode.cash);
    });

    test('"split dinner 600 with John via gpay" — full result', () {
      final r = parse('split dinner 600 with John via gpay');
      expect(r.flowType, FlowType.split);
      expect(r.amount, 600);
      expect(r.category, 'Food');
      expect(r.person, 'John');
      expect(r.payMode, PayMode.online);
      expect(r.confidence, closeTo(1.0, 0.001));
    });

    test('"netflix 149" — subscription category with default expense', () {
      final r = parse('netflix 149');
      expect(r.flowType, FlowType.expense);
      expect(r.amount, 149);
      expect(r.category, 'Subscription');
    });

    test('empty string — all nulls, expense default, zero confidence', () {
      final r = parse('');
      expect(r.flowType, FlowType.expense);
      expect(r.amount, isNull);
      expect(r.category, isNull);
      expect(r.person, isNull);
      expect(r.payMode, isNull);
      expect(r.note, isNull);
      expect(r.confidence, closeTo(0.0, 0.001));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. ParsedIntent fields
  // ═══════════════════════════════════════════════════════════════════════════
  group('ParsedIntent — field completeness', () {
    test('flowType is always set (never null)', () {
      for (final input in ['', 'hi', 'paid 200', 'lent 500']) {
        expect(parse(input).flowType, isNotNull, reason: input);
      }
    });

    test('confidence is always between 0 and 1', () {
      for (final input in ['', 'hi', 'paid 200 for lunch via gpay', 'lent 500']) {
        final c = parse(input).confidence;
        expect(c, greaterThanOrEqualTo(0.0), reason: input);
        expect(c, lessThanOrEqualTo(1.0), reason: input);
      }
    });

    test('date field is always null (not extracted by this parser)', () {
      expect(parse('paid 500 yesterday').date, isNull);
      expect(parse('received salary today').date, isNull);
    });

    test('title field is always null (not extracted by this parser)', () {
      expect(parse('paid 500 for laptop').title, isNull);
    });
  });
}
