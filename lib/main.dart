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
    if (kDebugMode) FlutterError.presentError(details);
  };

  const env = String.fromEnvironment('ENV', defaultValue: 'dev');

  // ── Handler 2: Dart async / isolate errors not caught anywhere else ────────
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
