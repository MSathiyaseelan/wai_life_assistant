import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
//import '../../core/theme/app_theme.dart';

// ── Enums ────────────────────────────────────────────────────────────────────

enum TxType { income, expense, split, lend, borrow, request }

enum PayMode { cash, online }

// TODO(v2): billWatch is planned for V2 — keep the enum value but exclude from kV1WalletTabs
enum WalletTab { wallet, splits, billWatch }

/// Tabs shown in V1. Bill Watch is hidden until V2.
const kV1WalletTabs = [WalletTab.wallet, WalletTab.splits];

extension TxTypeExt on TxType {
  String get label {
    switch (this) {
      case TxType.income:
        return 'Income';
      case TxType.expense:
        return 'Expense';
      case TxType.split:
        return 'Split';
      case TxType.lend:
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
      case TxType.lend:
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
      case TxType.lend:
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
      case TxType.lend:
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
      case WalletTab.wallet:
        return 'Wallet'; // overridden dynamically in tab bar
      case WalletTab.splits:
        return 'Splits';
      case WalletTab.billWatch:
        return 'Bill Watch';
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

  factory TxModel.fromRow(Map<String, dynamic> row) {
    return TxModel(
      id: row['id'] as String,
      type: TxType.values.firstWhere(
        (t) => t.name == row['type'],
        orElse: () => TxType.expense,
      ),
      payMode: row['pay_mode'] != null
          ? PayMode.values.firstWhere(
              (p) => p.name == row['pay_mode'],
              orElse: () => PayMode.cash,
            )
          : null,
      amount: (row['amount'] as num).toDouble(),
      category: row['category'] as String? ?? '',
      date: DateTime.tryParse(row['date'] as String? ?? '') ?? DateTime.now(),
      walletId: row['wallet_id'] as String,
      note: row['note'] as String?,
      person: row['person'] as String?,
      persons: row['persons'] != null
          ? List<String>.from(row['persons'] as List)
          : null,
      status: row['status'] as String?,
      dueDate: row['due_date'] as String?,
    );
  }
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

// ─────────────────────────────────────────────────────────────────────────────
// FAMILY / GROUP MEMBERS & ROLES
// ─────────────────────────────────────────────────────────────────────────────

enum MemberRole {
  admin('👑', 'Admin'),
  member('👤', 'Member'),
  viewer('👁️', 'Viewer');

  final String emoji, label;
  const MemberRole(this.emoji, this.label);
}

class FamilyMember {
  String id;
  String name;
  String emoji;
  MemberRole role;
  String? phone;
  String? relation; // e.g. "Wife", "Son", "Colleague"
  String? photoPath; // local file path or remote URL

  FamilyMember({
    required this.id,
    required this.name,
    required this.emoji,
    required this.role,
    this.phone,
    this.relation,
    this.photoPath,
  });

  FamilyMember copyWith({
    String? name,
    String? emoji,
    MemberRole? role,
    String? phone,
    String? relation,
    String? photoPath,
  }) => FamilyMember(
    id: id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    role: role ?? this.role,
    phone: phone ?? this.phone,
    relation: relation ?? this.relation,
    photoPath: photoPath ?? this.photoPath,
  );
}

class FamilyModel {
  String id;         // family UUID (used for RPCs)
  String name;
  String emoji;
  int colorIndex;
  List<FamilyMember> members;
  String? photoPath; // local file path or remote URL
  String? walletId;  // the linked wallet UUID (for switcher matching)

  FamilyModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorIndex,
    List<FamilyMember>? members,
    this.photoPath,
    this.walletId,
  }) : members = members ?? [];
}

// ── Fallback placeholder — no financial data ──────────────────────────────────

/// Minimal placeholder used only as a UI fallback while real data loads.
/// Financial fields are all zero — never shown to the user as real values.
WalletModel personalWallet = WalletModel(
  id: 'personal',
  name: 'Personal',
  emoji: '👤',
  isPersonal: true,
  cashIn: 0,
  cashOut: 0,
  onlineIn: 0,
  onlineOut: 0,
  gradient: AppColors.personalGrad,
);

// Legacy name kept to avoid breaking other call sites — always empty.
final List<FamilyModel> mockFamilies = [];

// Legacy name kept to avoid breaking other call sites — always empty.
final List<TxModel> mockTransactions = [];

// Legacy name kept to avoid breaking other call sites — always empty.
List<WalletModel> familyWallets = [];
