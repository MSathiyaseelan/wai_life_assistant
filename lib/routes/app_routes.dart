import 'package:flutter/material.dart';
import '../features/splash/splash_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/auth/login_screen.dart';
import 'package:wai_life_assistant/navigation/bottom_nav_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String dashboard = '/dashboard';
  static const String login = '/login';
  static const String bottomNav = '/bottomNav';

  static final Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    dashboard: (context) => const DashboardScreen(),
    login: (context) => const LoginScreen(),
    bottomNav: (context) => const BottomNavScreen(),
  };
}
