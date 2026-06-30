import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/core/services/privacy_prefs.dart';

// ─── Mirrors of private / SharedPrefs-dependent helpers ──────────────────────

/// Mirrors NetworkService._hasConnection — tested without initialising the
/// full connectivity plugin.
bool hasConnection(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// Mirrors NotificationPrefs.isQuietNow with injected hour, start, end.
bool isQuietNow({
  required bool enabled,
  required int hour,
  required int start,
  required int end,
}) {
  if (!enabled) return false;
  return start > end
      ? (hour >= start || hour < end)   // overnight window, e.g. 22→07
      : (hour >= start && hour < end);  // same-day window,  e.g. 09→17
}

/// Mirrors AppPrefs.currencySymbol display logic.
String currencySymbol({
  required String display,
  required String symbol,
  required String code,
}) {
  switch (display) {
    case 'code':
      return code;
    case 'short':
      return 'Rs';
    default:
      return symbol;
  }
}

/// Mirrors AppPrefs.appLanguageLabel lookup logic.
String languageLabel(
  String code,
  List<({String code, String label, String native})> languages,
) =>
    languages.firstWhere((l) => l.code == code,
        orElse: () => languages.first).label;

/// Mirrors NotificationPrefs.pantryMealTimeOfDay parse logic.
TimeOfDay parseMealTime(String hhmm) {
  final parts = hhmm.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts[0]) ?? 8,
    minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
  );
}

/// Mirrors PrivacyPrefs.lockMethod parse logic.
LockMethod parseLockMethod(String raw) =>
    raw == 'pin' ? LockMethod.pin : LockMethod.biometric;

/// Mirrors PrivacyPrefs.lockAfter parse logic.
LockAfter parseLockAfter(String raw) =>
    LockAfter.values.firstWhere((e) => e.name == raw,
        orElse: () => LockAfter.immediately);

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Network connectivity helper
  // ═══════════════════════════════════════════════════════════════════════════
  group('hasConnection()', () {
    test('empty list → offline', () {
      expect(hasConnection([]), false);
    });

    test('none only → offline', () {
      expect(hasConnection([ConnectivityResult.none]), false);
    });

    test('multiple none entries → offline', () {
      expect(
        hasConnection([ConnectivityResult.none, ConnectivityResult.none]),
        false,
      );
    });

    test('wifi → online', () {
      expect(hasConnection([ConnectivityResult.wifi]), true);
    });

    test('mobile → online', () {
      expect(hasConnection([ConnectivityResult.mobile]), true);
    });

    test('ethernet → online', () {
      expect(hasConnection([ConnectivityResult.ethernet]), true);
    });

    test('vpn → online', () {
      expect(hasConnection([ConnectivityResult.vpn]), true);
    });

    test('bluetooth → online', () {
      expect(hasConnection([ConnectivityResult.bluetooth]), true);
    });

    test('wifi + none → online (any non-none wins)', () {
      expect(
        hasConnection([ConnectivityResult.wifi, ConnectivityResult.none]),
        true,
      );
    });

    test('going offline: replace wifi with none → false', () {
      expect(hasConnection([ConnectivityResult.wifi]), true);
      expect(hasConnection([ConnectivityResult.none]), false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Quiet hours DND logic
  // ═══════════════════════════════════════════════════════════════════════════
  group('isQuietNow() — quiet hours DND', () {
    test('disabled → always false regardless of hour', () {
      for (int h = 0; h < 24; h++) {
        expect(
          isQuietNow(enabled: false, hour: h, start: 22, end: 7),
          false,
          reason: 'hour $h',
        );
      }
    });

    // ── Overnight window (22 → 07) ──
    test('overnight: hour at start (22) → quiet', () {
      expect(isQuietNow(enabled: true, hour: 22, start: 22, end: 7), true);
    });

    test('overnight: hour 23 → quiet', () {
      expect(isQuietNow(enabled: true, hour: 23, start: 22, end: 7), true);
    });

    test('overnight: hour 0 (midnight) → quiet', () {
      expect(isQuietNow(enabled: true, hour: 0, start: 22, end: 7), true);
    });

    test('overnight: hour 6 → quiet', () {
      expect(isQuietNow(enabled: true, hour: 6, start: 22, end: 7), true);
    });

    test('overnight: hour at end (7) → not quiet', () {
      expect(isQuietNow(enabled: true, hour: 7, start: 22, end: 7), false);
    });

    test('overnight: hour 12 (noon) → not quiet', () {
      expect(isQuietNow(enabled: true, hour: 12, start: 22, end: 7), false);
    });

    test('overnight: hour 21 (one before start) → not quiet', () {
      expect(isQuietNow(enabled: true, hour: 21, start: 22, end: 7), false);
    });

    // ── Same-day window (09 → 17 — e.g. office hours) ──
    test('same-day: hour at start (9) → quiet', () {
      expect(isQuietNow(enabled: true, hour: 9, start: 9, end: 17), true);
    });

    test('same-day: hour 13 → quiet', () {
      expect(isQuietNow(enabled: true, hour: 13, start: 9, end: 17), true);
    });

    test('same-day: hour 16 → quiet', () {
      expect(isQuietNow(enabled: true, hour: 16, start: 9, end: 17), true);
    });

    test('same-day: hour at end (17) → not quiet', () {
      expect(isQuietNow(enabled: true, hour: 17, start: 9, end: 17), false);
    });

    test('same-day: hour 8 (before start) → not quiet', () {
      expect(isQuietNow(enabled: true, hour: 8, start: 9, end: 17), false);
    });

    test('same-day: hour 20 (after end) → not quiet', () {
      expect(isQuietNow(enabled: true, hour: 20, start: 9, end: 17), false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. AppPrefs static data
  // ═══════════════════════════════════════════════════════════════════════════
  group('AppPrefs.languages', () {
    test('has 10 entries', () {
      expect(AppPrefs.languages.length, 10);
    });

    test('all entries have non-empty code, label, native', () {
      for (final l in AppPrefs.languages) {
        expect(l.code, isNotEmpty, reason: l.label);
        expect(l.label, isNotEmpty, reason: l.code);
        expect(l.native, isNotEmpty, reason: l.code);
      }
    });

    test('first entry is English (default)', () {
      expect(AppPrefs.languages.first.code, 'en');
      expect(AppPrefs.languages.first.label, 'English');
    });

    test('contains all expected language codes', () {
      final codes = AppPrefs.languages.map((l) => l.code).toSet();
      for (final code in ['en', 'ta', 'hi', 'te', 'kn', 'ml', 'bn', 'mr', 'gu', 'pa']) {
        expect(codes.contains(code), true, reason: 'missing $code');
      }
    });

    test('no duplicate codes', () {
      final codes = AppPrefs.languages.map((l) => l.code).toList();
      expect(codes.toSet().length, codes.length);
    });
  });

  group('AppPrefs.currencies', () {
    test('has 8 entries', () {
      expect(AppPrefs.currencies.length, 8);
    });

    test('all entries have non-empty code, symbol, name', () {
      for (final c in AppPrefs.currencies) {
        expect(c.code, isNotEmpty, reason: c.name);
        expect(c.symbol, isNotEmpty, reason: c.code);
        expect(c.name, isNotEmpty, reason: c.code);
      }
    });

    test('first currency is INR (default)', () {
      expect(AppPrefs.currencies.first.code, 'INR');
      expect(AppPrefs.currencies.first.symbol, '₹');
    });

    test('contains USD, EUR, GBP', () {
      final codes = AppPrefs.currencies.map((c) => c.code).toSet();
      expect(codes.contains('USD'), true);
      expect(codes.contains('EUR'), true);
      expect(codes.contains('GBP'), true);
    });

    test('no duplicate codes', () {
      final codes = AppPrefs.currencies.map((c) => c.code).toList();
      expect(codes.toSet().length, codes.length);
    });
  });

  group('AppPrefs.dateFormats', () {
    test('has 3 entries', () {
      expect(AppPrefs.dateFormats.length, 3);
    });

    test('all have key, label, example', () {
      for (final f in AppPrefs.dateFormats) {
        expect(f.key, isNotEmpty);
        expect(f.label, isNotEmpty);
        expect(f.example, isNotEmpty);
      }
    });

    test('first format is dmy (default)', () {
      expect(AppPrefs.dateFormats.first.key, 'dmy');
    });

    test('contains dmy, mdy, ymd', () {
      final keys = AppPrefs.dateFormats.map((f) => f.key).toSet();
      expect(keys, containsAll(['dmy', 'mdy', 'ymd']));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Currency display helper
  // ═══════════════════════════════════════════════════════════════════════════
  group('currencySymbol()', () {
    const symbol = '₹';
    const code = 'INR';

    test('display=symbol → returns symbol', () {
      expect(currencySymbol(display: 'symbol', symbol: symbol, code: code), symbol);
    });

    test('display=code → returns code string', () {
      expect(currencySymbol(display: 'code', symbol: symbol, code: code), code);
    });

    test('display=short → returns Rs', () {
      expect(currencySymbol(display: 'short', symbol: symbol, code: code), 'Rs');
    });

    test('display=unknown → falls through to symbol', () {
      expect(currencySymbol(display: 'fancy', symbol: symbol, code: code), symbol);
    });

    test('USD symbol display', () {
      expect(currencySymbol(display: 'symbol', symbol: '\$', code: 'USD'), '\$');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. Language label lookup
  // ═══════════════════════════════════════════════════════════════════════════
  group('languageLabel()', () {
    final langs = AppPrefs.languages;

    test('known code returns correct label', () {
      expect(languageLabel('en', langs), 'English');
      expect(languageLabel('ta', langs), 'Tamil');
      expect(languageLabel('hi', langs), 'Hindi');
    });

    test('unknown code falls back to first language label', () {
      expect(languageLabel('zz', langs), langs.first.label);
    });

    test('empty code falls back to first language label', () {
      expect(languageLabel('', langs), langs.first.label);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. Meal time parse helper
  // ═══════════════════════════════════════════════════════════════════════════
  group('parseMealTime()', () {
    test('08:00 → hour=8, minute=0', () {
      final t = parseMealTime('08:00');
      expect(t.hour, 8);
      expect(t.minute, 0);
    });

    test('06:30 → hour=6, minute=30', () {
      final t = parseMealTime('06:30');
      expect(t.hour, 6);
      expect(t.minute, 30);
    });

    test('21:45 → hour=21, minute=45', () {
      final t = parseMealTime('21:45');
      expect(t.hour, 21);
      expect(t.minute, 45);
    });

    test('invalid hour falls back to 8', () {
      final t = parseMealTime('xx:30');
      expect(t.hour, 8);
      expect(t.minute, 30);
    });

    test('invalid minute falls back to 0', () {
      final t = parseMealTime('09:yy');
      expect(t.hour, 9);
      expect(t.minute, 0);
    });

    test('missing colon (single segment) → hour parsed, minute defaults to 0', () {
      final t = parseMealTime('10');
      expect(t.hour, 10);
      expect(t.minute, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. LockAfter enum
  // ═══════════════════════════════════════════════════════════════════════════
  group('LockAfter enum', () {
    test('immediately: label and 0 seconds', () {
      expect(LockAfter.immediately.label, 'Immediately');
      expect(LockAfter.immediately.seconds, 0);
    });

    test('oneMin: label and 60 seconds', () {
      expect(LockAfter.oneMin.label, '1 minute');
      expect(LockAfter.oneMin.seconds, 60);
    });

    test('fiveMin: label and 300 seconds', () {
      expect(LockAfter.fiveMin.label, '5 minutes');
      expect(LockAfter.fiveMin.seconds, 300);
    });

    test('has exactly 3 values', () {
      expect(LockAfter.values.length, 3);
    });

    test('seconds are strictly increasing', () {
      final secs = LockAfter.values.map((e) => e.seconds).toList();
      for (int i = 1; i < secs.length; i++) {
        expect(secs[i] > secs[i - 1], true,
            reason: '${LockAfter.values[i].name} must be > ${LockAfter.values[i - 1].name}');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. LockMethod enum
  // ═══════════════════════════════════════════════════════════════════════════
  group('LockMethod enum', () {
    test('has biometric and pin', () {
      expect(LockMethod.values, containsAll([LockMethod.biometric, LockMethod.pin]));
    });

    test('name strings match', () {
      expect(LockMethod.biometric.name, 'biometric');
      expect(LockMethod.pin.name, 'pin');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. parseLockMethod
  // ═══════════════════════════════════════════════════════════════════════════
  group('parseLockMethod()', () {
    test('"pin" → LockMethod.pin', () {
      expect(parseLockMethod('pin'), LockMethod.pin);
    });

    test('"biometric" → LockMethod.biometric', () {
      expect(parseLockMethod('biometric'), LockMethod.biometric);
    });

    test('unknown string → biometric (default)', () {
      expect(parseLockMethod('face_id'), LockMethod.biometric);
    });

    test('empty string → biometric (default)', () {
      expect(parseLockMethod(''), LockMethod.biometric);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. parseLockAfter
  // ═══════════════════════════════════════════════════════════════════════════
  group('parseLockAfter()', () {
    test('"immediately" → LockAfter.immediately', () {
      expect(parseLockAfter('immediately'), LockAfter.immediately);
    });

    test('"oneMin" → LockAfter.oneMin', () {
      expect(parseLockAfter('oneMin'), LockAfter.oneMin);
    });

    test('"fiveMin" → LockAfter.fiveMin', () {
      expect(parseLockAfter('fiveMin'), LockAfter.fiveMin);
    });

    test('unknown string → LockAfter.immediately (default)', () {
      expect(parseLockAfter('tenMin'), LockAfter.immediately);
    });

    test('empty string → LockAfter.immediately (default)', () {
      expect(parseLockAfter(''), LockAfter.immediately);
    });

    test('round-trips for all enum values', () {
      for (final v in LockAfter.values) {
        expect(parseLockAfter(v.name), v, reason: v.name);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 11. ErrorSeverity enum
  // ═══════════════════════════════════════════════════════════════════════════
  group('ErrorSeverity enum', () {
    test('has 4 values', () {
      expect(ErrorSeverity.values.length, 4);
    });

    test('name strings match', () {
      expect(ErrorSeverity.critical.name, 'critical');
      expect(ErrorSeverity.error.name, 'error');
      expect(ErrorSeverity.warning.name, 'warning');
      expect(ErrorSeverity.info.name, 'info');
    });

    test('all names are non-empty', () {
      for (final s in ErrorSeverity.values) {
        expect(s.name, isNotEmpty);
      }
    });

    test('severity ordering: critical < error < warning < info (index ascending)', () {
      expect(
        ErrorSeverity.critical.index < ErrorSeverity.error.index,
        true,
      );
      expect(
        ErrorSeverity.error.index < ErrorSeverity.warning.index,
        true,
      );
      expect(
        ErrorSeverity.warning.index < ErrorSeverity.info.index,
        true,
      );
    });
  });
}
