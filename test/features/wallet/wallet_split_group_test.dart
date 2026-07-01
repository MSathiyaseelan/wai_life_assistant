import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/data/models/wallet/split_group_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

SplitParticipant participant(String id, {String name = 'P', String emoji = '😀', bool isMe = false}) =>
    SplitParticipant(id: id, name: name, emoji: emoji, isMe: isMe);

SplitShare share(String pid, double amount, {SettleStatus status = SettleStatus.pending}) =>
    SplitShare(participantId: pid, amount: amount, status: status);

SplitGroupTx tx({
  required String id,
  required String groupId,
  required String addedById,
  required double totalAmount,
  required List<SplitShare> shares,
  SplitType splitType = SplitType.equal,
}) => SplitGroupTx(
  id: id, groupId: groupId, addedById: addedById,
  title: 'Test Tx', totalAmount: totalAmount,
  splitType: splitType, shares: shares,
  date: DateTime(2025, 8, 1),
);

// Named differently from flutter_test's group() to avoid shadowing.
SplitGroup makeGroup({
  List<SplitParticipant> participants = const [],
  List<SplitGroupTx> transactions = const [],
  bool isSettled = false,
  bool pinned = false,
}) {
  final g = SplitGroup(
    id: 'grp1', name: 'Test Group', emoji: '🤝', walletId: 'personal',
    participants: participants, transactions: transactions,
    pinnedToDashboard: pinned,
  );
  g.isSettled = isSettled;
  return g;
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. SplitTypeExt
  // ═══════════════════════════════════════════════════════════════════════════
  group('SplitTypeExt', () {
    test('all values have non-empty label', () {
      for (final t in SplitType.values) {
        expect(t.label, isNotEmpty, reason: t.name);
      }
    });

    test('all values have non-empty emoji', () {
      for (final t in SplitType.values) {
        expect(t.emoji, isNotEmpty, reason: t.name);
      }
    });

    test('all values have a color', () {
      for (final t in SplitType.values) {
        expect(t.color, isA<Color>(), reason: t.name);
      }
    });

    test('spot checks', () {
      expect(SplitType.equal.label, 'Equal');
      expect(SplitType.equal.emoji, '⚖️');
      expect(SplitType.unequal.label, 'Unequal');
      expect(SplitType.percentage.label, 'Percentage');
      expect(SplitType.custom.label, 'Custom');
      expect(SplitType.custom.emoji, '✏️');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. SettleStatusExt
  // ═══════════════════════════════════════════════════════════════════════════
  group('SettleStatusExt', () {
    test('all values have non-empty label', () {
      for (final s in SettleStatus.values) {
        expect(s.label, isNotEmpty, reason: s.name);
      }
    });

    test('all values have a color', () {
      for (final s in SettleStatus.values) {
        expect(s.color, isA<Color>(), reason: s.name);
      }
    });

    test('all values have an icon', () {
      for (final s in SettleStatus.values) {
        expect(s.icon, isA<IconData>(), reason: s.name);
      }
    });

    test('spot checks — label', () {
      expect(SettleStatus.pending.label, 'Pending');
      expect(SettleStatus.settled.label, 'Settled ✓');
      expect(SettleStatus.proofSubmitted.label, 'Proof Sent');
      expect(SettleStatus.extensionRequested.label, 'Extension Requested');
      expect(SettleStatus.extensionGranted.label, 'Extension Granted');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. splitTypeFromString / settleStatusFromString
  // ═══════════════════════════════════════════════════════════════════════════
  group('splitTypeFromString', () {
    test('equal (default for unknown)', () {
      expect(splitTypeFromString('equal'), SplitType.equal);
      expect(splitTypeFromString(''), SplitType.equal);
      expect(splitTypeFromString('random'), SplitType.equal);
    });

    test('unequal', () => expect(splitTypeFromString('unequal'), SplitType.unequal));
    test('percentage', () => expect(splitTypeFromString('percentage'), SplitType.percentage));
    test('custom', () => expect(splitTypeFromString('custom'), SplitType.custom));
  });

  group('settleStatusFromString', () {
    test('pending (default for unknown)', () {
      expect(settleStatusFromString('pending'), SettleStatus.pending);
      expect(settleStatusFromString(''), SettleStatus.pending);
      expect(settleStatusFromString('unknown'), SettleStatus.pending);
    });

    test('proofSubmitted', () =>
        expect(settleStatusFromString('proofSubmitted'), SettleStatus.proofSubmitted));
    test('settled', () =>
        expect(settleStatusFromString('settled'), SettleStatus.settled));
    test('extensionRequested', () =>
        expect(settleStatusFromString('extensionRequested'), SettleStatus.extensionRequested));
    test('extensionGranted', () =>
        expect(settleStatusFromString('extensionGranted'), SettleStatus.extensionGranted));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. SplitGroupMsg.fromRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('SplitGroupMsg.fromRow', () {
    Map<String, dynamic> baseRow() => {
      'id': 'msg1',
      'group_id': 'grp1',
      'sender_id': 'user_a',
      'sender_name': 'Priya',
      'sender_emoji': '👩',
      'text': 'Hello group!',
      'created_at': '2025-08-10T10:30:00.000Z',
      'type': 'text',
    };

    test('parses all fields', () {
      final m = SplitGroupMsg.fromRow(baseRow());
      expect(m.id, 'msg1');
      expect(m.groupId, 'grp1');
      expect(m.senderId, 'user_a');
      expect(m.senderName, 'Priya');
      expect(m.senderEmoji, '👩');
      expect(m.text, 'Hello group!');
      expect(m.time, DateTime.utc(2025, 8, 10, 10, 30));
      expect(m.type, MsgType.text);
    });

    test('senderId defaults to empty string when absent', () {
      final row = baseRow()..remove('sender_id');
      expect(SplitGroupMsg.fromRow(row).senderId, '');
    });

    test('senderName defaults to empty string when absent', () {
      final row = baseRow()..remove('sender_name');
      expect(SplitGroupMsg.fromRow(row).senderName, '');
    });

    test('senderEmoji defaults to 👤 when absent', () {
      final row = baseRow()..remove('sender_emoji');
      expect(SplitGroupMsg.fromRow(row).senderEmoji, '👤');
    });

    test('text defaults to empty string when absent', () {
      final row = baseRow()..remove('text');
      expect(SplitGroupMsg.fromRow(row).text, '');
    });

    test('type absent → MsgType.text', () {
      final row = baseRow()..remove('type');
      expect(SplitGroupMsg.fromRow(row).type, MsgType.text);
    });

    test('unknown type string → MsgType.text', () {
      final row = baseRow()..['type'] = 'reaction';
      expect(SplitGroupMsg.fromRow(row).type, MsgType.text);
    });

    test('all MsgType strings parse correctly', () {
      final cases = {
        'text': MsgType.text,
        'txAdded': MsgType.txAdded,
        'settled': MsgType.settled,
        'extensionReq': MsgType.extensionReq,
        'extensionGranted': MsgType.extensionGranted,
        'reminder': MsgType.reminder,
      };
      for (final e in cases.entries) {
        final row = baseRow()..['type'] = e.key;
        expect(SplitGroupMsg.fromRow(row).type, e.value, reason: e.key);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. SplitGroupTx — shareFor, isFullySettled, settledCount
  // ═══════════════════════════════════════════════════════════════════════════
  group('SplitGroupTx.shareFor', () {
    final tx1 = SplitGroupTx(
      id: 't1', groupId: 'g', addedById: 'A', title: 'Dinner',
      totalAmount: 600, splitType: SplitType.equal,
      shares: [
        share('A', 200, status: SettleStatus.settled),
        share('B', 200),
        share('C', 200),
      ],
      date: DateTime(2025, 8, 1),
    );

    test('returns matching share for known participant', () {
      final s = tx1.shareFor('B');
      expect(s.participantId, 'B');
      expect(s.amount, 200);
    });

    test('returns correct status for known participant', () {
      expect(tx1.shareFor('A').status, SettleStatus.settled);
      expect(tx1.shareFor('B').status, SettleStatus.pending);
    });

    test('returns zero-amount fallback share for unknown participant', () {
      final s = tx1.shareFor('Z');
      expect(s.participantId, 'Z');
      expect(s.amount, 0);
    });
  });

  group('SplitGroupTx.isFullySettled', () {
    test('true when all shares are settled', () {
      final t = tx(
        id: 't1', groupId: 'g', addedById: 'A', totalAmount: 300,
        shares: [
          share('A', 100, status: SettleStatus.settled),
          share('B', 100, status: SettleStatus.settled),
          share('C', 100, status: SettleStatus.settled),
        ],
      );
      expect(t.isFullySettled, true);
    });

    test('false when any share is pending', () {
      final t = tx(
        id: 't1', groupId: 'g', addedById: 'A', totalAmount: 300,
        shares: [
          share('A', 100, status: SettleStatus.settled),
          share('B', 100, status: SettleStatus.pending),
        ],
      );
      expect(t.isFullySettled, false);
    });

    test('false when any share is proofSubmitted (not yet confirmed)', () {
      final t = tx(
        id: 't1', groupId: 'g', addedById: 'A', totalAmount: 200,
        shares: [
          share('A', 100, status: SettleStatus.settled),
          share('B', 100, status: SettleStatus.proofSubmitted),
        ],
      );
      expect(t.isFullySettled, false);
    });

    test('false when any share is extensionRequested', () {
      final t = tx(
        id: 't1', groupId: 'g', addedById: 'A', totalAmount: 200,
        shares: [
          share('A', 100, status: SettleStatus.settled),
          share('B', 100, status: SettleStatus.extensionRequested),
        ],
      );
      expect(t.isFullySettled, false);
    });

    test('true when shares is empty (vacuous truth)', () {
      final t = tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 0, shares: []);
      expect(t.isFullySettled, true);
    });
  });

  group('SplitGroupTx.settledCount', () {
    test('counts only settled shares', () {
      final t = tx(
        id: 't1', groupId: 'g', addedById: 'A', totalAmount: 600,
        shares: [
          share('A', 200, status: SettleStatus.settled),
          share('B', 200, status: SettleStatus.pending),
          share('C', 200, status: SettleStatus.settled),
        ],
      );
      expect(t.settledCount, 2);
    });

    test('0 when no shares are settled', () {
      final t = tx(
        id: 't1', groupId: 'g', addedById: 'A', totalAmount: 200,
        shares: [share('A', 100), share('B', 100)],
      );
      expect(t.settledCount, 0);
    });

    test('0 when shares is empty', () {
      final t = tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 0, shares: []);
      expect(t.settledCount, 0);
    });

    test('does not count proofSubmitted, extensionRequested, extensionGranted as settled', () {
      final t = tx(
        id: 't1', groupId: 'g', addedById: 'A', totalAmount: 400,
        shares: [
          share('A', 100, status: SettleStatus.proofSubmitted),
          share('B', 100, status: SettleStatus.extensionRequested),
          share('C', 100, status: SettleStatus.extensionGranted),
          share('D', 100, status: SettleStatus.settled),
        ],
      );
      expect(t.settledCount, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. SplitGroup constructor defaults
  // ═══════════════════════════════════════════════════════════════════════════
  group('SplitGroup constructor defaults', () {
    test('transactions defaults to empty list', () {
      final g = SplitGroup(
        id: 'g', name: 'X', emoji: '🤝', walletId: 'w', participants: [],
      );
      expect(g.transactions, isEmpty);
    });

    test('messages defaults to empty list', () {
      final g = SplitGroup(
        id: 'g', name: 'X', emoji: '🤝', walletId: 'w', participants: [],
      );
      expect(g.messages, isEmpty);
    });

    test('pinnedToDashboard defaults to false', () {
      final g = SplitGroup(
        id: 'g', name: 'X', emoji: '🤝', walletId: 'w', participants: [],
      );
      expect(g.pinnedToDashboard, false);
    });

    test('isSettled defaults to false', () {
      final g = SplitGroup(
        id: 'g', name: 'X', emoji: '🤝', walletId: 'w', participants: [],
      );
      expect(g.isSettled, false);
    });

    test('createdAt defaults to a recent DateTime when null passed', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final g = SplitGroup(
        id: 'g', name: 'X', emoji: '🤝', walletId: 'w', participants: [],
      );
      expect(g.createdAt.isAfter(before), true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. SplitGroup.totalSpend
  // ═══════════════════════════════════════════════════════════════════════════
  group('SplitGroup.totalSpend', () {
    test('sum of all tx totalAmounts', () {
      final g = makeGroup(
        participants: [participant('A'), participant('B')],
        transactions: [
          tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 600,
              shares: [share('A', 300), share('B', 300)]),
          tx(id: 't2', groupId: 'g', addedById: 'B', totalAmount: 240,
              shares: [share('A', 120), share('B', 120)]),
        ],
      );
      expect(g.totalSpend, 840.0);
    });

    test('0.0 when no transactions', () {
      expect(makeGroup().totalSpend, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. SplitGroup.isFullySettled
  // ═══════════════════════════════════════════════════════════════════════════
  group('SplitGroup.isFullySettled', () {
    test('true when isSettled flag is set (override)', () {
      expect(makeGroup(isSettled: true).isFullySettled, true);
    });

    test('false when no transactions and isSettled=false', () {
      expect(makeGroup().isFullySettled, false);
    });

    test('true when all txs are fully settled', () {
      final g = makeGroup(
        transactions: [
          tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 200,
              shares: [
                share('A', 100, status: SettleStatus.settled),
                share('B', 100, status: SettleStatus.settled),
              ]),
          tx(id: 't2', groupId: 'g', addedById: 'B', totalAmount: 100,
              shares: [
                share('A', 50, status: SettleStatus.settled),
                share('B', 50, status: SettleStatus.settled),
              ]),
        ],
      );
      expect(g.isFullySettled, true);
    });

    test('false when any tx has pending shares', () {
      final g = makeGroup(
        transactions: [
          tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 200,
              shares: [
                share('A', 100, status: SettleStatus.settled),
                share('B', 100, status: SettleStatus.pending),
              ]),
        ],
      );
      expect(g.isFullySettled, false);
    });

    test('isSettled flag overrides even when txs have pending shares', () {
      final g = makeGroup(
        isSettled: true,
        transactions: [
          tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 200,
              shares: [share('A', 100), share('B', 100)]),
        ],
      );
      expect(g.isFullySettled, true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. SplitGroup.pendingCount
  // ═══════════════════════════════════════════════════════════════════════════
  group('SplitGroup.pendingCount', () {
    test('0 when no transactions', () {
      expect(makeGroup().pendingCount, 0);
    });

    test('0 when all shares are settled', () {
      final g = makeGroup(transactions: [
        tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 200,
            shares: [
              share('A', 100, status: SettleStatus.settled),
              share('B', 100, status: SettleStatus.settled),
            ]),
      ]);
      expect(g.pendingCount, 0);
    });

    test('counts pending shares across all txs', () {
      final g = makeGroup(transactions: [
        tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 300,
            shares: [
              share('A', 100, status: SettleStatus.pending),
              share('B', 100, status: SettleStatus.settled),
              share('C', 100, status: SettleStatus.pending),
            ]),
        tx(id: 't2', groupId: 'g', addedById: 'B', totalAmount: 200,
            shares: [
              share('A', 100, status: SettleStatus.pending),
              share('C', 100, status: SettleStatus.settled),
            ]),
      ]);
      expect(g.pendingCount, 3);
    });

    test('counts extensionRequested as pending', () {
      final g = makeGroup(transactions: [
        tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 200,
            shares: [
              share('A', 100, status: SettleStatus.extensionRequested),
              share('B', 100, status: SettleStatus.settled),
            ]),
      ]);
      expect(g.pendingCount, 1);
    });

    test('does NOT count proofSubmitted or extensionGranted as pending', () {
      final g = makeGroup(transactions: [
        tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 300,
            shares: [
              share('A', 100, status: SettleStatus.proofSubmitted),
              share('B', 100, status: SettleStatus.extensionGranted),
              share('C', 100, status: SettleStatus.pending),
            ]),
      ]);
      expect(g.pendingCount, 1); // only C
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. SplitGroup.participantById
  // ═══════════════════════════════════════════════════════════════════════════
  group('SplitGroup.participantById', () {
    final g = makeGroup(participants: [
      participant('A', name: 'Arjun'),
      participant('B', name: 'Priya'),
      participant('C', name: 'Ravi'),
    ]);

    test('returns matching participant', () {
      expect(g.participantById('B')?.name, 'Priya');
    });

    test('returns null for unknown id', () {
      expect(g.participantById('Z'), isNull);
    });

    test('returns correct participant by id, not by position', () {
      expect(g.participantById('C')?.name, 'Ravi');
      expect(g.participantById('A')?.name, 'Arjun');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 11. SplitGroup.netBalances
  // ═══════════════════════════════════════════════════════════════════════════
  group('SplitGroup.netBalances — 2-person', () {
    // A pays 1000, shares equally: A=500, B=500
    // A net: +1000 - 500 = +500 (owed by B)
    // B net: -500 (owes A)
    final g = makeGroup(
      participants: [participant('A'), participant('B')],
      transactions: [
        tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 1000,
            shares: [share('A', 500), share('B', 500)]),
      ],
    );

    test('payer has positive net balance', () {
      expect(g.netBalances['A'], closeTo(500, 0.01));
    });

    test('non-payer has negative net balance', () {
      expect(g.netBalances['B'], closeTo(-500, 0.01));
    });

    test('all participants initialised in map', () {
      expect(g.netBalances.keys, containsAll(['A', 'B']));
    });

    test('net balances sum to zero', () {
      final sum = g.netBalances.values.fold(0.0, (a, b) => a + b);
      expect(sum, closeTo(0.0, 0.01));
    });
  });

  group('SplitGroup.netBalances — 3-person, A paid all', () {
    // A pays 300, 3-way equal: A=100, B=100, C=100
    // A net: +300 - 100 = +200
    // B net: -100
    // C net: -100
    final g = makeGroup(
      participants: [participant('A'), participant('B'), participant('C')],
      transactions: [
        tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 300,
            shares: [share('A', 100), share('B', 100), share('C', 100)]),
      ],
    );

    test('A net = +200', () => expect(g.netBalances['A'], closeTo(200, 0.01)));
    test('B net = -100', () => expect(g.netBalances['B'], closeTo(-100, 0.01)));
    test('C net = -100', () => expect(g.netBalances['C'], closeTo(-100, 0.01)));
    test('sum = 0', () {
      final sum = g.netBalances.values.fold(0.0, (a, b) => a + b);
      expect(sum, closeTo(0.0, 0.01));
    });
  });

  group('SplitGroup.netBalances — multiple transactions', () {
    // Tx1: A pays 300, shares A=100, B=100, C=100
    // Tx2: B pays 150, shares A=75, B=75
    // A net: +300 - 100 - 75 = +125
    // B net: -100 + 150 - 75 = -25
    // C net: -100
    final g = makeGroup(
      participants: [participant('A'), participant('B'), participant('C')],
      transactions: [
        tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 300,
            shares: [share('A', 100), share('B', 100), share('C', 100)]),
        tx(id: 't2', groupId: 'g', addedById: 'B', totalAmount: 150,
            shares: [share('A', 75), share('B', 75)]),
      ],
    );

    test('A net = +125', () => expect(g.netBalances['A'], closeTo(125, 0.01)));
    test('B net = -25', () => expect(g.netBalances['B'], closeTo(-25, 0.01)));
    test('C net = -100', () => expect(g.netBalances['C'], closeTo(-100, 0.01)));
    test('sum = 0', () {
      final sum = g.netBalances.values.fold(0.0, (a, b) => a + b);
      expect(sum, closeTo(0.0, 0.01));
    });
  });

  group('SplitGroup.netBalances — edge cases', () {
    test('all participants zero when no transactions', () {
      final g = makeGroup(participants: [participant('A'), participant('B')]);
      expect(g.netBalances['A'], closeTo(0, 0.01));
      expect(g.netBalances['B'], closeTo(0, 0.01));
    });

    test('empty map when no participants and no transactions', () {
      expect(makeGroup().netBalances, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 12. SplitGroup.settlementPlan
  // ═══════════════════════════════════════════════════════════════════════════
  group('SplitGroup.settlementPlan — simple 2-person', () {
    // B owes A 500 → one transfer: B→A 500
    final g = makeGroup(
      participants: [participant('A'), participant('B')],
      transactions: [
        tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 1000,
            shares: [share('A', 500), share('B', 500)]),
      ],
    );

    test('produces exactly one transfer', () {
      expect(g.settlementPlan.length, 1);
    });

    test('B pays A the correct amount', () {
      final plan = g.settlementPlan;
      expect(plan[0].fromId, 'B');
      expect(plan[0].toId, 'A');
      expect(plan[0].amount, closeTo(500, 0.01));
    });
  });

  group('SplitGroup.settlementPlan — 3-person, one creditor', () {
    // A net=+200, B net=-100, C net=-100 → B→A 100, C→A 100
    final g = makeGroup(
      participants: [participant('A'), participant('B'), participant('C')],
      transactions: [
        tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 300,
            shares: [share('A', 100), share('B', 100), share('C', 100)]),
      ],
    );

    test('produces two transfers', () {
      expect(g.settlementPlan.length, 2);
    });

    test('all transfers directed to A (the creditor)', () {
      for (final t in g.settlementPlan) {
        expect(t.toId, 'A');
      }
    });

    test('amounts are correct (100 each)', () {
      final amounts = g.settlementPlan.map((t) => t.amount).toList()..sort();
      expect(amounts[0], closeTo(100, 0.01));
      expect(amounts[1], closeTo(100, 0.01));
    });

    test('debtors are B and C', () {
      final froms = g.settlementPlan.map((t) => t.fromId).toSet();
      expect(froms, containsAll(['B', 'C']));
    });
  });

  group('SplitGroup.settlementPlan — multiple creditors and debtors', () {
    // Tx1: A pays 400, shares A=100, B=150, C=150 → A=+300, B=-150, C=-150
    // Tx2: D pays 100, shares B=100              → D=+100, B=-250
    // Final: A=+300, D=+100, B=-250, C=-150  (sum=0)
    // Greedy: B→A 250 (A credit left 50), C→A 50 (A done), C→D 100
    final g = makeGroup(
      participants: [participant('A'), participant('B'), participant('C'), participant('D')],
      transactions: [
        tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 400,
            shares: [share('A', 100), share('B', 150), share('C', 150)]),
        tx(id: 't2', groupId: 'g', addedById: 'D', totalAmount: 100,
            shares: [share('B', 100)]),
      ],
    );

    test('produces 3 transfers for 4-person split (minimum)', () {
      expect(g.settlementPlan.length, 3);
    });

    test('no transfer amount is zero or negative', () {
      for (final t in g.settlementPlan) {
        expect(t.amount, greaterThan(0.01));
      }
    });

    test('total transferred equals total debt (B=250, C=150)', () {
      final totalTransferred = g.settlementPlan.fold(0.0, (s, t) => s + t.amount);
      expect(totalTransferred, closeTo(400, 0.01));
    });
  });

  group('SplitGroup.settlementPlan — edge cases', () {
    test('empty plan when no transactions', () {
      final g = makeGroup(participants: [participant('A'), participant('B')]);
      expect(g.settlementPlan, isEmpty);
    });

    test('empty plan when all balances are zero (each paid own share)', () {
      // A pays 300 and A's share = 300 → A net = 0
      // B pays 150 and B's share = 150 → B net = 0
      final g = makeGroup(
        participants: [participant('A'), participant('B')],
        transactions: [
          tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 300,
              shares: [share('A', 300)]),
          tx(id: 't2', groupId: 'g', addedById: 'B', totalAmount: 150,
              shares: [share('B', 150)]),
        ],
      );
      expect(g.settlementPlan, isEmpty);
    });

    test('near-zero amounts (< 0.01) are filtered from result', () {
      // B owes 99.999; A's remaining credit of 0.001 is below threshold
      final g = makeGroup(
        participants: [participant('A'), participant('B')],
        transactions: [
          tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 100,
              shares: [share('A', 0.001), share('B', 99.999)]),
        ],
      );
      for (final t in g.settlementPlan) {
        expect(t.amount, greaterThan(0.01));
      }
    });

    test('single participant paying own share → no transfers', () {
      final g = makeGroup(
        participants: [participant('A')],
        transactions: [
          tx(id: 't1', groupId: 'g', addedById: 'A', totalAmount: 200,
              shares: [share('A', 200)]),
        ],
      );
      expect(g.settlementPlan, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 13. splitGroupFromRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('splitGroupFromRow', () {
    Map<String, dynamic> baseRow() => {
      'id': 'grp1',
      'name': 'Goa Trip',
      'emoji': '🏖️',
      'wallet_id': 'personal',
      'created_at': '2025-08-01T00:00:00.000Z',
      'pinned_to_dashboard': true,
      'split_participants': [
        {'id': 'p1', 'name': 'Arjun', 'emoji': '👨', 'phone': '9999', 'is_me': true},
        {'id': 'p2', 'name': 'Priya', 'emoji': '👩', 'is_me': false},
      ],
      'split_group_transactions': [
        {
          'id': 'tx1',
          'group_id': 'grp1',
          'added_by_id': 'p1',
          'title': 'Hotel',
          'total_amount': 6000.0,
          'split_type': 'equal',
          'date': '2025-08-02',
          'note': 'Beachside hotel',
          'payment_mode': 'online',
          'split_shares': [
            {
              'id': 's1', 'participant_id': 'p1', 'amount': 3000.0,
              'status': 'settled', 'percentage': null,
              'proof_note': null, 'proof_image_path': null,
              'proof_date': null, 'extension_date': null,
              'extension_reason': null, 'extension_response_msg': null,
              'reminder_count': null,
            },
            {
              'id': 's2', 'participant_id': 'p2', 'amount': 3000.0,
              'status': 'pending', 'percentage': null,
              'proof_note': null, 'proof_image_path': null,
              'proof_date': null, 'extension_date': null,
              'extension_reason': null, 'extension_response_msg': null,
              'reminder_count': 2,
            },
          ],
        },
      ],
    };

    test('parses group-level fields', () {
      final g = splitGroupFromRow(baseRow());
      expect(g.id, 'grp1');
      expect(g.name, 'Goa Trip');
      expect(g.emoji, '🏖️');
      expect(g.walletId, 'personal');
      expect(g.pinnedToDashboard, true);
    });

    test('parses participants', () {
      final g = splitGroupFromRow(baseRow());
      expect(g.participants.length, 2);
      expect(g.participants[0].id, 'p1');
      expect(g.participants[0].name, 'Arjun');
      expect(g.participants[0].isMe, true);
      expect(g.participants[1].isMe, false);
    });

    test('participant emoji defaults to 👤 when absent', () {
      final row = baseRow();
      (row['split_participants'] as List)[1].remove('emoji');
      final g = splitGroupFromRow(row);
      expect(g.participants[1].emoji, '👤');
    });

    test('parses transactions with shares', () {
      final g = splitGroupFromRow(baseRow());
      expect(g.transactions.length, 1);
      final t = g.transactions[0];
      expect(t.title, 'Hotel');
      expect(t.totalAmount, 6000.0);
      expect(t.splitType, SplitType.equal);
      expect(t.shares.length, 2);
    });

    test('parses share status correctly', () {
      final g = splitGroupFromRow(baseRow());
      final shares = g.transactions[0].shares;
      expect(shares[0].status, SettleStatus.settled);
      expect(shares[1].status, SettleStatus.pending);
    });

    test('parses reminderCount on share', () {
      final g = splitGroupFromRow(baseRow());
      expect(g.transactions[0].shares[1].reminderCount, 2);
    });

    test('emoji defaults to 🤝 when absent', () {
      final row = baseRow()..remove('emoji');
      expect(splitGroupFromRow(row).emoji, '🤝');
    });

    test('pinnedToDashboard defaults to false when absent', () {
      final row = baseRow()..remove('pinned_to_dashboard');
      expect(splitGroupFromRow(row).pinnedToDashboard, false);
    });

    test('absent participants → empty list', () {
      final row = baseRow()..remove('split_participants');
      expect(splitGroupFromRow(row).participants, isEmpty);
    });

    test('absent transactions → empty list', () {
      final row = baseRow()..remove('split_group_transactions');
      expect(splitGroupFromRow(row).transactions, isEmpty);
    });

    test('absent created_at → createdAt falls back to now', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final row = baseRow()..remove('created_at');
      expect(splitGroupFromRow(row).createdAt.isAfter(before), true);
    });
  });
}
