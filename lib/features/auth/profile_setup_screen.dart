import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/profile_service.dart';
import '../../core/services/error_logger.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl  = TextEditingController();
  final _nameFocus = FocusNode();

  DateTime? _dob;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _nameFocus.requestFocus());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _isValid => _nameCtrl.text.trim().isNotEmpty;

  String get _dobDisplay {
    if (_dob == null) return 'DD / MM / YYYY';
    return '${_dob!.day.toString().padLeft(2, '0')} / '
        '${_dob!.month.toString().padLeft(2, '0')} / '
        '${_dob!.year}';
  }

  Future<void> _pickDob() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select Date of Birth',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final profile = await ProfileService.instance.fetchProfile();
      if (profile == null) {
        await ProfileService.instance.bootstrapNewUser(name: name);
      }
      final dob = _dob == null
          ? null
          : '${_dob!.year}-'
            '${_dob!.month.toString().padLeft(2, '0')}-'
            '${_dob!.day.toString().padLeft(2, '0')}';
      await ProfileService.instance.updateProfile(name: name, dob: dob);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.onboarding,
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'profile_setup');
      if (!mounted) return;
      setState(() => _error = 'Failed to save profile. Please try again.');
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
                const SizedBox(height: 48),

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
                      child: Text('👤', style: TextStyle(fontSize: 30)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Center(
                  child: Text(
                    'Set up your profile',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Tell us a bit about yourself',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 36),

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
                      // Name
                      _FieldLabel('Your Name *', sub),
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

                      // DOB (optional)
                      _FieldLabel('Date of Birth (optional)', sub),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickDob,
                        child: _InputBox(
                          hasFocus: false,
                          hasError: false,
                          fieldBg: fieldBg,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cake_rounded,
                                  size: 20,
                                  color: _dob != null
                                      ? AppColors.primary
                                      : sub.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _dobDisplay,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: _dob != null
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    fontFamily: 'Nunito',
                                    color: _dob != null
                                        ? tc
                                        : sub.withValues(alpha: 0.5),
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.calendar_month_rounded,
                                  size: 18,
                                  color: sub.withValues(alpha: 0.4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(Icons.error_outline_rounded,
                                  size: 14, color: AppColors.error),
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

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: (_isValid && !_loading) ? _save : null,
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
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Center(
                        child: TextButton(
                          onPressed: _loading ? null : _skip,
                          child: Text(
                            'Skip for now',
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                              color: sub,
                            ),
                          ),
                        ),
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

  void _skip() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.onboarding,
      (route) => false,
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
