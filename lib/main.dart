import 'dart:async';
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
  WidgetsFlutterBinding.ensureInitialized();

  // ── Handler 1: Flutter framework errors (widget build, layout, rendering) ──
  FlutterError.onError = (FlutterErrorDetails details) {
    // Always log so errors are captured during development too.
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
    // In debug: also show the red error overlay so it's immediately visible.
    if (kDebugMode) FlutterError.presentError(details);
  };

  const env = String.fromEnvironment('ENV', defaultValue: 'dev');

  // ── Handler 2: Dart async / isolate errors not caught anywhere else ────────
  runZonedGuarded(
    () async { await bootstrapApp(env); },
    (error, stackTrace) {
      ErrorLogger.log(
        error,
        stackTrace: stackTrace,
        severity:   ErrorSeverity.critical,
        action:     'unhandled_async_error',
      );
    },
  );
}

class LifeAssistanceApp extends StatelessWidget {
  final EnvironmentConfig config;
  const LifeAssistanceApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
