import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';

// AppPrefs.weekStart / formatShortDate — used by Wallet Reports' weekly view.
// AppPrefs is a singleton that loads SharedPreferences once, so values are
// set through its own setters rather than re-mocked per test.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final p = AppPrefs.instance;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await p.init();
  });

  // 2026-09-24 is a Thursday.
  final thu = DateTime(2026, 9, 24, 15, 30);

  group('AppPrefs.weekStart', () {
    test('defaults to Sunday', () {
      expect(p.weekStartsOn, 'sunday');
      expect(p.weekStart(thu), DateTime(2026, 9, 20));
    });

    test('sunday start → previous Sunday, at midnight', () {
      p.weekStartsOn = 'sunday';
      expect(p.weekStart(thu), DateTime(2026, 9, 20));
    });

    test('monday start → previous Monday', () {
      p.weekStartsOn = 'monday';
      expect(p.weekStart(thu), DateTime(2026, 9, 21));
    });

    test('a Sunday is its own week start when weeks start on Sunday', () {
      p.weekStartsOn = 'sunday';
      expect(p.weekStart(DateTime(2026, 9, 20, 9)), DateTime(2026, 9, 20));
    });

    test('a Sunday belongs to the week starting the Monday before', () {
      p.weekStartsOn = 'monday';
      expect(p.weekStart(DateTime(2026, 9, 20)), DateTime(2026, 9, 14));
    });
  });

  group('AppPrefs.formatShortDate', () {
    final d = DateTime(2026, 8, 4);
    test('dmy → dd/MM', () {
      p.dateFormat = 'dmy';
      expect(p.formatShortDate(d), '04/08');
    });
    test('mdy → MM/dd', () {
      p.dateFormat = 'mdy';
      expect(p.formatShortDate(d), '08/04');
    });
    test('ymd → MM-dd', () {
      p.dateFormat = 'ymd';
      expect(p.formatShortDate(d), '08-04');
    });
  });
}
