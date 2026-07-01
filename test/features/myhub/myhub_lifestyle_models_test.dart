import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import 'package:wai_life_assistant/data/models/health/health_models.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. StorageType enum
  // ═══════════════════════════════════════════════════════════════════════════
  group('StorageType enum', () {
    test('all 10 values have non-empty emoji and label', () {
      expect(StorageType.values.length, 10);
      for (final t in StorageType.values) {
        expect(t.emoji, isNotEmpty, reason: t.name);
        expect(t.label, isNotEmpty, reason: t.name);
      }
    });
    test('shelf label', () { expect(StorageType.shelf.label, 'Shelf'); });
    test('box label', () { expect(StorageType.box.label, 'Box'); });
    test('almirah label', () { expect(StorageType.almirah.label, 'Almirah'); });
    test('other emoji', () { expect(StorageType.other.emoji, '📍'); });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. StorageContainer — fromJson / toJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('StorageContainer.fromJson', () {
    final fullJson = {
      'id': 'sc1',
      'wallet_id': 'w1',
      'type': 'almirah',
      'name': 'Bedroom Almirah',
      'location': 'Bedroom',
      'notes': 'Left — clothes, Right — formal',
      'color': 'White',
      'created_at': '2024-06-15T00:00:00.000Z',
    };

    test('all fields parsed', () {
      final c = StorageContainer.fromJson(fullJson);
      expect(c.id, 'sc1');
      expect(c.walletId, 'w1');
      expect(c.type, StorageType.almirah);
      expect(c.name, 'Bedroom Almirah');
      expect(c.location, 'Bedroom');
      expect(c.notes, 'Left — clothes, Right — formal');
      expect(c.color, 'White');
      expect(c.createdAt, DateTime.parse('2024-06-15T00:00:00.000Z'));
    });

    test('unknown type → StorageType.other', () {
      final c = StorageContainer.fromJson({...fullJson, 'type': 'unknownType'});
      expect(c.type, StorageType.other);
    });

    test('all valid StorageType values parse correctly', () {
      for (final t in StorageType.values) {
        final c = StorageContainer.fromJson({...fullJson, 'type': t.name});
        expect(c.type, t, reason: t.name);
      }
    });

    test('missing created_at → createdAt defaults to now (not null)', () {
      final before = DateTime.now();
      final c = StorageContainer.fromJson({...fullJson}..remove('created_at'));
      expect(c.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    });

    test('null optional fields → null', () {
      final c = StorageContainer.fromJson({
        'id': 'sc1', 'wallet_id': 'w1', 'type': 'box', 'name': 'Box 1',
      });
      expect(c.location, isNull);
      expect(c.notes, isNull);
      expect(c.color, isNull);
    });
  });

  group('StorageContainer.toJson', () {
    test('required fields always included', () {
      final c = StorageContainer(id: 'sc1', walletId: 'w1', type: StorageType.box, name: 'Box 1');
      final j = c.toJson();
      expect(j['wallet_id'], 'w1');
      expect(j['type'], 'box');
      expect(j['name'], 'Box 1');
    });

    test('id and created_at NOT in toJson', () {
      final c = StorageContainer(id: 'sc1', walletId: 'w1', type: StorageType.shelf, name: 'My Shelf');
      final j = c.toJson();
      expect(j.containsKey('id'), isFalse);
      expect(j.containsKey('created_at'), isFalse);
    });

    test('null optional fields omitted', () {
      final c = StorageContainer(id: 'sc1', walletId: 'w1', type: StorageType.drawer, name: 'D1');
      final j = c.toJson();
      expect(j.containsKey('location'), isFalse);
      expect(j.containsKey('notes'), isFalse);
      expect(j.containsKey('color'), isFalse);
    });

    test('non-null optional fields included', () {
      final c = StorageContainer(
        id: 'sc1', walletId: 'w1', type: StorageType.box, name: 'Box 2',
        location: 'Store Room', notes: 'Old docs', color: 'Brown',
      );
      final j = c.toJson();
      expect(j['location'], 'Store Room');
      expect(j['notes'], 'Old docs');
      expect(j['color'], 'Brown');
    });

    test('type serialised as enum name', () {
      final c = StorageContainer(id: 'sc1', walletId: 'w1', type: StorageType.locker, name: 'L1');
      expect(c.toJson()['type'], 'locker');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. StoredItem — fromJson / toJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('StoredItem.fromJson', () {
    final fullJson = {
      'id': 'si1',
      'wallet_id': 'w1',
      'container_id': 'sc1',
      'name': 'Birth Certificate',
      'description': 'Original copy',
      'category': 'Documents',
      'emoji': '📄',
      'stored_on': '2024-03-10',
      'stored_by': 'me',
      'notes': 'Keep safe',
      'is_fragile': false,
      'is_important': true,
    };

    test('all fields parsed', () {
      final item = StoredItem.fromJson(fullJson);
      expect(item.id, 'si1');
      expect(item.walletId, 'w1');
      expect(item.containerId, 'sc1');
      expect(item.name, 'Birth Certificate');
      expect(item.description, 'Original copy');
      expect(item.category, 'Documents');
      expect(item.emoji, '📄');
      expect(item.storedOn, DateTime(2024, 3, 10));
      expect(item.storedBy, 'me');
      expect(item.notes, 'Keep safe');
      expect(item.isFragile, isFalse);
      expect(item.isImportant, isTrue);
    });

    test('missing is_fragile → false', () {
      final item = StoredItem.fromJson({...fullJson}..remove('is_fragile'));
      expect(item.isFragile, isFalse);
    });

    test('missing is_important → false', () {
      final item = StoredItem.fromJson({...fullJson}..remove('is_important'));
      expect(item.isImportant, isFalse);
    });

    test('missing stored_on → storedOn defaults to now (not null)', () {
      final before = DateTime.now();
      final item = StoredItem.fromJson({
        'id': 'si1', 'wallet_id': 'w1', 'container_id': 'sc1', 'name': 'X',
      });
      expect(item.storedOn.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    });
  });

  group('StoredItem.toJson', () {
    test('required fields always included', () {
      final item = StoredItem(id: 'si1', walletId: 'w1', containerId: 'sc1', name: 'Doc',
          storedOn: DateTime(2024, 3, 10));
      final j = item.toJson();
      expect(j['wallet_id'], 'w1');
      expect(j['container_id'], 'sc1');
      expect(j['name'], 'Doc');
      expect(j['is_fragile'], isFalse);
      expect(j['is_important'], isFalse);
    });

    test('id NOT in toJson', () {
      final j = StoredItem(id: 'si1', walletId: 'w1', containerId: 'sc1', name: 'X',
          storedOn: DateTime(2024, 1, 1)).toJson();
      expect(j.containsKey('id'), isFalse);
    });

    test('storedOn formatted as YYYY-MM-DD', () {
      final item = StoredItem(id: 'si1', walletId: 'w1', containerId: 'sc1', name: 'X',
          storedOn: DateTime(2024, 8, 5));
      expect(item.toJson()['stored_on'], '2024-08-05');
    });

    test('null optional fields omitted', () {
      final item = StoredItem(id: 'si1', walletId: 'w1', containerId: 'sc1', name: 'X',
          storedOn: DateTime(2024, 1, 1));
      final j = item.toJson();
      expect(j.containsKey('description'), isFalse);
      expect(j.containsKey('category'), isFalse);
      expect(j.containsKey('emoji'), isFalse);
      expect(j.containsKey('stored_by'), isFalse);
      expect(j.containsKey('notes'), isFalse);
    });

    test('round-trip fromJson → toJson → fromJson', () {
      final orig = StoredItem(
        id: 'si1', walletId: 'w1', containerId: 'sc1', name: 'Passport',
        description: 'Valid till 2030', category: 'Documents', emoji: '🛂',
        storedOn: DateTime(2024, 5, 20), storedBy: 'me',
        isFragile: false, isImportant: true,
      );
      final j = {...orig.toJson(), 'id': orig.id};
      final back = StoredItem.fromJson(j);
      expect(back.name, orig.name);
      expect(back.category, orig.category);
      expect(back.storedOn, orig.storedOn);
      expect(back.isImportant, orig.isImportant);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. ClothingCategory / ClothingGender enums
  // ═══════════════════════════════════════════════════════════════════════════
  group('ClothingCategory enum', () {
    test('12 values, all have non-empty emoji and label', () {
      expect(ClothingCategory.values.length, 12);
      for (final c in ClothingCategory.values) {
        expect(c.emoji, isNotEmpty, reason: c.name);
        expect(c.label, isNotEmpty, reason: c.name);
      }
    });
    test('topwear label', () => expect(ClothingCategory.topwear.label, 'Topwear'));
    test('ethnic label', () => expect(ClothingCategory.ethnic.label, 'Ethnic / Traditional'));
    test('formal label', () => expect(ClothingCategory.formal.label, 'Formal / Office'));
  });

  group('ClothingGender enum', () {
    test('4 values', () => expect(ClothingGender.values.length, 4));
    test('values', () {
      expect(ClothingGender.values, containsAll([
        ClothingGender.male, ClothingGender.female,
        ClothingGender.kids, ClothingGender.unisex,
      ]));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. ClothingItem — fromJson / toJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('ClothingItem.fromJson', () {
    final fullJson = {
      'id': 'c1',
      'wallet_id': 'w1',
      'member_id': 'me',
      'name': 'White Oxford Shirt',
      'category': 'topwear',
      'gender': 'male',
      'brand': 'Arrow',
      'size': 'L',
      'color': 'White',
      'photo_path': '/path/to/photo.jpg',
      'notes': 'Slim fit',
      'wishlist': false,
      'wishlist_source': null,
      'match_with': ['c2', 'c3'],
      'added_on': '2024-01-15',
    };

    test('all fields parsed', () {
      final item = ClothingItem.fromJson(fullJson);
      expect(item.id, 'c1');
      expect(item.walletId, 'w1');
      expect(item.memberId, 'me');
      expect(item.name, 'White Oxford Shirt');
      expect(item.category, ClothingCategory.topwear);
      expect(item.gender, ClothingGender.male);
      expect(item.brand, 'Arrow');
      expect(item.size, 'L');
      expect(item.color, 'White');
      expect(item.photoPath, '/path/to/photo.jpg');
      expect(item.notes, 'Slim fit');
      expect(item.wishlist, isFalse);
      expect(item.matchWith, ['c2', 'c3']);
      expect(item.addedOn, DateTime(2024, 1, 15));
    });

    test('unknown category → ClothingCategory.topwear (fallback)', () {
      final item = ClothingItem.fromJson({...fullJson, 'category': 'unknown'});
      expect(item.category, ClothingCategory.topwear);
    });

    test('unknown gender → ClothingGender.unisex (fallback)', () {
      final item = ClothingItem.fromJson({...fullJson, 'gender': 'alien'});
      expect(item.gender, ClothingGender.unisex);
    });

    test('all valid categories parse correctly', () {
      for (final cat in ClothingCategory.values) {
        final item = ClothingItem.fromJson({...fullJson, 'category': cat.name});
        expect(item.category, cat, reason: cat.name);
      }
    });

    test('all valid genders parse correctly', () {
      for (final g in ClothingGender.values) {
        final item = ClothingItem.fromJson({...fullJson, 'gender': g.name});
        expect(item.gender, g, reason: g.name);
      }
    });

    test('missing wishlist → false', () {
      final item = ClothingItem.fromJson({...fullJson}..remove('wishlist'));
      expect(item.wishlist, isFalse);
    });

    test('missing match_with → empty list', () {
      final item = ClothingItem.fromJson({...fullJson}..remove('match_with'));
      expect(item.matchWith, isEmpty);
    });

    test('missing added_on → addedOn defaults to now', () {
      final before = DateTime.now();
      final item = ClothingItem.fromJson({...fullJson}..remove('added_on'));
      expect(item.addedOn.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    });
  });

  group('ClothingItem.toJson', () {
    test('required fields always included', () {
      final item = ClothingItem(
        id: 'c1', walletId: 'w1', memberId: 'me', name: 'Shirt',
        category: ClothingCategory.topwear, gender: ClothingGender.male,
        addedOn: DateTime(2024, 1, 15),
      );
      final j = item.toJson();
      expect(j['wallet_id'], 'w1');
      expect(j['member_id'], 'me');
      expect(j['name'], 'Shirt');
      expect(j['category'], 'topwear');
      expect(j['gender'], 'male');
      expect(j['wishlist'], isFalse);
      expect(j['match_with'], isEmpty);
    });

    test('id NOT in toJson', () {
      final item = ClothingItem(
        id: 'c1', walletId: 'w1', memberId: 'me', name: 'X',
        category: ClothingCategory.footwear, gender: ClothingGender.unisex,
      );
      expect(item.toJson().containsKey('id'), isFalse);
    });

    test('addedOn formatted as YYYY-MM-DD', () {
      final item = ClothingItem(
        id: 'c1', walletId: 'w1', memberId: 'me', name: 'X',
        category: ClothingCategory.ethnic, gender: ClothingGender.female,
        addedOn: DateTime(2024, 12, 31),
      );
      expect(item.toJson()['added_on'], '2024-12-31');
    });

    test('null optional fields omitted', () {
      final item = ClothingItem(
        id: 'c1', walletId: 'w1', memberId: 'me', name: 'X',
        category: ClothingCategory.nightwear, gender: ClothingGender.kids,
      );
      final j = item.toJson();
      expect(j.containsKey('brand'), isFalse);
      expect(j.containsKey('size'), isFalse);
      expect(j.containsKey('color'), isFalse);
      expect(j.containsKey('photo_path'), isFalse);
      expect(j.containsKey('notes'), isFalse);
      expect(j.containsKey('wishlist_source'), isFalse);
    });

    test('matchWith list serialised', () {
      final item = ClothingItem(
        id: 'c1', walletId: 'w1', memberId: 'me', name: 'Chinos',
        category: ClothingCategory.bottomwear, gender: ClothingGender.male,
        matchWith: ['c2', 'c3'],
      );
      expect(item.toJson()['match_with'], ['c2', 'c3']);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. DeviceCategory enum
  // ═══════════════════════════════════════════════════════════════════════════
  group('DeviceCategory enum', () {
    test('9 values, all have non-empty emoji and label', () {
      expect(DeviceCategory.values.length, 9);
      for (final d in DeviceCategory.values) {
        expect(d.emoji, isNotEmpty, reason: d.name);
        expect(d.label, isNotEmpty, reason: d.name);
      }
    });
    test('phone label', () => expect(DeviceCategory.phone.label, 'Phone'));
    test('smartwatch label', () => expect(DeviceCategory.smartwatch.label, 'Wearable'));
    test('console label', () => expect(DeviceCategory.console.label, 'Gaming'));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. DeviceModel.isUnderWarranty
  //    Parses warrantyExpiry string 'YYYY-MM-DD' and compares to DateTime.now()
  // ═══════════════════════════════════════════════════════════════════════════
  group('DeviceModel.isUnderWarranty', () {
    DeviceModel device({String? warrantyExpiry}) => DeviceModel(
          id: 'd1', name: 'iPhone', walletId: 'w1', ownerId: 'me',
          category: DeviceCategory.phone, warrantyExpiry: warrantyExpiry,
        );

    test('null warrantyExpiry → false', () => expect(device().isUnderWarranty, isFalse));

    test('future date → true', () {
      expect(device(warrantyExpiry: '2030-01-01').isUnderWarranty, isTrue);
    });

    test('past date → false', () {
      expect(device(warrantyExpiry: '2020-01-01').isUnderWarranty, isFalse);
    });

    test('malformed string (non-numeric) → false (catch block)', () {
      expect(device(warrantyExpiry: 'not-a-date').isUnderWarranty, isFalse);
    });

    test('only 2 parts (wrong format) → false', () {
      expect(device(warrantyExpiry: 'bad-date').isUnderWarranty, isFalse);
    });

    test('empty string (1 part) → false', () {
      expect(device(warrantyExpiry: '').isUnderWarranty, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. HealthProfile — fromJson / toJson / copyWith
  // ═══════════════════════════════════════════════════════════════════════════
  group('HealthProfile.fromJson', () {
    final fullJson = {
      'id': 'hp1',
      'wallet_id': 'w1',
      'member_id': 'me',
      'blood_group': 'O+',
      'height': '175 cm',
      'weight': '72 kg',
      'emergency_contact': 'Mom',
      'emergency_phone': '9876543210',
      'allergies': ['Penicillin', 'Dust'],
      'conditions': ['Hypertension'],
      'disabilities': [],
    };

    test('all fields parsed', () {
      final hp = HealthProfile.fromJson(fullJson);
      expect(hp.id, 'hp1');
      expect(hp.walletId, 'w1');
      expect(hp.memberId, 'me');
      expect(hp.bloodGroup, 'O+');
      expect(hp.height, '175 cm');
      expect(hp.weight, '72 kg');
      expect(hp.emergencyContact, 'Mom');
      expect(hp.emergencyPhone, '9876543210');
      expect(hp.allergies, ['Penicillin', 'Dust']);
      expect(hp.conditions, ['Hypertension']);
      expect(hp.disabilities, isEmpty);
    });

    test('missing allergies/conditions/disabilities → empty lists', () {
      final hp = HealthProfile.fromJson({
        'id': 'hp1', 'wallet_id': 'w1', 'member_id': 'me',
      });
      expect(hp.allergies, isEmpty);
      expect(hp.conditions, isEmpty);
      expect(hp.disabilities, isEmpty);
    });

    test('null optional fields → null', () {
      final hp = HealthProfile.fromJson({
        'id': 'hp1', 'wallet_id': 'w1', 'member_id': 'me',
        'allergies': [], 'conditions': [], 'disabilities': [],
      });
      expect(hp.bloodGroup, isNull);
      expect(hp.height, isNull);
    });
  });

  group('HealthProfile.toJson', () {
    test('required fields always included', () {
      final hp = HealthProfile(
        id: 'hp1', walletId: 'w1', memberId: 'me',
        allergies: ['Dust'], conditions: [], disabilities: [],
      );
      final j = hp.toJson();
      expect(j['wallet_id'], 'w1');
      expect(j['member_id'], 'me');
      expect(j['allergies'], ['Dust']);
      expect(j['conditions'], isEmpty);
      expect(j['disabilities'], isEmpty);
    });

    test('id NOT in toJson', () {
      final hp = HealthProfile(id: 'hp1', walletId: 'w1', memberId: 'me');
      expect(hp.toJson().containsKey('id'), isFalse);
    });

    test('null optional fields omitted', () {
      final hp = HealthProfile(id: 'hp1', walletId: 'w1', memberId: 'me');
      final j = hp.toJson();
      expect(j.containsKey('blood_group'), isFalse);
      expect(j.containsKey('height'), isFalse);
      expect(j.containsKey('weight'), isFalse);
      expect(j.containsKey('emergency_contact'), isFalse);
      expect(j.containsKey('emergency_phone'), isFalse);
    });

    test('non-null optional fields included', () {
      final hp = HealthProfile(id: 'hp1', walletId: 'w1', memberId: 'me', bloodGroup: 'AB+');
      expect(hp.toJson()['blood_group'], 'AB+');
    });
  });

  group('HealthProfile.copyWith', () {
    final base = HealthProfile(
      id: 'hp1', walletId: 'w1', memberId: 'me',
      bloodGroup: 'O+', height: '170 cm', weight: '65 kg',
      allergies: ['Dust'], conditions: ['Asthma'], disabilities: [],
    );

    test('copyWith preserves id, walletId, memberId (not changeable)', () {
      final copy = base.copyWith(bloodGroup: 'A+');
      expect(copy.id, base.id);
      expect(copy.walletId, base.walletId);
      expect(copy.memberId, base.memberId);
    });

    test('copyWith updates specified field', () {
      final copy = base.copyWith(bloodGroup: 'B+', weight: '70 kg');
      expect(copy.bloodGroup, 'B+');
      expect(copy.weight, '70 kg');
      expect(copy.height, base.height); // unchanged
    });

    test('copyWith with no args returns equivalent (not same instance)', () {
      final copy = base.copyWith();
      expect(copy.bloodGroup, base.bloodGroup);
      expect(copy.allergies, base.allergies);
      expect(identical(copy, base), isFalse);
    });

    test('copyWith lists produce independent copies (mutating copy does not affect original)', () {
      final copy = base.copyWith();
      copy.allergies.add('Pollen');
      expect(base.allergies, ['Dust']); // original unchanged
    });

    test('copyWith with new list replaces it', () {
      final copy = base.copyWith(allergies: ['Pollen', 'Peanuts']);
      expect(copy.allergies, ['Pollen', 'Peanuts']);
      expect(base.allergies, ['Dust']); // original unchanged
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. Medication — fromJson / toJson / scheduleLabel
  // ═══════════════════════════════════════════════════════════════════════════
  group('Medication.scheduleLabel', () {
    test('scheduleTimes only — joined with "  ·  "', () {
      final med = Medication(
        id: 'm1', walletId: 'w1', memberId: 'me',
        name: 'Metformin', dosage: '500mg', frequency: 'Twice daily',
        scheduleTimes: ['Morning', 'Night'],
      );
      expect(med.scheduleLabel, 'Morning  ·  Night');
    });

    test('scheduleTimes + mealTiming appended', () {
      final med = Medication(
        id: 'm1', walletId: 'w1', memberId: 'me',
        name: 'X', dosage: '10mg', frequency: 'Once',
        scheduleTimes: ['Morning'], mealTiming: 'After Meal',
      );
      expect(med.scheduleLabel, 'Morning  ·  After Meal');
    });

    test('mealTiming only, no scheduleTimes', () {
      final med = Medication(
        id: 'm1', walletId: 'w1', memberId: 'me',
        name: 'X', dosage: '10mg', frequency: 'Once',
        mealTiming: 'After Meal',
      );
      expect(med.scheduleLabel, 'After Meal');
    });

    test('empty scheduleTimes, no mealTiming → empty string', () {
      final med = Medication(
        id: 'm1', walletId: 'w1', memberId: 'me',
        name: 'X', dosage: '10mg', frequency: 'Once',
      );
      expect(med.scheduleLabel, '');
    });

    test('multiple times + mealTiming', () {
      final med = Medication(
        id: 'm1', walletId: 'w1', memberId: 'me',
        name: 'X', dosage: '10mg', frequency: 'TID',
        scheduleTimes: ['6 AM', '2 PM', '10 PM'], mealTiming: 'Before Food',
      );
      expect(med.scheduleLabel, '6 AM  ·  2 PM  ·  10 PM  ·  Before Food');
    });
  });

  group('Medication.fromJson', () {
    final fullJson = {
      'id': 'm1',
      'wallet_id': 'w1',
      'member_id': 'me',
      'name': 'Metformin',
      'dosage': '500mg',
      'frequency': 'Twice daily',
      'schedule_times': ['Morning', 'Night'],
      'meal_timing': 'After Meal',
      'notes': 'Take with water',
      'is_active': true,
      'start_date': '2025-01-01',
      'end_date': '2025-06-30',
      'refill_date': '2025-06-01',
    };

    test('all fields parsed', () {
      final med = Medication.fromJson(fullJson);
      expect(med.id, 'm1');
      expect(med.name, 'Metformin');
      expect(med.dosage, '500mg');
      expect(med.frequency, 'Twice daily');
      expect(med.scheduleTimes, ['Morning', 'Night']);
      expect(med.mealTiming, 'After Meal');
      expect(med.notes, 'Take with water');
      expect(med.isActive, isTrue);
      expect(med.startDate, DateTime(2025, 1, 1));
      expect(med.endDate, DateTime(2025, 6, 30));
      expect(med.refillDate, DateTime(2025, 6, 1));
    });

    test('missing is_active → true (default)', () {
      final med = Medication.fromJson({...fullJson}..remove('is_active'));
      expect(med.isActive, isTrue);
    });

    test('missing schedule_times → empty list', () {
      final med = Medication.fromJson({...fullJson}..remove('schedule_times'));
      expect(med.scheduleTimes, isEmpty);
    });

    test('missing end_date → null', () {
      final med = Medication.fromJson({...fullJson}..remove('end_date'));
      expect(med.endDate, isNull);
    });

    test('missing start_date → defaults to now', () {
      final before = DateTime.now();
      final med = Medication.fromJson({...fullJson}..remove('start_date'));
      expect(med.startDate.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    });
  });

  group('Medication.toJson', () {
    test('required fields always included', () {
      final med = Medication(
        id: 'm1', walletId: 'w1', memberId: 'me',
        name: 'Aspirin', dosage: '75mg', frequency: 'Once daily',
        startDate: DateTime(2025, 1, 1), isActive: true,
        scheduleTimes: ['Night'],
      );
      final j = med.toJson();
      expect(j['name'], 'Aspirin');
      expect(j['dosage'], '75mg');
      expect(j['is_active'], isTrue);
      expect(j['start_date'], '2025-01-01');
      expect(j['schedule_times'], ['Night']);
    });

    test('null optional fields omitted', () {
      final med = Medication(
        id: 'm1', walletId: 'w1', memberId: 'me',
        name: 'X', dosage: '10mg', frequency: 'Once',
        startDate: DateTime(2025, 1, 1),
      );
      final j = med.toJson();
      expect(j.containsKey('meal_timing'), isFalse);
      expect(j.containsKey('notes'), isFalse);
      expect(j.containsKey('end_date'), isFalse);
      expect(j.containsKey('refill_date'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. DoctorRecord — fromJson / toJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('DoctorRecord.fromJson / toJson', () {
    test('all fields parsed', () {
      final dr = DoctorRecord.fromJson({
        'id': 'dr1', 'wallet_id': 'w1', 'member_id': 'me',
        'name': 'Dr. Priya', 'specialty': 'Cardiology',
        'hospital': 'Apollo', 'phone': '9876543210', 'notes': 'Good',
      });
      expect(dr.id, 'dr1');
      expect(dr.name, 'Dr. Priya');
      expect(dr.specialty, 'Cardiology');
      expect(dr.hospital, 'Apollo');
    });

    test('null optional fields omitted from toJson', () {
      final dr = DoctorRecord(id: 'dr1', walletId: 'w1', memberId: 'me', name: 'Dr. X');
      final j = dr.toJson();
      expect(j.containsKey('specialty'), isFalse);
      expect(j.containsKey('hospital'), isFalse);
      expect(j.containsKey('phone'), isFalse);
    });

    test('id NOT in toJson', () {
      expect(DoctorRecord(id: 'dr1', walletId: 'w1', memberId: 'me', name: 'Dr. X')
          .toJson().containsKey('id'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 11. MedDocType enum / MedicalDocument.fromJson
  // ═══════════════════════════════════════════════════════════════════════════
  group('MedDocType enum', () {
    test('6 values, all have non-empty emoji and label', () {
      expect(MedDocType.values.length, 6);
      for (final t in MedDocType.values) {
        expect(t.emoji, isNotEmpty, reason: t.name);
        expect(t.label, isNotEmpty, reason: t.name);
      }
    });
    test('labReport label', () => expect(MedDocType.labReport.label, 'Lab Report'));
    test('vaccination emoji', () => expect(MedDocType.vaccination.emoji, '💉'));
  });

  group('MedicalDocument.fromJson', () {
    final base = {
      'id': 'md1', 'wallet_id': 'w1', 'member_id': 'me',
      'title': 'Blood Test', 'doc_type': 'labReport',
      'file_urls': ['https://example.com/report.pdf'],
      'doc_date': '2024-06-15',
    };

    test('file_urls array parsed', () {
      final md = MedicalDocument.fromJson(base);
      expect(md.fileUrls, ['https://example.com/report.pdf']);
      expect(md.docType, MedDocType.labReport);
      expect(md.docDate, DateTime(2024, 6, 15));
    });

    test('legacy file_url used when file_urls absent', () {
      final j = {...base}..remove('file_urls');
      j['file_url'] = 'https://example.com/legacy.pdf';
      final md = MedicalDocument.fromJson(j);
      expect(md.fileUrls, ['https://example.com/legacy.pdf']);
    });

    test('legacy file_url ignored when file_urls already present and non-empty', () {
      final j = {...base, 'file_url': 'https://example.com/legacy.pdf'};
      final md = MedicalDocument.fromJson(j);
      expect(md.fileUrls, ['https://example.com/report.pdf']); // new takes precedence
    });

    test('unknown doc_type → MedDocType.other', () {
      final md = MedicalDocument.fromJson({...base, 'doc_type': 'unknown'});
      expect(md.docType, MedDocType.other);
    });

    test('all valid doc_types parse correctly', () {
      for (final t in MedDocType.values) {
        final md = MedicalDocument.fromJson({...base, 'doc_type': t.name});
        expect(md.docType, t, reason: t.name);
      }
    });
  });

  group('MedicalDocument.toJson', () {
    test('doc_type serialised as enum name', () {
      final md = MedicalDocument(
        id: 'md1', walletId: 'w1', memberId: 'me',
        title: 'X', docType: MedDocType.prescription,
        docDate: DateTime(2025, 3, 1),
      );
      expect(md.toJson()['doc_type'], 'prescription');
    });

    test('doc_date formatted as YYYY-MM-DD', () {
      final md = MedicalDocument(
        id: 'md1', walletId: 'w1', memberId: 'me',
        title: 'X', docType: MedDocType.other,
        docDate: DateTime(2025, 11, 5),
      );
      expect(md.toJson()['doc_date'], '2025-11-05');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 12. Appointment — fromJson / toJson / isUpcoming
  // ═══════════════════════════════════════════════════════════════════════════
  group('Appointment.isUpcoming', () {
    test('far future date → true', () {
      final appt = Appointment(
        id: 'a1', walletId: 'w1', memberId: 'me', doctorName: 'Dr. X',
        apptDate: DateTime(2030, 1, 1),
      );
      expect(appt.isUpcoming, isTrue);
    });

    test('far past date → false', () {
      final appt = Appointment(
        id: 'a1', walletId: 'w1', memberId: 'me', doctorName: 'Dr. X',
        apptDate: DateTime(2020, 1, 1),
      );
      expect(appt.isUpcoming, isFalse);
    });

    test('tomorrow → true', () {
      final appt = Appointment(
        id: 'a1', walletId: 'w1', memberId: 'me', doctorName: 'Dr. X',
        apptDate: DateTime.now().add(const Duration(days: 1)),
      );
      expect(appt.isUpcoming, isTrue);
    });
  });

  group('Appointment.fromJson / toJson', () {
    test('all fields parsed', () {
      final a = Appointment.fromJson({
        'id': 'a1', 'wallet_id': 'w1', 'member_id': 'me',
        'doctor_name': 'Dr. Sharma', 'appt_date': '2025-08-10',
        'appt_time': '10:30 AM', 'location': 'Apollo Hospital', 'notes': 'Fasting',
      });
      expect(a.doctorName, 'Dr. Sharma');
      expect(a.apptDate, DateTime(2025, 8, 10));
      expect(a.apptTime, '10:30 AM');
      expect(a.location, 'Apollo Hospital');
    });

    test('id NOT in toJson', () {
      final a = Appointment(
        id: 'a1', walletId: 'w1', memberId: 'me', doctorName: 'Dr. X',
        apptDate: DateTime(2025, 8, 10),
      );
      expect(a.toJson().containsKey('id'), isFalse);
    });

    test('appt_date formatted as YYYY-MM-DD', () {
      final a = Appointment(
        id: 'a1', walletId: 'w1', memberId: 'me', doctorName: 'Dr. X',
        apptDate: DateTime(2025, 9, 5),
      );
      expect(a.toJson()['appt_date'], '2025-09-05');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 13. VitalType enum / HealthVital — fromJson / toJson / displayValue
  // ═══════════════════════════════════════════════════════════════════════════
  group('VitalType enum', () {
    test('6 values, all have emoji, label, unit', () {
      expect(VitalType.values.length, 6);
      for (final v in VitalType.values) {
        expect(v.emoji, isNotEmpty, reason: v.name);
        expect(v.label, isNotEmpty, reason: v.name);
        expect(v.unit, isNotEmpty, reason: v.name);
      }
    });
    test('bloodPressure unit', () => expect(VitalType.bloodPressure.unit, 'mmHg'));
    test('bloodSugar unit', () => expect(VitalType.bloodSugar.unit, 'mg/dL'));
    test('weight unit', () => expect(VitalType.weight.unit, 'kg'));
    test('spo2 unit', () => expect(VitalType.spo2.unit, '%'));
    test('heartRate unit', () => expect(VitalType.heartRate.unit, 'bpm'));
  });

  group('HealthVital.displayValue', () {
    HealthVital vital({
      required VitalType type, required double value, double? value2,
    }) => HealthVital(
          id: 'v1', walletId: 'w1', memberId: 'me',
          type: type, value: value, value2: value2,
        );

    test('bloodPressure with value2 → "120/80 mmHg"', () {
      expect(vital(type: VitalType.bloodPressure, value: 120, value2: 80).displayValue, '120/80 mmHg');
    });

    test('bloodPressure without value2 → regular format "120 mmHg"', () {
      expect(vital(type: VitalType.bloodPressure, value: 120).displayValue, '120 mmHg');
    });

    test('integer weight → no decimal "70 kg"', () {
      expect(vital(type: VitalType.weight, value: 70.0).displayValue, '70 kg');
    });

    test('decimal bloodSugar → 1dp "98.5 mg/dL"', () {
      expect(vital(type: VitalType.bloodSugar, value: 98.5).displayValue, '98.5 mg/dL');
    });

    test('integer spo2 → no decimal "97 %"', () {
      expect(vital(type: VitalType.spo2, value: 97.0).displayValue, '97 %');
    });

    test('integer heartRate → no decimal "72 bpm"', () {
      expect(vital(type: VitalType.heartRate, value: 72.0).displayValue, '72 bpm');
    });
  });

  group('HealthVital.fromJson', () {
    final baseJson = {
      'id': 'v1', 'wallet_id': 'w1', 'member_id': 'me',
      'vital_type': 'weight', 'value': 70.0,
      'recorded_at': '2025-06-15T08:00:00.000Z',
    };

    test('all fields parsed', () {
      final v = HealthVital.fromJson({...baseJson, 'value2': 80.0, 'sub_type': 'systolic', 'notes': 'Morning'});
      expect(v.value, 70.0);
      expect(v.value2, 80.0);
      expect(v.subType, 'systolic');
      expect(v.notes, 'Morning');
    });

    test('value as int → toDouble', () {
      final v = HealthVital.fromJson({...baseJson, 'value': 70});
      expect(v.value, 70.0);
    });

    test('unknown vital_type → VitalType.heartRate (fallback)', () {
      final v = HealthVital.fromJson({...baseJson, 'vital_type': 'unknown'});
      expect(v.type, VitalType.heartRate);
    });

    test('all valid vital types parse correctly', () {
      for (final t in VitalType.values) {
        final v = HealthVital.fromJson({...baseJson, 'vital_type': t.name});
        expect(v.type, t, reason: t.name);
      }
    });
  });

  group('HealthVital.toJson', () {
    test('vital_type serialised as enum name', () {
      final v = HealthVital(
        id: 'v1', walletId: 'w1', memberId: 'me',
        type: VitalType.bloodSugar, value: 98.5,
      );
      expect(v.toJson()['vital_type'], 'bloodSugar');
    });

    test('null value2 omitted', () {
      final v = HealthVital(id: 'v1', walletId: 'w1', memberId: 'me', type: VitalType.weight, value: 70);
      expect(v.toJson().containsKey('value2'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 14. Vaccination — fromJson / toJson / isDueSoon / isOverdue
  // ═══════════════════════════════════════════════════════════════════════════
  group('Vaccination.isDueSoon', () {
    test('null nextDue → false', () {
      final v = Vaccination(id: 'v1', walletId: 'w1', memberId: 'me',
          vaccineName: 'Flu', dateGiven: DateTime(2024, 10, 1));
      expect(v.isDueSoon, isFalse);
    });

    test('nextDue within 30 days → true', () {
      final v = Vaccination(id: 'v1', walletId: 'w1', memberId: 'me',
          vaccineName: 'Flu', dateGiven: DateTime(2024, 10, 1),
          nextDue: DateTime.now().add(const Duration(days: 15)));
      expect(v.isDueSoon, isTrue);
    });

    test('nextDue exactly 30 days → true (≤ 30)', () {
      final v = Vaccination(id: 'v1', walletId: 'w1', memberId: 'me',
          vaccineName: 'Flu', dateGiven: DateTime(2024, 10, 1),
          nextDue: DateTime.now().add(const Duration(days: 30)));
      expect(v.isDueSoon, isTrue);
    });

    test('nextDue > 30 days → false', () {
      final v = Vaccination(id: 'v1', walletId: 'w1', memberId: 'me',
          vaccineName: 'Flu', dateGiven: DateTime(2024, 10, 1),
          nextDue: DateTime.now().add(const Duration(days: 60)));
      expect(v.isDueSoon, isFalse);
    });
  });

  group('Vaccination.isOverdue', () {
    test('null nextDue → false', () {
      final v = Vaccination(id: 'v1', walletId: 'w1', memberId: 'me',
          vaccineName: 'Flu', dateGiven: DateTime(2024, 10, 1));
      expect(v.isOverdue, isFalse);
    });

    test('nextDue in past → true', () {
      final v = Vaccination(id: 'v1', walletId: 'w1', memberId: 'me',
          vaccineName: 'Flu', dateGiven: DateTime(2024, 10, 1),
          nextDue: DateTime(2020, 1, 1));
      expect(v.isOverdue, isTrue);
    });

    test('nextDue in future → false', () {
      final v = Vaccination(id: 'v1', walletId: 'w1', memberId: 'me',
          vaccineName: 'Flu', dateGiven: DateTime(2024, 10, 1),
          nextDue: DateTime(2030, 1, 1));
      expect(v.isOverdue, isFalse);
    });
  });

  group('Vaccination.fromJson / toJson', () {
    test('all fields parsed', () {
      final v = Vaccination.fromJson({
        'id': 'v1', 'wallet_id': 'w1', 'member_id': 'me',
        'vaccine_name': 'Hepatitis B', 'date_given': '2024-01-15',
        'next_due': '2025-01-15', 'dose_number': 2, 'notes': 'Second dose',
      });
      expect(v.vaccineName, 'Hepatitis B');
      expect(v.dateGiven, DateTime(2024, 1, 15));
      expect(v.nextDue, DateTime(2025, 1, 15));
      expect(v.doseNumber, 2);
      expect(v.notes, 'Second dose');
    });

    test('null optional fields → null', () {
      final v = Vaccination.fromJson({
        'id': 'v1', 'wallet_id': 'w1', 'member_id': 'me',
        'vaccine_name': 'Flu', 'date_given': '2024-10-01',
      });
      expect(v.nextDue, isNull);
      expect(v.doseNumber, isNull);
    });

    test('date_given formatted as YYYY-MM-DD in toJson', () {
      final v = Vaccination(
        id: 'v1', walletId: 'w1', memberId: 'me',
        vaccineName: 'Flu', dateGiven: DateTime(2024, 10, 15),
      );
      expect(v.toJson()['date_given'], '2024-10-15');
    });

    test('null nextDue omitted from toJson', () {
      final v = Vaccination(
        id: 'v1', walletId: 'w1', memberId: 'me',
        vaccineName: 'Flu', dateGiven: DateTime(2024, 10, 1),
      );
      expect(v.toJson().containsKey('next_due'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 15. InsurancePolicy — fromJson / toJson / isExpired / expiresSoon
  // ═══════════════════════════════════════════════════════════════════════════
  group('InsurancePolicy.isExpired', () {
    test('null expiryDate → false', () {
      final p = InsurancePolicy(id: 'p1', walletId: 'w1', memberId: 'me', policyName: 'Health');
      expect(p.isExpired, isFalse);
    });

    test('past expiryDate → true', () {
      final p = InsurancePolicy(id: 'p1', walletId: 'w1', memberId: 'me', policyName: 'Health',
          expiryDate: DateTime(2020, 1, 1));
      expect(p.isExpired, isTrue);
    });

    test('future expiryDate → false', () {
      final p = InsurancePolicy(id: 'p1', walletId: 'w1', memberId: 'me', policyName: 'Health',
          expiryDate: DateTime(2030, 1, 1));
      expect(p.isExpired, isFalse);
    });
  });

  group('InsurancePolicy.expiresSoon', () {
    test('null expiryDate → false', () {
      final p = InsurancePolicy(id: 'p1', walletId: 'w1', memberId: 'me', policyName: 'Health');
      expect(p.expiresSoon, isFalse);
    });

    test('already expired → false (expiresSoon checks !isExpired)', () {
      final p = InsurancePolicy(id: 'p1', walletId: 'w1', memberId: 'me', policyName: 'Health',
          expiryDate: DateTime(2020, 1, 1));
      expect(p.expiresSoon, isFalse);
    });

    test('expires within 60 days → true', () {
      final p = InsurancePolicy(id: 'p1', walletId: 'w1', memberId: 'me', policyName: 'Health',
          expiryDate: DateTime.now().add(const Duration(days: 30)));
      expect(p.expiresSoon, isTrue);
    });

    test('expires > 60 days → false', () {
      final p = InsurancePolicy(id: 'p1', walletId: 'w1', memberId: 'me', policyName: 'Health',
          expiryDate: DateTime.now().add(const Duration(days: 90)));
      expect(p.expiresSoon, isFalse);
    });
  });

  group('InsurancePolicy.fromJson / toJson', () {
    test('all fields parsed', () {
      final p = InsurancePolicy.fromJson({
        'id': 'p1', 'wallet_id': 'w1', 'member_id': 'me',
        'policy_name': 'Star Health', 'policy_number': 'SH123',
        'provider': 'Star Health Insurance', 'notes': 'Family floater',
        'coverage_amount': 500000.0, 'expiry_date': '2026-03-31',
      });
      expect(p.policyName, 'Star Health');
      expect(p.policyNumber, 'SH123');
      expect(p.coverageAmount, 500000.0);
      expect(p.expiryDate, DateTime(2026, 3, 31));
    });

    test('coverage_amount as int → toDouble', () {
      final p = InsurancePolicy.fromJson({
        'id': 'p1', 'wallet_id': 'w1', 'member_id': 'me',
        'policy_name': 'X', 'coverage_amount': 500000,
      });
      expect(p.coverageAmount, 500000.0);
    });

    test('null optional fields omitted from toJson', () {
      final p = InsurancePolicy(id: 'p1', walletId: 'w1', memberId: 'me', policyName: 'X');
      final j = p.toJson();
      expect(j.containsKey('policy_number'), isFalse);
      expect(j.containsKey('coverage_amount'), isFalse);
      expect(j.containsKey('expiry_date'), isFalse);
    });

    test('expiry_date formatted as YYYY-MM-DD in toJson', () {
      final p = InsurancePolicy(id: 'p1', walletId: 'w1', memberId: 'me', policyName: 'X',
          expiryDate: DateTime(2026, 12, 31));
      expect(p.toJson()['expiry_date'], '2026-12-31');
    });
  });
}
