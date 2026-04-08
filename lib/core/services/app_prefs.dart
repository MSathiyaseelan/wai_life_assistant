import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppPrefs — general app-wide preferences (Language, Currency, Date, Scope, AI)
// ─────────────────────────────────────────────────────────────────────────────

class AppPrefs extends ChangeNotifier {
  AppPrefs._();
  static final AppPrefs instance = AppPrefs._();

  static const _pfx = 'app_';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    notifyListeners();
  }

  bool get ready => _prefs != null;

  // ── helpers ────────────────────────────────────────────────────────────────

  String _s(String key, {required String def}) =>
      _prefs?.getString('$_pfx$key') ?? def;

  bool _b(String key, {required bool def}) =>
      _prefs?.getBool('$_pfx$key') ?? def;

  Future<void> _setS(String key, String v) async {
    await _prefs?.setString('$_pfx$key', v);
    notifyListeners();
  }

  Future<void> _setB(String key, bool v) async {
    await _prefs?.setBool('$_pfx$key', v);
    notifyListeners();
  }

  // ── Language & Voice ───────────────────────────────────────────────────────

  static const languages = <({String code, String label, String native})>[
    (code: 'en', label: 'English',    native: 'English'),
    (code: 'ta', label: 'Tamil',      native: 'தமிழ்'),
    (code: 'hi', label: 'Hindi',      native: 'हिंदी'),
    (code: 'te', label: 'Telugu',     native: 'తెలుగు'),
    (code: 'kn', label: 'Kannada',    native: 'ಕನ್ನಡ'),
    (code: 'ml', label: 'Malayalam',  native: 'മലയാളം'),
    (code: 'bn', label: 'Bengali',    native: 'বাংলা'),
    (code: 'mr', label: 'Marathi',    native: 'मराठी'),
    (code: 'gu', label: 'Gujarati',   native: 'ગુજરાતી'),
    (code: 'pa', label: 'Punjabi',    native: 'ਪੰਜਾਬੀ'),
  ];

  String get appLanguage      => _s('app_language',   def: 'en');
  set appLanguage(String v)   => _setS('app_language', v);

  String get voiceLanguage    => _s('voice_language',  def: 'en');
  set voiceLanguage(String v) => _setS('voice_language', v);

  String get appLanguageLabel =>
      languages.firstWhere((l) => l.code == appLanguage,
          orElse: () => languages.first).label;

  // ── Currency ───────────────────────────────────────────────────────────────

  static const currencies = <({String code, String symbol, String name})>[
    (code: 'INR', symbol: '₹',  name: 'Indian Rupee'),
    (code: 'USD', symbol: '\$', name: 'US Dollar'),
    (code: 'EUR', symbol: '€',  name: 'Euro'),
    (code: 'GBP', symbol: '£',  name: 'British Pound'),
    (code: 'AED', symbol: 'د.إ', name: 'UAE Dirham'),
    (code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar'),
    (code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
    (code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar'),
  ];

  /// e.g. 'INR'
  String get primaryCurrency    => _s('primary_currency',  def: 'INR');
  set primaryCurrency(String v)  => _setS('primary_currency', v);

  /// 'symbol' | 'code' | 'short'  →  ₹ | INR | Rs
  String get currencyDisplay     => _s('currency_display', def: 'symbol');
  set currencyDisplay(String v)  => _setS('currency_display', v);

  ({String code, String symbol, String name}) get currentCurrency =>
      currencies.firstWhere((c) => c.code == primaryCurrency,
          orElse: () => currencies.first);

  String get currencySymbol {
    final c = currentCurrency;
    switch (currencyDisplay) {
      case 'code':  return c.code;
      case 'short': return 'Rs';
      default:      return c.symbol;
    }
  }

  // ── Date & Time ────────────────────────────────────────────────────────────

  /// 'dmy' → DD/MM/YYYY  |  'mdy' → MM/DD/YYYY  |  'ymd' → YYYY-MM-DD
  String get dateFormat    => _s('date_format',   def: 'dmy');
  set dateFormat(String v) => _setS('date_format', v);

  static const dateFormats = <({String key, String label, String example})>[
    (key: 'dmy', label: 'DD/MM/YYYY', example: '08/04/2026'),
    (key: 'mdy', label: 'MM/DD/YYYY', example: '04/08/2026'),
    (key: 'ymd', label: 'YYYY-MM-DD', example: '2026-04-08'),
  ];

  /// 'sunday' | 'monday'
  String get weekStartsOn    => _s('week_starts_on',  def: 'sunday');
  set weekStartsOn(String v) => _setS('week_starts_on', v);

  // ── Default Scope ──────────────────────────────────────────────────────────

  /// 'personal' | 'family'
  String get walletScope    => _s('wallet_scope',  def: 'personal');
  set walletScope(String v) => _setS('wallet_scope', v);

  String get pantryScope    => _s('pantry_scope',  def: 'personal');
  set pantryScope(String v) => _setS('pantry_scope', v);

  String get planItScope    => _s('planit_scope',  def: 'personal');
  set planItScope(String v) => _setS('planit_scope', v);

  // ── AI Parser ──────────────────────────────────────────────────────────────

  bool get aiAlwaysConfirm    => _b('ai_always_confirm',  def: true);
  set aiAlwaysConfirm(bool v) => _setB('ai_always_confirm', v);

  String get aiVoiceLanguage    => _s('ai_voice_language',  def: 'en');
  set aiVoiceLanguage(String v) => _setS('ai_voice_language', v);
}
