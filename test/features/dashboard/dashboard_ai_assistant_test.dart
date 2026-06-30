// Tests for Dashboard AI Assistant — pure logic only (no Supabase / network).
// Covers IntentClassifier, AssistantResponse, ActionPayload, DeepLink, and
// HighlightChip — all dependencies-free classes that hold real business logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/features/dashboard/ai_assistant/intent_classifier.dart';
import 'package:wai_life_assistant/features/dashboard/ai_assistant/assistant_response.dart';
import 'package:wai_life_assistant/core/services/ai_parser.dart';

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // IntentClassifier
  // ───────────────────────────────────────────────────────────────────────────

  group('IntentClassifier.classify — data sources', () {
    final c = IntentClassifier.instance;

    test('wallet keywords resolve to wallet source', () {
      for (final q in [
        'How much did I spend this month?',
        'What is my balance?',
        'Show my income for June',
        'I paid ₹500 for coffee',
        'Transfer money to savings',
        'lend 200 to Ravi',
      ]) {
        final intent = c.classify(q);
        expect(intent.dataSources, contains(DataSource.wallet),
            reason: '"$q" should include wallet');
      }
    });

    test('pantry keywords resolve to pantry source', () {
      for (final q in [
        'What\'s on my grocery list?',
        'Add milk to pantry',
        'What should I cook tonight?',
        'Do I have eggs in the fridge?',
      ]) {
        final intent = c.classify(q);
        expect(intent.dataSources, contains(DataSource.pantry),
            reason: '"$q" should include pantry');
      }
    });

    test('planit keywords resolve to planit source', () {
      for (final q in [
        'Any pending tasks?',
        'When is my bill due?',
        'Set a reminder for tomorrow',
        'My upcoming birthdays?',
      ]) {
        final intent = c.classify(q);
        expect(intent.dataSources, contains(DataSource.planit),
            reason: '"$q" should include planit');
      }
    });

    test('health keywords resolve to health source', () {
      for (final q in [
        'What medications am I taking?',
        'My next doctor appointment?',
        'Log blood pressure reading',
        'Upcoming vaccinations?',
      ]) {
        final intent = c.classify(q);
        expect(intent.dataSources, contains(DataSource.health),
            reason: '"$q" should include health');
      }
    });

    test('family keywords add family + wallet sources', () {
      final intent = c.classify('How much did my family spend this month?');
      expect(intent.dataSources, containsAll([DataSource.family, DataSource.wallet]));
      expect(intent.needsFamily, isTrue);
    });

    test('functions keywords resolve to functions source', () {
      final intent = c.classify('Any upcoming wedding functions?');
      expect(intent.dataSources, contains(DataSource.functions));
    });

    test('myHub keywords (where/kept/stored) resolve to myHub source', () {
      final intent = c.classify('Where did I keep my passport?');
      expect(intent.dataSources, contains(DataSource.myHub));
    });

    test('crossTab keywords (summary/overview) resolve to crossTab source', () {
      final intent = c.classify('Give me an overview of everything');
      expect(intent.dataSources, contains(DataSource.crossTab));
    });

    test('unrecognised question defaults to wallet + planit', () {
      final intent = c.classify('hello');
      expect(intent.dataSources, containsAll([DataSource.wallet, DataSource.planit]));
    });

    test('family flag is false for non-family queries', () {
      final intent = c.classify('How much did I spend?');
      expect(intent.needsFamily, isFalse);
    });
  });

  group('IntentClassifier.classify — time range', () {
    final c = IntentClassifier.instance;

    test('today queries', () {
      expect(c.classify('What did I spend today?').timeRange, TimeRange.today);
      expect(c.classify('tonight\'s plan').timeRange, TimeRange.today);
    });

    test('this week queries', () {
      expect(c.classify('Spending this week').timeRange, TimeRange.thisWeek);
    });

    test('last month queries', () {
      expect(c.classify('last month expenses').timeRange, TimeRange.lastMonth);
      expect(c.classify('previous month income').timeRange, TimeRange.lastMonth);
    });

    test('this month queries', () {
      expect(c.classify('This month\'s expenses?').timeRange, TimeRange.thisMonth);
    });

    test('all time queries', () {
      expect(c.classify('Show all time spending').timeRange, TimeRange.allTime);
    });

    test('default is thisMonth when no time keyword', () {
      expect(c.classify('How much did I spend?').timeRange, TimeRange.thisMonth);
    });
  });

  group('IntentClassifier.classify — query type', () {
    final c = IntentClassifier.instance;

    test('amount questions → specific', () {
      expect(c.classify('how much did I spend?').queryType, QueryType.specific);
      expect(c.classify('total income this month').queryType, QueryType.specific);
    });

    test('comparison questions → comparison', () {
      expect(c.classify('compare my spending vs last month').queryType, QueryType.comparison);
      expect(c.classify('difference between income and expense').queryType, QueryType.comparison);
    });

    test('suggestion questions → suggestion', () {
      expect(c.classify('suggest ways to save money').queryType, QueryType.suggestion);
      expect(c.classify('should I buy groceries today?').queryType, QueryType.suggestion);
    });

    test('prediction questions → prediction', () {
      expect(c.classify('will I overspend next month?').queryType, QueryType.prediction);
      expect(c.classify('forecast my expenses').queryType, QueryType.prediction);
    });

    test('summary questions → summary', () {
      expect(c.classify('give me a summary of finances').queryType, QueryType.summary);
    });

    test('unclassified defaults to specific', () {
      expect(c.classify('grocery list').queryType, QueryType.specific);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // AssistantResponse
  // ───────────────────────────────────────────────────────────────────────────

  group('AssistantResponse.fromResult', () {
    test('failed AIParseResult returns error answer', () {
      final result = AIParseResult(
        success: false,
        error: 'Gemini is down. Please try again.',
      );
      final response = AssistantResponse.fromResult(result);
      expect(response.answer, 'Gemini is down. Please try again.');
      expect(response.isAction, isFalse);
    });

    test('null data returns fallback message', () {
      final result = AIParseResult(success: false, error: null);
      final response = AssistantResponse.fromResult(result);
      expect(response.answer, 'Sorry, something went wrong. Please try again.');
    });

    test('successful read result parses answer', () {
      final result = AIParseResult(
        success: true,
        data: {
          'response_type': 'answer',
          'answer': 'You spent ₹4,500 this month.',
          'confidence': 0.95,
          'highlights': [],
          'suggestions': [],
          'deep_links': [],
        },
      );
      final response = AssistantResponse.fromResult(result);
      expect(response.answer, 'You spent ₹4,500 this month.');
      expect(response.confidence, 0.95);
      expect(response.isAction, isFalse);
    });

    test('successful action result parses action payload', () {
      final result = AIParseResult(
        success: true,
        data: {
          'response_type': 'action',
          'answer': 'I\'ll add milk to your grocery list.',
          'confidence': 0.98,
          'action_type': 'add_grocery',
          'confirm_message': 'Add milk to grocery list?',
          'data': {'name': 'Milk', 'qty': 2, 'unit': 'litres', 'category': 'Dairy'},
        },
      );
      final response = AssistantResponse.fromResult(result);
      expect(response.isAction, isTrue);
      expect(response.action!.actionType, ActionType.addGrocery);
      expect(response.action!.confirmMessage, 'Add milk to grocery list?');
      expect(response.action!.data['name'], 'Milk');
    });

    test('highlights are parsed from list', () {
      final result = AIParseResult(
        success: true,
        data: {
          'response_type': 'answer',
          'answer': 'Monthly breakdown:',
          'confidence': 0.9,
          'highlights': [
            {'label': 'Total Spent', 'value': '₹12,000', 'color': 'red'},
            {'label': 'Saved', 'value': '₹3,000', 'color': 'green'},
          ],
          'suggestions': [],
          'deep_links': [],
        },
      );
      final response = AssistantResponse.fromResult(result);
      expect(response.highlights.length, 2);
      expect(response.highlights[0].label, 'Total Spent');
      expect(response.highlights[0].color, 'red');
      expect(response.highlights[1].value, '₹3,000');
    });

    test('suggestions list is parsed', () {
      final result = AIParseResult(
        success: true,
        data: {
          'response_type': 'answer',
          'answer': 'Here\'s what I found.',
          'confidence': 0.85,
          'highlights': [],
          'suggestions': ['What\'s my savings rate?', 'Show top expenses'],
          'deep_links': [],
        },
      );
      final response = AssistantResponse.fromResult(result);
      expect(response.suggestions, ['What\'s my savings rate?', 'Show top expenses']);
    });

    test('deep_links are parsed with correct tab indices', () {
      final result = AIParseResult(
        success: true,
        data: {
          'response_type': 'answer',
          'answer': 'Check your wallet.',
          'confidence': 0.9,
          'highlights': [],
          'suggestions': [],
          'deep_links': [
            {'label': 'Open Wallet', 'tab': 'wallet'},
            {'label': 'Open Pantry', 'tab': 'pantry'},
          ],
        },
      );
      final response = AssistantResponse.fromResult(result);
      expect(response.deepLinks.length, 2);
      expect(response.deepLinks[0].tab, 1); // wallet
      expect(response.deepLinks[1].tab, 2); // pantry
    });

    test('missing confidence field defaults to 1.0', () {
      final result = AIParseResult(
        success: true,
        data: {
          'response_type': 'answer',
          'answer': 'Test answer',
          'highlights': [],
          'suggestions': [],
          'deep_links': [],
        },
      );
      final response = AssistantResponse.fromResult(result);
      expect(response.confidence, 1.0);
    });

    test('isEmpty returns true when answer is empty', () {
      const response = AssistantResponse(answer: '');
      expect(response.isEmpty, isTrue);
    });

    test('isEmpty returns false when answer has content', () {
      const response = AssistantResponse(answer: 'Some answer');
      expect(response.isEmpty, isFalse);
    });
  });

  group('AssistantResponse.fromRaw', () {
    test('parses valid embedded JSON', () {
      const raw = 'Here is the result: {"answer":"You spent a lot","highlights":[],'
          '"suggestions":[],"deep_links":[],"confidence":0.8}';
      final response = AssistantResponse.fromRaw(raw);
      expect(response.answer, 'You spent a lot');
      expect(response.confidence, 0.8);
    });

    test('falls back to plain text when JSON is invalid', () {
      const raw = 'This is just a plain text answer without JSON.';
      final response = AssistantResponse.fromRaw(raw);
      expect(response.answer, 'This is just a plain text answer without JSON.');
    });

    test('extracts [GO:tab] deep-link tags from plain text', () {
      const raw = 'Check your wallet [GO:wallet] or pantry [GO:pantry] for details.';
      final response = AssistantResponse.fromRaw(raw);
      expect(response.deepLinks.length, 2);
      expect(response.deepLinks[0].tab, 1);
      expect(response.deepLinks[1].tab, 2);
      expect(response.answer, isNot(contains('[GO:')));
    });

    test('handles empty string gracefully', () {
      final response = AssistantResponse.fromRaw('');
      expect(response.answer, '');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // ActionPayload
  // ───────────────────────────────────────────────────────────────────────────

  group('ActionPayload.fromJson', () {
    test('returns null for null input', () {
      expect(ActionPayload.fromJson(null), isNull);
    });

    test('returns null for unknown action_type', () {
      final payload = ActionPayload.fromJson({'action_type': 'unknown_action'});
      expect(payload, isNull);
    });

    test('add_expense parses correctly', () {
      final payload = ActionPayload.fromJson({
        'action_type': 'add_expense',
        'confirm_message': 'Record ₹200 for coffee?',
        'data': {'title': 'Coffee', 'amount': 200, 'category': 'Food', 'pay_mode': 'UPI'},
      });
      expect(payload, isNotNull);
      expect(payload!.actionType, ActionType.addExpense);
      expect(payload.confirmMessage, 'Record ₹200 for coffee?');
      expect(payload.data['amount'], 200);
    });

    test('add_income parses correctly', () {
      final payload = ActionPayload.fromJson({
        'action_type': 'add_income',
        'confirm_message': 'Add salary income?',
        'data': {'title': 'Salary', 'amount': 50000, 'category': 'Salary'},
      });
      expect(payload!.actionType, ActionType.addIncome);
    });

    test('add_grocery parses correctly', () {
      final payload = ActionPayload.fromJson({
        'action_type': 'add_grocery',
        'confirm_message': 'Add tomatoes to grocery?',
        'data': {'name': 'Tomatoes', 'qty': 1, 'unit': 'kg', 'category': 'Vegetables'},
      });
      expect(payload!.actionType, ActionType.addGrocery);
      expect(payload.data['name'], 'Tomatoes');
    });

    test('add_task parses correctly', () {
      final payload = ActionPayload.fromJson({
        'action_type': 'add_task',
        'confirm_message': 'Add task?',
        'data': {'title': 'Pay electricity bill', 'due_date': '2026-07-01'},
      });
      expect(payload!.actionType, ActionType.addTask);
    });

    test('add_reminder parses correctly', () {
      final payload = ActionPayload.fromJson({
        'action_type': 'add_reminder',
        'confirm_message': 'Set reminder?',
        'data': {'title': 'Doctor appointment', 'due_date': '2026-07-05', 'due_time': '10:00', 'priority': 'high'},
      });
      expect(payload!.actionType, ActionType.addReminder);
    });

    test('add_lend parses correctly', () {
      final payload = ActionPayload.fromJson({
        'action_type': 'add_lend',
        'confirm_message': 'Record lend?',
        'data': {'person': 'Ravi', 'amount': 500, 'note': 'For lunch'},
      });
      expect(payload!.actionType, ActionType.addLend);
    });

    test('add_borrow parses correctly', () {
      final payload = ActionPayload.fromJson({
        'action_type': 'add_borrow',
        'confirm_message': 'Record borrow?',
        'data': {'person': 'Priya', 'amount': 1000},
      });
      expect(payload!.actionType, ActionType.addBorrow);
    });

    test('add_medication parses correctly', () {
      final payload = ActionPayload.fromJson({
        'action_type': 'add_medication',
        'confirm_message': 'Add medication?',
        'data': {'name': 'Metformin', 'dosage': '500mg', 'frequency': 'twice daily'},
      });
      expect(payload!.actionType, ActionType.addMedication);
    });

    test('add_appointment parses correctly', () {
      final payload = ActionPayload.fromJson({
        'action_type': 'add_appointment',
        'confirm_message': 'Book appointment?',
        'data': {'doctor_name': 'Dr. Sharma', 'speciality': 'Cardiologist', 'appt_date': '2026-07-10'},
      });
      expect(payload!.actionType, ActionType.addAppointment);
    });

    test('add_vital parses correctly', () {
      final payload = ActionPayload.fromJson({
        'action_type': 'add_vital',
        'confirm_message': 'Log vital?',
        'data': {'vital_type': 'Blood Pressure', 'value': 120, 'value2': 80, 'sub_type': 'mmHg'},
      });
      expect(payload!.actionType, ActionType.addVital);
    });

    test('add_special_day parses correctly', () {
      final payload = ActionPayload.fromJson({
        'action_type': 'add_special_day',
        'confirm_message': 'Add special day?',
        'data': {'title': 'Anniversary', 'date': '2026-08-15', 'type': 'anniversary'},
      });
      expect(payload!.actionType, ActionType.addSpecialDay);
    });

    test('displayFields for add_expense returns expected keys', () {
      final payload = ActionPayload.fromJson({
        'action_type': 'add_expense',
        'confirm_message': 'Record expense?',
        'data': {'title': 'Coffee', 'amount': 200, 'category': 'Food', 'pay_mode': 'UPI'},
      })!;
      final fields = payload.displayFields;
      final labels = fields.map((f) => f.$1).toList();
      expect(labels, containsAll(['For', 'Amount', 'Category', 'Via']));
    });

    test('displayFields for add_grocery returns expected keys', () {
      final payload = ActionPayload.fromJson({
        'action_type': 'add_grocery',
        'confirm_message': 'Add grocery?',
        'data': {'name': 'Milk', 'qty': 2, 'unit': 'litres', 'category': 'Dairy'},
      })!;
      final fields = payload.displayFields;
      final labels = fields.map((f) => f.$1).toList();
      expect(labels, containsAll(['Item', 'Qty', 'Category']));
    });

    test('displayFields omits empty fields', () {
      final payload = ActionPayload.fromJson({
        'action_type': 'add_expense',
        'confirm_message': 'Record?',
        'data': {'title': 'Coffee', 'amount': 200}, // no category or pay_mode
      })!;
      final labels = payload.displayFields.map((f) => f.$1).toList();
      expect(labels, isNot(contains('Category')));
      expect(labels, isNot(contains('Via')));
    });

    test('icon and label return non-empty strings for all action types', () {
      const allTypes = [
        'add_grocery', 'add_task', 'add_reminder', 'add_expense', 'add_income',
        'add_lend', 'add_borrow', 'add_function_upcoming', 'add_function_my',
        'add_meal', 'add_special_day', 'add_wardrobe_item', 'add_medication',
        'add_appointment', 'add_vital', 'add_vaccination', 'add_doctor', 'add_insurance',
      ];
      for (final type in allTypes) {
        final payload = ActionPayload.fromJson({
          'action_type': type,
          'confirm_message': 'Confirm?',
          'data': <String, dynamic>{},
        });
        expect(payload, isNotNull, reason: '$type should parse');
        expect(payload!.icon, isNotEmpty, reason: '$type should have icon');
        expect(payload.label, isNotEmpty, reason: '$type should have label');
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // DeepLink
  // ───────────────────────────────────────────────────────────────────────────

  group('DeepLink.fromJson — tab index mapping', () {
    test('wallet → tab 1', () {
      final link = DeepLink.fromJson({'label': 'Open', 'tab': 'wallet'});
      expect(link.tab, 1);
    });

    test('pantry → tab 2', () {
      final link = DeepLink.fromJson({'label': 'Open', 'tab': 'pantry'});
      expect(link.tab, 2);
    });

    test('myhub → tab 3', () {
      final link = DeepLink.fromJson({'label': 'Open', 'tab': 'myhub'});
      expect(link.tab, 3);
    });

    test('health → tab 3', () {
      final link = DeepLink.fromJson({'label': 'Open', 'tab': 'health'});
      expect(link.tab, 3);
    });

    test('functions → tab 3', () {
      final link = DeepLink.fromJson({'label': 'Open', 'tab': 'functions'});
      expect(link.tab, 3);
    });

    test('planit → tab 4', () {
      final link = DeepLink.fromJson({'label': 'Open', 'tab': 'planit'});
      expect(link.tab, 4);
    });

    test('unknown tab → 0 (dashboard)', () {
      final link = DeepLink.fromJson({'label': 'Open', 'tab': 'unknown'});
      expect(link.tab, 0);
    });

    test('sub_tab is parsed', () {
      final link = DeepLink.fromJson({'label': 'Open', 'tab': 'pantry', 'sub_tab': 'grocery'});
      expect(link.subTab, 'grocery');
    });

    test('missing label defaults to "Open"', () {
      final link = DeepLink.fromJson({'tab': 'wallet'});
      expect(link.label, 'Open');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // HighlightChip
  // ───────────────────────────────────────────────────────────────────────────

  group('HighlightChip.fromJson', () {
    test('parses all fields', () {
      final chip = HighlightChip.fromJson({
        'label': 'Total Spent',
        'value': '₹12,500',
        'color': 'red',
      });
      expect(chip.label, 'Total Spent');
      expect(chip.value, '₹12,500');
      expect(chip.color, 'red');
    });

    test('missing color defaults to blue', () {
      final chip = HighlightChip.fromJson({'label': 'Score', 'value': '85'});
      expect(chip.color, 'blue');
    });

    test('missing fields default to empty strings', () {
      final chip = HighlightChip.fromJson({});
      expect(chip.label, '');
      expect(chip.value, '');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Edge cases — multi-domain queries
  // ───────────────────────────────────────────────────────────────────────────

  group('IntentClassifier — multi-domain queries', () {
    final c = IntentClassifier.instance;

    test('family expense query gets both family and wallet', () {
      final intent = c.classify('How much did my family spend on groceries?');
      expect(intent.dataSources, containsAll([DataSource.family, DataSource.wallet, DataSource.pantry]));
    });

    test('query with birthday resolves planit + functions', () {
      // "birthday" matches both planit (special day) and functions
      final intent = c.classify('Any upcoming birthday functions?');
      expect(intent.dataSources, containsAll([DataSource.planit, DataSource.functions]));
    });

    test('summary query gets crossTab source', () {
      final intent = c.classify('Give me a total summary of everything');
      expect(intent.dataSources, contains(DataSource.crossTab));
    });

    test('needsFamily is false for general wallet query', () {
      final intent = c.classify('How much did I spend on food?');
      expect(intent.needsFamily, isFalse);
    });
  });
}
