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

  SplitGroup({
    required this.id,
    required this.name,
    required this.emoji,
    required this.walletId,
    required this.participants,
    List<SplitGroupTx>? transactions,
    List<SplitGroupMsg>? messages,
    DateTime? createdAt,
  }) : transactions = transactions ?? [],
       messages = messages ?? [],
       createdAt = createdAt ?? DateTime.now();

  double get totalSpend =>
      transactions.fold(0.0, (s, tx) => s + tx.totalAmount);

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
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK DATA
// ─────────────────────────────────────────────────────────────────────────────

final _pMe = SplitParticipant(
  id: 'me',
  name: 'Me (Arjun)',
  emoji: '🧑',
  isMe: true,
);
final _pPriya = SplitParticipant(
  id: 'priya',
  name: 'Priya',
  emoji: '👧',
  phone: '9876543212',
);
final _pRahul = SplitParticipant(
  id: 'rahul',
  name: 'Rahul',
  emoji: '👨',
  phone: '9876500001',
);
final _pSneha = SplitParticipant(
  id: 'sneha',
  name: 'Sneha',
  emoji: '👩',
  phone: '9876500002',
);

List<SplitGroup> mockSplitGroups = [
  SplitGroup(
    id: 'sg1',
    name: 'Goa Trip',
    emoji: '✈️',
    walletId: 'personal',
    participants: [_pMe, _pPriya, _pRahul, _pSneha],
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
    transactions: [
      SplitGroupTx(
        id: 'st1',
        groupId: 'sg1',
        addedById: 'me',
        title: 'Hotel Booking',
        totalAmount: 4800,
        splitType: SplitType.equal,
        date: DateTime.now().subtract(const Duration(days: 8)),
        shares: [
          SplitShare(
            participantId: 'me',
            amount: 1200,
            status: SettleStatus.settled,
          ),
          SplitShare(
            participantId: 'priya',
            amount: 1200,
            status: SettleStatus.settled,
          ),
          SplitShare(
            participantId: 'rahul',
            amount: 1200,
            status: SettleStatus.proofSubmitted,
            proofNote: 'Paid via GPay ref# 4821',
            proofDate: DateTime.now().subtract(const Duration(days: 2)),
          ),
          SplitShare(
            participantId: 'sneha',
            amount: 1200,
            status: SettleStatus.extensionRequested,
            extensionDate: DateTime.now().add(const Duration(days: 5)),
            extensionReason: 'Salary credit on 5th',
          ),
        ],
      ),
      SplitGroupTx(
        id: 'st2',
        groupId: 'sg1',
        addedById: 'rahul',
        title: 'Beach Shack Dinner',
        totalAmount: 2200,
        splitType: SplitType.unequal,
        date: DateTime.now().subtract(const Duration(days: 7)),
        note: 'Rahul had extra drinks',
        shares: [
          SplitShare(
            participantId: 'me',
            amount: 600,
            status: SettleStatus.settled,
          ),
          SplitShare(
            participantId: 'priya',
            amount: 600,
            status: SettleStatus.settled,
          ),
          SplitShare(
            participantId: 'rahul',
            amount: 200,
            status: SettleStatus.settled,
          ),
          SplitShare(
            participantId: 'sneha',
            amount: 800,
            status: SettleStatus.pending,
          ),
        ],
      ),
      SplitGroupTx(
        id: 'st3',
        groupId: 'sg1',
        addedById: 'priya',
        title: 'Scooter Rental',
        totalAmount: 1200,
        splitType: SplitType.percentage,
        date: DateTime.now().subtract(const Duration(days: 6)),
        shares: [
          SplitShare(
            participantId: 'me',
            amount: 480,
            percentage: 40,
            status: SettleStatus.settled,
          ),
          SplitShare(
            participantId: 'priya',
            amount: 360,
            percentage: 30,
            status: SettleStatus.settled,
          ),
          SplitShare(
            participantId: 'rahul',
            amount: 240,
            percentage: 20,
            status: SettleStatus.settled,
          ),
          SplitShare(
            participantId: 'sneha',
            amount: 120,
            percentage: 10,
            status: SettleStatus.pending,
          ),
        ],
      ),
    ],
    messages: [
      SplitGroupMsg(
        id: 'm1',
        groupId: 'sg1',
        senderId: 'me',
        senderName: 'Arjun',
        senderEmoji: '🧑',
        text: 'Added hotel booking ₹4,800 — split equally',
        time: DateTime.now().subtract(const Duration(days: 8)),
        type: MsgType.txAdded,
      ),
      SplitGroupMsg(
        id: 'm2',
        groupId: 'sg1',
        senderId: 'priya',
        senderName: 'Priya',
        senderEmoji: '👧',
        text: 'Done! Settled my share 🙌',
        time: DateTime.now().subtract(const Duration(days: 7, hours: 2)),
      ),
      SplitGroupMsg(
        id: 'm3',
        groupId: 'sg1',
        senderId: 'rahul',
        senderName: 'Rahul',
        senderEmoji: '👨',
        text: 'Added dinner bill ₹2,200 — unequal split',
        time: DateTime.now().subtract(const Duration(days: 7)),
        type: MsgType.txAdded,
      ),
      SplitGroupMsg(
        id: 'm4',
        groupId: 'sg1',
        senderId: 'sneha',
        senderName: 'Sneha',
        senderEmoji: '👩',
        text: 'Can I settle hotel share by 5th? Salary credit then 🙏',
        time: DateTime.now().subtract(const Duration(hours: 5)),
        type: MsgType.extensionReq,
      ),
      SplitGroupMsg(
        id: 'm5',
        groupId: 'sg1',
        senderId: 'me',
        senderName: 'Arjun',
        senderEmoji: '🧑',
        text: 'No problem Sneha, extension granted till 5th!',
        time: DateTime.now().subtract(const Duration(hours: 4)),
        type: MsgType.extensionGranted,
      ),
      SplitGroupMsg(
        id: 'm6',
        groupId: 'sg1',
        senderId: 'rahul',
        senderName: 'Rahul',
        senderEmoji: '👨',
        text: 'Sent hotel share via GPay 🤙',
        time: DateTime.now().subtract(const Duration(hours: 1)),
        type: MsgType.settled,
      ),
    ],
  ),
  SplitGroup(
    id: 'sg2',
    name: 'Office Lunch',
    emoji: '🍱',
    walletId: 'personal',
    participants: [_pMe, _pRahul, _pSneha],
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    transactions: [
      SplitGroupTx(
        id: 'st4',
        groupId: 'sg2',
        addedById: 'me',
        title: 'Murugan Idli Shop',
        totalAmount: 750,
        splitType: SplitType.equal,
        date: DateTime.now().subtract(const Duration(days: 2)),
        shares: [
          SplitShare(
            participantId: 'me',
            amount: 250,
            status: SettleStatus.settled,
          ),
          SplitShare(
            participantId: 'rahul',
            amount: 250,
            status: SettleStatus.settled,
          ),
          SplitShare(
            participantId: 'sneha',
            amount: 250,
            status: SettleStatus.pending,
          ),
        ],
      ),
    ],
    messages: [
      SplitGroupMsg(
        id: 'm7',
        groupId: 'sg2',
        senderId: 'me',
        senderName: 'Arjun',
        senderEmoji: '🧑',
        text: 'Paid for lunch ₹750 — split equally 3 ways',
        time: DateTime.now().subtract(const Duration(days: 2)),
        type: MsgType.txAdded,
      ),
      SplitGroupMsg(
        id: 'm8',
        groupId: 'sg2',
        senderId: 'rahul',
        senderName: 'Rahul',
        senderEmoji: '👨',
        text: 'Transferred ₹250 👍',
        time: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      ),
    ],
  ),
];
