import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../core/logging/app_logger.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/auth/auth_service.dart';

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
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final loggedIn = AuthService.instance.isLoggedIn;
    Navigator.pushReplacementNamed(
      context,
      loggedIn ? AppRoutes.bottomNav : AppRoutes.login,
    );
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
