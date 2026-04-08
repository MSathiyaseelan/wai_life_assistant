import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PrivacyPrefs — persists Privacy & Security settings
//   • Non-sensitive flags  → SharedPreferences
//   • PIN                  → FlutterSecureStorage (encrypted on-device)
// ─────────────────────────────────────────────────────────────────────────────

enum LockMethod { biometric, pin }

enum LockAfter {
  immediately('Immediately', 0),
  oneMin('1 minute', 60),
  fiveMin('5 minutes', 300);

  const LockAfter(this.label, this.seconds);
  final String label;
  final int seconds;
}

class PrivacyPrefs extends ChangeNotifier {
  PrivacyPrefs._();
  static final PrivacyPrefs instance = PrivacyPrefs._();

  static const _pfx = 'privacy_';
  static const _pinKey = 'app_pin';

  static const _ss = FlutterSecureStorage();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    notifyListeners();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  bool _b(String key, {bool def = false}) =>
      _prefs?.getBool('$_pfx$key') ?? def;

  String _s(String key, {required String def}) =>
      _prefs?.getString('$_pfx$key') ?? def;

  Future<void> _setB(String key, bool v) async {
    await _prefs?.setBool('$_pfx$key', v);
    notifyListeners();
  }

  Future<void> _setS(String key, String v) async {
    await _prefs?.setString('$_pfx$key', v);
    notifyListeners();
  }

  // ── App Lock ───────────────────────────────────────────────────────────────

  bool get appLockEnabled => _b('app_lock_enabled');
  set appLockEnabled(bool v) => _setB('app_lock_enabled', v);

  LockMethod get lockMethod {
    final raw = _s('lock_method', def: 'biometric');
    return raw == 'pin' ? LockMethod.pin : LockMethod.biometric;
  }

  set lockMethod(LockMethod v) => _setS('lock_method', v.name);

  LockAfter get lockAfter {
    final raw = _s('lock_after', def: 'immediately');
    return LockAfter.values.firstWhere((e) => e.name == raw,
        orElse: () => LockAfter.immediately);
  }

  set lockAfter(LockAfter v) => _setS('lock_after', v.name);

  // ── PIN ────────────────────────────────────────────────────────────────────

  Future<bool> hasPin() async {
    final v = await _ss.read(key: _pinKey);
    return v != null && v.isNotEmpty;
  }

  Future<void> savePin(String pin) async {
    await _ss.write(key: _pinKey, value: pin);
  }

  Future<bool> checkPin(String pin) async {
    final stored = await _ss.read(key: _pinKey);
    return stored == pin;
  }

  Future<void> clearPin() async {
    await _ss.delete(key: _pinKey);
  }

  // ── Locked Notes ───────────────────────────────────────────────────────────

  bool get lockedNotesBiometric => _b('locked_notes_biometric', def: true);
  set lockedNotesBiometric(bool v) => _setB('locked_notes_biometric', v);

  // ── Data Privacy ───────────────────────────────────────────────────────────

  bool get allowPersonalisation => _b('allow_personalisation', def: true);
  set allowPersonalisation(bool v) => _setB('allow_personalisation', v);
}
