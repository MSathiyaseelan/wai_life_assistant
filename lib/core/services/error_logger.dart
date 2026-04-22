import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ERROR LOGGER
// Enriches exceptions with device/user/screen context then persists to the
// error_logs Supabase table.  Never throws — if logging itself fails it
// falls back to debugPrint so the original error is never swallowed.
// ─────────────────────────────────────────────────────────────────────────────

enum ErrorSeverity {
  critical, // app crash, data-loss risk
  error,    // feature broken, user impacted
  warning,  // degraded experience
  info,     // diagnostic context, non-breaking
}

class _DeviceInfo {
  final String model;
  final String osVersion;
  const _DeviceInfo({required this.model, required this.osVersion});
}

class ErrorLogger {
  ErrorLogger._();

  static final _db = Supabase.instance.client;

  static _DeviceInfo? _device;
  static PackageInfo? _pkg;

  // Updated by ErrorTrackingObserver on every navigation event.
  static String _screen  = 'unknown';
  static String _feature = 'unknown';

  // ── Init (call once in app_bootstrap, after Supabase.initialize) ───────────
  static Future<void> initialize() async {
    try {
      _pkg    = await PackageInfo.fromPlatform();
      _device = await _fetchDeviceInfo();
    } catch (e) {
      debugPrint('[ErrorLogger] init failed (non-fatal): $e');
    }
  }

  // ── Called by ErrorTrackingObserver ────────────────────────────────────────
  static void setScreen(String screen, {String? feature}) {
    _screen  = screen;
    _feature = feature ?? _feature;
  }

  // ── Primary log method ─────────────────────────────────────────────────────
  static Future<void> log(
    dynamic error, {
    StackTrace?           stackTrace,
    ErrorSeverity         severity  = ErrorSeverity.error,
    String?               action,
    String?               familyId,
    String?               appScope,
    Map<String, dynamic>? extra,
  }) async {
    // Always print in debug so you still see it in the IDE console.
    debugPrint('[ErrorLogger] ${severity.name.toUpperCase()}: $error');
    if (stackTrace != null && kDebugMode) debugPrint(stackTrace.toString());

    try {
      final uid      = _db.auth.currentUser?.id;
      final isOnline = await _checkOnline();

      await _db.from('error_logs').insert({
        'error_type':    error.runtimeType.toString(),
        'error_message': error.toString(),
        'stack_trace':   stackTrace?.toString(),
        'screen_name':   _screen,
        'feature':       _feature,
        'action':        action,
        'severity':      severity.name,
        'user_id':       uid,
        'family_id':     familyId,
        'app_scope':     appScope,
        'device_os':     Platform.isAndroid ? 'android' : 'ios',
        'os_version':    _device?.osVersion,
        'device_model':  _device?.model,
        'app_version':   _pkg?.version,
        'build_number':  _pkg?.buildNumber,
        'was_online':    isOnline,
        'extra_data':    extra,
        'status':        'new',
      });
    } catch (loggingError) {
      // Logging must never crash the app.
      debugPrint('[ErrorLogger] failed to persist error: $loggingError');
      debugPrint('[ErrorLogger] original error: $error');
    }
  }

  // ── Convenience methods ────────────────────────────────────────────────────

  static Future<void> critical(
    dynamic error, {
    StackTrace?           stackTrace,
    String?               action,
    Map<String, dynamic>? extra,
  }) => log(error, stackTrace: stackTrace, severity: ErrorSeverity.critical, action: action, extra: extra);

  static Future<void> warning(
    dynamic error, {
    String?               action,
    Map<String, dynamic>? extra,
  }) => log(error, severity: ErrorSeverity.warning, action: action, extra: extra);

  static Future<void> info(
    String message, {
    Map<String, dynamic>? extra,
  }) => log(message, severity: ErrorSeverity.info, extra: extra);

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<_DeviceInfo> _fetchDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return _DeviceInfo(model: info.model, osVersion: info.version.release);
    } else {
      final info = await plugin.iosInfo;
      return _DeviceInfo(model: info.model, osVersion: info.systemVersion);
    }
  }

  // connectivity_plus v6 returns List<ConnectivityResult>
  static Future<bool> _checkOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.isNotEmpty && !results.contains(ConnectivityResult.none);
    } catch (_) {
      return true; // assume online if connectivity check fails
    }
  }
}
