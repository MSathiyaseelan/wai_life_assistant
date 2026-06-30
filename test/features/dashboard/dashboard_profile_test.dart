// Tests for Dashboard Profile — pure logic only (no Supabase / network).
// Covers SubscriptionPlanData, ProfileService.parseSwitcherData,
// WalletModel, FamilyMember, TxModel, TxGroup, and MemberRole.

import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/data/models/subscription/subscription_models.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/data/services/profile_service.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _planRow({
  String planKey = 'personal_free',
  String name = 'Personal Free',
  double monthly = 0,
  double yearly = 0,
  Map<String, dynamic> limits = const {},
}) =>
    {
      'plan_key': planKey,
      'name': name,
      'price_monthly': monthly,
      'price_yearly': yearly,
      'plan_limits': limits,
    };

Map<String, dynamic> _fullLimits() => {
      'family_max_members': 5,
      'ai_parser_calls_month': 40,
      'ai_assistant_calls_month': 50,
      'wallet_transactions_month': 200,
      'wallet_split_groups_month': 10,
      'wallet_bill_watch_max': 20,
      'wallet_custom_categories_max': 30,
      'pantry_meal_weeks_ahead': 4,
      'pantry_recipes_max': 100,
      'functions_upcoming_max': 50,
      'functions_my_max': 25,
      'wardrobe_items_max': 200,
      'wardrobe_outfit_log_months': 12,
      'health_medications_max': 50,
      'health_appointments_max': 100,
      'health_vital_logs_month': 300,
      'planit_tasks_max': 200,
      'planit_reminders_max': 100,
      'planit_special_days_max': 100,
      'notif_push_enabled': true,
      'notif_custom_alerts': true,
    };

// ── Switcher row builder ──────────────────────────────────────────────────────

Map<String, dynamic> _switcherRow({
  String personalWalletId = 'wallet-personal-1',
  String emoji = '😎',
  double cashIn = 10000,
  double cashOut = 4000,
  double onlineIn = 5000,
  double onlineOut = 2000,
  List<Map<String, dynamic>> families = const [],
}) =>
    {
      'personal_wallet_id': personalWalletId,
      'emoji': emoji,
      'cash_in': cashIn,
      'cash_out': cashOut,
      'online_in': onlineIn,
      'online_out': onlineOut,
      'families': families,
    };

Map<String, dynamic> _familyRow({
  String familyId = 'fam-1',
  String name = 'Kumar Family',
  String familyEmoji = '👨‍👩‍👧',
  int colorIndex = 0,
  String? walletId = 'wallet-family-1',
  String myRole = 'admin',
  List<Map<String, dynamic>> members = const [],
}) =>
    {
      'family_id': familyId,
      'name': name,
      'emoji': familyEmoji,
      'color_index': colorIndex,
      'wallet_id': walletId,
      'my_role': myRole,
      'perm_invite': 'admin_only',
      'perm_edit': 'any_member',
      'perm_delete': 'admin_only',
      'members': members,
    };

Map<String, dynamic> _memberRow({
  String id = 'mem-1',
  String? userId,
  String name = 'Priya',
  String emoji = '👩',
  String role = 'member',
  String? phone,
  String? relation,
}) =>
    {
      'id': id,
      'user_id': userId,
      'name': name,
      'emoji': emoji,
      'role': role,
      'phone': phone,
      'relation': relation,
    };

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // SubscriptionPlanData.fromRow
  // ───────────────────────────────────────────────────────────────────────────

  group('SubscriptionPlanData.fromRow — basic fields', () {
    test('parses plan key and name', () {
      final plan = SubscriptionPlanData.fromRow(_planRow(
        planKey: 'family_pro',
        name: 'Family Pro',
      ));
      expect(plan.planKey, 'family_pro');
      expect(plan.name, 'Family Pro');
    });

    test('parses monthly and yearly prices', () {
      final plan = SubscriptionPlanData.fromRow(
        _planRow(monthly: 199.0, yearly: 1999.0),
      );
      expect(plan.priceMonthly, 199.0);
      expect(plan.priceYearly, 1999.0);
    });

    test('prices default to 0 when missing', () {
      final plan = SubscriptionPlanData.fromRow({
        'plan_key': 'personal_free',
        'name': 'Free',
        'plan_limits': <String, dynamic>{},
      });
      expect(plan.priceMonthly, 0.0);
      expect(plan.priceYearly, 0.0);
    });
  });

  group('SubscriptionPlanData.fromRow — limit fields', () {
    test('parses all limit fields from plan_limits map', () {
      final plan = SubscriptionPlanData.fromRow(
        _planRow(limits: _fullLimits()),
      );
      expect(plan.familyMaxMembers, 5);
      expect(plan.aiParserCallsMonth, 40);
      expect(plan.aiAssistantCallsMonth, 50);
      expect(plan.walletTransactionsMonth, 200);
      expect(plan.walletSplitGroupsMonth, 10);
      expect(plan.walletBillWatchMax, 20);
      expect(plan.walletCustomCategoriesMax, 30);
      expect(plan.pantryMealWeeksAhead, 4);
      expect(plan.pantryRecipesMax, 100);
      expect(plan.functionsUpcomingMax, 50);
      expect(plan.functionsMyMax, 25);
      expect(plan.wardrobeItemsMax, 200);
      expect(plan.wardrobeOutfitLogMonths, 12);
      expect(plan.healthMedicationsMax, 50);
      expect(plan.healthAppointmentsMax, 100);
      expect(plan.healthVitalLogsMonth, 300);
      expect(plan.planItTasksMax, 200);
      expect(plan.planItRemindersMax, 100);
      expect(plan.planItSpecialDaysMax, 100);
      expect(plan.notifPushEnabled, isTrue);
      expect(plan.notifCustomAlerts, isTrue);
    });

    test('applies documented defaults when plan_limits is empty', () {
      final plan = SubscriptionPlanData.fromRow(_planRow());
      // Defaults from fromRow code
      expect(plan.familyMaxMembers, 0);
      expect(plan.aiParserCallsMonth, 30);
      expect(plan.aiAssistantCallsMonth, 20);
      expect(plan.walletTransactionsMonth, 100);
      expect(plan.walletSplitGroupsMonth, 3);
      expect(plan.walletBillWatchMax, 5);
      expect(plan.walletCustomCategoriesMax, 10);
      expect(plan.pantryMealWeeksAhead, 1);
      expect(plan.pantryRecipesMax, 10);
      expect(plan.functionsUpcomingMax, 15);
      expect(plan.functionsMyMax, 5);
      expect(plan.wardrobeItemsMax, 30);
      expect(plan.wardrobeOutfitLogMonths, 1);
      expect(plan.healthMedicationsMax, 15);
      expect(plan.healthAppointmentsMax, 20);
      expect(plan.healthVitalLogsMonth, 60);
      expect(plan.planItTasksMax, 50);
      expect(plan.planItRemindersMax, 30);
      expect(plan.planItSpecialDaysMax, 30);
      expect(plan.notifPushEnabled, isFalse);
      expect(plan.notifCustomAlerts, isFalse);
    });

    test('null plan_limits map treated as empty', () {
      final plan = SubscriptionPlanData.fromRow({
        'plan_key': 'personal_free',
        'name': 'Free',
        'price_monthly': 0,
        'price_yearly': 0,
        'plan_limits': null,
      });
      expect(plan.familyMaxMembers, 0);
      expect(plan.aiAssistantCallsMonth, 20);
    });

    test('int limit stored as double is cast safely', () {
      final plan = SubscriptionPlanData.fromRow(
        _planRow(limits: {'ai_parser_calls_month': 30.0}),
      );
      expect(plan.aiParserCallsMonth, 30);
    });
  });

  group('SubscriptionPlanData — static label helpers', () {
    test('limitLabel: -1 → ∞', () {
      expect(SubscriptionPlanData.limitLabel(-1), '∞');
    });

    test('limitLabel: 0 → —', () {
      expect(SubscriptionPlanData.limitLabel(0), '—');
    });

    test('limitLabel: positive number → string of that number', () {
      expect(SubscriptionPlanData.limitLabel(50), '50');
      expect(SubscriptionPlanData.limitLabel(1), '1');
    });

    test('weeksLabel: -1 → ∞', () {
      expect(SubscriptionPlanData.weeksLabel(-1), '∞');
    });

    test('weeksLabel: 1 → "1 wk" (singular)', () {
      expect(SubscriptionPlanData.weeksLabel(1), '1 wk');
    });

    test('weeksLabel: > 1 → "N wks" (plural)', () {
      expect(SubscriptionPlanData.weeksLabel(4), '4 wks');
      expect(SubscriptionPlanData.weeksLabel(52), '52 wks');
    });

    test('monthsLabel: -1 → ∞', () {
      expect(SubscriptionPlanData.monthsLabel(-1), '∞');
    });

    test('monthsLabel: 1 → "1 mo" (singular)', () {
      expect(SubscriptionPlanData.monthsLabel(1), '1 mo');
    });

    test('monthsLabel: > 1 → "N mo" (plural)', () {
      expect(SubscriptionPlanData.monthsLabel(12), '12 mo');
    });

    test('boolLabel: true → ✓', () {
      expect(SubscriptionPlanData.boolLabel(true), '✓');
    });

    test('boolLabel: false → ✗', () {
      expect(SubscriptionPlanData.boolLabel(false), '✗');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // ProfileService.parseSwitcherData — pure transformation (no Supabase)
  // ───────────────────────────────────────────────────────────────────────────

  group('ProfileService.parseSwitcherData — personal wallet', () {
    final svc = ProfileService.instance;

    test('extracts personal wallet id', () {
      final result = svc.parseSwitcherData(_switcherRow(personalWalletId: 'pw-abc'));
      expect(result.personal.id, 'pw-abc');
    });

    test('personal wallet uses profile emoji', () {
      final result = svc.parseSwitcherData(_switcherRow(emoji: '🧑'));
      expect(result.personal.emoji, '🧑');
    });

    test('personal wallet isPersonal flag is true', () {
      final result = svc.parseSwitcherData(_switcherRow());
      expect(result.personal.isPersonal, isTrue);
    });

    test('personal wallet name is always "Personal"', () {
      final result = svc.parseSwitcherData(_switcherRow());
      expect(result.personal.name, 'Personal');
    });

    test('cash and online balances are mapped correctly', () {
      final result = svc.parseSwitcherData(_switcherRow(
        cashIn: 10000, cashOut: 4000,
        onlineIn: 5000, onlineOut: 2000,
      ));
      final w = result.personal;
      expect(w.cashIn, 10000);
      expect(w.cashOut, 4000);
      expect(w.onlineIn, 5000);
      expect(w.onlineOut, 2000);
    });

    test('null numeric fields default to 0', () {
      final row = {
        'personal_wallet_id': 'pw-1',
        'emoji': '👤',
        'cash_in': null,
        'cash_out': null,
        'online_in': null,
        'online_out': null,
        'families': <dynamic>[],
      };
      final result = svc.parseSwitcherData(row);
      expect(result.personal.cashIn, 0);
      expect(result.personal.onlineOut, 0);
    });

    test('null emoji defaults to 👤', () {
      final row = {
        'personal_wallet_id': 'pw-1',
        'emoji': null,
        'families': <dynamic>[],
      };
      final result = svc.parseSwitcherData(row);
      expect(result.personal.emoji, '👤');
    });
  });

  group('ProfileService.parseSwitcherData — families', () {
    final svc = ProfileService.instance;

    test('empty families list returns no families or family wallets', () {
      final result = svc.parseSwitcherData(_switcherRow(families: []));
      expect(result.families, isEmpty);
      expect(result.familyWallets, isEmpty);
    });

    test('single family is parsed correctly', () {
      final result = svc.parseSwitcherData(_switcherRow(
        families: [
          _familyRow(familyId: 'fam-1', name: 'Kumar Family', walletId: 'fw-1'),
        ],
      ));
      expect(result.families.length, 1);
      expect(result.families.first.id, 'fam-1');
      expect(result.families.first.name, 'Kumar Family');
    });

    test('multiple families are all parsed', () {
      final result = svc.parseSwitcherData(_switcherRow(
        families: [
          _familyRow(familyId: 'fam-1', name: 'Kumar Family'),
          _familyRow(familyId: 'fam-2', name: 'Office Group', walletId: 'fw-2'),
        ],
      ));
      expect(result.families.length, 2);
      expect(result.families.map((f) => f.id), containsAll(['fam-1', 'fam-2']));
    });

    test('family wallet created when wallet_id present', () {
      final result = svc.parseSwitcherData(_switcherRow(
        families: [_familyRow(walletId: 'fw-99')],
      ));
      expect(result.familyWallets.length, 1);
      expect(result.familyWallets.first.id, 'fw-99');
      expect(result.familyWallets.first.isPersonal, isFalse);
    });

    test('no family wallet created when wallet_id is null', () {
      final result = svc.parseSwitcherData(_switcherRow(
        families: [_familyRow(walletId: null)],
      ));
      expect(result.familyWallets, isEmpty);
    });

    test('family wallet uses family name and emoji', () {
      final result = svc.parseSwitcherData(_switcherRow(
        families: [
          _familyRow(name: 'Work Crew', familyEmoji: '💼', walletId: 'fw-1'),
        ],
      ));
      final fw = result.familyWallets.first;
      expect(fw.name, 'Work Crew');
      expect(fw.emoji, '💼');
    });

    test('permission fields are parsed', () {
      final row = _switcherRow(families: [
        {
          ..._familyRow(),
          'perm_invite': 'any_member',
          'perm_edit': 'admin_only',
          'perm_delete': 'any_member',
        },
      ]);
      final result = svc.parseSwitcherData(row);
      final fam = result.families.first;
      expect(fam.permInvite, 'any_member');
      expect(fam.permEdit, 'admin_only');
      expect(fam.permDelete, 'any_member');
    });

    test('missing perm fields default to safe values', () {
      final row = _switcherRow(families: [
        {
          'family_id': 'f1',
          'name': 'Test',
          'emoji': '👥',
          'color_index': 0,
          'wallet_id': null,
          'my_role': 'member',
          'members': <dynamic>[],
          // no perm fields
        },
      ]);
      final result = svc.parseSwitcherData(row);
      final fam = result.families.first;
      expect(fam.permInvite, 'admin_only');
      expect(fam.permEdit, 'any_member');
      expect(fam.permDelete, 'admin_only');
    });
  });

  group('ProfileService.parseSwitcherData — member roles', () {
    final svc = ProfileService.instance;

    test('"admin" role parses to MemberRole.admin', () {
      final result = svc.parseSwitcherData(_switcherRow(
        families: [
          _familyRow(members: [_memberRow(role: 'admin')]),
        ],
      ));
      expect(result.families.first.members.first.role, MemberRole.admin);
    });

    test('"member" role parses to MemberRole.member', () {
      final result = svc.parseSwitcherData(_switcherRow(
        families: [
          _familyRow(members: [_memberRow(role: 'member')]),
        ],
      ));
      expect(result.families.first.members.first.role, MemberRole.member);
    });

    test('"viewer" role parses to MemberRole.viewer', () {
      final result = svc.parseSwitcherData(_switcherRow(
        families: [
          _familyRow(members: [_memberRow(role: 'viewer')]),
        ],
      ));
      expect(result.families.first.members.first.role, MemberRole.viewer);
    });

    test('unknown role defaults to MemberRole.member', () {
      final result = svc.parseSwitcherData(_switcherRow(
        families: [
          _familyRow(members: [_memberRow(role: 'superuser')]),
        ],
      ));
      expect(result.families.first.members.first.role, MemberRole.member);
    });

    test('null role defaults to MemberRole.member', () {
      final result = svc.parseSwitcherData(_switcherRow(
        families: [
          _familyRow(members: [_memberRow(role: 'null_role')]),
        ],
      ));
      expect(result.families.first.members.first.role, MemberRole.member);
    });

    test('member name and emoji are set', () {
      final result = svc.parseSwitcherData(_switcherRow(
        families: [
          _familyRow(members: [
            _memberRow(name: 'Kavitha', emoji: '👩‍🦱', relation: 'Wife'),
          ]),
        ],
      ));
      final m = result.families.first.members.first;
      expect(m.name, 'Kavitha');
      expect(m.emoji, '👩‍🦱');
      expect(m.relation, 'Wife');
    });

    test('my_role on family is parsed for admin', () {
      final result = svc.parseSwitcherData(_switcherRow(
        families: [_familyRow(myRole: 'admin')],
      ));
      expect(result.families.first.myRole, MemberRole.admin);
    });

    test('my_role on family is parsed for viewer', () {
      final result = svc.parseSwitcherData(_switcherRow(
        families: [_familyRow(myRole: 'viewer')],
      ));
      expect(result.families.first.myRole, MemberRole.viewer);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // WalletModel computed properties
  // ───────────────────────────────────────────────────────────────────────────

  group('WalletModel computed properties', () {
    WalletModel wallet({
      double cashIn = 0,
      double cashOut = 0,
      double onlineIn = 0,
      double onlineOut = 0,
    }) =>
        WalletModel(
          id: 'w1',
          name: 'Test',
          emoji: '💳',
          isPersonal: true,
          cashIn: cashIn,
          cashOut: cashOut,
          onlineIn: onlineIn,
          onlineOut: onlineOut,
          gradient: const [],
        );

    test('totalIn = cashIn + onlineIn', () {
      expect(wallet(cashIn: 5000, onlineIn: 3000).totalIn, 8000);
    });

    test('totalOut = cashOut + onlineOut', () {
      expect(wallet(cashOut: 2000, onlineOut: 1500).totalOut, 3500);
    });

    test('balance = totalIn - totalOut', () {
      final w = wallet(cashIn: 10000, onlineIn: 5000, cashOut: 3000, onlineOut: 2000);
      expect(w.balance, 10000.0);
    });

    test('balance is negative when spending exceeds income', () {
      final w = wallet(cashIn: 1000, cashOut: 3000);
      expect(w.balance, -2000);
    });

    test('zero wallet has zero balance', () {
      expect(wallet().balance, 0.0);
    });

    test('fractional amounts handled correctly', () {
      final w = wallet(cashIn: 1000.50, cashOut: 500.25);
      expect(w.balance, closeTo(500.25, 0.001));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // FamilyMember.copyWith
  // ───────────────────────────────────────────────────────────────────────────

  group('FamilyMember.copyWith', () {
    final base = FamilyMember(
      id: 'mem-1',
      name: 'Ravi',
      emoji: '👨',
      role: MemberRole.member,
      phone: '9876543210',
      relation: 'Brother',
    );

    test('returns equal values when no overrides', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.name, base.name);
      expect(copy.emoji, base.emoji);
      expect(copy.role, base.role);
      expect(copy.phone, base.phone);
      expect(copy.relation, base.relation);
    });

    test('overrides name only', () {
      final copy = base.copyWith(name: 'Rajesh');
      expect(copy.name, 'Rajesh');
      expect(copy.emoji, base.emoji);
      expect(copy.role, base.role);
    });

    test('overrides role to admin', () {
      final copy = base.copyWith(role: MemberRole.admin);
      expect(copy.role, MemberRole.admin);
      expect(copy.name, base.name);
    });

    test('overrides phone', () {
      final copy = base.copyWith(phone: '1234567890');
      expect(copy.phone, '1234567890');
    });

    test('overrides userId', () {
      final copy = base.copyWith(userId: 'user-uuid-123');
      expect(copy.userId, 'user-uuid-123');
      expect(copy.id, base.id); // id never changes
    });

    test('id is always preserved (not overridable)', () {
      final copy = base.copyWith(name: 'New Name');
      expect(copy.id, 'mem-1');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // MemberRole enum
  // ───────────────────────────────────────────────────────────────────────────

  group('MemberRole enum', () {
    test('admin has crown emoji and "Admin" label', () {
      expect(MemberRole.admin.emoji, '👑');
      expect(MemberRole.admin.label, 'Admin');
    });

    test('member has person emoji and "Member" label', () {
      expect(MemberRole.member.emoji, '👤');
      expect(MemberRole.member.label, 'Member');
    });

    test('viewer has eye emoji and "Viewer" label', () {
      expect(MemberRole.viewer.emoji, '👁️');
      expect(MemberRole.viewer.label, 'Viewer');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TxModel.fromRow
  // ───────────────────────────────────────────────────────────────────────────

  group('TxModel.fromRow', () {
    Map<String, dynamic> txRow({
      String id = 'tx-1',
      String type = 'expense',
      String? payMode = 'cash',
      double amount = 500,
      String category = 'Food',
      String? title,
      String? note,
      String date = '2026-06-30',
      String walletId = 'wallet-1',
      String? person,
      List? persons,
      String? status,
      String? dueDate,
      String? userId,
      String? groupId,
    }) =>
        {
          'id': id,
          'type': type,
          'pay_mode': payMode,
          'amount': amount,
          'category': category,
          'title': title,
          'note': note,
          'date': date,
          'wallet_id': walletId,
          'person': person,
          'persons': persons,
          'status': status,
          'due_date': dueDate,
          'user_id': userId,
          'group_id': groupId,
        };

    test('parses id, type, amount, category', () {
      final tx = TxModel.fromRow(txRow(id: 'tx-99', amount: 1500, category: 'Transport'));
      expect(tx.id, 'tx-99');
      expect(tx.type, TxType.expense);
      expect(tx.amount, 1500);
      expect(tx.category, 'Transport');
    });

    test('all TxType values are parsed', () {
      for (final t in TxType.values) {
        final tx = TxModel.fromRow(txRow(type: t.name));
        expect(tx.type, t, reason: 'type ${t.name} should parse');
      }
    });

    test('unknown type defaults to expense', () {
      final tx = TxModel.fromRow(txRow(type: 'unknown_type'));
      expect(tx.type, TxType.expense);
    });

    test('cash pay mode is parsed', () {
      final tx = TxModel.fromRow(txRow(payMode: 'cash'));
      expect(tx.payMode, PayMode.cash);
    });

    test('online pay mode is parsed', () {
      final tx = TxModel.fromRow(txRow(payMode: 'online'));
      expect(tx.payMode, PayMode.online);
    });

    test('null pay_mode returns null payMode', () {
      final tx = TxModel.fromRow(txRow(payMode: null));
      expect(tx.payMode, isNull);
    });

    test('date is parsed from ISO string', () {
      final tx = TxModel.fromRow(txRow(date: '2026-06-15'));
      expect(tx.date.year, 2026);
      expect(tx.date.month, 6);
      expect(tx.date.day, 15);
    });

    test('invalid date falls back to DateTime.now() (does not throw)', () {
      expect(() => TxModel.fromRow(txRow(date: 'not-a-date')), returnsNormally);
    });

    test('walletId is set', () {
      final tx = TxModel.fromRow(txRow(walletId: 'wlt-xyz'));
      expect(tx.walletId, 'wlt-xyz');
    });

    test('optional fields are null when absent', () {
      final tx = TxModel.fromRow(txRow());
      expect(tx.title, isNull);
      expect(tx.note, isNull);
      expect(tx.person, isNull);
      expect(tx.persons, isNull);
      expect(tx.status, isNull);
      expect(tx.dueDate, isNull);
      expect(tx.userId, isNull);
      expect(tx.groupId, isNull);
    });

    test('persons list is parsed', () {
      final tx = TxModel.fromRow(txRow(persons: ['Ravi', 'Kavitha', 'Priya']));
      expect(tx.persons, ['Ravi', 'Kavitha', 'Priya']);
    });

    test('title, note, person are set when present', () {
      final tx = TxModel.fromRow(txRow(
        title: 'Zomato dinner',
        note: 'Split with family',
        person: 'Ravi',
      ));
      expect(tx.title, 'Zomato dinner');
      expect(tx.note, 'Split with family');
      expect(tx.person, 'Ravi');
    });

    test('groupId is set when present', () {
      final tx = TxModel.fromRow(txRow(groupId: 'grp-123'));
      expect(tx.groupId, 'grp-123');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TxType extensions
  // ───────────────────────────────────────────────────────────────────────────

  group('TxType extensions', () {
    test('income is positive', () {
      expect(TxType.income.isPositive, isTrue);
    });

    test('borrow is positive', () {
      expect(TxType.borrow.isPositive, isTrue);
    });

    test('returned is positive', () {
      expect(TxType.returned.isPositive, isTrue);
    });

    test('expense is not positive', () {
      expect(TxType.expense.isPositive, isFalse);
    });

    test('lend is not positive', () {
      expect(TxType.lend.isPositive, isFalse);
    });

    test('request isPending', () {
      expect(TxType.request.isPending, isTrue);
    });

    test('expense is not pending', () {
      expect(TxType.expense.isPending, isFalse);
    });

    test('all types have non-empty label', () {
      for (final t in TxType.values) {
        expect(t.label, isNotEmpty, reason: '${t.name} should have label');
      }
    });

    test('all types have non-empty emoji', () {
      for (final t in TxType.values) {
        expect(t.emoji, isNotEmpty, reason: '${t.name} should have emoji');
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TxGroup computed properties
  // ───────────────────────────────────────────────────────────────────────────

  group('TxGroup computed properties', () {
    TxModel makeTx(double amount, DateTime date) => TxModel(
          id: 'tx',
          type: TxType.expense,
          amount: amount,
          category: 'Food',
          date: date,
          walletId: 'w1',
        );

    test('total sums all transaction amounts', () {
      final group = TxGroup(
        id: 'g1',
        walletId: 'w1',
        name: 'Trip',
        emoji: '✈️',
        transactions: [
          makeTx(1000, DateTime(2026, 6, 1)),
          makeTx(2500, DateTime(2026, 6, 2)),
          makeTx(750, DateTime(2026, 6, 3)),
        ],
      );
      expect(group.total, 4250);
    });

    test('total is 0 for empty transactions list', () {
      final group = TxGroup(
        id: 'g1', walletId: 'w1', name: 'Empty', emoji: '📦', transactions: [],
      );
      expect(group.total, 0.0);
    });

    test('latestDate returns date of first transaction', () {
      final d1 = DateTime(2026, 6, 30);
      final d2 = DateTime(2026, 6, 1);
      final group = TxGroup(
        id: 'g1', walletId: 'w1', name: 'G', emoji: '📦',
        transactions: [makeTx(100, d1), makeTx(200, d2)],
      );
      expect(group.latestDate, d1);
    });

    test('earliestDate returns date of last transaction', () {
      final d1 = DateTime(2026, 6, 30);
      final d2 = DateTime(2026, 6, 1);
      final group = TxGroup(
        id: 'g1', walletId: 'w1', name: 'G', emoji: '📦',
        transactions: [makeTx(100, d1), makeTx(200, d2)],
      );
      expect(group.earliestDate, d2);
    });

    test('latestDate and earliestDate do not throw for empty list', () {
      final group = TxGroup(
        id: 'g1', walletId: 'w1', name: 'Empty', emoji: '📦', transactions: [],
      );
      expect(() => group.latestDate, returnsNormally);
      expect(() => group.earliestDate, returnsNormally);
    });

    test('withTransactions produces same group with new tx list', () {
      final base = TxGroup(
        id: 'g1', walletId: 'w1', name: 'Trip', emoji: '✈️', transactions: [],
      );
      final txs = [makeTx(500, DateTime(2026, 6, 1))];
      final updated = base.withTransactions(txs);
      expect(updated.id, base.id);
      expect(updated.name, base.name);
      expect(updated.transactions.length, 1);
      expect(updated.total, 500);
    });
  });
}
