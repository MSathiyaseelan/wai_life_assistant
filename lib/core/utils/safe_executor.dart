import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/error_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SAFE EXECUTOR
// Wraps async operations with typed error handling + automatic ErrorLogger
// reporting.  Each error type gets the right severity and relevant context.
//
// Usage:
//   final result = await SafeExecutor.run(
//     () => WalletService.instance.addTransaction(...),
//     feature: 'wallet',
//     action:  'add_expense',
//     extra:   {'amount': 500, 'category': 'Food'},
//   );
// ─────────────────────────────────────────────────────────────────────────────

class SafeExecutor {
  SafeExecutor._();

  static Future<T?> run<T>(
    Future<T> Function() operation, {
    required String feature,
    required String action,
    T? fallback,
    bool throwOnError = false,
    Map<String, dynamic>? extra,
  }) async {
    try {
      return await operation();

    } on PostgrestException catch (e, stack) {
      await ErrorLogger.log(
        e,
        stackTrace: stack,
        severity:   ErrorSeverity.error,
        action:     action,
        extra: {
          'feature':     feature,
          'db_code':     e.code,
          'db_hint':     e.hint,
          'db_details':  e.details,
          ...?extra,
        },
      );
      if (throwOnError) rethrow;
      return fallback;

    } on FunctionException catch (e, stack) {
      await ErrorLogger.log(
        e,
        stackTrace: stack,
        severity:   ErrorSeverity.error,
        action:     action,
        extra: {
          'feature':          feature,
          'function_status':  e.status,
          'function_details': e.details,
          ...?extra,
        },
      );
      if (throwOnError) rethrow;
      return fallback;

    } on SocketException catch (e, stack) {
      await ErrorLogger.log(
        e,
        stackTrace: stack,
        severity:   ErrorSeverity.warning,
        action:     action,
        extra: {'feature': feature, ...?extra},
      );
      if (throwOnError) rethrow;
      return fallback;

    } on TimeoutException catch (e, stack) {
      await ErrorLogger.log(
        e,
        stackTrace: stack,
        severity:   ErrorSeverity.warning,
        action:     action,
        extra: {'feature': feature, ...?extra},
      );
      if (throwOnError) rethrow;
      return fallback;

    } catch (e, stack) {
      await ErrorLogger.log(
        e,
        stackTrace: stack,
        severity:   ErrorSeverity.error,
        action:     action,
        extra: {'feature': feature, ...?extra},
      );
      if (throwOnError) rethrow;
      return fallback;
    }
  }
}
