// Tests for WeekCalendarStrip private helpers, mirrored as top-level functions.
//
// Source: lib/features/pantry/widgets/week_calendar_strip.dart
//
// All three helpers are pure DateTime logic — no widget tree, no Flutter
// binding, no Supabase. The mirrors below reproduce each function exactly,
// with one difference: canGoNextWeek accepts an explicit `today` so tests
// are not coupled to DateTime.now().

import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mirrors of private helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Mirror of _WeekCalendarStripState._mondayOf
DateTime mondayOf(DateTime date) {
  final diff = date.weekday - 1; // Mon=1→0, Sun=7→6
  return DateTime(date.year, date.month, date.day - diff);
}

/// Mirror of _WeekCalendarStripState._canGoNextWeek
/// `today` replaces DateTime.now() so tests are deterministic.
bool canGoNextWeek({
  required DateTime weekStart,
  required DateTime today,
  int maxWeeksAhead = 1,
}) {
  if (maxWeeksAhead < 0) return true;
  final currentMonday = DateTime(today.year, today.month, today.day)
      .subtract(Duration(days: today.weekday - 1));
  final nextStart = weekStart.add(const Duration(days: 7));
  final weeksAhead = nextStart.difference(currentMonday).inDays ~/ 7;
  return weeksAhead <= maxWeeksAhead;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Mirror of _WeekCalendarStripState._headerLabel
String headerLabel(DateTime weekStart) {
  final end = weekStart.add(const Duration(days: 6));
  if (weekStart.month == end.month) {
    return '${_months[weekStart.month - 1]} ${weekStart.year}';
  }
  return '${_months[weekStart.month - 1]} – ${_months[end.month - 1]} ${end.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Reference calendar — known Mondays used across test groups:
//
//   Jan  6 2025  Mon
//   Mar 31 2025  Mon
//   Jun 30 2025  Mon
//   Aug  4 2025  Mon
//   Sep 29 2025  Mon
//   Dec 29 2025  Mon
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. mondayOf
  // ═══════════════════════════════════════════════════════════════════════════
  group('mondayOf — all weekdays in same month', () {
    // Week of Jan 6–12 2025 (verified Monday)
    test('Monday → returns same day', () {
      expect(mondayOf(DateTime(2025, 1, 6)), DateTime(2025, 1, 6));
    });

    test('Tuesday → day - 1', () {
      expect(mondayOf(DateTime(2025, 1, 7)), DateTime(2025, 1, 6));
    });

    test('Wednesday → day - 2', () {
      expect(mondayOf(DateTime(2025, 1, 8)), DateTime(2025, 1, 6));
    });

    test('Thursday → day - 3', () {
      expect(mondayOf(DateTime(2025, 1, 9)), DateTime(2025, 1, 6));
    });

    test('Friday → day - 4', () {
      expect(mondayOf(DateTime(2025, 1, 10)), DateTime(2025, 1, 6));
    });

    test('Saturday → day - 5', () {
      expect(mondayOf(DateTime(2025, 1, 11)), DateTime(2025, 1, 6));
    });

    test('Sunday → day - 6', () {
      expect(mondayOf(DateTime(2025, 1, 12)), DateTime(2025, 1, 6));
    });
  });

  group('mondayOf — month boundary', () {
    // Jan 1 2025 is Wednesday (weekday=3, diff=2)
    // day - diff = 1 - 2 = -1 → Dart rolls back to Dec 30 2024
    test('Wed Jan 1 2025 → Mon Dec 30 2024 (underflow wraps to prev month)', () {
      expect(mondayOf(DateTime(2025, 1, 1)), DateTime(2024, 12, 30));
    });

    // Jan 2 2025 is Thursday (weekday=4, diff=3) → day-3 = -1 → Dec 30 2024
    test('Thu Jan 2 2025 → Mon Dec 30 2024', () {
      expect(mondayOf(DateTime(2025, 1, 2)), DateTime(2024, 12, 30));
    });

    // Mon Jan 6 2025 — no underflow
    test('Mon Jan 6 2025 → Mon Jan 6 2025 (no underflow)', () {
      expect(mondayOf(DateTime(2025, 1, 6)), DateTime(2025, 1, 6));
    });

    // Aug 31 2025 is Sunday (weekday=7, diff=6) → Aug 25 2025
    test('Sun Aug 31 2025 → Mon Aug 25 2025', () {
      expect(mondayOf(DateTime(2025, 8, 31)), DateTime(2025, 8, 25));
    });

    // Sep 1 2025 is Monday
    test('Mon Sep 1 2025 → Mon Sep 1 2025', () {
      expect(mondayOf(DateTime(2025, 9, 1)), DateTime(2025, 9, 1));
    });

    // Sep 2 2025 is Tuesday (weekday=2, diff=1) → Sep 1
    test('Tue Sep 2 2025 → Mon Sep 1 2025', () {
      expect(mondayOf(DateTime(2025, 9, 2)), DateTime(2025, 9, 1));
    });
  });

  group('mondayOf — year boundary', () {
    // Dec 29 2025 is Monday
    test('Mon Dec 29 2025 → Dec 29 itself', () {
      expect(mondayOf(DateTime(2025, 12, 29)), DateTime(2025, 12, 29));
    });

    // Dec 31 2025 is Wednesday (weekday=3, diff=2) → Dec 29
    test('Wed Dec 31 2025 → Mon Dec 29 2025', () {
      expect(mondayOf(DateTime(2025, 12, 31)), DateTime(2025, 12, 29));
    });

    // Jan 1 2026 is Thursday (weekday=4, diff=3) → Dec 29 2025
    test('Thu Jan 1 2026 → Mon Dec 29 2025 (year rollback)', () {
      expect(mondayOf(DateTime(2026, 1, 1)), DateTime(2025, 12, 29));
    });

    // Jan 4 2026 is Sunday (weekday=7, diff=6) → Dec 29 2025
    test('Sun Jan 4 2026 → Mon Dec 29 2025', () {
      expect(mondayOf(DateTime(2026, 1, 4)), DateTime(2025, 12, 29));
    });

    // Jan 5 2026 is Monday → Jan 5 itself
    test('Mon Jan 5 2026 → Jan 5 2026 (new week, new year)', () {
      expect(mondayOf(DateTime(2026, 1, 5)), DateTime(2026, 1, 5));
    });
  });

  group('mondayOf — mid-year spot checks', () {
    // Mar 31 2025 is Monday
    test('Mon Mar 31 2025 → Mar 31', () {
      expect(mondayOf(DateTime(2025, 3, 31)), DateTime(2025, 3, 31));
    });

    // Apr 1 2025 is Tuesday → Mar 31
    test('Tue Apr 1 2025 → Mon Mar 31 2025 (month rollback to March)', () {
      expect(mondayOf(DateTime(2025, 4, 1)), DateTime(2025, 3, 31));
    });

    // Jun 30 2025 is Monday
    test('Mon Jun 30 2025 → Jun 30', () {
      expect(mondayOf(DateTime(2025, 6, 30)), DateTime(2025, 6, 30));
    });

    // Aug 4 2025 is Monday
    test('Mon Aug 4 2025 → Aug 4', () {
      expect(mondayOf(DateTime(2025, 8, 4)), DateTime(2025, 8, 4));
    });

    // Sep 29 2025 is Monday
    test('Mon Sep 29 2025 → Sep 29', () {
      expect(mondayOf(DateTime(2025, 9, 29)), DateTime(2025, 9, 29));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. canGoNextWeek
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // Tests use today = Mon Aug 4 2025 (weekday=1, so currentMonday = Aug 4).
  // This makes weeksAhead arithmetic clean integer multiples of 7.

  group('canGoNextWeek — maxWeeksAhead = -1 (unlimited)', () {
    final today = DateTime(2025, 8, 4); // Monday

    test('always true when on current week', () {
      expect(
        canGoNextWeek(weekStart: DateTime(2025, 8, 4), today: today, maxWeeksAhead: -1),
        true,
      );
    });

    test('always true when many weeks ahead', () {
      expect(
        canGoNextWeek(weekStart: DateTime(2025, 10, 13), today: today, maxWeeksAhead: -1),
        true,
      );
    });

    test('always true even on past week', () {
      expect(
        canGoNextWeek(weekStart: DateTime(2025, 7, 14), today: today, maxWeeksAhead: -1),
        true,
      );
    });
  });

  group('canGoNextWeek — maxWeeksAhead = 1 (free plan default)', () {
    final today = DateTime(2025, 8, 4); // Monday → currentMonday = Aug 4

    // weekStart=Aug 4 (current): nextStart=Aug 11, weeksAhead=1 → 1<=1 true
    test('on current week → can go to next (weeksAhead=1)', () {
      expect(
        canGoNextWeek(weekStart: DateTime(2025, 8, 4), today: today),
        true,
      );
    });

    // weekStart=Jul 28 (prev): nextStart=Aug 4, weeksAhead=0 → 0<=1 true
    test('on previous week → can go to current (weeksAhead=0)', () {
      expect(
        canGoNextWeek(weekStart: DateTime(2025, 7, 28), today: today),
        true,
      );
    });

    // weekStart=Jul 21 (two back): nextStart=Jul 28, weeksAhead negative → 0<=1 true
    test('two weeks behind → can navigate forward (weeksAhead<0 floor 0)', () {
      expect(
        canGoNextWeek(weekStart: DateTime(2025, 7, 21), today: today),
        true,
      );
    });

    // weekStart=Aug 11 (+1): nextStart=Aug 18, weeksAhead=2 → 2<=1 false
    test('one week ahead → cannot go further (weeksAhead=2 > max 1)', () {
      expect(
        canGoNextWeek(weekStart: DateTime(2025, 8, 11), today: today),
        false,
      );
    });

    // weekStart=Aug 18 (+2): nextStart=Aug 25, weeksAhead=3 → false
    test('two weeks ahead → blocked', () {
      expect(
        canGoNextWeek(weekStart: DateTime(2025, 8, 18), today: today),
        false,
      );
    });
  });

  group('canGoNextWeek — maxWeeksAhead = 0 (strictly current week only)', () {
    final today = DateTime(2025, 8, 4);

    // weekStart=Jul 28: nextStart=Aug 4, weeksAhead=0 → 0<=0 true
    test('prev week → can navigate to current (weeksAhead=0)', () {
      expect(
        canGoNextWeek(weekStart: DateTime(2025, 7, 28), today: today, maxWeeksAhead: 0),
        true,
      );
    });

    // weekStart=Aug 4: nextStart=Aug 11, weeksAhead=1 → 1<=0 false
    test('current week → blocked from going ahead (weeksAhead=1)', () {
      expect(
        canGoNextWeek(weekStart: DateTime(2025, 8, 4), today: today, maxWeeksAhead: 0),
        false,
      );
    });
  });

  group('canGoNextWeek — maxWeeksAhead = 2', () {
    final today = DateTime(2025, 8, 4);

    // weekStart=Aug 11 (+1): nextStart=Aug 18, weeksAhead=2 → 2<=2 true
    test('one week ahead → can go to two weeks ahead', () {
      expect(
        canGoNextWeek(weekStart: DateTime(2025, 8, 11), today: today, maxWeeksAhead: 2),
        true,
      );
    });

    // weekStart=Aug 18 (+2): nextStart=Aug 25, weeksAhead=3 → 3<=2 false
    test('two weeks ahead → blocked at three', () {
      expect(
        canGoNextWeek(weekStart: DateTime(2025, 8, 18), today: today, maxWeeksAhead: 2),
        false,
      );
    });
  });

  group('canGoNextWeek — today is mid-week (not Monday)', () {
    // today = Thursday Aug 7 2025 (weekday=4)
    // currentMonday = Aug 7 - (4-1=3) days = Aug 4
    final today = DateTime(2025, 8, 7); // Thursday

    test('weekStart=Aug 4 → currentMonday still Aug 4 regardless of today being Thu', () {
      // nextStart=Aug 11, weeksAhead=1, max=1 → true
      expect(
        canGoNextWeek(weekStart: DateTime(2025, 8, 4), today: today),
        true,
      );
    });

    test('weekStart=Aug 11 → weeksAhead=2, max=1 → false', () {
      expect(
        canGoNextWeek(weekStart: DateTime(2025, 8, 11), today: today),
        false,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. headerLabel
  // ═══════════════════════════════════════════════════════════════════════════
  group('headerLabel — same-month weeks', () {
    test('Mon Jan 6 → Jan 6–12 → "Jan 2025"', () {
      expect(headerLabel(DateTime(2025, 1, 6)), 'Jan 2025');
    });

    test('Mon Aug 4 → Aug 4–10 → "Aug 2025"', () {
      expect(headerLabel(DateTime(2025, 8, 4)), 'Aug 2025');
    });

    test('Mon Aug 25 → Aug 25–31 → "Aug 2025" (end is still Aug)', () {
      expect(headerLabel(DateTime(2025, 8, 25)), 'Aug 2025');
    });

    test('Mon Nov 3 → Nov 3–9 → "Nov 2025"', () {
      expect(headerLabel(DateTime(2025, 11, 3)), 'Nov 2025');
    });

    test('Mon Dec 22 → Dec 22–28 → "Dec 2025"', () {
      expect(headerLabel(DateTime(2025, 12, 22)), 'Dec 2025');
    });

    test('Mon Feb 3 → Feb 3–9 → "Feb 2025"', () {
      expect(headerLabel(DateTime(2025, 2, 3)), 'Feb 2025');
    });
  });

  group('headerLabel — cross-month weeks', () {
    // Sep 29 Mon → Oct 5 → different months
    test('Mon Sep 29 → Sep 29–Oct 5 → "Sep – Oct 2025"', () {
      expect(headerLabel(DateTime(2025, 9, 29)), 'Sep – Oct 2025');
    });

    // Mar 31 Mon → Apr 6 → different months
    test('Mon Mar 31 → Mar 31–Apr 6 → "Mar – Apr 2025"', () {
      expect(headerLabel(DateTime(2025, 3, 31)), 'Mar – Apr 2025');
    });

    // Jun 30 Mon → Jul 6 → different months
    test('Mon Jun 30 → Jun 30–Jul 6 → "Jun – Jul 2025"', () {
      expect(headerLabel(DateTime(2025, 6, 30)), 'Jun – Jul 2025');
    });

    // Oct 27 Mon → Nov 2 (Oct 27+6=Nov 2) → cross month
    // Oct 27 2025: Aug 4 Mon + (days to Oct 27) = let's verify
    // Actually just trust Dart's date arithmetic
    test('Mon Oct 27 → Oct 27–Nov 2 → "Oct – Nov 2025"', () {
      expect(headerLabel(DateTime(2025, 10, 27)), 'Oct – Nov 2025');
    });
  });

  group('headerLabel — cross-year weeks', () {
    // Dec 29 Mon → Jan 4 2026 → year shows end year
    test('Mon Dec 29 2025 → Dec 29–Jan 4 → "Dec – Jan 2026"', () {
      expect(headerLabel(DateTime(2025, 12, 29)), 'Dec – Jan 2026');
    });

    // Dec 28 2020 Mon → Jan 3 2021
    test('Mon Dec 28 2020 → "Dec – Jan 2021"', () {
      expect(headerLabel(DateTime(2020, 12, 28)), 'Dec – Jan 2021');
    });

    // The year in the label is end.year, NOT weekStart.year
    test('year in label comes from end date (Jan year, not Dec year)', () {
      final label = headerLabel(DateTime(2025, 12, 29));
      expect(label, contains('2026'));
      expect(label, isNot(contains('2025')));
    });
  });

  group('headerLabel — month abbreviations', () {
    // Verify all 12 month abbreviations appear correctly in same-month labels.
    // We need known Mondays for each month in 2025.
    // Jan 6, Feb 3, Mar 3, Apr 7, May 5, Jun 2,
    // Jul 7, Aug 4, Sep 1, Oct 6, Nov 3, Dec 1 — all verified as Mondays.
    final cases = {
      DateTime(2025, 1, 6): 'Jan 2025',
      DateTime(2025, 2, 3): 'Feb 2025',
      DateTime(2025, 3, 3): 'Mar 2025',
      DateTime(2025, 4, 7): 'Apr 2025',
      DateTime(2025, 5, 5): 'May 2025',
      DateTime(2025, 6, 2): 'Jun 2025',
      DateTime(2025, 7, 7): 'Jul 2025',
      DateTime(2025, 8, 4): 'Aug 2025',
      DateTime(2025, 9, 1): 'Sep 2025',
      DateTime(2025, 10, 6): 'Oct 2025',
      DateTime(2025, 11, 3): 'Nov 2025',
      DateTime(2025, 12, 1): 'Dec 2025',
    };

    for (final entry in cases.entries) {
      test('${_months[entry.key.month - 1]} month label', () {
        expect(headerLabel(entry.key), entry.value);
      });
    }
  });

  group('headerLabel — format structure', () {
    test('same-month format has no dash separator', () {
      expect(headerLabel(DateTime(2025, 8, 4)), isNot(contains('–')));
    });

    test('cross-month format contains " – " separator', () {
      expect(headerLabel(DateTime(2025, 9, 29)), contains(' – '));
    });

    test('same-month format: "MMM YYYY"', () {
      final label = headerLabel(DateTime(2025, 8, 4));
      expect(label, matches(RegExp(r'^[A-Z][a-z]{2} \d{4}$')));
    });

    test('cross-month format: "MMM – MMM YYYY"', () {
      final label = headerLabel(DateTime(2025, 9, 29));
      expect(label, matches(RegExp(r'^[A-Z][a-z]{2} – [A-Z][a-z]{2} \d{4}$')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Integration: mondayOf → headerLabel pipeline
  // ═══════════════════════════════════════════════════════════════════════════
  group('mondayOf + headerLabel pipeline', () {
    test('mid-week date produces correct header via monday anchor', () {
      // Thu Sep 4 2025 → mondayOf = Sep 1 → header = "Sep 2025"
      final monday = mondayOf(DateTime(2025, 9, 4));
      expect(headerLabel(monday), 'Sep 2025');
    });

    test('Sunday at month end anchors to correct cross-month header', () {
      // Sun Sep 28 2025 (weekday=7, diff=6) → mondayOf = Sep 22 → "Sep 2025"
      final monday = mondayOf(DateTime(2025, 9, 28));
      expect(headerLabel(monday), 'Sep 2025');
    });

    test('Wednesday Jan 1 2025 → mondayOf = Dec 30 2024 → "Dec – Jan 2025"', () {
      final monday = mondayOf(DateTime(2025, 1, 1));
      expect(monday, DateTime(2024, 12, 30));
      expect(headerLabel(monday), 'Dec – Jan 2025');
    });

    test('Sunday Jan 4 2026 → mondayOf = Dec 29 2025 → "Dec – Jan 2026"', () {
      final monday = mondayOf(DateTime(2026, 1, 4));
      expect(monday, DateTime(2025, 12, 29));
      expect(headerLabel(monday), 'Dec – Jan 2026');
    });

    test('Monday always returns same-day from mondayOf', () {
      // Any Monday fed into mondayOf comes back unchanged
      for (final date in [
        DateTime(2025, 1, 6),
        DateTime(2025, 8, 4),
        DateTime(2025, 9, 29),
        DateTime(2025, 12, 29),
      ]) {
        expect(mondayOf(date), date, reason: date.toString());
      }
    });
  });
}
