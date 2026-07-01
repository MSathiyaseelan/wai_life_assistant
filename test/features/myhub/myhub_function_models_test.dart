import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

MoiEntry makeMoi({
  String id = 'm1',
  String personName = 'Alice',
  double amount = 1000,
  MoiKind kind = MoiKind.newMoi,
  bool returned = false,
  double? returnedAmount,
  DateTime? returnedOn,
}) => MoiEntry(
      id: id,
      personName: personName,
      amount: amount,
      kind: kind,
      returned: returned,
      returnedAmount: returnedAmount,
      returnedOn: returnedOn,
    );

GiftEntry makeGift({
  String id = 'g1',
  String guestName = 'Guest',
  required GiftType giftType,
  double? goldGrams,
  double? silverGrams,
  String? itemDescription,
  String? giftCardValue,
}) => GiftEntry(
      id: id,
      guestName: guestName,
      giftType: giftType,
      goldGrams: goldGrams,
      silverGrams: silverGrams,
      itemDescription: itemDescription,
      giftCardValue: giftCardValue,
    );

FunctionModel makeFunction({
  String id = 'f1',
  String walletId = 'w1',
  FunctionType type = FunctionType.wedding,
  String title = 'Test Wedding',
  List<GiftEntry>? gifts,
  List<MoiEntry>? moi,
  List<FunctionVendor>? vendors,
  DateTime? functionDate,
}) => FunctionModel(
      id: id,
      walletId: walletId,
      type: type,
      title: title,
      gifts: gifts ?? [],
      moi: moi ?? [],
      vendors: vendors ?? [],
      functionDate: functionDate,
    );

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. FunctionType enum — emoji and label
  // ═══════════════════════════════════════════════════════════════════════════
  group('FunctionType — emoji and label', () {
    test('wedding', () {
      expect(FunctionType.wedding.emoji, '💒');
      expect(FunctionType.wedding.label, 'Wedding');
    });
    test('birthday', () {
      expect(FunctionType.birthday.emoji, '🎂');
      expect(FunctionType.birthday.label, 'Birthday');
    });
    test('houseWarming', () {
      expect(FunctionType.houseWarming.emoji, '🏠');
      expect(FunctionType.houseWarming.label, 'Housewarming');
    });
    test('other', () {
      expect(FunctionType.other.emoji, '🎊');
      expect(FunctionType.other.label, 'Others');
    });
    test('all 10 values have non-empty emoji and label', () {
      expect(FunctionType.values.length, 10);
      for (final ft in FunctionType.values) {
        expect(ft.emoji, isNotEmpty, reason: ft.name);
        expect(ft.label, isNotEmpty, reason: ft.name);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. GiftType enum — emoji and label
  // ═══════════════════════════════════════════════════════════════════════════
  group('GiftType — emoji and label', () {
    test('gold', () { expect(GiftType.gold.emoji, '🥇'); expect(GiftType.gold.label, 'Gold'); });
    test('silver', () { expect(GiftType.silver.emoji, '🥈'); expect(GiftType.silver.label, 'Silver'); });
    test('giftCard', () { expect(GiftType.giftCard.emoji, '🎴'); expect(GiftType.giftCard.label, 'Gift Card'); });
    test('other', () { expect(GiftType.other.emoji, '✨'); expect(GiftType.other.label, 'Others'); });
    test('all 7 values have non-empty emoji and label', () {
      expect(GiftType.values.length, 7);
      for (final gt in GiftType.values) {
        expect(gt.emoji, isNotEmpty, reason: gt.name);
        expect(gt.label, isNotEmpty, reason: gt.name);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. MoiKind / BridalStatus enum
  // ═══════════════════════════════════════════════════════════════════════════
  group('MoiKind enum', () {
    test('newMoi label', () => expect(MoiKind.newMoi.label, 'New Moi'));
    test('returnMoi label', () => expect(MoiKind.returnMoi.label, 'Return Moi'));
    test('newMoi emoji', () => expect(MoiKind.newMoi.emoji, '🆕'));
    test('returnMoi emoji', () => expect(MoiKind.returnMoi.emoji, '🔁'));
  });

  group('BridalStatus enum', () {
    test('pending label', () => expect(BridalStatus.pending.label, 'Pending'));
    test('booked emoji', () => expect(BridalStatus.booked.emoji, '📋'));
    test('done emoji', () => expect(BridalStatus.done.emoji, '✅'));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. PlannedGiftItem — fromJson / toJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('PlannedGiftItem.fromJson', () {
    test('category and notes parsed', () {
      final item = PlannedGiftItem.fromJson({'category': 'Cash', 'notes': '₹5000'});
      expect(item.category, 'Cash');
      expect(item.notes, '₹5000');
    });

    test('missing category → empty string', () {
      final item = PlannedGiftItem.fromJson({'notes': 'something'});
      expect(item.category, '');
    });

    test('missing notes → null', () {
      final item = PlannedGiftItem.fromJson({'category': 'Gold'});
      expect(item.notes, isNull);
    });
  });

  group('PlannedGiftItem.toJson', () {
    test('notes present → included in map', () {
      final item = PlannedGiftItem(category: 'Cash', notes: '₹5000');
      final j = item.toJson();
      expect(j['category'], 'Cash');
      expect(j['notes'], '₹5000');
    });

    test('notes null → key absent from map', () {
      final item = PlannedGiftItem(category: 'Gold');
      expect(item.toJson().containsKey('notes'), isFalse);
    });

    test('round-trip fromJson → toJson', () {
      final orig = PlannedGiftItem(category: 'Gold', notes: 'Wedding gift');
      final back = PlannedGiftItem.fromJson(orig.toJson());
      expect(back.category, orig.category);
      expect(back.notes, orig.notes);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. GiftEntry.summary — all branches
  //    GiftEntry.summary uses AppPrefs.cs which defaults to '₹' when
  //    SharedPreferences is not initialised.
  // ═══════════════════════════════════════════════════════════════════════════
  group('GiftEntry.summary — gold', () {
    test('gold with grams → "Xg Gold" (double format)', () {
      final entry = makeGift(giftType: GiftType.gold, goldGrams: 8.0);
      expect(entry.summary, '8.0g Gold');
    });

    test('gold without grams → "Gold"', () {
      final entry = makeGift(giftType: GiftType.gold);
      expect(entry.summary, 'Gold');
    });

    test('gold 10.0g → "10.0g Gold"', () {
      expect(makeGift(giftType: GiftType.gold, goldGrams: 10.0).summary, '10.0g Gold');
    });
  });

  group('GiftEntry.summary — silver', () {
    test('silver with grams → "Xg Silver"', () {
      expect(makeGift(giftType: GiftType.silver, silverGrams: 50.0).summary, '50.0g Silver');
    });

    test('silver without grams → "Silver"', () {
      expect(makeGift(giftType: GiftType.silver).summary, 'Silver');
    });
  });

  group('GiftEntry.summary — giftCard', () {
    test('giftCard with value → "₹5000 Card" (AppPrefs.cs = ₹ by default)', () {
      expect(makeGift(giftType: GiftType.giftCard, giftCardValue: '5000').summary, '₹5000 Card');
    });

    test('giftCard without value → "Gift Card" (label fallback)', () {
      expect(makeGift(giftType: GiftType.giftCard).summary, 'Gift Card');
    });
  });

  group('GiftEntry.summary — default (other types)', () {
    test('giftItem with itemDescription → description returned', () {
      final entry = makeGift(giftType: GiftType.giftItem, itemDescription: 'Microwave Oven');
      expect(entry.summary, 'Microwave Oven');
    });

    test('giftItem without description → giftType.label ("Gift Item")', () {
      expect(makeGift(giftType: GiftType.giftItem).summary, 'Gift Item');
    });

    test('household with description → description', () {
      expect(makeGift(giftType: GiftType.household, itemDescription: 'Mixer').summary, 'Mixer');
    });

    test('clothing without description → "Clothing" (label)', () {
      expect(makeGift(giftType: GiftType.clothing).summary, 'Clothing');
    });

    test('other without description → "Others" (label)', () {
      expect(makeGift(giftType: GiftType.other).summary, 'Others');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. GiftedItem.giftSummary
  // ═══════════════════════════════════════════════════════════════════════════
  group('GiftedItem.giftSummary', () {
    GiftedItem makeGifted({required GiftType giftType, double? goldGrams, double? silverGrams}) =>
        GiftedItem(
          id: 'gi1',
          walletId: 'w1',
          toName: 'Person',
          functionTitle: 'Wedding',
          memberId: 'me',
          functionType: FunctionType.wedding,
          giftType: giftType,
          goldGrams: goldGrams,
          silverGrams: silverGrams,
        );

    test('gold with grams → "Xg Gold"', () => expect(makeGifted(giftType: GiftType.gold, goldGrams: 4.0).giftSummary, '4.0g Gold'));
    test('gold without grams → "Gold"', () => expect(makeGifted(giftType: GiftType.gold).giftSummary, 'Gold'));
    test('silver with grams → "Xg Silver"', () => expect(makeGifted(giftType: GiftType.silver, silverGrams: 20.0).giftSummary, '20.0g Silver'));
    test('silver without grams → "Silver"', () => expect(makeGifted(giftType: GiftType.silver).giftSummary, 'Silver'));
    test('default (giftItem) → giftType.label', () => expect(makeGifted(giftType: GiftType.giftItem).giftSummary, 'Gift Item'));
    test('giftCard default → "Gift Card" (no special case in GiftedItem)', () => expect(makeGifted(giftType: GiftType.giftCard).giftSummary, 'Gift Card'));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. FunctionVendor.balance
  // ═══════════════════════════════════════════════════════════════════════════
  group('FunctionVendor.balance', () {
    FunctionVendor vendor({double? total, double? advance}) => FunctionVendor(
          id: 'v1',
          name: 'Caterer',
          category: VendorCategory.catering,
          totalCost: total,
          advancePaid: advance,
        );

    test('both null → 0.0', () => expect(vendor().balance, 0.0));
    test('totalCost only → balance = totalCost', () => expect(vendor(total: 180000).balance, 180000.0));
    test('advance only → balance = -advance', () => expect(vendor(advance: 50000).balance, -50000.0));
    test('partial advance → remainder', () => expect(vendor(total: 180000, advance: 50000).balance, 130000.0));
    test('fully paid → 0.0', () => expect(vendor(total: 150000, advance: 150000).balance, 0.0));
    test('overpaid → negative balance', () => expect(vendor(total: 100000, advance: 120000).balance, -20000.0));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. MoiEntry — fromJson / toJson / toDraftJson / fromDraftJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('MoiEntry.fromJson — field parsing', () {
    final fullJson = {
      'id': 'm1',
      'person_name': 'Selvam',
      'family_name': 'Chettiar Family',
      'place': 'Coimbatore',
      'phone': '9876543210',
      'relation': 'Friend',
      'amount': 5000,
      'kind': 'newMoi',
      'returned': false,
      'returned_amount': null,
      'returned_on': null,
      'returned_for_function': null,
      'notes': 'Wedding gift',
    };

    test('all fields parsed', () {
      final entry = MoiEntry.fromJson(fullJson);
      expect(entry.id, 'm1');
      expect(entry.personName, 'Selvam');
      expect(entry.familyName, 'Chettiar Family');
      expect(entry.place, 'Coimbatore');
      expect(entry.phone, '9876543210');
      expect(entry.relation, 'Friend');
      expect(entry.amount, 5000.0);
      expect(entry.kind, MoiKind.newMoi);
      expect(entry.returned, isFalse);
      expect(entry.returnedAmount, isNull);
      expect(entry.returnedOn, isNull);
      expect(entry.notes, 'Wedding gift');
    });

    test('amount as int → converted to double', () {
      final entry = MoiEntry.fromJson({...fullJson, 'amount': 3000});
      expect(entry.amount, 3000.0);
      expect(entry.amount, isA<double>());
    });

    test('returned_amount as num → toDouble', () {
      final entry = MoiEntry.fromJson({...fullJson, 'returned': true, 'returned_amount': 3000});
      expect(entry.returnedAmount, 3000.0);
    });

    test('returned_on parsed as DateTime', () {
      final entry = MoiEntry.fromJson({...fullJson, 'returned_on': '2025-04-10'});
      expect(entry.returnedOn, DateTime(2025, 4, 10));
    });
  });

  group('MoiEntry.fromJson — kind parsing', () {
    test('"returnMoi" → MoiKind.returnMoi', () {
      final entry = MoiEntry.fromJson({
        'id': 'm1', 'person_name': 'A', 'amount': 1000, 'kind': 'returnMoi', 'returned': false,
      });
      expect(entry.kind, MoiKind.returnMoi);
    });

    test('"newMoi" → MoiKind.newMoi', () {
      final entry = MoiEntry.fromJson({
        'id': 'm1', 'person_name': 'A', 'amount': 1000, 'kind': 'newMoi', 'returned': false,
      });
      expect(entry.kind, MoiKind.newMoi);
    });

    test('any other string → MoiKind.newMoi (else branch)', () {
      final entry = MoiEntry.fromJson({
        'id': 'm1', 'person_name': 'A', 'amount': 1000, 'kind': 'unknown', 'returned': false,
      });
      expect(entry.kind, MoiKind.newMoi);
    });

    test('missing returned → defaults to false', () {
      final entry = MoiEntry.fromJson({
        'id': 'm1', 'person_name': 'A', 'amount': 1000, 'kind': 'newMoi',
      });
      expect(entry.returned, isFalse);
    });
  });

  group('MoiEntry.toJson — always serialises all fields (including null)', () {
    test('all non-null fields present', () {
      final entry = MoiEntry(
        id: 'm1',
        personName: 'Selvam',
        familyName: 'Chettiar',
        place: 'Coimbatore',
        phone: '9876543210',
        relation: 'Friend',
        amount: 5000,
        kind: MoiKind.newMoi,
        returned: true,
        returnedAmount: 5000,
        returnedOn: DateTime(2025, 4, 10),
        returnedForFunction: 'Arjun Wedding',
        notes: 'Prompt return',
      );
      final j = entry.toJson();
      expect(j['person_name'], 'Selvam');
      expect(j['family_name'], 'Chettiar');
      expect(j['amount'], 5000);
      expect(j['kind'], 'newMoi');
      expect(j['returned'], isTrue);
      expect(j['returned_amount'], 5000);
      expect(j['returned_on'], '2025-04-10');
      expect(j['returned_for_function'], 'Arjun Wedding');
      expect(j['notes'], 'Prompt return');
    });

    test('null optional fields included as null (not omitted)', () {
      final entry = makeMoi();
      final j = entry.toJson();
      expect(j.containsKey('family_name'), isTrue);
      expect(j['family_name'], isNull);
      expect(j.containsKey('returned_amount'), isTrue);
      expect(j['returned_amount'], isNull);
    });

    test('kind serialised as enum name string', () {
      expect(makeMoi(kind: MoiKind.returnMoi).toJson()['kind'], 'returnMoi');
      expect(makeMoi(kind: MoiKind.newMoi).toJson()['kind'], 'newMoi');
    });

    test('returnedOn formatted as YYYY-MM-DD', () {
      final entry = makeMoi(returned: true, returnedOn: DateTime(2025, 8, 5));
      expect(entry.toJson()['returned_on'], '2025-08-05');
    });
  });

  group('MoiEntry — toDraftJson / fromDraftJson', () {
    test('toDraftJson includes id (not in toJson)', () {
      final entry = makeMoi(id: 'draft-123');
      final j = entry.toDraftJson();
      expect(j['id'], 'draft-123');
    });

    test('toDraftJson includes all toJson fields', () {
      final entry = makeMoi(id: 'd1', personName: 'Alice', amount: 2000);
      final j = entry.toDraftJson();
      expect(j['person_name'], 'Alice');
      expect(j['amount'], 2000);
    });

    test('fromDraftJson sets isDraft = true', () {
      final entry = makeMoi(id: 'd1');
      final draft = MoiEntry.fromDraftJson(entry.toDraftJson());
      expect(draft.isDraft, isTrue);
    });

    test('fromJson sets isDraft = false (default)', () {
      final entry = MoiEntry.fromJson({
        'id': 'm1', 'person_name': 'A', 'amount': 1000, 'kind': 'newMoi', 'returned': false,
      });
      expect(entry.isDraft, isFalse);
    });

    test('round-trip toDraftJson → fromDraftJson preserves data', () {
      final orig = MoiEntry(
        id: 'd1', personName: 'Bob', familyName: 'Smith',
        amount: 3000, kind: MoiKind.returnMoi, returned: true,
        returnedAmount: 3000, returnedOn: DateTime(2025, 1, 15),
      );
      final back = MoiEntry.fromDraftJson(orig.toDraftJson());
      expect(back.id, orig.id);
      expect(back.personName, orig.personName);
      expect(back.familyName, orig.familyName);
      expect(back.amount, orig.amount);
      expect(back.kind, orig.kind);
      expect(back.returned, orig.returned);
      expect(back.returnedAmount, orig.returnedAmount);
      expect(back.returnedOn, orig.returnedOn);
      expect(back.isDraft, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. FunctionModel.fromJson — field mapping
  // ═══════════════════════════════════════════════════════════════════════════
  group('FunctionModel.fromJson — field parsing', () {
    final fullJson = {
      'id': 'f1',
      'wallet_id': 'w1',
      'type': 'wedding',
      'title': 'Arjun Wedding',
      'who_function': 'Son - Arjun',
      'custom_type': null,
      'function_date': '2025-03-12',
      'venue': 'Grand Palace Hall',
      'address': 'Anna Nagar, Chennai',
      'notes': 'Full vegetarian',
      'is_planned': true,
      'icon': '💒',
    };

    test('all scalar fields parsed', () {
      final fm = FunctionModel.fromJson(fullJson);
      expect(fm.id, 'f1');
      expect(fm.walletId, 'w1');
      expect(fm.type, FunctionType.wedding);
      expect(fm.title, 'Arjun Wedding');
      expect(fm.whoFunction, 'Son - Arjun');
      expect(fm.customType, isNull);
      expect(fm.functionDate, DateTime(2025, 3, 12));
      expect(fm.venue, 'Grand Palace Hall');
      expect(fm.address, 'Anna Nagar, Chennai');
      expect(fm.notes, 'Full vegetarian');
      expect(fm.isPlanned, isTrue);
      expect(fm.icon, '💒');
    });

    test('unknown type → FunctionType.other', () {
      final fm = FunctionModel.fromJson({...fullJson, 'type': 'unknownCeremony'});
      expect(fm.type, FunctionType.other);
    });

    test('all valid type strings parse correctly', () {
      for (final ft in FunctionType.values) {
        final fm = FunctionModel.fromJson({...fullJson, 'type': ft.name});
        expect(fm.type, ft, reason: ft.name);
      }
    });

    test('missing title → empty string', () {
      final fm = FunctionModel.fromJson({...fullJson}..remove('title'));
      expect(fm.title, '');
    });

    test('missing who_function → empty string', () {
      final fm = FunctionModel.fromJson({...fullJson}..remove('who_function'));
      expect(fm.whoFunction, '');
    });

    test('missing is_planned → false', () {
      final fm = FunctionModel.fromJson({...fullJson}..remove('is_planned'));
      expect(fm.isPlanned, isFalse);
    });

    test('missing icon → "🎊" default', () {
      final fm = FunctionModel.fromJson({...fullJson}..remove('icon'));
      expect(fm.icon, '🎊');
    });

    test('null function_date → functionDate is null', () {
      final fm = FunctionModel.fromJson({...fullJson, 'function_date': null});
      expect(fm.functionDate, isNull);
    });
  });

  group('FunctionModel.fromJson — list fields are NOT parsed from JSON', () {
    // gifts, moi, vendors, chat, memberIds come from separate DB tables
    // and are never populated by fromJson.
    final json = {
      'id': 'f1', 'wallet_id': 'w1', 'type': 'wedding',
      'title': 'Test', 'is_planned': false, 'icon': '🎊',
    };

    test('gifts always empty after fromJson', () => expect(FunctionModel.fromJson(json).gifts, isEmpty));
    test('moi always empty after fromJson', () => expect(FunctionModel.fromJson(json).moi, isEmpty));
    test('vendors always empty after fromJson', () => expect(FunctionModel.fromJson(json).vendors, isEmpty));
    test('chat always empty after fromJson', () => expect(FunctionModel.fromJson(json).chat, isEmpty));
    test('memberIds defaults to ["me"] after fromJson',
        () => expect(FunctionModel.fromJson(json).memberIds, ['me']));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. FunctionModel.toJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('FunctionModel.toJson', () {
    test('scalar fields serialised', () {
      final fm = makeFunction(
        id: 'f1', walletId: 'w1', type: FunctionType.birthday, title: 'Party',
        functionDate: DateTime(2025, 6, 15),
      );
      final j = fm.toJson();
      expect(j['wallet_id'], 'w1');
      expect(j['type'], 'birthday');
      expect(j['title'], 'Party');
      expect(j['is_planned'], isFalse);
      expect(j['function_date'], '2025-06-15');
    });

    test('null optional fields omitted (venue, address, notes, customType, functionDate)', () {
      final fm = makeFunction();
      final j = fm.toJson();
      expect(j.containsKey('venue'), isFalse);
      expect(j.containsKey('address'), isFalse);
      expect(j.containsKey('notes'), isFalse);
      expect(j.containsKey('custom_type'), isFalse);
      expect(j.containsKey('function_date'), isFalse);
    });

    test('id is NOT included in toJson', () {
      expect(makeFunction().toJson().containsKey('id'), isFalse);
    });

    test('functionDate formatted as YYYY-MM-DD', () {
      final fm = makeFunction(functionDate: DateTime(2025, 12, 1));
      expect(fm.toJson()['function_date'], '2025-12-01');
    });

    test('type serialised as enum name', () {
      expect(makeFunction(type: FunctionType.graduation).toJson()['type'], 'graduation');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 11. FunctionModel — computed totals
  // ═══════════════════════════════════════════════════════════════════════════
  group('FunctionModel.totalCash / totalMoiReceived', () {
    test('empty moi → 0.0', () {
      expect(makeFunction().totalCash, 0.0);
      expect(makeFunction().totalMoiReceived, 0.0);
    });

    test('sums all moi amounts regardless of returned status', () {
      final fm = makeFunction(moi: [
        makeMoi(amount: 5000, returned: false),
        makeMoi(id: 'm2', amount: 3000, returned: true),
        makeMoi(id: 'm3', amount: 10000, returned: false),
      ]);
      expect(fm.totalCash, 18000.0);
      expect(fm.totalMoiReceived, 18000.0); // identical getter
    });

    test('totalCash and totalMoiReceived always equal', () {
      final fm = makeFunction(moi: [makeMoi(amount: 7777)]);
      expect(fm.totalCash, fm.totalMoiReceived);
    });
  });

  group('FunctionModel.totalGold', () {
    test('empty gifts → 0.0', () => expect(makeFunction().totalGold, 0.0));

    test('only gold entries counted', () {
      final fm = makeFunction(gifts: [
        makeGift(giftType: GiftType.gold, goldGrams: 8.0),
        makeGift(id: 'g2', giftType: GiftType.gold, goldGrams: 10.0),
        makeGift(id: 'g3', giftType: GiftType.silver, silverGrams: 50.0),
        makeGift(id: 'g4', giftType: GiftType.giftItem),
      ]);
      expect(fm.totalGold, 18.0);
    });

    test('gold entry with null goldGrams contributes 0', () {
      final fm = makeFunction(gifts: [makeGift(giftType: GiftType.gold)]);
      expect(fm.totalGold, 0.0);
    });
  });

  group('FunctionModel.totalSilver', () {
    test('empty gifts → 0.0', () => expect(makeFunction().totalSilver, 0.0));

    test('only silver entries counted', () {
      final fm = makeFunction(gifts: [
        makeGift(giftType: GiftType.gold, goldGrams: 8.0),
        makeGift(id: 'g2', giftType: GiftType.silver, silverGrams: 50.0),
        makeGift(id: 'g3', giftType: GiftType.silver, silverGrams: 30.0),
      ]);
      expect(fm.totalSilver, 80.0);
    });
  });

  group('FunctionModel.totalMoiReturned', () {
    test('no returned entries → 0.0', () {
      final fm = makeFunction(moi: [
        makeMoi(amount: 5000, returned: false),
        makeMoi(id: 'm2', amount: 3000, returned: false),
      ]);
      expect(fm.totalMoiReturned, 0.0);
    });

    test('uses returnedAmount when set', () {
      final fm = makeFunction(moi: [
        makeMoi(amount: 3000, returned: true, returnedAmount: 3000),
      ]);
      expect(fm.totalMoiReturned, 3000.0);
    });

    test('falls back to amount when returnedAmount is null', () {
      final fm = makeFunction(moi: [
        makeMoi(amount: 2000, returned: true, returnedAmount: null),
      ]);
      expect(fm.totalMoiReturned, 2000.0);
    });

    test('sums only returned entries', () {
      final fm = makeFunction(moi: [
        makeMoi(id: 'm1', amount: 5000, returned: false),
        makeMoi(id: 'm2', amount: 3000, returned: true, returnedAmount: 3000),
        makeMoi(id: 'm3', amount: 2000, returned: true), // returnedAmount null → uses amount
      ]);
      expect(fm.totalMoiReturned, 5000.0); // 3000 + 2000
    });
  });

  group('FunctionModel.moiPending', () {
    test('empty moi → 0', () => expect(makeFunction().moiPending, 0));

    test('all not returned → all pending', () {
      final fm = makeFunction(moi: [
        makeMoi(returned: false),
        makeMoi(id: 'm2', returned: false),
      ]);
      expect(fm.moiPending, 2);
    });

    test('mix of returned / not returned', () {
      final fm = makeFunction(moi: [
        makeMoi(id: 'm1', returned: false),
        makeMoi(id: 'm2', returned: true),
        makeMoi(id: 'm3', returned: false),
        makeMoi(id: 'm4', returned: true),
      ]);
      expect(fm.moiPending, 2);
    });

    test('all returned → 0 pending', () {
      final fm = makeFunction(moi: [
        makeMoi(returned: true),
        makeMoi(id: 'm2', returned: true),
      ]);
      expect(fm.moiPending, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 12. FunctionParticipant — fromJson / toJson / totalCount
  // ═══════════════════════════════════════════════════════════════════════════
  group('FunctionParticipant.totalCount', () {
    test('no family members → 1 (self)', () {
      final p = FunctionParticipant(id: 'p1', functionId: 'f1', name: 'Ravi');
      expect(p.totalCount, 1);
    });

    test('3 family members → 4 (self + 3)', () {
      final p = FunctionParticipant(
        id: 'p1', functionId: 'f1', name: 'Ravi',
        familyMembers: [
          ParticipantFamilyMember(name: 'Wife', relation: 'Spouse'),
          ParticipantFamilyMember(name: 'Son', relation: 'Child'),
          ParticipantFamilyMember(name: 'Daughter', relation: 'Child'),
        ],
      );
      expect(p.totalCount, 4);
    });
  });

  group('FunctionParticipant.fromJson', () {
    test('all fields parsed', () {
      final j = {
        'id': 'p1',
        'function_id': 'f1',
        'name': 'Ravi Kumar',
        'place': 'Chennai',
        'relation': 'Friend',
        'phone': '9876543210',
        'family_members': [
          {'name': 'Priya', 'relation': 'Spouse'},
        ],
      };
      final p = FunctionParticipant.fromJson(j);
      expect(p.id, 'p1');
      expect(p.functionId, 'f1');
      expect(p.name, 'Ravi Kumar');
      expect(p.place, 'Chennai');
      expect(p.relation, 'Friend');
      expect(p.phone, '9876543210');
      expect(p.familyMembers.length, 1);
      expect(p.familyMembers.first.name, 'Priya');
      expect(p.familyMembers.first.relation, 'Spouse');
    });

    test('missing family_members → empty list', () {
      final p = FunctionParticipant.fromJson({
        'id': 'p1', 'function_id': 'f1', 'name': 'Ravi',
      });
      expect(p.familyMembers, isEmpty);
    });
  });

  group('FunctionParticipant.toJson', () {
    test('toJson includes functionId, name, familyMembers', () {
      final p = FunctionParticipant(
        id: 'p1', functionId: 'f1', name: 'Ravi',
        place: 'Chennai', relation: 'Friend',
        familyMembers: [ParticipantFamilyMember(name: 'Priya', relation: 'Spouse')],
      );
      final j = p.toJson();
      expect(j['function_id'], 'f1');
      expect(j['name'], 'Ravi');
      expect(j['place'], 'Chennai');
      expect((j['family_members'] as List).length, 1);
    });

    test('id NOT included in toJson', () {
      expect(FunctionParticipant(id: 'p1', functionId: 'f1', name: 'Ravi').toJson().containsKey('id'), isFalse);
    });

    test('null optional fields omitted', () {
      final j = FunctionParticipant(id: 'p1', functionId: 'f1', name: 'Ravi').toJson();
      expect(j.containsKey('place'), isFalse);
      expect(j.containsKey('relation'), isFalse);
      expect(j.containsKey('phone'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 13. ParticipantFamilyMember — fromJson / toJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('ParticipantFamilyMember.fromJson / toJson', () {
    test('fromJson parses name and relation', () {
      final m = ParticipantFamilyMember.fromJson({'name': 'Priya', 'relation': 'Spouse'});
      expect(m.name, 'Priya');
      expect(m.relation, 'Spouse');
    });

    test('missing name → empty string', () {
      expect(ParticipantFamilyMember.fromJson({'relation': 'Child'}).name, '');
    });

    test('toJson round-trip', () {
      final orig = ParticipantFamilyMember(name: 'Anbu', relation: 'Uncle');
      final back = ParticipantFamilyMember.fromJson(orig.toJson());
      expect(back.name, orig.name);
      expect(back.relation, orig.relation);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 14. ClothingMember — fromJson / toJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('ClothingMember.fromJson', () {
    test('all fields parsed', () {
      final m = ClothingMember.fromJson({
        'name': 'Arjun',
        'gender': 'men',
        'dress_type': 'Veshti',
        'size': 'L',
        'brand': 'Pothys',
        'budget': 5000.0,
        'purchased': true,
      });
      expect(m.name, 'Arjun');
      expect(m.gender, FunctionClothingGender.men);
      expect(m.dressType, 'Veshti');
      expect(m.size, 'L');
      expect(m.brand, 'Pothys');
      expect(m.budget, 5000.0);
      expect(m.purchased, isTrue);
    });

    test('budget as int → toDouble', () {
      final m = ClothingMember.fromJson({'name': 'X', 'gender': 'women', 'budget': 3000, 'purchased': false});
      expect(m.budget, 3000.0);
    });

    test('unknown gender → FunctionClothingGender.men (fallback)', () {
      final m = ClothingMember.fromJson({'name': 'X', 'gender': 'unknown', 'purchased': false});
      expect(m.gender, FunctionClothingGender.men);
    });

    test('missing purchased → false', () {
      final m = ClothingMember.fromJson({'name': 'X', 'gender': 'girl'});
      expect(m.purchased, isFalse);
    });

    test('all valid genders parse correctly', () {
      for (final g in FunctionClothingGender.values) {
        final m = ClothingMember.fromJson({'name': 'X', 'gender': g.name, 'purchased': false});
        expect(m.gender, g, reason: g.name);
      }
    });
  });

  group('ClothingMember.toJson', () {
    test('null optional fields omitted', () {
      final m = ClothingMember(name: 'X', gender: FunctionClothingGender.boy);
      final j = m.toJson();
      expect(j.containsKey('dress_type'), isFalse);
      expect(j.containsKey('size'), isFalse);
      expect(j.containsKey('brand'), isFalse);
      expect(j.containsKey('budget'), isFalse);
    });

    test('gender serialised as enum name', () {
      expect(ClothingMember(name: 'X', gender: FunctionClothingGender.infant).toJson()['gender'], 'infant');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 15. ClothingFamily — fromJson / toJson / totalBudget / purchasedCount
  // ═══════════════════════════════════════════════════════════════════════════
  group('ClothingFamily.totalBudget', () {
    ClothingFamily makeFamily(List<ClothingMember> members) =>
        ClothingFamily(id: 'cf1', functionId: 'f1', familyName: 'Kumar', members: members);

    test('empty members → 0.0', () => expect(makeFamily([]).totalBudget, 0.0));

    test('sums all member budgets', () {
      final fam = makeFamily([
        ClothingMember(name: 'A', gender: FunctionClothingGender.men, budget: 5000),
        ClothingMember(name: 'B', gender: FunctionClothingGender.women, budget: 3000),
        ClothingMember(name: 'C', gender: FunctionClothingGender.boy, budget: 2000),
      ]);
      expect(fam.totalBudget, 10000.0);
    });

    test('null budget contributes 0', () {
      final fam = makeFamily([
        ClothingMember(name: 'A', gender: FunctionClothingGender.men, budget: 5000),
        ClothingMember(name: 'B', gender: FunctionClothingGender.women), // budget null
      ]);
      expect(fam.totalBudget, 5000.0);
    });
  });

  group('ClothingFamily.purchasedCount', () {
    ClothingFamily makeFamily(List<ClothingMember> members) =>
        ClothingFamily(id: 'cf1', functionId: 'f1', familyName: 'Kumar', members: members);

    test('no purchased → 0', () {
      final fam = makeFamily([
        ClothingMember(name: 'A', gender: FunctionClothingGender.men, purchased: false),
        ClothingMember(name: 'B', gender: FunctionClothingGender.women, purchased: false),
      ]);
      expect(fam.purchasedCount, 0);
    });

    test('some purchased', () {
      final fam = makeFamily([
        ClothingMember(name: 'A', gender: FunctionClothingGender.men, purchased: true),
        ClothingMember(name: 'B', gender: FunctionClothingGender.women, purchased: false),
        ClothingMember(name: 'C', gender: FunctionClothingGender.girl, purchased: true),
      ]);
      expect(fam.purchasedCount, 2);
    });

    test('all purchased → full count', () {
      final fam = makeFamily([
        ClothingMember(name: 'A', gender: FunctionClothingGender.men, purchased: true),
        ClothingMember(name: 'B', gender: FunctionClothingGender.women, purchased: true),
      ]);
      expect(fam.purchasedCount, 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 16. FunctionReturnGift — fromJson / toJson / totalCost
  // ═══════════════════════════════════════════════════════════════════════════
  group('FunctionReturnGift.totalCost', () {
    test('price × quantity', () {
      final rg = FunctionReturnGift(id: 'rg1', functionId: 'f1', giftName: 'Box', approxPrice: 500, quantity: 10);
      expect(rg.totalCost, 5000.0);
    });

    test('null approxPrice → 0 * quantity = 0', () {
      final rg = FunctionReturnGift(id: 'rg1', functionId: 'f1', giftName: 'Box', quantity: 5);
      expect(rg.totalCost, 0.0);
    });

    test('default quantity = 1', () {
      final rg = FunctionReturnGift(id: 'rg1', functionId: 'f1', giftName: 'Box', approxPrice: 1000);
      expect(rg.totalCost, 1000.0);
    });
  });

  group('FunctionReturnGift.fromJson', () {
    test('all fields parsed', () {
      final rg = FunctionReturnGift.fromJson({
        'id': 'rg1',
        'function_id': 'f1',
        'gift_name': 'Copper Vessel',
        'approx_price': 350.0,
        'where_to_buy': 'Local market',
        'vendor': 'Copper King',
        'quantity': 50,
      });
      expect(rg.id, 'rg1');
      expect(rg.functionId, 'f1');
      expect(rg.giftName, 'Copper Vessel');
      expect(rg.approxPrice, 350.0);
      expect(rg.whereToBuy, 'Local market');
      expect(rg.vendor, 'Copper King');
      expect(rg.quantity, 50);
    });

    test('approx_price as int → toDouble', () {
      final rg = FunctionReturnGift.fromJson({
        'id': 'rg1', 'function_id': 'f1', 'gift_name': 'Box', 'approx_price': 350,
      });
      expect(rg.approxPrice, 350.0);
    });

    test('missing quantity → defaults to 1', () {
      final rg = FunctionReturnGift.fromJson({
        'id': 'rg1', 'function_id': 'f1', 'gift_name': 'Box',
      });
      expect(rg.quantity, 1);
    });
  });

  group('FunctionReturnGift.toJson', () {
    test('null optional fields omitted', () {
      final rg = FunctionReturnGift(id: 'rg1', functionId: 'f1', giftName: 'Box');
      final j = rg.toJson();
      expect(j.containsKey('approx_price'), isFalse);
      expect(j.containsKey('where_to_buy'), isFalse);
      expect(j.containsKey('vendor'), isFalse);
    });

    test('quantity always included', () {
      final j = FunctionReturnGift(id: 'rg1', functionId: 'f1', giftName: 'Box', quantity: 25).toJson();
      expect(j['quantity'], 25);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 17. BridalEssential — fromJson / toJson / status parsing
  // ═══════════════════════════════════════════════════════════════════════════
  group('BridalEssential.fromJson', () {
    test('all fields parsed', () {
      final be = BridalEssential.fromJson({
        'id': 'be1',
        'function_id': 'f1',
        'item': 'Bridal Saree',
        'category': 'Clothing',
        'details': 'Red Kanchipuram silk',
        'vendor': 'Pothys Silks',
        'status': 'booked',
        'cost': 45000.0,
      });
      expect(be.id, 'be1');
      expect(be.item, 'Bridal Saree');
      expect(be.category, 'Clothing');
      expect(be.details, 'Red Kanchipuram silk');
      expect(be.vendor, 'Pothys Silks');
      expect(be.status, BridalStatus.booked);
      expect(be.cost, 45000.0);
    });

    test('all BridalStatus values parse correctly', () {
      for (final s in BridalStatus.values) {
        final be = BridalEssential.fromJson({
          'id': 'be1', 'function_id': 'f1', 'item': 'X', 'status': s.name,
        });
        expect(be.status, s, reason: s.name);
      }
    });

    test('unknown status → BridalStatus.pending', () {
      final be = BridalEssential.fromJson({
        'id': 'be1', 'function_id': 'f1', 'item': 'X', 'status': 'unknown',
      });
      expect(be.status, BridalStatus.pending);
    });

    test('missing status → BridalStatus.pending (default)', () {
      final be = BridalEssential.fromJson({'id': 'be1', 'function_id': 'f1', 'item': 'X'});
      expect(be.status, BridalStatus.pending);
    });

    test('cost as int → toDouble', () {
      final be = BridalEssential.fromJson({
        'id': 'be1', 'function_id': 'f1', 'item': 'X', 'cost': 5000,
      });
      expect(be.cost, 5000.0);
    });
  });

  group('BridalEssential.toJson', () {
    test('status serialised as enum name', () {
      final be = BridalEssential(id: 'be1', functionId: 'f1', item: 'X', status: BridalStatus.done);
      expect(be.toJson()['status'], 'done');
    });

    test('null optional fields omitted', () {
      final be = BridalEssential(id: 'be1', functionId: 'f1', item: 'X');
      final j = be.toJson();
      expect(j.containsKey('category'), isFalse);
      expect(j.containsKey('cost'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 18. UpcomingFunction — fromJson (hardcoded memberId) / toJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('UpcomingFunction.fromJson', () {
    final json = {
      'id': 'u1',
      'wallet_id': 'w1',
      'person_name': 'Priya Anand',
      'family_name': 'Anand Family',
      'function_title': 'Wedding',
      'member_id': 'user999', // should be ignored — always 'me'
      'type': 'wedding',
      'date': '2025-05-20',
      'venue': 'Grand Hall',
      'notes': 'Evening ceremony',
      'planned_gifts': [
        {'category': 'Cash', 'notes': '₹5000'},
        {'category': 'Gold'},
      ],
    };

    test('all fields parsed', () {
      final uf = UpcomingFunction.fromJson(json);
      expect(uf.id, 'u1');
      expect(uf.walletId, 'w1');
      expect(uf.personName, 'Priya Anand');
      expect(uf.familyName, 'Anand Family');
      expect(uf.functionTitle, 'Wedding');
      expect(uf.type, FunctionType.wedding);
      expect(uf.date, DateTime(2025, 5, 20));
      expect(uf.venue, 'Grand Hall');
      expect(uf.notes, 'Evening ceremony');
    });

    test('memberId always hardcoded to "me" regardless of JSON', () {
      final uf = UpcomingFunction.fromJson(json);
      expect(uf.memberId, 'me');
    });

    test('plannedGifts list parsed', () {
      final uf = UpcomingFunction.fromJson(json);
      expect(uf.plannedGifts.length, 2);
      expect(uf.plannedGifts.first.category, 'Cash');
      expect(uf.plannedGifts.first.notes, '₹5000');
      expect(uf.plannedGifts.last.category, 'Gold');
      expect(uf.plannedGifts.last.notes, isNull);
    });

    test('missing planned_gifts → empty list', () {
      final uf = UpcomingFunction.fromJson({...json}..remove('planned_gifts'));
      expect(uf.plannedGifts, isEmpty);
    });

    test('missing date → null', () {
      final uf = UpcomingFunction.fromJson({...json, 'date': null});
      expect(uf.date, isNull);
    });
  });

  group('UpcomingFunction.toJson', () {
    test('id NOT included in toJson', () {
      final uf = UpcomingFunction(
        id: 'u1', walletId: 'w1', personName: 'Priya', functionTitle: 'Wedding',
        memberId: 'me', type: FunctionType.wedding,
      );
      expect(uf.toJson().containsKey('id'), isFalse);
    });

    test('memberId NOT included in toJson', () {
      final uf = UpcomingFunction(
        id: 'u1', walletId: 'w1', personName: 'Priya', functionTitle: 'Wedding',
        memberId: 'me', type: FunctionType.wedding,
      );
      expect(uf.toJson().containsKey('member_id'), isFalse);
    });

    test('plannedGifts serialised', () {
      final uf = UpcomingFunction(
        id: 'u1', walletId: 'w1', personName: 'Priya', functionTitle: 'Wedding',
        memberId: 'me', type: FunctionType.wedding,
        plannedGifts: [PlannedGiftItem(category: 'Cash', notes: '₹5000')],
      );
      final gifts = uf.toJson()['planned_gifts'] as List;
      expect(gifts.length, 1);
      expect(gifts.first['category'], 'Cash');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 19. AttendedFunction — fromJson / toJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('AttendedFunction.fromJson', () {
    final json = {
      'id': 'af1',
      'wallet_id': 'w1',
      'function_name': 'House Warming',
      'person_name': 'Suresh',
      'family_name': 'Kumar Family',
      'type': 'houseWarming',
      'date': '2024-08-15',
      'venue': 'Porur, Chennai',
      'notes': 'Afternoon event',
      'gifts': [
        {'category': 'Gold', 'notes': '2g chain'},
      ],
    };

    test('all fields parsed', () {
      final af = AttendedFunction.fromJson(json);
      expect(af.id, 'af1');
      expect(af.functionName, 'House Warming');
      expect(af.personName, 'Suresh');
      expect(af.type, FunctionType.houseWarming);
      expect(af.date, DateTime(2024, 8, 15));
      expect(af.venue, 'Porur, Chennai');
    });

    test('gifts list parsed', () {
      final af = AttendedFunction.fromJson(json);
      expect(af.gifts.length, 1);
      expect(af.gifts.first.category, 'Gold');
    });

    test('missing gifts → empty list', () {
      final af = AttendedFunction.fromJson({...json}..remove('gifts'));
      expect(af.gifts, isEmpty);
    });

    test('missing function_name → empty string', () {
      final af = AttendedFunction.fromJson({...json}..remove('function_name'));
      expect(af.functionName, '');
    });
  });

  group('AttendedFunction.toJson', () {
    test('id NOT in toJson', () {
      final af = AttendedFunction(
        id: 'af1', walletId: 'w1', functionName: 'Test', type: FunctionType.birthday,
      );
      expect(af.toJson().containsKey('id'), isFalse);
    });

    test('null personName omitted', () {
      final af = AttendedFunction(id: 'af1', walletId: 'w1', functionName: 'Test', type: FunctionType.other);
      expect(af.toJson().containsKey('person_name'), isFalse);
    });

    test('gifts serialised', () {
      final af = AttendedFunction(
        id: 'af1', walletId: 'w1', functionName: 'Test', type: FunctionType.wedding,
        gifts: [PlannedGiftItem(category: 'Cash')],
      );
      final giftList = af.toJson()['gifts'] as List;
      expect(giftList.length, 1);
    });
  });
}
