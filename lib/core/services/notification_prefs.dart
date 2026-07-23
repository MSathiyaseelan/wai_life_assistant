import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationPrefs — persists all notification settings via SharedPreferences
// ─────────────────────────────────────────────────────────────────────────────

class NotificationPrefs extends ChangeNotifier {
  NotificationPrefs._();
  static final NotificationPrefs instance = NotificationPrefs._();

  static const _pfx = 'notif_';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    notifyListeners();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  bool _b(String key, {bool def = true}) =>
      _prefs?.getBool('$_pfx$key') ?? def;

  int _i(String key, {required int def}) =>
      _prefs?.getInt('$_pfx$key') ?? def;

  String _s(String key, {required String def}) =>
      _prefs?.getString('$_pfx$key') ?? def;

  Future<void> _setB(String key, bool v) async {
    await _prefs?.setBool('$_pfx$key', v);
    notifyListeners();
  }

  Future<void> _setI(String key, int v) async {
    await _prefs?.setInt('$_pfx$key', v);
    notifyListeners();
  }

  Future<void> _setS(String key, String v) async {
    await _prefs?.setString('$_pfx$key', v);
    notifyListeners();
  }

  // ── Master ─────────────────────────────────────────────────────────────────
  bool get masterOn => _b('master');
  set masterOn(bool v) => _setB('master', v);

  // ── Wallet ─────────────────────────────────────────────────────────────────
  bool get walletFamilyExpense => _b('wallet_family_expense');
  set walletFamilyExpense(bool v) => _setB('wallet_family_expense', v);

  bool get walletLendBorrow => _b('wallet_lend_borrow');
  set walletLendBorrow(bool v) => _setB('wallet_lend_borrow', v);

  // ── Pantry ─────────────────────────────────────────────────────────────────
  bool get pantryLowStock => _b('pantry_low_stock');
  set pantryLowStock(bool v) => _setB('pantry_low_stock', v);

  bool get pantryExpiry => _b('pantry_expiry');
  set pantryExpiry(bool v) => _setB('pantry_expiry', v);

  /// Days before expiry to alert (1 / 2 / 3 / 7)
  int get pantryExpiryDays => _i('pantry_expiry_days', def: 2);
  set pantryExpiryDays(int v) => _setI('pantry_expiry_days', v);

  bool get pantryMealReminder => _b('pantry_meal_reminder');
  set pantryMealReminder(bool v) => _setB('pantry_meal_reminder', v);

  /// HH:MM string for meal plan reminder time, e.g. "08:00"
  String get pantryMealTime => _s('pantry_meal_time', def: '08:00');
  set pantryMealTime(String v) => _setS('pantry_meal_time', v);

  TimeOfDay get pantryMealTimeOfDay {
    final parts = pantryMealTime.split(':');
    return TimeOfDay(
      hour:   int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  // ── PlanIt ─────────────────────────────────────────────────────────────────
  bool get planItTaskDue => _b('planit_task_due');
  set planItTaskDue(bool v) => _setB('planit_task_due', v);

  /// Days before task due to remind (1 / 3 / 7)
  int get planItTaskDueDays => _i('planit_task_due_days', def: 1);
  set planItTaskDueDays(int v) => _setI('planit_task_due_days', v);

  bool get planItSpecialDay => _b('planit_special_day');
  set planItSpecialDay(bool v) => _setB('planit_special_day', v);

  /// Days before special day to remind (1 / 3 / 7)
  int get planItSpecialDayDays => _i('planit_special_day_days', def: 3);
  set planItSpecialDayDays(int v) => _setI('planit_special_day_days', v);

  bool get planItAlertMe => _b('planit_alert_me');
  set planItAlertMe(bool v) => _setB('planit_alert_me', v);

  bool get planItStickyMentions => _b('planit_sticky_mentions');
  set planItStickyMentions(bool v) => _setB('planit_sticky_mentions', v);

  // ── Functions ──────────────────────────────────────────────────────────────
  bool get functionsUpcoming => _b('functions_upcoming');
  set functionsUpcoming(bool v) => _setB('functions_upcoming', v);

  /// Days before function to remind (3 / 7 / 14)
  int get functionsUpcomingDays => _i('functions_upcoming_days', def: 7);
  set functionsUpcomingDays(int v) => _setI('functions_upcoming_days', v);

  // ── Quiet Hours (DND) ──────────────────────────────────────────────────────
  bool get quietHoursEnabled => _b('quiet_hours_enabled', def: false);
  set quietHoursEnabled(bool v) => _setB('quiet_hours_enabled', v);

  /// Hour (0–23) when quiet hours start. Default 22 (10 PM).
  int get quietStart => _i('quiet_start', def: 22);
  set quietStart(int v) => _setI('quiet_start', v);

  /// Hour (0–23) when quiet hours end. Default 7 (7 AM).
  int get quietEnd => _i('quiet_end', def: 7);
  set quietEnd(int v) => _setI('quiet_end', v);

  /// Returns true if the current local time is inside the quiet window.
  bool get isQuietNow => isHourQuiet(DateTime.now().hour);

  /// Same check as [isQuietNow] but for an arbitrary hour — used to decide
  /// whether a *future* scheduled local notification (e.g. a reminder alarm)
  /// will land inside quiet hours at fire time, since it can't be evaluated
  /// against "now" ahead of time.
  bool isHourQuiet(int hour) {
    if (!quietHoursEnabled) return false;
    final start = quietStart;
    final end   = quietEnd;
    // Handles overnight window (e.g. 22 → 07)
    return start > end
        ? (hour >= start || hour < end)
        : (hour >= start && hour < end);
  }
}
