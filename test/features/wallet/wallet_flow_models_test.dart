import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/flow_models.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. FlowTypeExt — label
  // ═══════════════════════════════════════════════════════════════════════════
  group('FlowTypeExt.label', () {
    test('expense → "Add Expense"', () => expect(FlowType.expense.label, 'Add Expense'));
    test('income → "Add Income"', () => expect(FlowType.income.label, 'Add Income'));
    test('split → "Split Bill"', () => expect(FlowType.split.label, 'Split Bill'));
    test('lend → "Lend Money"', () => expect(FlowType.lend.label, 'Lend Money'));
    test('borrow → "Borrow"', () => expect(FlowType.borrow.label, 'Borrow'));
    test('request → "Request Money"', () => expect(FlowType.request.label, 'Request Money'));
    test('returned → "Returned Money"', () => expect(FlowType.returned.label, 'Returned Money'));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. FlowTypeExt — emoji
  // ═══════════════════════════════════════════════════════════════════════════
  group('FlowTypeExt.emoji', () {
    test('expense → 💸', () => expect(FlowType.expense.emoji, '💸'));
    test('income → 💰', () => expect(FlowType.income.emoji, '💰'));
    test('split → ⚖️', () => expect(FlowType.split.emoji, '⚖️'));
    test('lend → 📤', () => expect(FlowType.lend.emoji, '📤'));
    test('borrow → 📥', () => expect(FlowType.borrow.emoji, '📥'));
    test('request → 🔔', () => expect(FlowType.request.emoji, '🔔'));
    test('returned → ↩️', () => expect(FlowType.returned.emoji, '↩️'));
    test('all emojis are non-empty strings', () {
      for (final ft in FlowType.values) {
        expect(ft.emoji, isNotEmpty, reason: ft.name);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. FlowTypeExt — color (exact AppColors constants)
  // ═══════════════════════════════════════════════════════════════════════════
  group('FlowTypeExt.color', () {
    test('expense → AppColors.expense', () => expect(FlowType.expense.color, AppColors.expense));
    test('income → AppColors.income', () => expect(FlowType.income.color, AppColors.income));
    test('split → AppColors.split', () => expect(FlowType.split.color, AppColors.split));
    test('lend → AppColors.lend', () => expect(FlowType.lend.color, AppColors.lend));
    test('borrow → AppColors.borrow', () => expect(FlowType.borrow.color, AppColors.borrow));
    test('request → AppColors.request', () => expect(FlowType.request.color, AppColors.request));
    test('returned → AppColors.returned', () => expect(FlowType.returned.color, AppColors.returned));
    test('all colors are non-null Color instances', () {
      for (final ft in FlowType.values) {
        expect(ft.color, isA<Color>(), reason: ft.name);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. FlowTypeExt — steps
  // ═══════════════════════════════════════════════════════════════════════════
  group('FlowTypeExt.steps — step lists', () {
    test('expense: 8 steps ending with confirm', () {
      final s = FlowType.expense.steps;
      expect(s.length, 8);
      expect(s.first, FlowStep.amount);
      expect(s.last, FlowStep.confirm);
    });

    test('expense steps: amount, title, owner, paymode, date, category, note, confirm', () {
      expect(FlowType.expense.steps, [
        FlowStep.amount, FlowStep.title, FlowStep.owner, FlowStep.paymode,
        FlowStep.date, FlowStep.category, FlowStep.note, FlowStep.confirm,
      ]);
    });

    test('income has same steps as expense', () {
      expect(FlowType.income.steps, FlowType.expense.steps);
    });

    test('split: amount, persons, splitType, date, title, note, confirm', () {
      expect(FlowType.split.steps, [
        FlowStep.amount, FlowStep.persons, FlowStep.splitType,
        FlowStep.date, FlowStep.title, FlowStep.note, FlowStep.confirm,
      ]);
    });

    test('split has 7 steps', () => expect(FlowType.split.steps.length, 7));

    test('lend: amount, person, paymode, dueDate, title, note, confirm', () {
      expect(FlowType.lend.steps, [
        FlowStep.amount, FlowStep.person, FlowStep.paymode,
        FlowStep.dueDate, FlowStep.title, FlowStep.note, FlowStep.confirm,
      ]);
    });

    test('borrow has same steps as lend', () {
      expect(FlowType.borrow.steps, FlowType.lend.steps);
    });

    test('request: no paymode step (6 steps)', () {
      final s = FlowType.request.steps;
      expect(s.length, 6);
      expect(s.contains(FlowStep.paymode), isFalse);
    });

    test('request: amount, person, dueDate, title, note, confirm', () {
      expect(FlowType.request.steps, [
        FlowStep.amount, FlowStep.person, FlowStep.dueDate,
        FlowStep.title, FlowStep.note, FlowStep.confirm,
      ]);
    });

    test('returned: amount, person, paymode, date, title, note, confirm', () {
      expect(FlowType.returned.steps, [
        FlowStep.amount, FlowStep.person, FlowStep.paymode,
        FlowStep.date, FlowStep.title, FlowStep.note, FlowStep.confirm,
      ]);
    });

    test('returned uses date (not dueDate)', () {
      final s = FlowType.returned.steps;
      expect(s.contains(FlowStep.date), isTrue);
      expect(s.contains(FlowStep.dueDate), isFalse);
    });

    test('all flow types start with amount', () {
      for (final ft in FlowType.values) {
        expect(ft.steps.first, FlowStep.amount, reason: ft.name);
      }
    });

    test('all flow types end with confirm', () {
      for (final ft in FlowType.values) {
        expect(ft.steps.last, FlowStep.confirm, reason: ft.name);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. FlowTypeExt — txType mapping
  // ═══════════════════════════════════════════════════════════════════════════
  group('FlowTypeExt.txType', () {
    test('expense → TxType.expense', () => expect(FlowType.expense.txType, TxType.expense));
    test('income → TxType.income', () => expect(FlowType.income.txType, TxType.income));
    test('split → TxType.split', () => expect(FlowType.split.txType, TxType.split));
    test('lend → TxType.lend', () => expect(FlowType.lend.txType, TxType.lend));
    test('borrow → TxType.borrow', () => expect(FlowType.borrow.txType, TxType.borrow));
    test('request → TxType.request', () => expect(FlowType.request.txType, TxType.request));
    test('returned → TxType.returned', () => expect(FlowType.returned.txType, TxType.returned));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. FlowStepExt — botQuestion for amount (all 7 flows)
  // ═══════════════════════════════════════════════════════════════════════════
  group('FlowStepExt.botQuestion — amount step', () {
    test('expense → "💸 How much did you spend?"',
        () => expect(FlowStep.amount.botQuestion(FlowType.expense), '💸 How much did you spend?'));
    test('income → "💰 How much did you receive?"',
        () => expect(FlowStep.amount.botQuestion(FlowType.income), '💰 How much did you receive?'));
    test('split → "⚖️ What\'s the total bill amount?"',
        () => expect(FlowStep.amount.botQuestion(FlowType.split), '⚖️ What\'s the total bill amount?'));
    test('lend → "📤 How much did you lend?"',
        () => expect(FlowStep.amount.botQuestion(FlowType.lend), '📤 How much did you lend?'));
    test('borrow → "📥 How much did you borrow?"',
        () => expect(FlowStep.amount.botQuestion(FlowType.borrow), '📥 How much did you borrow?'));
    test('request → "🔔 How much do you want to request?"',
        () => expect(FlowStep.amount.botQuestion(FlowType.request), '🔔 How much do you want to request?'));
    test('returned → "↩️ How much was returned?"',
        () => expect(FlowStep.amount.botQuestion(FlowType.returned), '↩️ How much was returned?'));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. FlowStepExt — botQuestion for all other steps
  // ═══════════════════════════════════════════════════════════════════════════
  group('FlowStepExt.botQuestion — category step', () {
    test('income → "What\'s the source of income?"',
        () => expect(FlowStep.category.botQuestion(FlowType.income), 'What\'s the source of income?'));
    test('expense → "What was it for?"',
        () => expect(FlowStep.category.botQuestion(FlowType.expense), 'What was it for?'));
    test('non-income (split) → "What was it for?"',
        () => expect(FlowStep.category.botQuestion(FlowType.split), 'What was it for?'));
  });

  group('FlowStepExt.botQuestion — owner / paymode / date / persons / splitType', () {
    test('owner (any flow) → "Personal or Family account?"',
        () => expect(FlowStep.owner.botQuestion(FlowType.expense), 'Personal or Family account?'));
    test('paymode (any flow) → "Cash or Online payment?"',
        () => expect(FlowStep.paymode.botQuestion(FlowType.lend), 'Cash or Online payment?'));
    test('date (any flow) → "When did this happen?"',
        () => expect(FlowStep.date.botQuestion(FlowType.expense), 'When did this happen?'));
    test('persons (split) → "Who\'s splitting with you?"',
        () => expect(FlowStep.persons.botQuestion(FlowType.split), 'Who\'s splitting with you?'));
    test('splitType (split) → "How do you want to split?"',
        () => expect(FlowStep.splitType.botQuestion(FlowType.split), 'How do you want to split?'));
  });

  group('FlowStepExt.botQuestion — person step (flow-dependent)', () {
    test('lend → "Who did you lend to?"',
        () => expect(FlowStep.person.botQuestion(FlowType.lend), 'Who did you lend to?'));
    test('borrow → "Who did you borrow from?"',
        () => expect(FlowStep.person.botQuestion(FlowType.borrow), 'Who did you borrow from?'));
    test('request → "Who are you requesting from?"',
        () => expect(FlowStep.person.botQuestion(FlowType.request), 'Who are you requesting from?'));
    test('returned → "Who returned the money?"',
        () => expect(FlowStep.person.botQuestion(FlowType.returned), 'Who returned the money?'));
    test('expense (default) → "Who is the person?"',
        () => expect(FlowStep.person.botQuestion(FlowType.expense), 'Who is the person?'));
  });

  group('FlowStepExt.botQuestion — dueDate step', () {
    test('request → "📅 Set a tentative return date? (optional)"',
        () => expect(FlowStep.dueDate.botQuestion(FlowType.request),
            '📅 Set a tentative return date? (optional)'));
    test('lend → "Set a due date?"',
        () => expect(FlowStep.dueDate.botQuestion(FlowType.lend), 'Set a due date?'));
    test('borrow → "Set a due date?"',
        () => expect(FlowStep.dueDate.botQuestion(FlowType.borrow), 'Set a due date?'));
  });

  group('FlowStepExt.botQuestion — title step', () {
    test('expense → "What is this spend for?"',
        () => expect(FlowStep.title.botQuestion(FlowType.expense), 'What is this spend for?'));
    test('income → "What is this income from?"',
        () => expect(FlowStep.title.botQuestion(FlowType.income), 'What is this income from?'));
    test('lend (default) → "Give it a short title? (optional)"',
        () => expect(FlowStep.title.botQuestion(FlowType.lend), 'Give it a short title? (optional)'));
    test('split (default) → "Give it a short title? (optional)"',
        () => expect(FlowStep.title.botQuestion(FlowType.split), 'Give it a short title? (optional)'));
  });

  group('FlowStepExt.botQuestion — note / confirm', () {
    test('note (any flow) → "Add a note? (optional)"',
        () => expect(FlowStep.note.botQuestion(FlowType.expense), 'Add a note? (optional)'));
    test('confirm (any flow) → "✅ Here\'s your summary — looks good?"',
        () => expect(FlowStep.confirm.botQuestion(FlowType.income),
            '✅ Here\'s your summary — looks good?'));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. FlowData._fmt (tested via summaryRows Amount row)
  //    AppPrefs.cs defaults to '₹' when SharedPreferences is uninitialised.
  // ═══════════════════════════════════════════════════════════════════════════
  group('FlowData._fmt — amount formatting via summaryRows', () {
    String amountRow(double v) {
      final fd = FlowData();
      fd.amount = v;
      return fd.summaryRows.firstWhere((e) => e.key == 'Amount').value;
    }

    test('< 1000 → integer string: 500 → "₹500"', () => expect(amountRow(500), '₹500'));
    test('< 1000 → integer string: 999 → "₹999"', () => expect(amountRow(999), '₹999'));
    test('exactly 1000 → K format: "₹1.0K"', () => expect(amountRow(1000), '₹1.0K'));
    test('1500 → "₹1.5K"', () => expect(amountRow(1500), '₹1.5K'));
    test('99999 → K: "₹100.0K"', () => expect(amountRow(99999), '₹100.0K'));
    test('exactly 100000 → L format: "₹1.0L"', () => expect(amountRow(100000), '₹1.0L'));
    test('150000 → "₹1.5L"', () => expect(amountRow(150000), '₹1.5L'));
    test('0 → "₹0"', () => expect(amountRow(0), '₹0'));

    test('L takes priority over K (100000 threshold)', () {
      // 100000 is exactly at the L boundary — must use L, not K
      expect(amountRow(100000), contains('L'));
      expect(amountRow(100000), isNot(contains('K')));
    });

    test('below 1000 produces no suffix', () {
      expect(amountRow(750), isNot(anyOf(contains('K'), contains('L'))));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. FlowData.summaryRows — row presence and keys
  // ═══════════════════════════════════════════════════════════════════════════
  group('FlowData.summaryRows — empty FlowData', () {
    test('all fields null → no rows', () {
      expect(FlowData().summaryRows, isEmpty);
    });
  });

  group('FlowData.summaryRows — individual field rows', () {
    test('amount set → "Amount" row present', () {
      final fd = FlowData()..amount = 500;
      final keys = fd.summaryRows.map((e) => e.key).toList();
      expect(keys, contains('Amount'));
    });

    test('title set (non-empty) → "Title" row', () {
      final fd = FlowData()..title = 'Dinner';
      expect(fd.summaryRows.map((e) => e.key), contains('Title'));
    });

    test('title = empty string → no "Title" row', () {
      final fd = FlowData()..title = '';
      expect(fd.summaryRows.map((e) => e.key), isNot(contains('Title')));
    });

    test('category set → "Category" row', () {
      final fd = FlowData()..category = 'Food';
      expect(fd.summaryRows.map((e) => e.key), contains('Category'));
      expect(fd.summaryRows.firstWhere((e) => e.key == 'Category').value, 'Food');
    });

    test('owner set → "Account" row', () {
      final fd = FlowData()..owner = 'Personal';
      expect(fd.summaryRows.map((e) => e.key), contains('Account'));
      expect(fd.summaryRows.firstWhere((e) => e.key == 'Account').value, 'Personal');
    });

    test('paymode set → "Payment" row', () {
      final fd = FlowData()..paymode = 'Online';
      expect(fd.summaryRows.map((e) => e.key), contains('Payment'));
    });

    test('persons set → "Split with" row, values joined with ", "', () {
      final fd = FlowData()..persons = ['Arjun', 'Priya', 'Rahul'];
      final row = fd.summaryRows.firstWhere((e) => e.key == 'Split with');
      expect(row.value, 'Arjun, Priya, Rahul');
    });

    test('persons single item → no trailing comma', () {
      final fd = FlowData()..persons = ['Arjun'];
      expect(fd.summaryRows.firstWhere((e) => e.key == 'Split with').value, 'Arjun');
    });

    test('splitType set → "Split type" row', () {
      final fd = FlowData()..splitType = 'Equal';
      expect(fd.summaryRows.firstWhere((e) => e.key == 'Split type').value, 'Equal');
    });

    test('person set → "Person" row', () {
      final fd = FlowData()..person = 'Priya';
      expect(fd.summaryRows.firstWhere((e) => e.key == 'Person').value, 'Priya');
    });

    test('dueDate set → "Due date" row', () {
      final fd = FlowData()..dueDate = 'Jan 2026';
      expect(fd.summaryRows.firstWhere((e) => e.key == 'Due date').value, 'Jan 2026');
    });

    test('note set (non-empty) → "Note" row', () {
      final fd = FlowData()..note = 'for dinner';
      expect(fd.summaryRows.firstWhere((e) => e.key == 'Note').value, 'for dinner');
    });

    test('note = empty string → no "Note" row', () {
      final fd = FlowData()..note = '';
      expect(fd.summaryRows.map((e) => e.key), isNot(contains('Note')));
    });
  });

  group('FlowData.summaryRows — Date field priority', () {
    test('pickedDate set → "Date" row with d/m/y format', () {
      final fd = FlowData()..pickedDate = DateTime(2025, 8, 4);
      final row = fd.summaryRows.firstWhere((e) => e.key == 'Date');
      expect(row.value, '4/8/2025');
    });

    test('date string set (no pickedDate) → "Date" row with string value', () {
      final fd = FlowData()..date = 'Yesterday';
      expect(fd.summaryRows.firstWhere((e) => e.key == 'Date').value, 'Yesterday');
    });

    test('pickedDate takes priority over date string', () {
      final fd = FlowData()
        ..pickedDate = DateTime(2025, 12, 31)
        ..date = 'Yesterday';
      // Should use pickedDate, formatted as d/m/y
      expect(fd.summaryRows.firstWhere((e) => e.key == 'Date').value, '31/12/2025');
    });

    test('pickedDate formats as day/month/year (no zero-padding)', () {
      final fd = FlowData()..pickedDate = DateTime(2025, 1, 5);
      expect(fd.summaryRows.firstWhere((e) => e.key == 'Date').value, '5/1/2025');
    });
  });

  group('FlowData.summaryRows — row ordering', () {
    test('rows appear in defined order: Amount before Title before Category', () {
      final fd = FlowData()
        ..amount = 500
        ..title = 'Dinner'
        ..category = 'Food';
      final keys = fd.summaryRows.map((e) => e.key).toList();
      expect(keys.indexOf('Amount'), lessThan(keys.indexOf('Title')));
      expect(keys.indexOf('Title'), lessThan(keys.indexOf('Category')));
    });

    test('Person appears before Date in row order', () {
      final fd = FlowData()
        ..person = 'Arjun'
        ..date = 'Today';
      final keys = fd.summaryRows.map((e) => e.key).toList();
      expect(keys.indexOf('Person'), lessThan(keys.indexOf('Date')));
    });

    test('Note is the last row', () {
      final fd = FlowData()
        ..amount = 500
        ..category = 'Food'
        ..note = 'quick lunch';
      expect(fd.summaryRows.last.key, 'Note');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. ChatMessage — copyWith
  // ═══════════════════════════════════════════════════════════════════════════
  group('ChatMessage.copyWith', () {
    const original = ChatMessage(
      role: ChatRole.bot,
      text: 'Hello!',
      widgetStep: FlowStep.amount,
      animate: true,
    );

    test('copyWith replaces widgetStep', () {
      final copy = original.copyWith(widgetStep: FlowStep.confirm);
      expect(copy.widgetStep, FlowStep.confirm);
    });

    test('copyWith preserves role', () {
      expect(original.copyWith(widgetStep: FlowStep.note).role, ChatRole.bot);
    });

    test('copyWith preserves text', () {
      expect(original.copyWith(widgetStep: FlowStep.note).text, 'Hello!');
    });

    test('copyWith preserves animate', () {
      expect(original.copyWith(widgetStep: FlowStep.note).animate, true);
    });

    test('copyWith(widgetStep: null) keeps existing widgetStep via ??', () {
      final copy = original.copyWith();
      expect(copy.widgetStep, FlowStep.amount);
    });

    test('copyWith on user message', () {
      const userMsg = ChatMessage(role: ChatRole.user, text: '500', animate: false);
      final copy = userMsg.copyWith(widgetStep: FlowStep.category);
      expect(copy.role, ChatRole.user);
      expect(copy.text, '500');
      expect(copy.widgetStep, FlowStep.category);
      expect(copy.animate, false);
    });

    test('widgetStep can be replaced with null when current is non-null — null passed keeps old', () {
      // copyWith only accepts FlowStep? — null input → old value kept (not cleared)
      final copy = original.copyWith();
      expect(copy.widgetStep, isNotNull);
    });
  });

  group('ChatMessage — defaults', () {
    test('animate defaults to false', () {
      const msg = ChatMessage(role: ChatRole.bot, text: 'Hi');
      expect(msg.animate, isFalse);
    });

    test('widgetStep defaults to null', () {
      const msg = ChatMessage(role: ChatRole.user, text: 'Hi');
      expect(msg.widgetStep, isNull);
    });
  });

  group('ChatRole — enum values', () {
    test('has exactly 2 values: bot and user', () {
      expect(ChatRole.values.length, 2);
      expect(ChatRole.values, containsAll([ChatRole.bot, ChatRole.user]));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 11. Category constant lists
  // ═══════════════════════════════════════════════════════════════════════════
  group('expenseCategories constant list', () {
    test('has 12 entries', () => expect(expenseCategories.length, 12));
    test('contains Food entry', () => expect(expenseCategories, contains('🍕 Food')));
    test('contains Travel entry', () => expect(expenseCategories, contains('🚗 Travel')));
    test('contains Shopping entry', () => expect(expenseCategories, contains('🛒 Shopping')));
    test('contains Health entry', () => expect(expenseCategories, contains('💊 Health')));
    test('all entries have emoji prefix (first char non-ASCII)', () {
      for (final c in expenseCategories) {
        expect(c.runes.first, greaterThan(127), reason: c);
      }
    });
  });

  group('incomeCategories constant list', () {
    test('has 8 entries', () => expect(incomeCategories.length, 8));
    test('contains Salary entry', () => expect(incomeCategories, contains('💼 Salary')));
    test('contains Freelance entry', () => expect(incomeCategories, contains('💻 Freelance')));
    test('contains Bonus entry', () => expect(incomeCategories, contains('💰 Bonus')));
    test('all entries have emoji prefix', () {
      for (final c in incomeCategories) {
        expect(c.runes.first, greaterThan(127), reason: c);
      }
    });
  });

  group('contactNames constant list', () {
    test('has 8 entries', () => expect(contactNames.length, 8));
    test('contains Arjun', () => expect(contactNames, contains('Arjun')));
    test('contains Priya', () => expect(contactNames, contains('Priya')));
    test('all names are non-empty strings', () {
      for (final n in contactNames) {
        expect(n, isNotEmpty);
      }
    });
  });
}
