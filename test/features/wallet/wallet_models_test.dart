import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. TxModel.fromRow
  // ═══════════════════════════════════════════════════════════════════════════
  group('TxModel.fromRow', () {
    Map<String, dynamic> baseRow() => {
      'id': 'tx1',
      'type': 'expense',
      'pay_mode': 'online',
      'amount': 250.0,
      'category': 'Food',
      'title': 'Lunch',
      'note': 'With team',
      'date': '2025-08-10',
      'wallet_id': 'personal',
      'person': 'Priya',
      'persons': ['Priya', 'Ravi'],
      'status': 'pending',
      'due_date': '2025-09-01',
      'user_id': 'user_abc',
      'group_id': 'grp_1',
    };

    test('parses all fields correctly', () {
      final tx = TxModel.fromRow(baseRow());
      expect(tx.id, 'tx1');
      expect(tx.type, TxType.expense);
      expect(tx.payMode, PayMode.online);
      expect(tx.amount, 250.0);
      expect(tx.category, 'Food');
      expect(tx.title, 'Lunch');
      expect(tx.note, 'With team');
      expect(tx.date, DateTime(2025, 8, 10));
      expect(tx.walletId, 'personal');
      expect(tx.person, 'Priya');
      expect(tx.persons, ['Priya', 'Ravi']);
      expect(tx.status, 'pending');
      expect(tx.dueDate, '2025-09-01');
      expect(tx.userId, 'user_abc');
      expect(tx.groupId, 'grp_1');
    });

    test('amount as int is cast to double', () {
      final row = baseRow()..['amount'] = 500; // int
      expect(TxModel.fromRow(row).amount, 500.0);
    });

    test('unknown type string defaults to expense', () {
      final row = baseRow()..['type'] = 'transfer';
      expect(TxModel.fromRow(row).type, TxType.expense);
    });

    test('all TxType values parse correctly by name', () {
      for (final t in TxType.values) {
        final row = baseRow()..['type'] = t.name;
        expect(TxModel.fromRow(row).type, t, reason: t.name);
      }
    });

    test('pay_mode null → payMode is null', () {
      final row = baseRow()..['pay_mode'] = null;
      expect(TxModel.fromRow(row).payMode, isNull);
    });

    test('pay_mode absent → payMode is null', () {
      final row = baseRow()..remove('pay_mode');
      expect(TxModel.fromRow(row).payMode, isNull);
    });

    test('unknown pay_mode string defaults to cash', () {
      final row = baseRow()..['pay_mode'] = 'gpay';
      expect(TxModel.fromRow(row).payMode, PayMode.cash);
    });

    test('both PayMode values parse correctly', () {
      for (final pm in PayMode.values) {
        final row = baseRow()..['pay_mode'] = pm.name;
        expect(TxModel.fromRow(row).payMode, pm, reason: pm.name);
      }
    });

    test('valid date string parses to DateTime', () {
      final row = baseRow()..['date'] = '2025-12-25';
      expect(TxModel.fromRow(row).date, DateTime(2025, 12, 25));
    });

    test('invalid date string falls back to now', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final row = baseRow()..['date'] = 'not-a-date';
      final tx = TxModel.fromRow(row);
      expect(tx.date.isAfter(before), true);
    });

    test('null date string falls back to now', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final row = baseRow()..['date'] = null;
      final tx = TxModel.fromRow(row);
      expect(tx.date.isAfter(before), true);
    });

    test('category absent → empty string', () {
      final row = baseRow()..remove('category');
      expect(TxModel.fromRow(row).category, '');
    });

    test('optional string fields are null when absent', () {
      final row = baseRow()
        ..remove('title')
        ..remove('note')
        ..remove('person')
        ..remove('status')
        ..remove('due_date')
        ..remove('user_id')
        ..remove('group_id');
      final tx = TxModel.fromRow(row);
      expect(tx.title, isNull);
      expect(tx.note, isNull);
      expect(tx.person, isNull);
      expect(tx.status, isNull);
      expect(tx.dueDate, isNull);
      expect(tx.userId, isNull);
      expect(tx.groupId, isNull);
    });

    test('persons absent → null (not empty list)', () {
      final row = baseRow()..remove('persons');
      expect(TxModel.fromRow(row).persons, isNull);
    });

    test('persons list parses correctly', () {
      final row = baseRow()..['persons'] = ['Ali', 'Bob', 'Chen'];
      expect(TxModel.fromRow(row).persons, ['Ali', 'Bob', 'Chen']);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. TxGroup.fromRow and computed getters
  // ═══════════════════════════════════════════════════════════════════════════
  group('TxGroup.fromRow', () {
    Map<String, dynamic> baseRow() => {
      'id': 'grp1',
      'wallet_id': 'personal',
      'name': 'Goa Trip',
      'emoji': '🏖️',
    };

    test('parses all fields', () {
      final g = TxGroup.fromRow(baseRow());
      expect(g.id, 'grp1');
      expect(g.walletId, 'personal');
      expect(g.name, 'Goa Trip');
      expect(g.emoji, '🏖️');
      expect(g.transactions, isEmpty);
    });

    test('emoji defaults to 📦 when absent', () {
      final row = baseRow()..remove('emoji');
      expect(TxGroup.fromRow(row).emoji, '📦');
    });

    test('transactions always starts empty from fromRow', () {
      expect(TxGroup.fromRow(baseRow()).transactions, isEmpty);
    });
  });

  group('TxGroup computed getters', () {
    TxModel tx(double amount, DateTime date) => TxModel(
      id: 'tx', type: TxType.expense, amount: amount,
      category: 'Food', date: date, walletId: 'personal',
    );

    test('total = sum of all transaction amounts', () {
      final g = TxGroup(
        id: 'g', walletId: 'w', name: 'X', emoji: '📦',
        transactions: [
          tx(100, DateTime(2025, 8, 1)),
          tx(250, DateTime(2025, 8, 2)),
          tx(50, DateTime(2025, 8, 3)),
        ],
      );
      expect(g.total, 400.0);
    });

    test('total = 0.0 when no transactions', () {
      final g = TxGroup(
        id: 'g', walletId: 'w', name: 'X', emoji: '📦',
        transactions: [],
      );
      expect(g.total, 0.0);
    });

    test('latestDate = date of first transaction', () {
      final d1 = DateTime(2025, 8, 10);
      final d2 = DateTime(2025, 8, 1);
      final g = TxGroup(
        id: 'g', walletId: 'w', name: 'X', emoji: '📦',
        transactions: [tx(100, d1), tx(200, d2)],
      );
      expect(g.latestDate, d1);
    });

    test('earliestDate = date of last transaction', () {
      final d1 = DateTime(2025, 8, 10);
      final d2 = DateTime(2025, 7, 20);
      final g = TxGroup(
        id: 'g', walletId: 'w', name: 'X', emoji: '📦',
        transactions: [tx(100, d1), tx(200, d2)],
      );
      expect(g.earliestDate, d2);
    });

    test('latestDate and earliestDate fall back to now when empty', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final g = TxGroup(
        id: 'g', walletId: 'w', name: 'X', emoji: '📦',
        transactions: [],
      );
      expect(g.latestDate.isAfter(before), true);
      expect(g.earliestDate.isAfter(before), true);
    });

    test('withTransactions returns new group with provided txs', () {
      final g = TxGroup.fromRow({
        'id': 'g1', 'wallet_id': 'w', 'name': 'Trip', 'emoji': '🚗',
      });
      final txs = [tx(100, DateTime(2025, 8, 1))];
      final g2 = g.withTransactions(txs);
      expect(g2.id, g.id);
      expect(g2.name, g.name);
      expect(g2.transactions, txs);
      expect(g.transactions, isEmpty); // original unchanged
    });

    test('withTransactions total reflects new txs', () {
      final g = TxGroup.fromRow({
        'id': 'g1', 'wallet_id': 'w', 'name': 'X', 'emoji': '📦',
      }).withTransactions([
        tx(300, DateTime(2025, 8, 1)),
        tx(200, DateTime(2025, 8, 2)),
      ]);
      expect(g.total, 500.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. WalletModel computed getters
  // ═══════════════════════════════════════════════════════════════════════════
  group('WalletModel computed getters', () {
    WalletModel wallet({
      double cashIn = 0, double cashOut = 0,
      double onlineIn = 0, double onlineOut = 0,
    }) => WalletModel(
      id: 'w', name: 'Personal', emoji: '👤', isPersonal: true,
      cashIn: cashIn, cashOut: cashOut,
      onlineIn: onlineIn, onlineOut: onlineOut,
      gradient: const [Colors.blue, Colors.purple],
    );

    test('totalIn = cashIn + onlineIn', () {
      expect(wallet(cashIn: 1000, onlineIn: 2500).totalIn, 3500.0);
    });

    test('totalOut = cashOut + onlineOut', () {
      expect(wallet(cashOut: 500, onlineOut: 1200).totalOut, 1700.0);
    });

    test('balance = totalIn - totalOut', () {
      expect(
        wallet(cashIn: 5000, onlineIn: 2000, cashOut: 1000, onlineOut: 3000).balance,
        3000.0,
      );
    });

    test('balance is zero when in equals out', () {
      expect(wallet(cashIn: 1000, cashOut: 500, onlineIn: 500, onlineOut: 1000).balance, 0.0);
    });

    test('balance is negative when spend exceeds income', () {
      expect(wallet(cashIn: 500, onlineIn: 500, cashOut: 2000).balance, -1000.0);
    });

    test('all totals zero when no transactions', () {
      final w = wallet();
      expect(w.totalIn, 0.0);
      expect(w.totalOut, 0.0);
      expect(w.balance, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. BudgetModel.fromRow and computed getters
  // ═══════════════════════════════════════════════════════════════════════════
  group('BudgetModel.fromRow', () {
    Map<String, dynamic> baseRow() => {
      'id': 'b1',
      'wallet_id': 'personal',
      'category': 'Food',
      'limit_amount': 5000.0,
      'last_80_alert_month': '2025-07',
      'last_100_alert_month': null,
    };

    test('parses all fields', () {
      final b = BudgetModel.fromRow(baseRow());
      expect(b.id, 'b1');
      expect(b.walletId, 'personal');
      expect(b.category, 'Food');
      expect(b.limitAmount, 5000.0);
      expect(b.last80AlertMonth, '2025-07');
      expect(b.last100AlertMonth, isNull);
    });

    test('limitAmount as int is cast to double', () {
      final row = baseRow()..['limit_amount'] = 3000; // int
      expect(BudgetModel.fromRow(row).limitAmount, 3000.0);
    });

    test('both alert months null when absent', () {
      final row = baseRow()
        ..remove('last_80_alert_month')
        ..remove('last_100_alert_month');
      final b = BudgetModel.fromRow(row);
      expect(b.last80AlertMonth, isNull);
      expect(b.last100AlertMonth, isNull);
    });

    test('spent defaults to 0 (not in DB row)', () {
      expect(BudgetModel.fromRow(baseRow()).spent, 0.0);
    });
  });

  group('BudgetModel computed getters — pct', () {
    BudgetModel budget(double limit, double spent) =>
        BudgetModel(id: 'b', walletId: 'w', category: 'Food', limitAmount: limit)
          ..spent = spent;

    test('pct = spent / limitAmount', () {
      expect(budget(5000, 4000).pct, closeTo(0.8, 0.001));
    });

    test('pct = 0 when limitAmount is zero (no divide-by-zero)', () {
      expect(budget(0, 500).pct, 0.0);
    });

    test('pct = 0 when spent = 0', () {
      expect(budget(5000, 0).pct, 0.0);
    });

    test('pct = 1.0 when exactly at limit', () {
      expect(budget(5000, 5000).pct, 1.0);
    });

    test('pct > 1.0 when over limit', () {
      expect(budget(5000, 6000).pct, closeTo(1.2, 0.001));
    });
  });

  group('BudgetModel computed getters — alert states', () {
    BudgetModel budget(double limit, double spent) =>
        BudgetModel(id: 'b', walletId: 'w', category: 'Food', limitAmount: limit)
          ..spent = spent;

    test('isOver = false when below limit', () {
      expect(budget(5000, 3000).isOver, false);
    });

    test('isOver = true when at exactly 100%', () {
      expect(budget(5000, 5000).isOver, true);
    });

    test('isOver = true when above limit', () {
      expect(budget(5000, 6000).isOver, true);
    });

    test('isNear = true when between 80% and 100% (exclusive)', () {
      expect(budget(5000, 4000).isNear, true); // 80%
      expect(budget(5000, 4999).isNear, true); // 99.98%
    });

    test('isNear = false when below 80%', () {
      expect(budget(5000, 3999).isNear, false);
    });

    test('isNear = false when isOver is true', () {
      expect(budget(5000, 5000).isNear, false); // at 100%, isOver wins
      expect(budget(5000, 5500).isNear, false);
    });

    test('isAlert = false when well under budget', () {
      expect(budget(5000, 1000).isAlert, false);
    });

    test('isAlert = true when near (80–99%)', () {
      expect(budget(5000, 4200).isAlert, true);
    });

    test('isAlert = true when over (100%+)', () {
      expect(budget(5000, 5500).isAlert, true);
    });

    test('alertEmoji is 🔴 when isOver', () {
      expect(budget(5000, 5001).alertEmoji, '🔴');
    });

    test('alertEmoji is 🟠 when isNear (not over)', () {
      expect(budget(5000, 4500).alertEmoji, '🟠');
    });

    test('alertEmoji is 🟠 (not over) even at exactly 80%', () {
      expect(budget(5000, 4000).alertEmoji, '🟠');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. FamilyMember.copyWith
  // ═══════════════════════════════════════════════════════════════════════════
  group('FamilyMember.copyWith', () {
    final base = FamilyMember(
      id: 'mem1',
      userId: 'uid1',
      name: 'Priya',
      emoji: '👩',
      role: MemberRole.member,
      phone: '9999999999',
      relation: 'Wife',
      photoPath: '/path/to/photo.jpg',
    );

    test('id is immutable', () {
      final copy = base.copyWith(name: 'Riya');
      expect(copy.id, 'mem1');
    });

    test('no-op copyWith preserves all fields', () {
      final copy = base.copyWith();
      expect(copy.userId, base.userId);
      expect(copy.name, base.name);
      expect(copy.emoji, base.emoji);
      expect(copy.role, base.role);
      expect(copy.phone, base.phone);
      expect(copy.relation, base.relation);
      expect(copy.photoPath, base.photoPath);
    });

    test('overrides name', () {
      expect(base.copyWith(name: 'Deepa').name, 'Deepa');
    });

    test('overrides emoji', () {
      expect(base.copyWith(emoji: '👸').emoji, '👸');
    });

    test('overrides role', () {
      expect(base.copyWith(role: MemberRole.admin).role, MemberRole.admin);
    });

    test('overrides phone', () {
      expect(base.copyWith(phone: '8888888888').phone, '8888888888');
    });

    test('overrides relation', () {
      expect(base.copyWith(relation: 'Sister').relation, 'Sister');
    });

    test('overrides userId', () {
      expect(base.copyWith(userId: 'uid2').userId, 'uid2');
    });

    test('overrides photoPath', () {
      expect(base.copyWith(photoPath: '/new/path.jpg').photoPath, '/new/path.jpg');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. FamilyModel permission getters
  // ═══════════════════════════════════════════════════════════════════════════
  group('FamilyModel — isAdmin', () {
    test('isAdmin = true when myRole = admin', () {
      final f = FamilyModel(id: 'f', name: 'X', emoji: '🏠', colorIndex: 0,
          myRole: MemberRole.admin);
      expect(f.isAdmin, true);
    });

    test('isAdmin = false when myRole = member', () {
      final f = FamilyModel(id: 'f', name: 'X', emoji: '🏠', colorIndex: 0,
          myRole: MemberRole.member);
      expect(f.isAdmin, false);
    });

    test('isAdmin = false when myRole = viewer', () {
      final f = FamilyModel(id: 'f', name: 'X', emoji: '🏠', colorIndex: 0,
          myRole: MemberRole.viewer);
      expect(f.isAdmin, false);
    });
  });

  group('FamilyModel — canInvite', () {
    FamilyModel model({required MemberRole role, String perm = 'admin_only'}) =>
        FamilyModel(id: 'f', name: 'X', emoji: '🏠', colorIndex: 0,
            myRole: role, permInvite: perm);

    test('admin can always invite regardless of perm', () {
      expect(model(role: MemberRole.admin, perm: 'admin_only').canInvite, true);
      expect(model(role: MemberRole.admin, perm: 'any_member').canInvite, true);
    });

    test('member can invite when perm = any_member', () {
      expect(model(role: MemberRole.member, perm: 'any_member').canInvite, true);
    });

    test('member cannot invite when perm = admin_only', () {
      expect(model(role: MemberRole.member, perm: 'admin_only').canInvite, false);
    });

    test('viewer cannot invite when perm = admin_only', () {
      expect(model(role: MemberRole.viewer, perm: 'admin_only').canInvite, false);
    });

    test('viewer can invite when perm = any_member', () {
      expect(model(role: MemberRole.viewer, perm: 'any_member').canInvite, true);
    });
  });

  group('FamilyModel — canEdit', () {
    FamilyModel model({required MemberRole role, String perm = 'any_member'}) =>
        FamilyModel(id: 'f', name: 'X', emoji: '🏠', colorIndex: 0,
            myRole: role, permEdit: perm);

    test('admin can always edit', () {
      expect(model(role: MemberRole.admin, perm: 'admin_only').canEdit, true);
    });

    test('member can edit when perm = any_member', () {
      expect(model(role: MemberRole.member, perm: 'any_member').canEdit, true);
    });

    test('member cannot edit when perm = admin_only', () {
      expect(model(role: MemberRole.member, perm: 'admin_only').canEdit, false);
    });
  });

  group('FamilyModel — canDelete', () {
    FamilyModel model({required MemberRole role, String perm = 'admin_only'}) =>
        FamilyModel(id: 'f', name: 'X', emoji: '🏠', colorIndex: 0,
            myRole: role, permDelete: perm);

    test('admin can always delete', () {
      expect(model(role: MemberRole.admin, perm: 'admin_only').canDelete, true);
    });

    test('member cannot delete when perm = admin_only', () {
      expect(model(role: MemberRole.member, perm: 'admin_only').canDelete, false);
    });

    test('member can delete when perm = any_member', () {
      expect(model(role: MemberRole.member, perm: 'any_member').canDelete, true);
    });

    test('viewer cannot delete when perm = admin_only', () {
      expect(model(role: MemberRole.viewer, perm: 'admin_only').canDelete, false);
    });
  });

  group('FamilyModel — members default', () {
    test('members defaults to empty list when not provided', () {
      final f = FamilyModel(id: 'f', name: 'X', emoji: '🏠', colorIndex: 0);
      expect(f.members, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. TxType extensions
  // ═══════════════════════════════════════════════════════════════════════════
  group('TxTypeExt — label, emoji, color, bgColor', () {
    test('all values have non-empty label', () {
      for (final t in TxType.values) {
        expect(t.label, isNotEmpty, reason: t.name);
      }
    });

    test('all values have non-empty emoji', () {
      for (final t in TxType.values) {
        expect(t.emoji, isNotEmpty, reason: t.name);
      }
    });

    test('all values have a color', () {
      for (final t in TxType.values) {
        expect(t.color, isA<Color>(), reason: t.name);
      }
    });

    test('all values have a bgColor', () {
      for (final t in TxType.values) {
        expect(t.bgColor, isA<Color>(), reason: t.name);
      }
    });

    test('spot checks — label', () {
      expect(TxType.income.label, 'Income');
      expect(TxType.expense.label, 'Expense');
      expect(TxType.lend.label, 'Lent');
      expect(TxType.borrow.label, 'Borrowed');
      expect(TxType.request.label, 'Request');
      expect(TxType.returned.label, 'Returned');
      expect(TxType.split.label, 'Split');
    });

    test('spot checks — emoji', () {
      expect(TxType.income.emoji, '💰');
      expect(TxType.expense.emoji, '💸');
      expect(TxType.lend.emoji, '📤');
      expect(TxType.borrow.emoji, '📥');
      expect(TxType.request.emoji, '🔔');
    });
  });

  group('TxTypeExt — isPositive', () {
    test('income, borrow, returned are positive', () {
      expect(TxType.income.isPositive, true);
      expect(TxType.borrow.isPositive, true);
      expect(TxType.returned.isPositive, true);
    });

    test('expense, split, lend, request are not positive', () {
      expect(TxType.expense.isPositive, false);
      expect(TxType.split.isPositive, false);
      expect(TxType.lend.isPositive, false);
      expect(TxType.request.isPositive, false);
    });
  });

  group('TxTypeExt — isPending', () {
    test('only request isPending', () {
      expect(TxType.request.isPending, true);
    });

    test('all other types are not pending', () {
      for (final t in TxType.values) {
        if (t != TxType.request) {
          expect(t.isPending, false, reason: t.name);
        }
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. WalletTabExt / MemberRole
  // ═══════════════════════════════════════════════════════════════════════════
  group('WalletTabExt', () {
    test('all values have non-empty label', () {
      for (final tab in WalletTab.values) {
        expect(tab.label, isNotEmpty, reason: tab.name);
      }
    });

    test('spot checks', () {
      expect(WalletTab.wallet.label, 'Wallet');
      expect(WalletTab.splits.label, 'Splits');
      expect(WalletTab.billWatch.label, 'Bill Watch');
    });

    test('kV1WalletTabs excludes billWatch', () {
      expect(kV1WalletTabs, contains(WalletTab.wallet));
      expect(kV1WalletTabs, contains(WalletTab.splits));
      expect(kV1WalletTabs, isNot(contains(WalletTab.billWatch)));
    });
  });

  group('MemberRole', () {
    test('all values have non-empty emoji and label', () {
      for (final r in MemberRole.values) {
        expect(r.emoji, isNotEmpty, reason: r.name);
        expect(r.label, isNotEmpty, reason: r.name);
      }
    });

    test('spot checks', () {
      expect(MemberRole.admin.emoji, '👑');
      expect(MemberRole.admin.label, 'Admin');
      expect(MemberRole.member.emoji, '👤');
      expect(MemberRole.viewer.emoji, '👁️');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. walletCategoryEmoji
  // ═══════════════════════════════════════════════════════════════════════════
  group('walletCategoryEmoji — primary categories', () {
    test('food → 🍔', () => expect(walletCategoryEmoji('food'), '🍔'));
    test('groceries → 🛒', () => expect(walletCategoryEmoji('groceries'), '🛒'));
    test('transport → 🚗', () => expect(walletCategoryEmoji('transport'), '🚗'));
    test('fuel → ⛽', () => expect(walletCategoryEmoji('fuel'), '⛽'));
    test('shopping → 🛍️', () => expect(walletCategoryEmoji('shopping'), '🛍️'));
    test('health → 💊', () => expect(walletCategoryEmoji('health'), '💊'));
    test('hospital → 🏥', () => expect(walletCategoryEmoji('hospital'), '🏥'));
    test('education → 📚', () => expect(walletCategoryEmoji('education'), '📚'));
    test('entertainment → 🎬', () => expect(walletCategoryEmoji('entertainment'), '🎬'));
    test('utilities → 💡', () => expect(walletCategoryEmoji('utilities'), '💡'));
    test('rent → 🏠', () => expect(walletCategoryEmoji('rent'), '🏠'));
    test('salary → 💰', () => expect(walletCategoryEmoji('salary'), '💰'));
    test('freelance → 💻', () => expect(walletCategoryEmoji('freelance'), '💻'));
    test('investment → 📈', () => expect(walletCategoryEmoji('investment'), '📈'));
    test('travel → ✈️', () => expect(walletCategoryEmoji('travel'), '✈️'));
    test('clothing → 👕', () => expect(walletCategoryEmoji('clothing'), '👕'));
    test('subscription → 📺', () => expect(walletCategoryEmoji('subscription'), '📺'));
    test('bills → 💳', () => expect(walletCategoryEmoji('bills'), '💳'));
    test('gifts → 🎁', () => expect(walletCategoryEmoji('gifts'), '🎁'));
    test('insurance → 🛡️', () => expect(walletCategoryEmoji('insurance'), '🛡️'));
  });

  group('walletCategoryEmoji — aliases', () {
    test('dining → 🍔 (alias for food)', () => expect(walletCategoryEmoji('dining'), '🍔'));
    test('restaurant → 🍔', () => expect(walletCategoryEmoji('restaurant'), '🍔'));
    test('transportation → 🚗', () => expect(walletCategoryEmoji('transportation'), '🚗'));
    test('commute → 🚗', () => expect(walletCategoryEmoji('commute'), '🚗'));
    test('petrol → ⛽', () => expect(walletCategoryEmoji('petrol'), '⛽'));
    test('diesel → ⛽', () => expect(walletCategoryEmoji('diesel'), '⛽'));
    test('medical → 💊', () => expect(walletCategoryEmoji('medical'), '💊'));
    test('school → 📚', () => expect(walletCategoryEmoji('school'), '📚'));
    test('college → 📚', () => expect(walletCategoryEmoji('college'), '📚'));
    test('utility → 💡', () => expect(walletCategoryEmoji('utility'), '💡'));
    test('electricity → 💡', () => expect(walletCategoryEmoji('electricity'), '💡'));
    test('water → 💡', () => expect(walletCategoryEmoji('water'), '💡'));
    test('housing → 🏠', () => expect(walletCategoryEmoji('housing'), '🏠'));
    test('vacation → ✈️', () => expect(walletCategoryEmoji('vacation'), '✈️'));
    test('clothes → 👕', () => expect(walletCategoryEmoji('clothes'), '👕'));
    test('fashion → 👕', () => expect(walletCategoryEmoji('fashion'), '👕'));
    test('ott → 📺', () => expect(walletCategoryEmoji('ott'), '📺'));
  });

  group('walletCategoryEmoji — case insensitivity and fallback', () {
    test('FOOD → 🍔 (uppercase)', () => expect(walletCategoryEmoji('FOOD'), '🍔'));
    test('Food → 🍔 (title case)', () => expect(walletCategoryEmoji('Food'), '🍔'));
    test('SALARY → 💰', () => expect(walletCategoryEmoji('SALARY'), '💰'));
    test('unknown category → 📦', () => expect(walletCategoryEmoji('misc'), '📦'));
    test('empty string → 📦', () => expect(walletCategoryEmoji(''), '📦'));
    test('random string → 📦', () => expect(walletCategoryEmoji('snacks_v2'), '📦'));
  });
}
