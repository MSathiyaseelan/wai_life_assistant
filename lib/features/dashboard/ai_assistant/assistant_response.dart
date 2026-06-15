import 'dart:convert';
import 'package:wai_life_assistant/core/services/ai_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ActionType — what the AI wants to write into the app
// ─────────────────────────────────────────────────────────────────────────────

enum ActionType {
  addGrocery,
  addTask,
  addReminder,
  addExpense,
  addIncome,
  addFunctionUpcoming,
  addFunctionMy,
  addMeal,
  addSpecialDay,
  addWardrobeItem,
  addMedication,
  addAppointment,
  addVital,
  addVaccination,
  addDoctor,
  addInsurance,
}

// ─────────────────────────────────────────────────────────────────────────────
// ActionPayload — structured write action returned by Gemini
// ─────────────────────────────────────────────────────────────────────────────

class ActionPayload {
  final ActionType actionType;
  final String confirmMessage;
  final Map<String, dynamic> data;

  const ActionPayload({
    required this.actionType,
    required this.confirmMessage,
    required this.data,
  });

  static ActionPayload? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final type = _parseType(j['action_type'] as String? ?? '');
    if (type == null) return null;
    return ActionPayload(
      actionType: type,
      confirmMessage: j['confirm_message'] as String? ?? '',
      data: (j['data'] as Map<String, dynamic>?) ?? {},
    );
  }

  static ActionType? _parseType(String s) => switch (s) {
        'add_grocery'            => ActionType.addGrocery,
        'add_task'               => ActionType.addTask,
        'add_reminder'           => ActionType.addReminder,
        'add_expense'            => ActionType.addExpense,
        'add_income'             => ActionType.addIncome,
        'add_function_upcoming'  => ActionType.addFunctionUpcoming,
        'add_function_my'        => ActionType.addFunctionMy,
        'add_meal'               => ActionType.addMeal,
        'add_special_day'        => ActionType.addSpecialDay,
        'add_wardrobe_item'      => ActionType.addWardrobeItem,
        'add_medication'         => ActionType.addMedication,
        'add_appointment'        => ActionType.addAppointment,
        'add_vital'              => ActionType.addVital,
        'add_vaccination'        => ActionType.addVaccination,
        'add_doctor'             => ActionType.addDoctor,
        'add_insurance'          => ActionType.addInsurance,
        _                        => null,
      };

  String get icon => switch (actionType) {
        ActionType.addGrocery           => '🛒',
        ActionType.addTask              => '✅',
        ActionType.addReminder          => '🔔',
        ActionType.addExpense           => '💸',
        ActionType.addIncome            => '💰',
        ActionType.addFunctionUpcoming  => '🎉',
        ActionType.addFunctionMy        => '🎊',
        ActionType.addMeal              => '🍽️',
        ActionType.addSpecialDay        => '📅',
        ActionType.addWardrobeItem      => '👗',
        ActionType.addMedication        => '💊',
        ActionType.addAppointment       => '🏥',
        ActionType.addVital             => '❤️',
        ActionType.addVaccination       => '💉',
        ActionType.addDoctor            => '👨‍⚕️',
        ActionType.addInsurance         => '🛡️',
      };

  String get label => switch (actionType) {
        ActionType.addGrocery           => 'Add to Grocery List',
        ActionType.addTask              => 'Add Task',
        ActionType.addReminder          => 'Set Reminder',
        ActionType.addExpense           => 'Record Expense',
        ActionType.addIncome            => 'Record Income',
        ActionType.addFunctionUpcoming  => 'Add Upcoming Function',
        ActionType.addFunctionMy        => 'Add My Function',
        ActionType.addMeal              => 'Log Meal',
        ActionType.addSpecialDay        => 'Add Special Day',
        ActionType.addWardrobeItem      => 'Add to Wardrobe',
        ActionType.addMedication        => 'Add Medication',
        ActionType.addAppointment       => 'Book Appointment',
        ActionType.addVital             => 'Log Vital',
        ActionType.addVaccination       => 'Record Vaccination',
        ActionType.addDoctor            => 'Add Doctor',
        ActionType.addInsurance         => 'Add Insurance Policy',
      };

  /// Human-readable key-value pairs to show in the confirmation card.
  List<(String, String)> get displayFields {
    String str(String key) => (data[key] as String? ?? '').trim();
    String num_(String key) {
      final v = data[key];
      return v == null ? '' : v.toString();
    }

    return switch (actionType) {
      ActionType.addGrocery => [
          if (str('name').isNotEmpty)     ('Item',     str('name')),
          if (num_('qty').isNotEmpty)     ('Qty',      '${num_('qty')} ${str('unit')}'),
          if (str('category').isNotEmpty) ('Category', str('category')),
        ],
      ActionType.addTask => [
          if (str('title').isNotEmpty)    ('Task',     str('title')),
          if (str('due_date').isNotEmpty) ('Due',      str('due_date')),
        ],
      ActionType.addReminder => [
          if (str('title').isNotEmpty)    ('Reminder', str('title')),
          if (str('due_date').isNotEmpty) ('Date',     str('due_date')),
          if (str('due_time').isNotEmpty) ('Time',     str('due_time')),
          if (str('priority').isNotEmpty) ('Priority', str('priority')),
        ],
      ActionType.addExpense => [
          if (str('title').isNotEmpty)    ('For',      str('title')),
          if (num_('amount').isNotEmpty)  ('Amount',   '₹${num_('amount')}'),
          if (str('category').isNotEmpty) ('Category', str('category')),
          if (str('pay_mode').isNotEmpty) ('Via',      str('pay_mode')),
        ],
      ActionType.addIncome => [
          if (str('title').isNotEmpty)    ('Source',   str('title')),
          if (num_('amount').isNotEmpty)  ('Amount',   '₹${num_('amount')}'),
          if (str('category').isNotEmpty) ('Category', str('category')),
        ],
      ActionType.addFunctionUpcoming => [
          if (str('function_title').isNotEmpty) ('Function', str('function_title')),
          if (str('person_name').isNotEmpty)    ('Person',   str('person_name')),
          if (str('type').isNotEmpty)           ('Type',     str('type')),
          if (str('date').isNotEmpty)           ('Date',     str('date')),
          if (str('venue').isNotEmpty)          ('Venue',    str('venue')),
        ],
      ActionType.addFunctionMy => [
          if (str('title').isNotEmpty)         ('Function',    str('title')),
          if (str('type').isNotEmpty)          ('Type',        str('type')),
          if (str('who_function').isNotEmpty)  ('Hosted by',   str('who_function')),
          if (str('function_date').isNotEmpty) ('Date',        str('function_date')),
          if (str('venue').isNotEmpty)         ('Venue',       str('venue')),
        ],
      ActionType.addMeal => [
          if (str('meal_name').isNotEmpty) ('Meal',      str('meal_name')),
          if (str('meal_time').isNotEmpty) ('Time',      str('meal_time')),
          if (str('date').isNotEmpty)      ('Date',      str('date')),
        ],
      ActionType.addSpecialDay => [
          if (str('title').isNotEmpty) ('Occasion', str('title')),
          if (str('date').isNotEmpty)  ('Date',     str('date')),
          if (str('type').isNotEmpty)  ('Type',     str('type')),
        ],
      ActionType.addWardrobeItem => [
          if (str('name').isNotEmpty)     ('Item',     str('name')),
          if (str('type').isNotEmpty)     ('Type',     str('type')),
          if (str('color').isNotEmpty)    ('Color',    str('color')),
          if (str('occasion').isNotEmpty) ('Occasion', str('occasion')),
        ],
      ActionType.addMedication => [
          if (str('name').isNotEmpty)      ('Medicine',   str('name')),
          if (str('dosage').isNotEmpty)    ('Dosage',     str('dosage')),
          if (str('frequency').isNotEmpty) ('Frequency',  str('frequency')),
        ],
      ActionType.addAppointment => [
          if (str('doctor_name').isNotEmpty) ('Doctor',    str('doctor_name')),
          if (str('speciality').isNotEmpty)  ('Specialty', str('speciality')),
          if (str('appt_date').isNotEmpty)   ('Date',      str('appt_date')),
        ],
      ActionType.addVital => [
          if (str('vital_type').isNotEmpty) ('Type',    str('vital_type')),
          if (num_('value').isNotEmpty)     ('Reading', '${num_('value')}${num_('value2').isNotEmpty ? '/${num_('value2')}' : ''} ${str('sub_type')}'),
          if (str('notes').isNotEmpty)      ('Notes',   str('notes')),
        ],
      ActionType.addVaccination => [
          if (str('vaccine_name').isNotEmpty) ('Vaccine',     str('vaccine_name')),
          if (str('date_given').isNotEmpty)   ('Date Given',  str('date_given')),
          if (str('next_due').isNotEmpty)     ('Next Due',    str('next_due')),
        ],
      ActionType.addDoctor => [
          if (str('name').isNotEmpty)       ('Doctor',    str('name')),
          if (str('speciality').isNotEmpty) ('Specialty', str('speciality')),
          if (str('phone').isNotEmpty)      ('Phone',     str('phone')),
        ],
      ActionType.addInsurance => [
          if (str('policy_name').isNotEmpty)  ('Policy',    str('policy_name')),
          if (str('provider').isNotEmpty)     ('Provider',  str('provider')),
          if (num_('coverage_amount').isNotEmpty) ('Coverage', '₹${num_('coverage_amount')}'),
          if (str('expiry_date').isNotEmpty)  ('Expires',   str('expiry_date')),
        ],
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HighlightChip
// ─────────────────────────────────────────────────────────────────────────────

class HighlightChip {
  final String label;
  final String value;
  final String color; // green | red | amber | blue

  const HighlightChip({
    required this.label,
    required this.value,
    required this.color,
  });

  factory HighlightChip.fromJson(Map<String, dynamic> j) => HighlightChip(
        label: j['label'] as String? ?? '',
        value: j['value'] as String? ?? '',
        color: j['color'] as String? ?? 'blue',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DeepLink
// ─────────────────────────────────────────────────────────────────────────────

class DeepLink {
  final String label;
  final int tab;
  final String? subTab;

  const DeepLink({required this.label, required this.tab, this.subTab});

  factory DeepLink.fromJson(Map<String, dynamic> j) {
    final tabStr = (j['tab'] as String? ?? '').toLowerCase();
    return DeepLink(
      label: j['label'] as String? ?? 'Open',
      tab: _tabIndex(tabStr),
      subTab: j['sub_tab'] as String?,
    );
  }

  static int _tabIndex(String tag) => switch (tag) {
        'wallet'                      => 1,
        'pantry'                      => 2,
        'myhub' || 'health' || 'functions' => 3,
        'planit'                      => 4,
        _                             => 0,
      };

  String get emoji => switch (tab) {
        1 => '₹',
        2 => '🥗',
        3 => '🏥',
        4 => '📅',
        _ => '→',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// AssistantResponse — structured response from Gemini
// ─────────────────────────────────────────────────────────────────────────────

class AssistantResponse {
  final String answer;
  final List<HighlightChip> highlights;
  final List<String> suggestions;
  final List<DeepLink> deepLinks;
  final double confidence;
  final ActionPayload? action;

  const AssistantResponse({
    required this.answer,
    this.highlights = const [],
    this.suggestions = const [],
    this.deepLinks = const [],
    this.confidence = 1.0,
    this.action,
  });

  bool get isAction => action != null;

  static AssistantResponse fromResult(AIParseResult result) {
    if (!result.success || result.data == null) {
      return AssistantResponse(answer: _friendlyError(result.error));
    }
    return _fromMap(result.data!);
  }

  static String _friendlyError(String? raw) {
    if (raw == null) return 'Sorry, I couldn\'t fetch an answer right now. Please try again.';
    final msg = raw.toLowerCase();
    if (msg.contains('high demand') || msg.contains('overloaded') ||
        msg.contains('try again later') || msg.contains('resource_exhausted') ||
        msg.contains('503') || msg.contains('capacity')) {
      return 'WAI is a bit busy right now — too many requests at the moment. Please try again in a few seconds.';
    }
    if (msg.contains('quota') || msg.contains('rate limit') || msg.contains('rate_limit') || msg.contains('429')) {
      return 'WAI has hit its request limit for now. Please wait a moment and try again.';
    }
    if (msg.contains('timeout') || msg.contains('deadline') || msg.contains('timed out')) {
      return 'WAI took too long to respond. Please check your connection and try again.';
    }
    if (msg.contains('no active prompt') || msg.contains('no prompt found')) {
      return 'WAI is still being configured for this type of question. Please try again soon.';
    }
    if (msg.contains('invalid json') || msg.contains('json parse')) {
      return 'WAI returned an unexpected response. Please try rephrasing your question.';
    }
    return 'Sorry, I couldn\'t fetch an answer right now. Please try again.';
  }

  static AssistantResponse _fromMap(Map<String, dynamic> data) {
    // Detect action response
    if (data['response_type'] == 'action') {
      final action = ActionPayload.fromJson(data);
      if (action != null) {
        return AssistantResponse(
          answer: data['answer'] as String? ?? '',
          confidence: (data['confidence'] as num?)?.toDouble() ?? 1.0,
          action: action,
          deepLinks: (data['deep_links'] as List? ?? [])
              .map((l) => DeepLink.fromJson(l as Map<String, dynamic>))
              .toList(),
        );
      }
    }

    // Standard query/answer response
    final highlights = (data['highlights'] as List? ?? [])
        .map((h) => HighlightChip.fromJson(h as Map<String, dynamic>))
        .toList();
    final suggestions = (data['suggestions'] as List? ?? [])
        .map((s) => s as String)
        .toList();
    final deepLinks = (data['deep_links'] as List? ?? [])
        .map((l) => DeepLink.fromJson(l as Map<String, dynamic>))
        .toList();
    return AssistantResponse(
      answer: data['answer'] as String? ?? '',
      highlights: highlights,
      suggestions: suggestions,
      deepLinks: deepLinks,
      confidence: (data['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  static AssistantResponse fromRaw(String raw) {
    try {
      final jsonStart = raw.indexOf('{');
      final jsonEnd = raw.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
        final data = jsonDecode(raw.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
        return _fromMap(data);
      }
    } catch (_) {}

    final tagPattern = RegExp(r'\[GO:(wallet|pantry|myhub|health|functions|planit)\]', caseSensitive: false);
    final deepLinks = tagPattern
        .allMatches(raw)
        .map((m) => DeepLink.fromJson({'label': 'Open ${m.group(1)}', 'tab': m.group(1)!.toLowerCase()}))
        .toList();

    return AssistantResponse(
      answer: raw.replaceAll(tagPattern, '').trim(),
      deepLinks: deepLinks,
    );
  }

  bool get isEmpty => answer.isEmpty;
}
