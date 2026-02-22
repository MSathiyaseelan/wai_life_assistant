import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';

// ── Enums ────────────────────────────────────────────────────────────────────

enum TxType { income, expense, split, lent, borrow, request }

enum PayMode { cash, online }

enum WalletTab { all, splits, borrow, lent, requests }

extension TxTypeExt on TxType {
  String get label {
    switch (this) {
      case TxType.income:
        return 'Income';
      case TxType.expense:
        return 'Expense';
      case TxType.split:
        return 'Split';
      case TxType.lent:
        return 'Lent';
      case TxType.borrow:
        return 'Borrowed';
      case TxType.request:
        return 'Request';
    }
  }

  Color get color {
    switch (this) {
      case TxType.income:
        return AppColors.income;
      case TxType.expense:
        return AppColors.expense;
      case TxType.split:
        return AppColors.split;
      case TxType.lent:
        return AppColors.lend;
      case TxType.borrow:
        return AppColors.borrow;
      case TxType.request:
        return AppColors.request;
    }
  }

  Color get bgColor {
    switch (this) {
      case TxType.income:
        return AppColors.incomeBg;
      case TxType.expense:
        return AppColors.expenseBg;
      case TxType.split:
        return AppColors.splitBg;
      case TxType.lent:
        return AppColors.lendBg;
      case TxType.borrow:
        return AppColors.borrowBg;
      case TxType.request:
        return AppColors.requestBg;
    }
  }

  String get emoji {
    switch (this) {
      case TxType.income:
        return '💰';
      case TxType.expense:
        return '💸';
      case TxType.split:
        return '⚖️';
      case TxType.lent:
        return '📤';
      case TxType.borrow:
        return '📥';
      case TxType.request:
        return '🔔';
    }
  }

  bool get isPositive => this == TxType.income || this == TxType.borrow;
  bool get isPending => this == TxType.request;
}

extension WalletTabExt on WalletTab {
  String get label {
    switch (this) {
      case WalletTab.all:
        return 'All';
      case WalletTab.splits:
        return 'Splits';
      case WalletTab.borrow:
        return 'Borrow';
      case WalletTab.lent:
        return 'Lend';
      case WalletTab.requests:
        return 'Requests';
    }
  }
}

// ── Models ───────────────────────────────────────────────────────────────────

class TxModel {
  final String id;
  final TxType type;
  final PayMode? payMode; // null for non-cash/online types
  final double amount;
  final String category;
  final String? note;
  final DateTime date;
  final String? person;
  final List<String>? persons;
  final String? status;
  final String? dueDate;
  final String walletId; // 'personal' or family id

  const TxModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    required this.walletId,
    this.payMode,
    this.note,
    this.person,
    this.persons,
    this.status,
    this.dueDate,
  });
}

class WalletModel {
  final String id;
  final String name;
  final String emoji;
  final bool isPersonal;
  final double cashIn;
  final double cashOut;
  final double onlineIn;
  final double onlineOut;
  final List<Color> gradient;

  const WalletModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.isPersonal,
    required this.cashIn,
    required this.cashOut,
    required this.onlineIn,
    required this.onlineOut,
    required this.gradient,
  });

  double get totalIn => cashIn + onlineIn;
  double get totalOut => cashOut + onlineOut;
  double get balance => totalIn - totalOut;
}

class FamilyModel {
  final String id;
  final String name;
  final String emoji;
  final int colorIndex;

  const FamilyModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorIndex,
  });
}

// ── Mock Data ─────────────────────────────────────────────────────────────────

final mockFamilies = [
  const FamilyModel(
    id: 'f1',
    name: 'Singh Family',
    emoji: '👨‍👩‍👧',
    colorIndex: 0,
  ),
  const FamilyModel(id: 'f2', name: 'Office Group', emoji: '👥', colorIndex: 1),
];

WalletModel personalWallet = WalletModel(
  id: 'personal',
  name: 'Personal',
  emoji: '👤',
  isPersonal: true,
  cashIn: 12000,
  cashOut: 4500,
  onlineIn: 33000,
  onlineOut: 8700,
  gradient: AppColors.personalGrad,
);

List<WalletModel> familyWallets = [
  WalletModel(
    id: 'f1',
    name: 'Singh Family',
    emoji: '👨‍👩‍👧',
    isPersonal: false,
    cashIn: 5000,
    cashOut: 2000,
    onlineIn: 15000,
    onlineOut: 6000,
    gradient: AppColors.familyGradients[0],
  ),
  WalletModel(
    id: 'f2',
    name: 'Office Group',
    emoji: '👥',
    isPersonal: false,
    cashIn: 0,
    cashOut: 0,
    onlineIn: 8000,
    onlineOut: 3200,
    gradient: AppColors.familyGradients[1],
  ),
];

final mockTransactions = [
  TxModel(
    id: '1',
    type: TxType.income,
    payMode: PayMode.online,
    amount: 45000,
    category: 'Salary',
    walletId: 'personal',
    note: 'Monthly salary',
    date: DateTime.now(),
  ),
  TxModel(
    id: '2',
    type: TxType.expense,
    payMode: PayMode.cash,
    amount: 500,
    category: 'Food',
    walletId: 'personal',
    note: 'Lunch at Murugan',
    date: DateTime.now(),
  ),
  TxModel(
    id: '3',
    type: TxType.expense,
    payMode: PayMode.online,
    amount: 1299,
    category: 'Shopping',
    walletId: 'personal',
    note: 'Amazon order',
    date: DateTime.now(),
  ),
  TxModel(
    id: '4',
    type: TxType.split,
    payMode: null,
    amount: 400,
    category: 'Dinner Split',
    walletId: 'personal',
    persons: ['Arjun', 'Priya'],
    status: '2/3 paid',
    date: DateTime.now(),
  ),
  TxModel(
    id: '5',
    type: TxType.income,
    payMode: PayMode.cash,
    amount: 2000,
    category: 'Freelance',
    walletId: 'personal',
    note: 'Design work',
    date: DateTime.now().subtract(const Duration(days: 1)),
  ),
  TxModel(
    id: '6',
    type: TxType.expense,
    payMode: PayMode.online,
    amount: 849,
    category: 'Grocery',
    walletId: 'f1',
    note: 'BigBasket order',
    date: DateTime.now().subtract(const Duration(days: 1)),
  ),
  TxModel(
    id: '7',
    type: TxType.lent,
    payMode: null,
    amount: 2000,
    category: 'Lent to Rahul',
    walletId: 'personal',
    person: 'Rahul',
    dueDate: 'Mar 1',
    date: DateTime.now().subtract(const Duration(days: 1)),
  ),
  TxModel(
    id: '8',
    type: TxType.borrow,
    payMode: null,
    amount: 500,
    category: 'Borrowed',
    walletId: 'personal',
    person: 'Sneha',
    date: DateTime.now().subtract(const Duration(days: 1)),
  ),
  TxModel(
    id: '9',
    type: TxType.request,
    payMode: null,
    amount: 750,
    category: 'Request',
    walletId: 'personal',
    person: 'Priya',
    status: 'pending',
    date: DateTime.now().subtract(const Duration(days: 2)),
  ),
  TxModel(
    id: '10',
    type: TxType.expense,
    payMode: PayMode.cash,
    amount: 320,
    category: 'Travel',
    walletId: 'personal',
    note: 'Auto fare',
    date: DateTime.now().subtract(const Duration(days: 2)),
  ),
  TxModel(
    id: '11',
    type: TxType.expense,
    payMode: PayMode.online,
    amount: 599,
    category: 'Entertainment',
    walletId: 'f1',
    note: 'Netflix',
    date: DateTime.now().subtract(const Duration(days: 3)),
  ),
  TxModel(
    id: '12',
    type: TxType.income,
    payMode: PayMode.online,
    amount: 3500,
    category: 'Rent',
    walletId: 'f1',
    note: 'From tenant',
    date: DateTime.now().subtract(const Duration(days: 3)),
  ),
];
