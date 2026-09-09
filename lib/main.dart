import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/navigation/error_tracking_observer.dart';
import 'core/services/error_logger.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'app_bootstrap.dart';
import 'core/env/environment_config.dart';
import 'core/env/app_environment.dart';

void main() {
  // ── Handler 1: Flutter framework errors (widget build, layout, rendering) ──
  // Set before ensureInitialized so it catches errors during binding setup.
  FlutterError.onError = (FlutterErrorDetails details) {
    ErrorLogger.log(
      details.exception,
      stackTrace: details.stack,
      severity:   details.silent ? ErrorSeverity.warning : ErrorSeverity.error,
      action:     'flutter_framework_error',
      extra: {
        'library':  details.library,
        'context':  details.context?.toString(),
        'silent':   details.silent,
        'is_debug': kDebugMode,
      },
    );
    FirebaseCrashlytics.instance.recordFlutterError(details);
    if (kDebugMode) FlutterError.presentError(details);
  };

  // ── Handler 2 (supplement): Native platform / method-channel exceptions ───
  // PlatformDispatcher catches errors that escape the Flutter framework layer
  // (e.g. platform channel errors, isolate startup failures).
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorLogger.log(
      error,
      stackTrace: stack,
      severity:   ErrorSeverity.critical,
      action:     'platform_dispatcher_error',
    );
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  const env = String.fromEnvironment('ENV', defaultValue: 'dev');

  // ── Handler 3: Dart async / isolate errors not caught anywhere else ────────
  // ensureInitialized must be called inside the same zone as runApp, so it
  // lives here rather than before runZonedGuarded.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await bootstrapApp(env);
    },
    (error, stackTrace) {
      ErrorLogger.log(
        error,
        stackTrace: stackTrace,
        severity:   ErrorSeverity.critical,
        action:     'unhandled_async_error',
      );
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
    },
  );
}

class LifeAssistanceApp extends StatelessWidget {
  final EnvironmentConfig config;
  const LifeAssistanceApp({super.key, required this.config});

  /// App-wide messenger, independent of any single screen's BuildContext.
  /// AppUpdateService needs this: an in-app-update download can take
  /// anywhere from seconds to minutes, and by the time it finishes the user
  /// may have navigated away from (or the framework may have disposed) the
  /// screen whose context originally started the check — showing the
  /// "restart to apply" prompt through this key instead means it still
  /// reaches the user wherever they currently are, rather than being
  /// silently dropped or shown on a hidden, buried screen.
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  /// App-wide navigator, for the same reason as [scaffoldMessengerKey] —
  /// AppUpdateService's "restart to apply" prompt is now a proper modal
  /// sheet (UpdateReadySheet) rather than a SnackBar, which needs a
  /// BuildContext with a Navigator above it to call showModalBottomSheet,
  /// independent of whichever screen happens to be active when the
  /// download finishes.
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: config.environment != AppEnvironment.prod,
      title: config.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
      navigatorObservers: [ErrorTrackingObserver()],
    );
  }
}
