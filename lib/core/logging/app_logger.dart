import 'dart:developer' as developer;
import '../env/env.dart';
import 'log_level.dart';

class AppLogger {
  static bool get _isLoggingEnabled => envConfig.enableLogs;

  static void _log(
    String message, {
    LogLevel level = LogLevel.debug,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_isLoggingEnabled) return;

    developer.log(
      message,
      name: 'LifeAssistance',
      error: error,
      stackTrace: stackTrace,
      level: _mapLevel(level),
    );
  }

  static int _mapLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }

  // Public APIs
  static void d(String message) => _log(message, level: LogLevel.debug);

  static void i(String message) => _log(message, level: LogLevel.info);

  static void w(String message) => _log(message, level: LogLevel.warning);

  static void e(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(
        message,
        level: LogLevel.error,
        error: error,
        stackTrace: stackTrace,
      );
}
