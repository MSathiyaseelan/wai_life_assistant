import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/profile_service.dart';
import '../../core/services/error_logger.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingSlide {
  final String emoji;
  final String title;
  final String subtitle;
  const _OnboardingSlide({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
}

const _slides = [
  _OnboardingSlide(
    emoji: '💰',
    title: 'Wallet',
    subtitle:
        'Track expenses and income with AI — just type or speak "Coffee 15 gpay" '
        'and it fills in the rest. Split bills, set budgets, and see where your money goes.',
  ),
  _OnboardingSlide(
    emoji: '🥗',
    title: 'Pantry',
    subtitle:
        'Plan meals, manage your grocery list, and scan bills to auto-add items — '
        'never run out of what you need.',
  ),
  _OnboardingSlide(
    emoji: '📅',
    title: 'PlanIt',
    subtitle:
        'Tasks, reminders, special days, and notes in one place — with smart '
        'alerts so nothing important slips through.',
  ),
  _OnboardingSlide(
    emoji: '🎊',
    title: 'Functions & Family',
    subtitle:
        'Keep track of functions you attend and host, record gifts given and '
        'received, and share it all with your family group.',
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _index = 0;
  bool _loading = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _slides.length - 1;

  Future<void> _finish() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await ProfileService.instance.markOnboarded();
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'mark_onboarded');
      // Non-fatal — still let the user into the app even if this write fails.
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.bottomNav, (route) => false);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF4F5FF);
    final tc = isDark ? Colors.white : const Color(0xFF0F172A);
    final sub = isDark ? Colors.white54 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: TextButton(
                  onPressed: _loading ? null : _finish,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(slide.emoji, style: const TextStyle(fontSize: 56)),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          slide.title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            color: tc,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Nunito',
                            color: sub,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : sub.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _isLast ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
