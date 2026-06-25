import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/app_routes.dart';
import '../../core/logging/app_logger.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/auth/auth_coordinator.dart';

// Sessions inactive for longer than this are expired and force re-login.
const _kInactivityDays = 30;
const _kLastActiveKey  = 'wai_last_active_ms';

/// Call on every app foreground resume to update the inactivity timestamp.
Future<void> recordActivity() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kLastActiveKey, DateTime.now().millisecondsSinceEpoch);
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    AppLogger.i("SplashScreen initialized");
    _init();
  }

  Future<void> _init() async {
    final loggedIn = AuthCoordinator.instance.isLoggedIn;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (loggedIn && await _isSessionExpired()) {
      await AuthCoordinator.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    if (loggedIn) await recordActivity();
    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      loggedIn ? AppRoutes.bottomNav : AppRoutes.login,
    );
  }

  Future<bool> _isSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kLastActiveKey);
    if (lastMs == null) return false; // first launch — not expired
    final lastActive = DateTime.fromMillisecondsSinceEpoch(lastMs);
    return DateTime.now().difference(lastActive).inDays >= _kInactivityDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App Name
              Text(
                'WAI Life Assistance',
                style: AppTextStyles.title.copyWith(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.sm),

              // Tagline
              Text(
                'Your personal life companion',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
