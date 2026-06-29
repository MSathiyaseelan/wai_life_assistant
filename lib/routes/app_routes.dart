import 'package:flutter/material.dart';
import '../features/splash/splash_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/profile_setup_screen.dart';
import 'package:wai_life_assistant/navigation/bottom_nav_screen.dart';

class AppRoutes {
  static const String splash       = '/';
  static const String dashboard    = '/dashboard';
  static const String login        = '/login';
  static const String otp          = '/otp';
  static const String profileSetup = '/profileSetup';
  static const String bottomNav    = '/bottomNav';

  // Feature screens (not in the route table — pushed imperatively)
  static const String wallet     = '/wallet';
  static const String pantry     = '/pantry';
  static const String planit     = '/planit';
  static const String functions  = '/functions';
  static const String settings   = '/settings';

  static final Map<String, WidgetBuilder> routes = {
    splash:       (context) => const SplashScreen(),
    dashboard:    (context) => const DashboardScreen(),
    login:        (context) => const LoginScreen(),
    otp: (context) {
      final phone = ModalRoute.of(context)!.settings.arguments as String;
      return OtpScreen(phone: phone);
    },
    profileSetup: (context) => const ProfileSetupScreen(),
    bottomNav:    (context) => const BottomNavScreen(),
  };
}
