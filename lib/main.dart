import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'app_bootstrap.dart';
import 'core/env/environment_config.dart';
import 'core/env/app_environment.dart';

void main() {
  const env = String.fromEnvironment('ENV', defaultValue: 'dev');

  bootstrapApp(env);
}

class LifeAssistanceApp extends StatelessWidget {
  final EnvironmentConfig config;
  const LifeAssistanceApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Root widget
      debugShowCheckedModeBanner: config.environment != AppEnvironment.prod,
      title: config.appName,
      //theme: AppTheme.lightTheme,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      //themeMode: _themeMode,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
