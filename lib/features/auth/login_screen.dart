import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import 'auth_coordinator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl   = TextEditingController();
  final _nameFocus  = FocusNode();
  final _phoneCtrl  = TextEditingController();
  final _phoneFocus = FocusNode();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => setState(() {}));
    _phoneFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameCtrl.text.trim().isNotEmpty && _phoneCtrl.text.trim().length == 10;

  Future<void> _sendOtp() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    if (phone.length != 10) {
      setState(() => _error = 'Please enter a valid 10-digit mobile number');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthCoordinator.instance.sendOtp('+91$phone');
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.otp,
        arguments: {'phone': '+91$phone', 'name': name},
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to send OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF4F5FF);
    final card    = isDark ? const Color(0xFF1A1B2E) : Colors.white;
    final tc      = isDark ? Colors.white : const Color(0xFF0F172A);
    final sub     = isDark ? Colors.white54 : const Color(0xFF64748B);
    final fieldBg = isDark ? const Color(0xFF252640) : const Color(0xFFF1F2FF);

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
                const SizedBox(height: 64),

                // Logo
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('✨', style: TextStyle(fontSize: 36)),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                Center(
                  child: Text(
                    'RiyasHome Life Assistance',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Enter your name and mobile number to continue',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                    textAlign: TextAlign.center,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('Your Name', sub),
                      const SizedBox(height: 8),
                      _InputBox(
                        hasFocus: _nameFocus.hasFocus,
                        hasError: _error != null && _nameCtrl.text.trim().isEmpty,
                        fieldBg: fieldBg,
                        child: TextField(
                          controller: _nameCtrl,
                          focusNode: _nameFocus,
                          keyboardType: TextInputType.name,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() => _error = null),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: tc,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            hintText: 'e.g. Sathiyaseelan',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Nunito',
                              color: sub.withValues(alpha: 0.5),
                            ),
                            prefixIcon: Icon(
                              Icons.person_rounded,
                              size: 20,
                              color: _nameFocus.hasFocus
                                  ? AppColors.primary
                                  : sub.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      _FieldLabel('Mobile Number', sub),
                      const SizedBox(height: 8),
                      _InputBox(
                        hasFocus: _phoneFocus.hasFocus,
                        hasError: _error != null && _phoneCtrl.text.trim().length != 10,
                        fieldBg: fieldBg,
                        child: Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.all(6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Text('🇮🇳',
                                      style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '+91',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Nunito',
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _phoneCtrl,
                                focusNode: _phoneFocus,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (_) => setState(() => _error = null),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Nunito',
                                  letterSpacing: 2,
                                  color: tc,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '00000 00000',
                                  hintStyle: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400,
                                    fontFamily: 'Nunito',
                                    letterSpacing: 2,
                                    color: sub.withValues(alpha: 0.5),
                                  ),
                                  counterText: '',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 14, color: AppColors.error),
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

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: (_isValid && !_loading) ? _sendOtp : null,
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
                                  'Send OTP',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Center(
                  child: Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      color: sub.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _FieldLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
          color: color,
        ),
      );
}

class _InputBox extends StatelessWidget {
  final bool hasFocus;
  final bool hasError;
  final Color fieldBg;
  final Widget child;

  const _InputBox({
    required this.hasFocus,
    required this.hasError,
    required this.fieldBg,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: fieldBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasError
                ? AppColors.error
                : hasFocus
                    ? AppColors.primary
                    : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: child,
      );
}
