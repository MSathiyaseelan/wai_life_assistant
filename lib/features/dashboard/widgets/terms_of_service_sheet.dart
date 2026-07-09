import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';

class TermsOfServiceSheet extends StatelessWidget {
  final bool isDark;
  const TermsOfServiceSheet({super.key, required this.isDark});

  Color get _bg  => isDark ? AppColors.cardDark : AppColors.cardLight;
  Color get _tc  => isDark ? AppColors.textDark : AppColors.textLight;
  Color get _sub => isDark ? AppColors.subDark  : AppColors.subLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _handle(),
          _header(context),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
              children: [
                _lastUpdated(),
                const SizedBox(height: 20),
                _section('1. Acceptance of Terms', Icons.handshake_rounded, const Color(0xFF4F46E5), [
                  _para('By downloading, installing, or using WAI Life Assistant ("WAI", "the App"), you agree to be bound by these Terms of Service. If you do not agree, do not use the App.'),
                  _para('These terms are governed by the laws of India.'),
                ]),
                _section('2. Use of the App', Icons.apps_rounded, const Color(0xFF0EA5E9), [
                  _para('WAI is a personal life management tool. You may use the App for lawful, personal, non-commercial purposes only. You must not:'),
                  _bullet('Use the App for any illegal or unauthorised purpose'),
                  _bullet('Attempt to gain unauthorised access to any part of the App or its infrastructure'),
                  _bullet('Reverse-engineer, decompile, or disassemble the App'),
                  _bullet('Transmit harmful, offensive, or misleading data through the App'),
                ]),
                _section('3. Your Account', Icons.person_rounded, const Color(0xFF10B981), [
                  _para('You are responsible for maintaining the confidentiality of your account and for all activity under your account. You must:'),
                  _bullet('Provide accurate information when creating your account'),
                  _bullet('Notify us immediately of any unauthorised use of your account'),
                  _bullet('Ensure your mobile number is correct for OTP authentication'),
                  _para('We reserve the right to suspend accounts that violate these terms.'),
                ]),
                _section('4. Data & Privacy', Icons.shield_rounded, const Color(0xFF8B5CF6), [
                  _para('Your use of the App is also governed by our Privacy Policy, which is incorporated into these Terms by reference. By using the App you consent to data practices described in the Privacy Policy.'),
                  _para('All your personal data is stored securely on Supabase infrastructure in the Mumbai (ap-south-1) region and is subject to Row Level Security — only you can access your records.'),
                ]),
                _section('5. Intellectual Property', Icons.copyright_rounded, const Color(0xFFF59E0B), [
                  _para('The App and all its content, features, and functionality are owned by the WAI team and are protected by applicable intellectual property laws.'),
                  _para('You are granted a limited, non-exclusive, non-transferable licence to use the App for personal purposes only. No ownership rights are transferred.'),
                ]),
                _section('6. Third-Party Services', Icons.hub_rounded, const Color(0xFFEC4899), [
                  _para('The App integrates third-party services that have their own terms:'),
                  _bullet('Firebase (Google) — authentication & push notifications'),
                  _bullet('Supabase — data storage and backend'),
                  _bullet('Google Gemini — AI assistant features'),
                  _para('We are not responsible for the practices of these third-party services.'),
                ]),
                _section('7. Disclaimer of Warranties', Icons.warning_amber_rounded, const Color(0xFFEF4444), [
                  _para('The App is provided "as is" without warranty of any kind. We do not warrant that the App will be error-free, uninterrupted, or free of harmful components.'),
                  _para('Financial figures, health data, and reminders displayed in the App are based solely on data you enter. WAI does not provide financial, medical, or legal advice.'),
                ]),
                _section('8. Limitation of Liability', Icons.gavel_rounded, const Color(0xFF6B7280), [
                  _para('To the maximum extent permitted by law, the WAI team shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the App.'),
                  _para('Our total liability for any claim arising from these terms shall not exceed the amount you paid for the App in the 12 months preceding the claim.'),
                ]),
                _section('9. Termination', Icons.cancel_rounded, const Color(0xFF64748B), [
                  _para('You may stop using the App at any time. You may request deletion of your account and data from within the App (Settings → Privacy & Security → Delete Account).'),
                  _para('We may suspend or terminate your access if you violate these Terms, with or without prior notice.'),
                ]),
                _section('10. Changes to Terms', Icons.edit_note_rounded, const Color(0xFF0369A1), [
                  _para('We may update these Terms from time to time. When we do, we will update the "Last Updated" date below and notify you through the App. Continued use after changes constitutes acceptance of the new terms.'),
                  _para('Contact for questions: successsathiya@gmail.com'),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: _sub.withAlpha(80),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Terms of Service',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                  color: _tc,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: _sub),
            ),
          ],
        ),
      );

  Widget _lastUpdated() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              'Last updated: June 2026',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );

  Widget _section(String title, IconData icon, Color color, List<Widget> children) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: _tc,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
          const SizedBox(height: 20),
        ],
      );

  Widget _para(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: _sub, height: 1.5),
        ),
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ', style: TextStyle(color: _sub, fontSize: 13)),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: _sub, height: 1.5),
              ),
            ),
          ],
        ),
      );
}
