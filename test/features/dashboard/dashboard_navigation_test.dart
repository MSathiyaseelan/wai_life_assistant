import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/core/services/dash_nav_service.dart';
import 'package:wai_life_assistant/routes/app_routes.dart';

// ─── Mirrors of private _DashboardScreenState helpers ────────────────────────

String greeting(int hour) {
  if (hour < 12) return 'Good morning,';
  if (hour < 17) return 'Good afternoon,';
  if (hour < 21) return 'Good evening,';
  return 'Good night,';
}

String initials(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'A';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

String fmtDob(String iso) {
  try {
    final d = DateTime.parse(iso);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  } catch (_) {
    return iso;
  }
}

bool isToday(DateTime d) {
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

bool isPlaceholder(String id) => id.isEmpty || id == 'personal';

// Mirror of local plateHeight inside build.
// 54 (header) + 28 (padding) + 58 (icon+label+dash) + maxCol * 46 + 32
double plateHeight(List<Object> mealTimes) {
  final byTime = <Object, int>{};
  for (final mt in mealTimes) {
    byTime[mt] = (byTime[mt] ?? 0) + 1;
  }
  final maxCol = byTime.values.fold(0, (a, b) => a > b ? a : b);
  return 54.0 + 28.0 + 58.0 + maxCol * 46.0 + 32.0;
}

// Mirror of local listCardHeight inside build.
// header(38) + subheader(43) + row(42) + addBtn(49) + empty(88)
double listCardHeight(int groceryCount, int quickCount) {
  final g = groceryCount;
  final q = quickCount;
  if (g == 0 && q == 0) return 38 + 88 + 49;
  double h = 38;
  if (g > 0) {
    h += 43 + g.clamp(0, 3) * 42;
    if (g > 3) h += 25;
  }
  if (q > 0) {
    if (g > 0) h += 1;
    h += 43 + q * 42;
  }
  return h + 49;
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. DashNavService — signal bus
  // ═══════════════════════════════════════════════════════════════════════════
  group('DashNavService', () {
    setUp(() {
      DashNavService.planIt.value = null;
      DashNavService.myHub.value = null;
      DashNavService.pantry.value = null;
    });

    test('planIt notifier starts null', () {
      expect(DashNavService.planIt.value, isNull);
    });

    test('myHub notifier starts null', () {
      expect(DashNavService.myHub.value, isNull);
    });

    test('pantry notifier starts null', () {
      expect(DashNavService.pantry.value, isNull);
    });

    test('planIt signals: alerts, tasks, special_days, wishes', () {
      for (final signal in ['alerts', 'tasks', 'special_days', 'wishes']) {
        DashNavService.planIt.value = signal;
        expect(DashNavService.planIt.value, signal);
        DashNavService.planIt.value = null;
      }
    });

    test('myHub signals: health:meds, health:appointments, health:vaccines, functions', () {
      for (final signal in [
        'health:meds',
        'health:appointments',
        'health:vaccines',
        'functions',
      ]) {
        DashNavService.myHub.value = signal;
        expect(DashNavService.myHub.value, signal);
        DashNavService.myHub.value = null;
      }
    });

    test('pantry signals: basket:tobuy, meal_map, meal_map with walletId', () {
      DashNavService.pantry.value = 'basket:tobuy';
      expect(DashNavService.pantry.value, 'basket:tobuy');

      DashNavService.pantry.value = 'meal_map';
      expect(DashNavService.pantry.value, 'meal_map');

      DashNavService.pantry.value = 'meal_map:family_wallet_id';
      expect(DashNavService.pantry.value, 'meal_map:family_wallet_id');
    });

    test('setting same value twice does not re-notify (ValueNotifier equality)', () {
      DashNavService.planIt.value = 'tasks';
      int callCount = 0;
      DashNavService.planIt.addListener(() => callCount++);
      DashNavService.planIt.value = 'tasks'; // same value — no notification
      expect(callCount, 0);
      DashNavService.planIt.value = 'alerts'; // different — notifies
      expect(callCount, 1);
    });

    test('listener fires when value changes', () {
      String? received;
      DashNavService.myHub.addListener(() {
        received = DashNavService.myHub.value;
      });
      DashNavService.myHub.value = 'functions';
      expect(received, 'functions');
    });

    test('listener can be removed', () {
      int count = 0;
      void listener() => count++;
      DashNavService.pantry.addListener(listener);
      DashNavService.pantry.value = 'meal_map';
      expect(count, 1);
      DashNavService.pantry.removeListener(listener);
      DashNavService.pantry.value = null;
      expect(count, 1); // no further notification
    });

    test('all three notifiers are independent', () {
      DashNavService.planIt.value = 'wishes';
      DashNavService.myHub.value = 'health:meds';
      DashNavService.pantry.value = 'basket:tobuy';
      expect(DashNavService.planIt.value, 'wishes');
      expect(DashNavService.myHub.value, 'health:meds');
      expect(DashNavService.pantry.value, 'basket:tobuy');
    });

    test('pantry meal_map walletId is embedded correctly', () {
      const walletId = 'f1_family_wallet';
      DashNavService.pantry.value = 'meal_map:$walletId';
      final signal = DashNavService.pantry.value!;
      expect(signal.startsWith('meal_map:'), true);
      expect(signal.split(':').last, walletId);
    });

    test('basket:tobuy with walletId is embedded correctly', () {
      const walletId = 'f1_family_wallet';
      DashNavService.pantry.value = 'basket:tobuy:$walletId';
      final signal = DashNavService.pantry.value!;
      expect(signal.startsWith('basket:tobuy:'), true);
      expect(signal.split(':').last, walletId);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. AppRoutes constants
  // ═══════════════════════════════════════════════════════════════════════════
  group('AppRoutes', () {
    test('named route constants have expected values', () {
      expect(AppRoutes.splash, '/');
      expect(AppRoutes.dashboard, '/dashboard');
      expect(AppRoutes.login, '/login');
      expect(AppRoutes.otp, '/otp');
      expect(AppRoutes.profileSetup, '/profileSetup');
      expect(AppRoutes.bottomNav, '/bottomNav');
    });

    test('feature route constants exist', () {
      expect(AppRoutes.wallet, '/wallet');
      expect(AppRoutes.pantry, '/pantry');
      expect(AppRoutes.planit, '/planit');
      expect(AppRoutes.functions, '/functions');
      expect(AppRoutes.settings, '/settings');
    });

    test('routes map contains navigable route keys', () {
      expect(AppRoutes.routes.containsKey(AppRoutes.splash), true);
      expect(AppRoutes.routes.containsKey(AppRoutes.dashboard), true);
      expect(AppRoutes.routes.containsKey(AppRoutes.login), true);
      expect(AppRoutes.routes.containsKey(AppRoutes.otp), true);
      expect(AppRoutes.routes.containsKey(AppRoutes.profileSetup), true);
      expect(AppRoutes.routes.containsKey(AppRoutes.bottomNav), true);
    });

    test('feature routes are NOT in the routes map (pushed imperatively)', () {
      expect(AppRoutes.routes.containsKey(AppRoutes.wallet), false);
      expect(AppRoutes.routes.containsKey(AppRoutes.pantry), false);
      expect(AppRoutes.routes.containsKey(AppRoutes.planit), false);
    });

    test('all route paths start with /', () {
      for (final key in AppRoutes.routes.keys) {
        expect(key.startsWith('/'), true, reason: 'route "$key" must start with /');
      }
    });

    test('no duplicate route keys', () {
      final keys = AppRoutes.routes.keys.toList();
      expect(keys.toSet().length, keys.length);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Greeting helper
  // ═══════════════════════════════════════════════════════════════════════════
  group('greeting()', () {
    test('hour 0 → Good morning', () => expect(greeting(0), 'Good morning,'));
    test('hour 6 → Good morning', () => expect(greeting(6), 'Good morning,'));
    test('hour 11 → Good morning', () => expect(greeting(11), 'Good morning,'));
    test('hour 12 → Good afternoon', () => expect(greeting(12), 'Good afternoon,'));
    test('hour 14 → Good afternoon', () => expect(greeting(14), 'Good afternoon,'));
    test('hour 16 → Good afternoon', () => expect(greeting(16), 'Good afternoon,'));
    test('hour 17 → Good evening', () => expect(greeting(17), 'Good evening,'));
    test('hour 20 → Good evening', () => expect(greeting(20), 'Good evening,'));
    test('hour 21 → Good night', () => expect(greeting(21), 'Good night,'));
    test('hour 23 → Good night', () => expect(greeting(23), 'Good night,'));

    test('all greetings end with a comma', () {
      for (int h = 0; h < 24; h++) {
        expect(greeting(h).endsWith(','), true, reason: 'hour $h');
      }
    });

    test('exactly 4 distinct greetings across 24 hours', () {
      final distinct = {for (int h = 0; h < 24; h++) greeting(h)};
      expect(distinct.length, 4);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Initials helper
  // ═══════════════════════════════════════════════════════════════════════════
  group('initials()', () {
    test('empty string → A', () => expect(initials(''), 'A'));
    test('only spaces → A', () => expect(initials('   '), 'A'));
    test('single word → first letter uppercase', () => expect(initials('ravi'), 'R'));
    test('single word already uppercase', () => expect(initials('Arjun'), 'A'));
    test('two words → first letters of each', () => expect(initials('Ravi Kumar'), 'RK'));
    test('two words lowercase → uppercase initials', () =>
        expect(initials('john doe'), 'JD'));
    test('three words → only first two count', () =>
        expect(initials('Sathiya Seelan Kumar'), 'SS'));
    test('extra spaces between words are ignored', () =>
        expect(initials('Priya  Sharma'), 'PS'));
    test('leading/trailing spaces stripped', () =>
        expect(initials('  Arun Raj  '), 'AR'));
    test('single letter name', () => expect(initials('A'), 'A'));
    test('name with hyphen treated as one word', () =>
        expect(initials('Mary-Jane'), 'M')); // hyphen not a splitter
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. fmtDob helper
  // ═══════════════════════════════════════════════════════════════════════════
  group('fmtDob()', () {
    test('formats 2000-01-15 → 15 Jan 2000', () =>
        expect(fmtDob('2000-01-15'), '15 Jan 2000'));
    test('formats 1990-12-31 → 31 Dec 1990', () =>
        expect(fmtDob('1990-12-31'), '31 Dec 1990'));
    test('day without leading zero in output', () =>
        expect(fmtDob('2005-03-07'), '7 Mar 2005'));
    test('all month abbreviations are 3 chars', () {
      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec',
      ];
      for (int m = 1; m <= 12; m++) {
        final iso = '2000-${m.toString().padLeft(2,'0')}-01';
        final result = fmtDob(iso);
        final parts = result.split(' ');
        expect(parts[1].length, 3, reason: 'month $m');
        expect(parts[1], months[m - 1], reason: 'month $m');
      }
    });
    test('invalid ISO string returned as-is', () =>
        expect(fmtDob('not-a-date'), 'not-a-date'));
    test('empty string returned as-is', () =>
        expect(fmtDob(''), ''));
    test('non-date string with dashes returned as-is', () =>
        expect(fmtDob('01-January-2000'), '01-January-2000'));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. isToday helper
  // ═══════════════════════════════════════════════════════════════════════════
  group('isToday()', () {
    test('DateTime.now() is today', () => expect(isToday(DateTime.now()), true));
    test('yesterday is not today', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(isToday(yesterday), false);
    });
    test('tomorrow is not today', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(isToday(tomorrow), false);
    });
    test('same date different time is today', () {
      final now = DateTime.now();
      final sameDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      expect(isToday(sameDay), true);
    });
    test('same date end of day is today', () {
      final now = DateTime.now();
      final eod = DateTime(now.year, now.month, now.day, 23, 59, 59);
      expect(isToday(eod), true);
    });
    test('a date far in the past is not today', () {
      expect(isToday(DateTime(2000, 1, 1)), false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. isPlaceholder helper
  // ═══════════════════════════════════════════════════════════════════════════
  group('isPlaceholder()', () {
    test('empty string is placeholder', () => expect(isPlaceholder(''), true));
    test('"personal" is placeholder', () => expect(isPlaceholder('personal'), true));
    test('real wallet id is not placeholder', () =>
        expect(isPlaceholder('wallet_abc_123'), false));
    test('"PERSONAL" (uppercase) is not placeholder', () =>
        expect(isPlaceholder('PERSONAL'), false));
    test('"personal2" is not placeholder', () =>
        expect(isPlaceholder('personal2'), false));
    test('space-only string is not placeholder', () =>
        expect(isPlaceholder(' '), false));
    test('family wallet id is not placeholder', () =>
        expect(isPlaceholder('f1'), false));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. plateHeight helper (meal card height calculation)
  // ═══════════════════════════════════════════════════════════════════════════
  group('plateHeight()', () {
    test('no meals → base height (maxCol=0)', () {
      // 54 + 28 + 58 + 0*46 + 32 = 172
      expect(plateHeight([]), 172.0);
    });

    test('1 meal of one mealTime → maxCol=1 → 172+46=218', () {
      expect(plateHeight(['breakfast']), 218.0);
    });

    test('2 meals of same mealTime → maxCol=2 → 172+92=264', () {
      expect(plateHeight(['breakfast', 'breakfast']), 264.0);
    });

    test('2 meals of different mealTime → maxCol=1 (each column=1) → 218', () {
      expect(plateHeight(['breakfast', 'lunch']), 218.0);
    });

    test('3 meals: breakfast×2, lunch×1 → maxCol=2 → 264', () {
      expect(plateHeight(['breakfast', 'breakfast', 'lunch']), 264.0);
    });

    test('maxCol comes from the busiest mealTime slot', () {
      // dinner: 3 entries, lunch: 1 entry → maxCol=3 → 172 + 3*46 = 310
      expect(
        plateHeight(['dinner', 'dinner', 'dinner', 'lunch']),
        310.0,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. listCardHeight helper (shopping list card height)
  // ═══════════════════════════════════════════════════════════════════════════
  group('listCardHeight()', () {
    test('empty list → 38 + 88 + 49 = 175', () {
      expect(listCardHeight(0, 0), 175.0);
    });

    test('1 grocery, 0 quick → 38 + 43 + 1*42 + 49 = 172', () {
      expect(listCardHeight(1, 0), 38 + 43 + 1 * 42 + 49.0);
    });

    test('3 groceries, 0 quick → capped at 3 rows → 38+43+3*42+49=256', () {
      expect(listCardHeight(3, 0), 38 + 43 + 3 * 42 + 49.0);
    });

    test('4 groceries → 3 capped rows + "show more" +25 → 38+43+3*42+25+49=281', () {
      expect(listCardHeight(4, 0), 38 + 43 + 3 * 42 + 25 + 49.0);
    });

    test('5 groceries → same cap + show more (one +25 only)', () {
      expect(listCardHeight(5, 0), 38 + 43 + 3 * 42 + 25 + 49.0);
    });

    test('0 grocery, 2 quick → 38 + 43 + 2*42 + 49 = 214', () {
      expect(listCardHeight(0, 2), 38 + 43 + 2 * 42 + 49.0);
    });

    test('1 grocery + 1 quick → both sections, separator +1 between', () {
      // 38 + (43 + 1*42) + 1 + (43 + 1*42) + 49
      final expected = 38 + 43 + 42 + 1 + 43 + 42 + 49.0;
      expect(listCardHeight(1, 1), expected);
    });

    test('3 groceries + 3 quick → cap on grocery rows', () {
      // 38 + (43 + 3*42) + 1 + (43 + 3*42) + 49
      final expected = 38 + 43 + 3 * 42 + 1 + 43 + 3 * 42 + 49.0;
      expect(listCardHeight(3, 3), expected);
    });

    test('grocery section only shows max 3 rows before +25 cap', () {
      final three = listCardHeight(3, 0);
      final four = listCardHeight(4, 0);
      expect(four - three, 25.0); // only the "+N more" pill added
    });

    test('adding more than 4 groceries does not change height (capped)', () {
      expect(listCardHeight(4, 0), listCardHeight(10, 0));
    });
  });
}
