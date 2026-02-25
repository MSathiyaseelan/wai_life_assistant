import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import '../../../../../core/theme/app_theme.dart';

// ── Flow types ────────────────────────────────────────────────────────────────

enum FlowType { expense, income, split, lend, borrow, request }

extension FlowTypeExt on FlowType {
  String get label {
    switch (this) {
      case FlowType.expense:
        return 'Add Expense';
      case FlowType.income:
        return 'Add Income';
      case FlowType.split:
        return 'Split Bill';
      case FlowType.lend:
        return 'Lend Money';
      case FlowType.borrow:
        return 'Borrow';
      case FlowType.request:
        return 'Request Money';
    }
  }

  String get emoji {
    switch (this) {
      case FlowType.expense:
        return '💸';
      case FlowType.income:
        return '💰';
      case FlowType.split:
        return '⚖️';
      case FlowType.lend:
        return '📤';
      case FlowType.borrow:
        return '📥';
      case FlowType.request:
        return '🔔';
    }
  }

  Color get color {
    switch (this) {
      case FlowType.expense:
        return AppColors.expense;
      case FlowType.income:
        return AppColors.income;
      case FlowType.split:
        return AppColors.split;
      case FlowType.lend:
        return AppColors.lend;
      case FlowType.borrow:
        return AppColors.borrow;
      case FlowType.request:
        return AppColors.request;
    }
  }

  /// Ordered list of step keys for this flow
  List<FlowStep> get steps {
    switch (this) {
      case FlowType.expense:
        return [
          FlowStep.amount,
          FlowStep.category,
          FlowStep.owner,
          FlowStep.paymode,
          FlowStep.date,
          FlowStep.confirm,
        ];
      case FlowType.income:
        return [
          FlowStep.amount,
          FlowStep.category,
          FlowStep.owner,
          FlowStep.paymode,
          FlowStep.date,
          FlowStep.confirm,
        ];
      case FlowType.split:
        return [
          FlowStep.amount,
          FlowStep.persons,
          FlowStep.splitType,
          FlowStep.date,
          FlowStep.confirm,
        ];
      case FlowType.lend:
        return [
          FlowStep.amount,
          FlowStep.person,
          FlowStep.dueDate,
          FlowStep.confirm,
        ];
      case FlowType.borrow:
        return [
          FlowStep.amount,
          FlowStep.person,
          FlowStep.dueDate,
          FlowStep.confirm,
        ];
      case FlowType.request:
        return [
          FlowStep.amount,
          FlowStep.person,
          FlowStep.note,
          FlowStep.confirm,
        ];
    }
  }

  /// Converts to TxType for saving
  TxType get txType {
    switch (this) {
      case FlowType.expense:
        return TxType.expense;
      case FlowType.income:
        return TxType.income;
      case FlowType.split:
        return TxType.split;
      case FlowType.lend:
        return TxType.lend;
      case FlowType.borrow:
        return TxType.borrow;
      case FlowType.request:
        return TxType.request;
    }
  }
}

// ── Step keys ─────────────────────────────────────────────────────────────────

enum FlowStep {
  amount,
  category,
  owner,
  paymode,
  date,
  persons,
  splitType,
  person,
  dueDate,
  note,
  confirm,
}

extension FlowStepExt on FlowStep {
  String botQuestion(FlowType flow) {
    switch (this) {
      case FlowStep.amount:
        switch (flow) {
          case FlowType.expense:
            return '💸 How much did you spend?';
          case FlowType.income:
            return '💰 How much did you receive?';
          case FlowType.split:
            return '⚖️ What\'s the total bill amount?';
          case FlowType.lend:
            return '📤 How much did you lend?';
          case FlowType.borrow:
            return '📥 How much did you borrow?';
          case FlowType.request:
            return '🔔 How much do you want to request?';
        }
      case FlowStep.category:
        return flow == FlowType.income
            ? 'What\'s the source of income?'
            : 'What was it for?';
      case FlowStep.owner:
        return 'Personal or Family account?';
      case FlowStep.paymode:
        return 'Cash or Online payment?';
      case FlowStep.date:
        return 'When did this happen?';
      case FlowStep.persons:
        return 'Who\'s splitting with you?';
      case FlowStep.splitType:
        return 'How do you want to split?';
      case FlowStep.person:
        switch (flow) {
          case FlowType.lend:
            return 'Who did you lend to?';
          case FlowType.borrow:
            return 'Who did you borrow from?';
          case FlowType.request:
            return 'Who are you requesting from?';
          default:
            return 'Who is the person?';
        }
      case FlowStep.dueDate:
        return 'Set a due date?';
      case FlowStep.note:
        return 'Add a note? (optional)';
      case FlowStep.confirm:
        return '✅ Here\'s your summary — looks good?';
    }
  }
}

// ── Flow data (collected answers) ─────────────────────────────────────────────

class FlowData {
  double? amount;
  String? category;
  String? owner; // 'Personal' | 'Family'
  String? paymode; // 'Cash' | 'Online'
  String? date;
  List<String>? persons;
  String? splitType;
  String? person;
  String? dueDate;
  String? note;

  FlowData();

  /// Builds a TxModel from collected data
  TxModel toTxModel(FlowType flowType, String walletId) {
    final now = DateTime.now();
    DateTime txDate = now;
    if (date == 'Yesterday') txDate = now.subtract(const Duration(days: 1));
    if (date == '2 days ago') txDate = now.subtract(const Duration(days: 2));

    PayMode? pm;
    if (paymode == 'Cash') pm = PayMode.cash;
    if (paymode == 'Online') pm = PayMode.online;

    final cat =
        category ?? (flowType == FlowType.income ? 'Income' : 'Expense');

    return TxModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: flowType.txType,
      amount: amount ?? 0,
      category: cat,
      date: txDate,
      walletId: walletId,
      payMode: pm,
      note: (note?.isEmpty ?? true) ? null : note,
      person: person,
      persons: persons,
      dueDate: dueDate,
    );
  }

  /// Summary rows for ConfirmStep
  List<MapEntry<String, String>> get summaryRows {
    final rows = <MapEntry<String, String>>[];
    if (amount != null) rows.add(MapEntry('Amount', '₹${_fmt(amount!)}'));
    if (category != null) rows.add(MapEntry('Category', category!));
    if (owner != null) rows.add(MapEntry('Account', owner!));
    if (paymode != null) rows.add(MapEntry('Payment', paymode!));
    if (persons != null) rows.add(MapEntry('Split with', persons!.join(', ')));
    if (splitType != null) rows.add(MapEntry('Split type', splitType!));
    if (person != null) rows.add(MapEntry('Person', person!));
    if (date != null) rows.add(MapEntry('Date', date!));
    if (dueDate != null) rows.add(MapEntry('Due date', dueDate!));
    if (note != null && note!.isNotEmpty) rows.add(MapEntry('Note', note!));
    return rows;
  }

  String _fmt(double v) => v >= 100000
      ? '${(v / 100000).toStringAsFixed(1)}L'
      : v >= 1000
      ? '${(v / 1000).toStringAsFixed(1)}K'
      : v.toStringAsFixed(0);
}

// ── Chat message model ────────────────────────────────────────────────────────

enum ChatRole { bot, user }

class ChatMessage {
  final ChatRole role;
  final String text;
  final FlowStep? widgetStep; // if bot, which input widget to show below it
  final bool animate;

  const ChatMessage({
    required this.role,
    required this.text,
    this.widgetStep,
    this.animate = false,
  });

  ChatMessage copyWith({FlowStep? widgetStep}) => ChatMessage(
    role: role,
    text: text,
    widgetStep: widgetStep ?? this.widgetStep,
    animate: animate,
  );
}

// ── Category data ─────────────────────────────────────────────────────────────

const expenseCategories = [
  '🍕 Food',
  '🚗 Travel',
  '🛒 Shopping',
  '💊 Health',
  '🎬 Entertainment',
  '🏠 Housing',
  '📚 Education',
  '💡 Utilities',
  '👕 Clothing',
  '🎁 Gifts',
  '🏋️ Fitness',
  '✈️ Vacation',
];

const incomeCategories = [
  '💼 Salary',
  '💻 Freelance',
  '📈 Investment',
  '🏠 Rent',
  '🎁 Gift',
  '💰 Bonus',
  '🔁 Refund',
  '📦 Business',
];

const contactNames = [
  'Arjun',
  'Priya',
  'Rahul',
  'Sneha',
  'Kumar',
  'Deepa',
  'Raj',
  'Anitha',
];
