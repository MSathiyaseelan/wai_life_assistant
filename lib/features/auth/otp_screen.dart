import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import 'package:wai_life_assistant/data/services/profile_service.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'auth_coordinator.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  /// Name collected on the Login screen — saved to the profile immediately
  /// on first verification so new users don't need a separate name prompt.
  final String name;
  const OtpScreen({super.key, required this.phone, this.name = ''});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  String? _error;
  int _resendSeconds = 30;
  bool _canResend = false;
  int _resendCount = 0;
  static const int _maxResends = 3;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthCoordinator.instance.isAutoVerified) {
        // Android auto-read the SMS — skip manual OTP entry
        _verify();
      } else {
        _nodes[0].requestFocus();
      }
    });
  }

  void _startResendTimer() {
    _resendSeconds = 30;
    _canResend = false;
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
          _tick();
        } else {
          _canResend = true;
        }
      });
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    for (final n in _nodes) { n.dispose(); }
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  void _onDigitInput(int index, String value) {
    setState(() => _error = null);
    if (value.isNotEmpty && index < 5) {
      _nodes[index + 1].requestFocus();
    }
    if (_otp.length == 6) _verify();
  }

  void _onBackspace(int index) {
    if (_ctrls[index].text.isEmpty && index > 0) {
      _ctrls[index - 1].clear();
      _nodes[index - 1].requestFocus();
    }
  }

  Future<void> _verify() async {
    if (_otp.length < 6) {
      setState(() => _error = 'Please enter the 6-digit OTP');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthCoordinator.instance.verifyOtp(widget.phone, _otp);
      if (!mounted) return;
      var profile = await ProfileService.instance.fetchProfile();
      if (!mounted) return;
      final nameFromLogin = widget.name.trim();
      if (profile == null) {
        // First-time sign-in — create the profile now with the name already
        // collected on the Login screen, alongside the verified mobile number.
        await ProfileService.instance.bootstrapNewUser(name: nameFromLogin);
        if (!mounted) return;
        profile = await ProfileService.instance.fetchProfile();
        if (!mounted) return;
      } else if (nameFromLogin.isNotEmpty &&
          (profile['name'] as String?)?.trim().isEmpty != false) {
        // Profile row already exists (e.g. an older account created before
        // Login collected a name) but has none set yet — apply what was just
        // typed instead of silently discarding it.
        await ProfileService.instance.updateProfile(name: nameFromLogin);
        if (!mounted) return;
        profile = await ProfileService.instance.fetchProfile();
        if (!mounted) return;
      }
      final hasName = (profile?['name'] as String?)?.trim().isNotEmpty == true;
      if (!hasName) {
        // New user or profile has no name — go to profile setup.
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.profileSetup,
          (route) => false,
        );
      } else {
        // Returning user — go straight to dashboard.
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.bottomNav,
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'otp_verify', severity: ErrorSeverity.critical);
      if (kDebugMode) debugPrint('[OTP] verification error: $e');
      if (!mounted) return;
      setState(() => _error = 'Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCount >= _maxResends) {
      setState(() => _error = 'Too many resend attempts. Please go back and try again.');
      return;
    }
    for (final c in _ctrls) { c.clear(); }
    _nodes[0].requestFocus();
    setState(() { _error = null; _resendCount++; });
    _startResendTimer();
    try {
      await AuthCoordinator.instance.resendOtp(widget.phone);
    } catch (_) {
      // Resend failure is non-fatal — user can retry again after the timer.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF4F5FF);
    final card = isDark ? const Color(0xFF1A1B2E) : Colors.white;
    final tc = isDark ? Colors.white : const Color(0xFF0F172A);
    final sub = isDark ? Colors.white54 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF252640)
                          : const Color(0xFFF1F2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: tc,
                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Icon
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('🔐', style: TextStyle(fontSize: 30)),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                Center(
                  child: Text(
                    'Verify your number',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                      children: [
                        const TextSpan(text: 'We sent a 6-digit OTP to\n'),
                        TextSpan(
                          text: widget.phone,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // OTP boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (i) => _OtpBox(
                          controller: _ctrls[i],
                          focusNode: _nodes[i],
                          isDark: isDark,
                          hasError: _error != null,
                          onChanged: (v) => _onDigitInput(i, v),
                          onBackspace: () => _onBackspace(i),
                        )),
                      ),

                      // Error
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.error_outline_rounded,
                                size: 14,
                                color: AppColors.error,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.error,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Verify button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: (_otp.length == 6 && !_loading)
                              ? _verify
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor:
                                AppColors.primary.withValues(alpha: 0.4),
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
                              : const Text(
                                  'Verify & Continue',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Resend row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't receive the OTP? ",
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                          _canResend
                              ? GestureDetector(
                                  onTap: _resend,
                                  child: const Text(
                                    'Resend',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Nunito',
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Resend in ${_resendSeconds}s',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: sub,
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.hasError,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final isFocused = focusNode.hasFocus;
    final filled = controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 44,
      height: 52,
      decoration: BoxDecoration(
        color: hasError
            ? AppColors.error.withValues(alpha: 0.08)
            : filled
                ? AppColors.primary.withValues(alpha: 0.1)
                : (isDark ? const Color(0xFF252640) : const Color(0xFFF1F2FF)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError
              ? AppColors.error
              : isFocused
                  ? AppColors.primary
                  : filled
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : Colors.transparent,
          width: 2,
        ),
      ),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (e) {
          if (e is KeyDownEvent &&
              e.logicalKey == LogicalKeyboardKey.backspace) {
            onBackspace();
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
            color: hasError
                ? AppColors.error
                : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
          ),
        ),
      ),
    );
  }
}
