import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SPLIT GROUP MODELS
// ─────────────────────────────────────────────────────────────────────────────

// How the total is divided among participants
enum SplitType { equal, unequal, percentage, custom }

extension SplitTypeExt on SplitType {
  String get label {
    switch (this) {
      case SplitType.equal:
        return 'Equal';
      case SplitType.unequal:
        return 'Unequal';
      case SplitType.percentage:
        return 'Percentage';
      case SplitType.custom:
        return 'Custom';
    }
  }

  String get emoji {
    switch (this) {
      case SplitType.equal:
        return '⚖️';
      case SplitType.unequal:
        return '📊';
      case SplitType.percentage:
        return '％';
      case SplitType.custom:
        return '✏️';
    }
  }

  Color get color {
    switch (this) {
      case SplitType.equal:
        return const Color(0xFF4A9EFF);
      case SplitType.unequal:
        return const Color(0xFFFFAA2C);
      case SplitType.percentage:
        return const Color(0xFF00C897);
      case SplitType.custom:
        return const Color(0xFF9C27B0);
    }
  }
}

// Settlement lifecycle for each person's share
enum SettleStatus {
  pending, // not yet acted
  proofSubmitted, // payer uploaded proof, waiting for receiver to confirm
  settled, // receiver confirmed — fully done
  extensionRequested, // payer asked for more time
  extensionGranted, // receiver approved the extension
}

extension SettleStatusExt on SettleStatus {
  String get label {
    switch (this) {
      case SettleStatus.pending:
        return 'Pending';
      case SettleStatus.proofSubmitted:
        return 'Proof Sent';
      case SettleStatus.settled:
        return 'Settled ✓';
      case SettleStatus.extensionRequested:
        return 'Extension Requested';
      case SettleStatus.extensionGranted:
        return 'Extension Granted';
    }
  }

  Color get color {
    switch (this) {
      case SettleStatus.pending:
        return const Color(0xFFFF9800);
      case SettleStatus.proofSubmitted:
        return const Color(0xFF2196F3);
      case SettleStatus.settled:
        return const Color(0xFF4CAF50);
      case SettleStatus.extensionRequested:
        return const Color(0xFF9C27B0);
      case SettleStatus.extensionGranted:
        return const Color(0xFF00BCD4);
    }
  }

  IconData get icon {
    switch (this) {
      case SettleStatus.pending:
        return Icons.schedule_rounded;
      case SettleStatus.proofSubmitted:
        return Icons.upload_rounded;
      case SettleStatus.settled:
        return Icons.check_circle_rounded;
      case SettleStatus.extensionRequested:
        return Icons.hourglass_top_rounded;
      case SettleStatus.extensionGranted:
        return Icons.event_available_rounded;
    }
  }
}

// ── Participant ───────────────────────────────────────────────────────────────
class SplitParticipant {
  final String id;
  String name;
  String emoji;
  String? phone;
  bool isMe;

  SplitParticipant({
    required this.id,
    required this.name,
    required this.emoji,
    this.phone,
    this.isMe = false,
  });
}

// ── Per-person share in a transaction ────────────────────────────────────────
class SplitShare {
  final String participantId;
  double amount;
  double? percentage;
  SettleStatus status;
  String? proofNote;
  String? proofImagePath;
  DateTime? proofDate;
  DateTime? extensionDate;
  String? extensionReason;
  int? reminderCount;
  DateTime? lastReminderAt;
  String? lastReminderBy;

  SplitShare({
    required this.participantId,
    required this.amount,
    this.percentage,
    this.status = SettleStatus.pending,
    this.proofNote,
    this.proofImagePath,
    this.proofDate,
    this.extensionDate,
    this.extensionReason,
    this.reminderCount,
    this.lastReminderAt,
    this.lastReminderBy,
  });
}

// ── A transaction added inside a split group ──────────────────────────────────
class SplitGroupTx {
  final String id;
  final String groupId;
  final String addedById; // who paid / added this
  String title;
  double totalAmount;
  SplitType splitType;
  List<SplitShare> shares;
  DateTime date;
  String? note;

  SplitGroupTx({
    required this.id,
    required this.groupId,
    required this.addedById,
    required this.title,
    required this.totalAmount,
    required this.splitType,
    required this.shares,
    required this.date,
    this.note,
  });

  SplitShare shareFor(String pid) => shares.firstWhere(
    (s) => s.participantId == pid,
    orElse: () => SplitShare(participantId: pid, amount: 0),
  );

  bool get isFullySettled =>
      shares.every((s) => s.status == SettleStatus.settled);

  int get settledCount =>
      shares.where((s) => s.status == SettleStatus.settled).length;
}

// ── Chat message types ────────────────────────────────────────────────────────
enum MsgType {
  text,
  txAdded,
  settled,
  extensionReq,
  extensionGranted,
  reminder,
}

class SplitGroupMsg {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String senderEmoji;
  final String text;
  final DateTime time;
  final MsgType type;

  const SplitGroupMsg({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.senderEmoji,
    required this.text,
    required this.time,
    this.type = MsgType.text,
  });

  factory SplitGroupMsg.fromRow(Map<String, dynamic> row) {
    return SplitGroupMsg(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      senderId: row['sender_id'] as String,
      senderName: row['sender_name'] as String? ?? '',
      senderEmoji: row['sender_emoji'] as String? ?? '👤',
      text: row['text'] as String? ?? '',
      time: DateTime.parse(row['created_at'] as String),
      type: _msgTypeFromString(row['type'] as String? ?? 'text'),
    );
  }

  static MsgType _msgTypeFromString(String s) {
    switch (s) {
      case 'txAdded':         return MsgType.txAdded;
      case 'settled':         return MsgType.settled;
      case 'extensionReq':    return MsgType.extensionReq;
      case 'extensionGranted':return MsgType.extensionGranted;
      case 'reminder':        return MsgType.reminder;
      default:                return MsgType.text;
    }
  }
}

// ── Split Group ───────────────────────────────────────────────────────────────
class SplitGroup {
  final String id;
  String name;
  String emoji;
  String walletId;
  List<SplitParticipant> participants;
  List<SplitGroupTx> transactions;
  List<SplitGroupMsg> messages;
  final DateTime createdAt;
  bool pinnedToDashboard;

  SplitGroup({
    required this.id,
    required this.name,
    required this.emoji,
    required this.walletId,
    required this.participants,
    List<SplitGroupTx>? transactions,
    List<SplitGroupMsg>? messages,
    DateTime? createdAt,
    this.pinnedToDashboard = false,
  }) : transactions = transactions ?? [],
       messages = messages ?? [],
       createdAt = createdAt ?? DateTime.now();

  bool isSettled = false; // set to true once all transactions fully settled

  double get totalSpend =>
      transactions.fold(0.0, (s, tx) => s + tx.totalAmount);

  bool get isFullySettled =>
      isSettled ||
      (transactions.isNotEmpty &&
          transactions.every((tx) => tx.isFullySettled));

  int get pendingCount => transactions
      .expand((tx) => tx.shares)
      .where(
        (s) =>
            s.status == SettleStatus.pending ||
            s.status == SettleStatus.extensionRequested,
      )
      .length;

  // Net balance per participant:
  //   positive = others owe them (they paid more)
  //   negative = they owe others
  Map<String, double> get netBalances {
    final map = <String, double>{for (final p in participants) p.id: 0.0};
    for (final tx in transactions) {
      // Payer gets credited the full amount
      map[tx.addedById] = (map[tx.addedById] ?? 0) + tx.totalAmount;
      // Each person is debited their share
      for (final s in tx.shares) {
        map[s.participantId] = (map[s.participantId] ?? 0) - s.amount;
      }
    }
    return map;
  }

  SplitParticipant? participantById(String id) {
    try {
      return participants.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // Minimum transactions to settle all debts.
  // Returns list of (fromId, toId, amount) — "fromId owes toId this amount".
  List<({String fromId, String toId, double amount})> get settlementPlan {
    final balances = Map<String, double>.from(netBalances);

    final debtorIds = balances.keys
        .where((k) => (balances[k] ?? 0) < -0.01)
        .toList()
      ..sort((a, b) => (balances[a] ?? 0).compareTo(balances[b] ?? 0));
    final creditorIds = balances.keys
        .where((k) => (balances[k] ?? 0) > 0.01)
        .toList()
      ..sort((a, b) => (balances[b] ?? 0).compareTo(balances[a] ?? 0));

    final debtAmt = {for (final id in debtorIds) id: -(balances[id] ?? 0)};
    final creditAmt = {for (final id in creditorIds) id: balances[id] ?? 0};

    final result = <({String fromId, String toId, double amount})>[];
    int i = 0, j = 0;
    while (i < debtorIds.length && j < creditorIds.length) {
      final from = debtorIds[i];
      final to = creditorIds[j];
      final pay = debtAmt[from]! < creditAmt[to]!
          ? debtAmt[from]!
          : creditAmt[to]!;
      if (pay > 0.01) result.add((fromId: from, toId: to, amount: pay));
      debtAmt[from] = debtAmt[from]! - pay;
      creditAmt[to] = creditAmt[to]! - pay;
      if ((debtAmt[from] ?? 0) < 0.01) i++;
      if ((creditAmt[to] ?? 0) < 0.01) j++;
    }
    return result;
  }
}

// Notifier holding the list of split groups pinned to the Dashboard.
// The wallet screen updates this whenever groups change (load / edit / delete).
// The dashboard also populates this directly from Supabase on init.
final pinnedSplitGroupsNotifier = ValueNotifier<List<SplitGroup>>([]);

// ─────────────────────────────────────────────────────────────────────────────
// DB ROW → MODEL CONVERTERS  (shared between wallet_screen and dashboard)
// ─────────────────────────────────────────────────────────────────────────────

SplitType splitTypeFromString(String s) {
  switch (s) {
    case 'unequal':    return SplitType.unequal;
    case 'percentage': return SplitType.percentage;
    case 'custom':     return SplitType.custom;
    default:           return SplitType.equal;
  }
}

SettleStatus settleStatusFromString(String s) {
  switch (s) {
    case 'proofSubmitted':     return SettleStatus.proofSubmitted;
    case 'settled':            return SettleStatus.settled;
    case 'extensionRequested': return SettleStatus.extensionRequested;
    case 'extensionGranted':   return SettleStatus.extensionGranted;
    default:                   return SettleStatus.pending;
  }
}

SplitGroup splitGroupFromRow(Map<String, dynamic> row) {
  final participants = (row['split_participants'] as List? ?? [])
      .map((p) => SplitParticipant(
            id: p['id'] as String,
            name: p['name'] as String,
            emoji: p['emoji'] as String? ?? '👤',
            phone: p['phone'] as String?,
            isMe: p['is_me'] as bool? ?? false,
          ))
      .toList();

  final transactions = (row['split_group_transactions'] as List? ?? [])
      .map((t) {
        final shares = (t['split_shares'] as List? ?? [])
            .map((s) => SplitShare(
                  participantId: s['participant_id'] as String,
                  amount: (s['amount'] as num).toDouble(),
                  percentage: s['percentage'] != null
                      ? (s['percentage'] as num).toDouble()
                      : null,
                  status: settleStatusFromString(s['status'] as String? ?? 'pending'),
                ))
            .toList();
        return SplitGroupTx(
          id: t['id'] as String,
          groupId: t['group_id'] as String,
          addedById: t['added_by_id'] as String,
          title: t['title'] as String,
          totalAmount: (t['total_amount'] as num).toDouble(),
          splitType: splitTypeFromString(t['split_type'] as String? ?? 'equal'),
          shares: shares,
          date: DateTime.parse(t['date'] as String),
          note: t['note'] as String?,
        );
      })
      .toList();

  final group = SplitGroup(
    id: row['id'] as String,
    name: row['name'] as String,
    emoji: row['emoji'] as String? ?? '🤝',
    walletId: row['wallet_id'] as String,
    participants: participants,
    transactions: transactions,
    createdAt: row['created_at'] != null
        ? DateTime.parse(row['created_at'] as String)
        : null,
    pinnedToDashboard: row['pinned_to_dashboard'] as bool? ?? false,
  );
  return group;
}

// ─────────────────────────────────────────────────────────────────────────────
// LEGACY STUB — kept so existing import sites compile; data removed
// ─────────────────────────────────────────────────────────────────────────────

// Legacy name kept so existing import sites compile — always empty.
List<SplitGroup> mockSplitGroups = [];
