// Tests for the pure summary logic in _MyHubScreenState (my_hub_screen.dart).
//
// The logic lives in `build()` and `_fmtDate()` — all pure Dart computations.
// We replicate each computation as a top-level helper here so it can be tested
// without a widget tree or Supabase.
//
// All helpers are direct mirrors of the production code; no behaviour is added
// or removed.

import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers mirrored from _MyHubScreenState
// ─────────────────────────────────────────────────────────────────────────────

/// Mirror of _MyHubScreenState._fmtDate(DateTime d)
String fmtDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

/// Mirror of the functions summary block in build().
/// Returns up to 2 summary rows.
List<String> functionSummaryRows(List<FunctionModel> functions) {
  return functions.take(2).map((f) {
    final diff = f.functionDate?.difference(DateTime.now()).inDays;
    String when = '';
    if (diff != null) {
      if (diff < 0) {
        when = 'Past';
      } else if (diff == 0) {
        when = 'Today';
      } else if (diff == 1) {
        when = 'Tomorrow';
      } else {
        when = 'in $diff days';
      }
    }
    return '🎊 ${f.title}${when.isNotEmpty ? ' · $when' : ''}';
  }).toList();
}

/// Mirror of the item locator summary block in build().
/// (personal-mode: all containers/items passed in)
List<String> locatorSummaryRows(
    List<StorageContainer> containers, List<StoredItem> items) {
  final itemCount = items.length;
  final importantCount = items.where((i) => i.isImportant).length;
  final lastImportant = (items.where((i) => i.isImportant).toList()
        ..sort((a, b) => b.storedOn.compareTo(a.storedOn)))
      .firstOrNull;
  return (containers.isNotEmpty || items.isNotEmpty)
      ? [
          '📦  ${containers.length} ${containers.length == 1 ? 'Container' : 'Containers'} · $itemCount ${itemCount == 1 ? 'item' : 'items'}',
          if (lastImportant != null)
            '⭐  ${lastImportant.name}${lastImportant.description != null ? ' · ${lastImportant.description}' : ''}',
          if (lastImportant == null && importantCount > 0)
            '⭐  $importantCount important',
        ]
      : <String>[];
}

/// Mirror of the wardrobe summary block in build().
List<String> wardrobeSummaryRows(List<ClothingItem> items) {
  final wardrobeCount = items.where((c) => !c.wishlist).length;
  final wishlistCount = items.where((c) => c.wishlist).length;
  final lastWardrobe = (items.where((c) => !c.wishlist).toList()
        ..sort((a, b) => b.addedOn.compareTo(a.addedOn)))
      .firstOrNull;
  return items.isNotEmpty
      ? [
          '👗  $wardrobeCount ${wardrobeCount == 1 ? 'item' : 'items'} in wardrobe'
              '${wishlistCount > 0 ? '  ·  💛 $wishlistCount wishlist' : ''}',
          if (lastWardrobe != null)
            '🆕  ${lastWardrobe.name}'
                '${lastWardrobe.color != null ? ' · ${lastWardrobe.color}' : ''}',
        ]
      : <String>[];
}

/// Mirror of the health summary block in build().
/// [fmtDateFn] is injected so tests can verify the exact date text.
List<String> healthSummaryRows({
  required int medications,
  required int appointments,
  DateTime? nextApptDate,
  String? nextApptDoctor,
  String Function(DateTime)? fmtDateFn,
}) {
  final fmt = fmtDateFn ?? fmtDate;
  return (medications > 0 || appointments > 0)
      ? [
          if (medications > 0)
            '💊  $medications active ${medications == 1 ? 'medication' : 'medications'}',
          if (nextApptDate != null)
            '📅  ${nextApptDoctor?.isNotEmpty == true ? nextApptDoctor! : 'Appointment'} · ${fmt(nextApptDate)}'
          else if (appointments > 0)
            '📅  $appointments upcoming ${appointments == 1 ? 'appointment' : 'appointments'}',
        ]
      : <String>[];
}

// ─────────────────────────────────────────────────────────────────────────────
// Test-data helpers
// ─────────────────────────────────────────────────────────────────────────────

FunctionModel mkFn(String title, {DateTime? date, String id = 'f1'}) =>
    FunctionModel(
      id: id, walletId: 'w1', type: FunctionType.wedding,
      title: title, functionDate: date,
    );

StorageContainer mkContainer({
  String id = 'c1',
  String walletId = 'w1',
  String name = 'Box 1',
}) => StorageContainer(
      id: id, walletId: walletId, type: StorageType.box, name: name,
    );

StoredItem mkItem({
  String id = 'si1',
  String name = 'Passport',
  String? description,
  bool isImportant = false,
  DateTime? storedOn,
}) => StoredItem(
      id: id, walletId: 'w1', containerId: 'c1', name: name,
      description: description,
      isImportant: isImportant,
      storedOn: storedOn ?? DateTime(2024, 1, 1),
    );

ClothingItem mkClothing({
  String id = 'ci1',
  String name = 'White Shirt',
  bool wishlist = false,
  String? color,
  DateTime? addedOn,
}) => ClothingItem(
      id: id, walletId: 'w1', memberId: 'me', name: name,
      category: ClothingCategory.topwear, gender: ClothingGender.male,
      wishlist: wishlist, color: color,
      addedOn: addedOn ?? DateTime(2024, 1, 1),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. _fmtDate — relative day labels and month-day fallback
  // ═══════════════════════════════════════════════════════════════════════════
  group('_fmtDate — relative labels', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    test('today (midnight) → "Today"', () {
      expect(fmtDate(today), 'Today');
    });

    test('today with time component → "Today" (time stripped)', () {
      expect(fmtDate(today.add(const Duration(hours: 11, minutes: 59))), 'Today');
    });

    test('tomorrow midnight → "Tomorrow"', () {
      expect(fmtDate(today.add(const Duration(days: 1))), 'Tomorrow');
    });

    test('yesterday midnight → "Yesterday"', () {
      expect(fmtDate(today.subtract(const Duration(days: 1))), 'Yesterday');
    });

    test('2 days from now → NOT "Tomorrow" (falls through to month-day)', () {
      final result = fmtDate(today.add(const Duration(days: 2)));
      expect(result, isNot('Tomorrow'));
      expect(result, isNot('Today'));
    });

    test('2 days ago → NOT "Yesterday"', () {
      final result = fmtDate(today.subtract(const Duration(days: 2)));
      expect(result, isNot('Yesterday'));
    });
  });

  group('_fmtDate — month-day fallback format', () {
    test('Jan 15 → "Jan 15"', () {
      // Use a fixed past date safely outside today±1
      expect(fmtDate(DateTime(2025, 1, 15)), 'Jan 15');
    });

    test('Feb 28 → "Feb 28"', () {
      expect(fmtDate(DateTime(2030, 2, 28)), 'Feb 28');
    });

    test('Mar 1 → "Mar 1" (no leading zero on day)', () {
      expect(fmtDate(DateTime(2025, 3, 1)), 'Mar 1');
    });

    test('Apr 10 → "Apr 10"', () {
      expect(fmtDate(DateTime(2025, 4, 10)), 'Apr 10');
    });

    test('May 20 → "May 20"', () {
      expect(fmtDate(DateTime(2030, 5, 20)), 'May 20');
    });

    test('Jun 5 → "Jun 5"', () {
      expect(fmtDate(DateTime(2030, 6, 5)), 'Jun 5');
    });

    test('Jul 4 → "Jul 4"', () {
      expect(fmtDate(DateTime(2030, 7, 4)), 'Jul 4');
    });

    test('Aug 25 → "Aug 25"', () {
      expect(fmtDate(DateTime(2025, 8, 25)), 'Aug 25');
    });

    test('Sep 15 → "Sep 15"', () {
      expect(fmtDate(DateTime(2025, 9, 15)), 'Sep 15');
    });

    test('Oct 31 → "Oct 31"', () {
      expect(fmtDate(DateTime(2030, 10, 31)), 'Oct 31');
    });

    test('Nov 11 → "Nov 11"', () {
      expect(fmtDate(DateTime(2030, 11, 11)), 'Nov 11');
    });

    test('Dec 31 → "Dec 31"', () {
      expect(fmtDate(DateTime(2030, 12, 31)), 'Dec 31');
    });

    test('uses d.day (integer, no leading zero) → day 3 gives "Mar 3" not "Mar 03"', () {
      expect(fmtDate(DateTime(2025, 3, 3)), 'Mar 3');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Functions summary rows
  // ═══════════════════════════════════════════════════════════════════════════
  group('functionSummaryRows — when labels', () {
    test('no functions → empty list', () {
      expect(functionSummaryRows([]), isEmpty);
    });

    test('function with no date → no suffix ("🎊 Title")', () {
      final rows = functionSummaryRows([mkFn('Arjun Wedding')]);
      expect(rows, ['🎊 Arjun Wedding']);
    });

    test('function with past date → "· Past"', () {
      final rows = functionSummaryRows([
        mkFn('Old Wedding', date: DateTime.now().subtract(const Duration(days: 3))),
      ]);
      expect(rows.first, '🎊 Old Wedding · Past');
    });

    test('function due today (hours away) → "· Today"', () {
      final rows = functionSummaryRows([
        mkFn('Today Event', date: DateTime.now().add(const Duration(hours: 2))),
      ]);
      expect(rows.first, '🎊 Today Event · Today');
    });

    test('function exactly 1 day away → "· Tomorrow"', () {
      final rows = functionSummaryRows([
        mkFn('Engagement', date: DateTime.now().add(const Duration(days: 1))),
      ]);
      expect(rows.first, '🎊 Engagement · Tomorrow');
    });

    test('function 5 days away → "· in 5 days"', () {
      final rows = functionSummaryRows([
        mkFn('Birthday', date: DateTime.now().add(const Duration(days: 5))),
      ]);
      expect(rows.first, '🎊 Birthday · in 5 days');
    });

    test('function 2 days away → "· in 2 days"', () {
      final rows = functionSummaryRows([
        mkFn('Naming', date: DateTime.now().add(const Duration(days: 2))),
      ]);
      expect(rows.first, '🎊 Naming · in 2 days');
    });
  });

  group('functionSummaryRows — count and take(2) cap', () {
    test('1 function → 1 row', () {
      expect(functionSummaryRows([mkFn('F1')]).length, 1);
    });

    test('2 functions → 2 rows', () {
      expect(functionSummaryRows([mkFn('F1'), mkFn('F2', id: 'f2')]).length, 2);
    });

    test('3 functions → capped at 2 rows (take(2))', () {
      expect(functionSummaryRows([
        mkFn('F1'), mkFn('F2', id: 'f2'), mkFn('F3', id: 'f3'),
      ]).length, 2);
    });

    test('take(2) preserves original order', () {
      final rows = functionSummaryRows([
        mkFn('Alpha'), mkFn('Beta', id: 'f2'), mkFn('Gamma', id: 'f3'),
      ]);
      expect(rows[0], contains('Alpha'));
      expect(rows[1], contains('Beta'));
    });

    test('each row starts with 🎊 emoji', () {
      final rows = functionSummaryRows([mkFn('F1'), mkFn('F2', id: 'f2')]);
      for (final r in rows) {
        expect(r, startsWith('🎊 '));
      }
    });

    test('title embedded verbatim in row', () {
      final rows = functionSummaryRows([mkFn('Priya & Arjun Wedding')]);
      expect(rows.first, contains('Priya & Arjun Wedding'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Locator summary rows
  // ═══════════════════════════════════════════════════════════════════════════
  group('locatorSummaryRows — empty state', () {
    test('no containers, no items → empty list', () {
      expect(locatorSummaryRows([], []), isEmpty);
    });
  });

  group('locatorSummaryRows — first row: container/item count', () {
    test('1 container, 1 item → singular forms', () {
      final rows = locatorSummaryRows([mkContainer()], [mkItem()]);
      expect(rows.first, '📦  1 Container · 1 item');
    });

    test('2 containers, 5 items → plural forms', () {
      final rows = locatorSummaryRows(
        [mkContainer(), mkContainer(id: 'c2')],
        [mkItem(), mkItem(id: 'si2'), mkItem(id: 'si3'), mkItem(id: 'si4'), mkItem(id: 'si5')],
      );
      expect(rows.first, '📦  2 Containers · 5 items');
    });

    test('0 containers, 3 items → "0 Containers · 3 items"', () {
      final rows = locatorSummaryRows(
        [],
        [mkItem(), mkItem(id: 'si2'), mkItem(id: 'si3')],
      );
      expect(rows.first, '📦  0 Containers · 3 items');
    });

    test('3 containers, 0 items → "3 Containers · 0 items"', () {
      final rows = locatorSummaryRows(
        [mkContainer(), mkContainer(id: 'c2'), mkContainer(id: 'c3')],
        [],
      );
      expect(rows.first, '📦  3 Containers · 0 items');
    });

    test('format prefix: "📦  " has 2 spaces after emoji', () {
      final rows = locatorSummaryRows([mkContainer()], []);
      expect(rows.first, startsWith('📦  '));
    });
  });

  group('locatorSummaryRows — second row: important item', () {
    test('no important items → only 1 row', () {
      final rows = locatorSummaryRows([mkContainer()], [mkItem(isImportant: false)]);
      expect(rows.length, 1);
    });

    test('1 important item without description → "⭐  Name"', () {
      final rows = locatorSummaryRows(
        [mkContainer()],
        [mkItem(name: 'Passport', isImportant: true)],
      );
      expect(rows.length, 2);
      expect(rows[1], '⭐  Passport');
    });

    test('1 important item with description → "⭐  Name · Description"', () {
      final rows = locatorSummaryRows(
        [mkContainer()],
        [mkItem(name: 'Passport', description: 'Valid till 2030', isImportant: true)],
      );
      expect(rows[1], '⭐  Passport · Valid till 2030');
    });

    test('important row has "⭐  " prefix with 2 spaces', () {
      final rows = locatorSummaryRows(
        [],
        [mkItem(name: 'X', isImportant: true)],
      );
      expect(rows[1], startsWith('⭐  '));
    });
  });

  group('locatorSummaryRows — lastImportant is most recently stored', () {
    test('picks newest storedOn among important items', () {
      final rows = locatorSummaryRows(
        [mkContainer()],
        [
          mkItem(id: 'si1', name: 'Old Doc',
              isImportant: true, storedOn: DateTime(2023, 1, 1)),
          mkItem(id: 'si2', name: 'New Doc',
              isImportant: true, storedOn: DateTime(2024, 6, 15)),
          mkItem(id: 'si3', name: 'Mid Doc',
              isImportant: true, storedOn: DateTime(2023, 12, 1)),
        ],
      );
      expect(rows[1], contains('New Doc')); // newest storedOn
    });

    test('non-important items excluded from lastImportant selection', () {
      final rows = locatorSummaryRows(
        [],
        [
          mkItem(id: 'si1', name: 'Important One',
              isImportant: true, storedOn: DateTime(2024, 1, 1)),
          mkItem(id: 'si2', name: 'Not Important',
              isImportant: false, storedOn: DateTime(2025, 1, 1)), // newer but not important
        ],
      );
      expect(rows[1], contains('Important One'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Wardrobe summary rows
  // ═══════════════════════════════════════════════════════════════════════════
  group('wardrobeSummaryRows — empty state', () {
    test('no items → empty list', () {
      expect(wardrobeSummaryRows([]), isEmpty);
    });
  });

  group('wardrobeSummaryRows — first row: count and wishlist', () {
    test('1 non-wishlist item, no wishlist → "👗  1 item in wardrobe"', () {
      final rows = wardrobeSummaryRows([mkClothing(wishlist: false)]);
      expect(rows.first, '👗  1 item in wardrobe');
    });

    test('3 non-wishlist items → "👗  3 items in wardrobe"', () {
      final rows = wardrobeSummaryRows([
        mkClothing(), mkClothing(id: 'ci2'), mkClothing(id: 'ci3'),
      ]);
      expect(rows.first, '👗  3 items in wardrobe');
    });

    test('2 non-wishlist, 1 wishlist → wishlist suffix included', () {
      final rows = wardrobeSummaryRows([
        mkClothing(id: 'ci1', wishlist: false),
        mkClothing(id: 'ci2', wishlist: false),
        mkClothing(id: 'ci3', wishlist: true),
      ]);
      expect(rows.first, '👗  2 items in wardrobe  ·  💛 1 wishlist');
    });

    test('0 non-wishlist, 2 wishlist items → "0 items in wardrobe  ·  💛 2 wishlist"', () {
      final rows = wardrobeSummaryRows([
        mkClothing(id: 'ci1', wishlist: true),
        mkClothing(id: 'ci2', wishlist: true),
      ]);
      expect(rows.first, '👗  0 items in wardrobe  ·  💛 2 wishlist');
    });

    test('no wishlist items → no wishlist suffix', () {
      final rows = wardrobeSummaryRows([mkClothing(wishlist: false)]);
      expect(rows.first, isNot(contains('wishlist')));
    });

    test('wishlist separator is "  ·  " (2 spaces on each side)', () {
      final rows = wardrobeSummaryRows([
        mkClothing(id: 'ci1', wishlist: false),
        mkClothing(id: 'ci2', wishlist: true),
      ]);
      expect(rows.first, contains('  ·  💛'));
    });

    test('"👗  " has 2 spaces after emoji', () {
      final rows = wardrobeSummaryRows([mkClothing()]);
      expect(rows.first, startsWith('👗  '));
    });
  });

  group('wardrobeSummaryRows — second row: most recent non-wishlist item', () {
    test('1 non-wishlist item → second row with name', () {
      final rows = wardrobeSummaryRows([mkClothing(name: 'Oxford Shirt')]);
      expect(rows.length, 2);
      expect(rows[1], '🆕  Oxford Shirt');
    });

    test('non-wishlist item with color → "🆕  Name · Color"', () {
      final rows = wardrobeSummaryRows([
        mkClothing(name: 'Chinos', color: 'Navy', wishlist: false),
      ]);
      expect(rows[1], '🆕  Chinos · Navy');
    });

    test('non-wishlist item without color → no color suffix', () {
      final rows = wardrobeSummaryRows([mkClothing(name: 'Veshti')]);
      expect(rows[1], '🆕  Veshti');
    });

    test('only wishlist items → no second row (lastWardrobe null)', () {
      final rows = wardrobeSummaryRows([mkClothing(wishlist: true)]);
      expect(rows.length, 1);
    });

    test('"🆕  " has 2 spaces after emoji', () {
      final rows = wardrobeSummaryRows([mkClothing()]);
      expect(rows[1], startsWith('🆕  '));
    });

    test('color separator " · " has single space on each side', () {
      final rows = wardrobeSummaryRows([mkClothing(name: 'Shirt', color: 'White')]);
      expect(rows[1], '🆕  Shirt · White');
    });
  });

  group('wardrobeSummaryRows — lastWardrobe is most recently added non-wishlist', () {
    test('picks newest addedOn among non-wishlist items', () {
      final rows = wardrobeSummaryRows([
        mkClothing(id: 'ci1', name: 'Old Shirt', wishlist: false, addedOn: DateTime(2023, 1, 1)),
        mkClothing(id: 'ci2', name: 'New Kurta', wishlist: false, addedOn: DateTime(2024, 9, 15)),
        mkClothing(id: 'ci3', name: 'Mid Jeans', wishlist: false, addedOn: DateTime(2024, 3, 20)),
      ]);
      expect(rows[1], contains('New Kurta')); // newest addedOn
    });

    test('wishlist items excluded from lastWardrobe', () {
      final rows = wardrobeSummaryRows([
        mkClothing(id: 'ci1', name: 'My Shirt', wishlist: false, addedOn: DateTime(2024, 1, 1)),
        mkClothing(id: 'ci2', name: 'Wishlist Blazer', wishlist: true, addedOn: DateTime(2025, 1, 1)), // newer
      ]);
      expect(rows[1], contains('My Shirt')); // wishlist ignored
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. Health summary rows
  // ═══════════════════════════════════════════════════════════════════════════
  group('healthSummaryRows — empty state', () {
    test('0 medications, 0 appointments → empty list', () {
      expect(healthSummaryRows(medications: 0, appointments: 0), isEmpty);
    });

    test('0 of each even with nextApptDate → guard prevents any output', () {
      expect(healthSummaryRows(
        medications: 0, appointments: 0,
        nextApptDate: DateTime.now(),
      ), isEmpty);
    });
  });

  group('healthSummaryRows — medication row', () {
    test('1 medication → singular "medication"', () {
      final rows = healthSummaryRows(medications: 1, appointments: 0);
      expect(rows, ['💊  1 active medication']);
    });

    test('3 medications → plural "medications"', () {
      final rows = healthSummaryRows(medications: 3, appointments: 0);
      expect(rows, ['💊  3 active medications']);
    });

    test('"💊  " prefix has 2 spaces after emoji', () {
      final rows = healthSummaryRows(medications: 1, appointments: 0);
      expect(rows.first, startsWith('💊  '));
    });

    test('0 medications → no medication row', () {
      final rows = healthSummaryRows(
        medications: 0, appointments: 2,
      );
      expect(rows, isNot(contains(contains('medication'))));
    });
  });

  group('healthSummaryRows — appointment row with nextApptDate', () {
    test('nextApptDate set, doctor name present → "📅  DrName · <date>"', () {
      final rows = healthSummaryRows(
        medications: 0, appointments: 1, // guard needs at least one > 0
        nextApptDate: DateTime(2025, 1, 15),
        nextApptDoctor: 'Dr. Sharma',
        fmtDateFn: (_) => 'Jan 15',
      );
      expect(rows, ['📅  Dr. Sharma · Jan 15']);
    });

    test('nextApptDate set, doctor empty string → falls back to "Appointment"', () {
      final rows = healthSummaryRows(
        medications: 0, appointments: 1,
        nextApptDate: DateTime(2025, 3, 10),
        nextApptDoctor: '',
        fmtDateFn: (_) => 'Mar 10',
      );
      expect(rows.last, '📅  Appointment · Mar 10');
    });

    test('nextApptDate set, doctor null → falls back to "Appointment"', () {
      final rows = healthSummaryRows(
        medications: 0, appointments: 1,
        nextApptDate: DateTime(2025, 5, 20),
        nextApptDoctor: null,
        fmtDateFn: (_) => 'May 20',
      );
      expect(rows.last, '📅  Appointment · May 20');
    });

    test('"📅  " prefix has 2 spaces after emoji', () {
      final rows = healthSummaryRows(
        medications: 0, appointments: 1,
        nextApptDate: DateTime(2025, 1, 1),
        fmtDateFn: (_) => 'Jan 1',
      );
      expect(rows.last, startsWith('📅  '));
    });

    test('date joined to doctor with " · " (single space on each side)', () {
      final rows = healthSummaryRows(
        medications: 0, appointments: 1,
        nextApptDate: DateTime(2025, 6, 15),
        nextApptDoctor: 'Dr. X',
        fmtDateFn: (_) => 'Jun 15',
      );
      // "📅  Dr. X · Jun 15" — single space each side of dot
      expect(rows.last, '📅  Dr. X · Jun 15');
    });
  });

  group('healthSummaryRows — appointment row without nextApptDate (count fallback)', () {
    test('nextApptDate null, 1 appointment → singular "appointment"', () {
      final rows = healthSummaryRows(medications: 0, appointments: 1);
      expect(rows, ['📅  1 upcoming appointment']);
    });

    test('nextApptDate null, 3 appointments → plural "appointments"', () {
      final rows = healthSummaryRows(medications: 0, appointments: 3);
      expect(rows, ['📅  3 upcoming appointments']);
    });

    test('nextApptDate null, 0 appointments → no appointment row', () {
      final rows = healthSummaryRows(medications: 2, appointments: 0);
      expect(rows.length, 1); // only medication row
      expect(rows.first, contains('medication'));
    });
  });

  group('healthSummaryRows — combined medications + appointment rows', () {
    test('medications + nextApptDate → 2 rows', () {
      final rows = healthSummaryRows(
        medications: 2, appointments: 0,
        nextApptDate: DateTime(2025, 8, 5),
        nextApptDoctor: 'Dr. Kumar',
        fmtDateFn: (_) => 'Aug 5',
      );
      expect(rows.length, 2);
      expect(rows[0], '💊  2 active medications');
      expect(rows[1], '📅  Dr. Kumar · Aug 5');
    });

    test('medications + appointments (no date) → 2 rows', () {
      final rows = healthSummaryRows(medications: 3, appointments: 2);
      expect(rows.length, 2);
      expect(rows[0], '💊  3 active medications');
      expect(rows[1], '📅  2 upcoming appointments');
    });

    test('nextApptDate takes priority over appointment count', () {
      // When both nextApptDate and appointments are set, date-based row wins
      final rows = healthSummaryRows(
        medications: 0, appointments: 5,
        nextApptDate: DateTime(2025, 9, 1),
        nextApptDoctor: 'Dr. Anbu',
        fmtDateFn: (_) => 'Sep 1',
      );
      expect(rows.length, 1);
      expect(rows.first, contains('Dr. Anbu'));
      expect(rows.first, isNot(contains('upcoming')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. _fmtDate used in health summary (integration)
  // ═══════════════════════════════════════════════════════════════════════════
  group('healthSummaryRows — fmtDate integration (real relative dates)', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    test('appointment today → "📅  Doctor · Today"', () {
      final rows = healthSummaryRows(
        medications: 0, appointments: 1,
        nextApptDate: today,
        nextApptDoctor: 'Dr. Raj',
      );
      expect(rows.last, '📅  Dr. Raj · Today');
    });

    test('appointment tomorrow → "📅  Doctor · Tomorrow"', () {
      final rows = healthSummaryRows(
        medications: 0, appointments: 1,
        nextApptDate: today.add(const Duration(days: 1)),
        nextApptDoctor: 'Dr. Priya',
      );
      expect(rows.last, '📅  Dr. Priya · Tomorrow');
    });

    test('appointment yesterday → "📅  Appointment · Yesterday"', () {
      final rows = healthSummaryRows(
        medications: 0, appointments: 1,
        nextApptDate: today.subtract(const Duration(days: 1)),
        nextApptDoctor: '',
      );
      expect(rows.last, '📅  Appointment · Yesterday');
    });

    test('appointment on fixed past date → month-day format', () {
      final rows = healthSummaryRows(
        medications: 0, appointments: 1,
        nextApptDate: DateTime(2025, 8, 20),
        nextApptDoctor: 'Dr. X',
      );
      expect(rows.last, '📅  Dr. X · Aug 20');
    });
  });
}
