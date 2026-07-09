import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Privacy Policy Sheet — DPDP Act (India) compliant
// ─────────────────────────────────────────────────────────────────────────────

class PrivacyPolicySheet extends StatelessWidget {
  final bool isDark;
  const PrivacyPolicySheet({super.key, required this.isDark});

  Color get _bg   => isDark ? AppColors.cardDark  : AppColors.cardLight;
  Color get _tc   => isDark ? AppColors.textDark  : AppColors.textLight;
  Color get _sub  => isDark ? AppColors.subDark   : AppColors.subLight;

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
                _section('1. Data Fiduciary', Icons.business_rounded, const Color(0xFF4F46E5), [
                  _para('WAI Life Assistant ("WAI", "we", "us") is the Data Fiduciary as defined under the Digital Personal Data Protection Act, 2023 (DPDP Act). WAI is operated by an independent developer based in India.'),
                  _para('Contact: successsathiya@gmail.com'),
                ]),
                _section('2. Data We Collect', Icons.inventory_2_rounded, const Color(0xFF0EA5E9), [
                  _para('We collect only the personal data you choose to enter into the app:'),
                  _bullet('Identity: Name, date of birth'),
                  _bullet('Contact: Mobile phone number (used for OTP login)'),
                  _bullet('Financial: Income, expenses, wallets, budgets you record'),
                  _bullet('Lifestyle: Health notes, pantry items, tasks, reminders, wardrobe entries, wishes'),
                  _bullet('Device: Firebase device token for push notifications'),
                  _para('We do not collect location data, contacts, camera images (unless you upload a bill), or any background sensor data.'),
                ]),
                _section('3. Purpose of Processing', Icons.track_changes_rounded, const Color(0xFF10B981), [
                  _para('Your data is used solely to provide and improve the WAI app\'s features:'),
                  _bullet('Authenticating your identity via OTP'),
                  _bullet('Storing and displaying your personal records across devices'),
                  _bullet('Sending reminders and alerts you create'),
                  _bullet('Running AI parsing on data you explicitly submit (e.g., bill scan, SMS parser)'),
                  _para('We do not use your data for advertising, profiling, or selling to third parties.'),
                ]),
                _section('4. Data Storage & Security', Icons.shield_rounded, const Color(0xFF8B5CF6), [
                  _para('Your data is stored in Supabase (hosted on AWS ap-south-1 — Mumbai region). All data is:'),
                  _bullet('Encrypted in transit (TLS 1.3)'),
                  _bullet('Encrypted at rest (AES-256)'),
                  _bullet('Access-controlled by Row Level Security — only you can read your records'),
                  _bullet('Locally cached credentials are stored in encrypted storage (Android Keystore / iOS Secure Enclave)'),
                ]),
                _section('5. Your Rights (DPDP Act 2023)', Icons.verified_user_rounded, const Color(0xFFF59E0B), [
                  _para('As a Data Principal under the DPDP Act, you have the following rights:'),
                  _bullet('Right to Access: View all data we hold about you (use Export My Data in Privacy & Security settings)'),
                  _bullet('Right to Correction: Edit any data directly in the app'),
                  _bullet('Right to Erasure: Request full account deletion — your data is deleted within 30 days'),
                  _bullet('Right to Grievance Redressal: Contact us at successsathiya@gmail.com — we respond within 7 days'),
                  _bullet('Right to Withdraw Consent: Delete your account at any time from Privacy & Security settings'),
                ]),
                _section('6. Data Retention', Icons.schedule_rounded, const Color(0xFFEC4899), [
                  _para('We retain your data for as long as your account is active. When you delete your account:'),
                  _bullet('All your personal records are immediately soft-deleted'),
                  _bullet('Hard deletion completes within 30 days'),
                  _bullet('Anonymised aggregate statistics (no personal identifiers) may be retained for service improvement'),
                  _para('Deleted items in the Recycle Bin are permanently purged after 30 days.'),
                ]),
                _section('7. Third-Party Services', Icons.extension_rounded, const Color(0xFF64748B), [
                  _para('WAI uses these third-party services:'),
                  _bullet('Firebase (Google) — OTP authentication and push notifications. Privacy policy: firebase.google.com/support/privacy'),
                  _bullet('Supabase — Database, storage, and edge functions. Privacy policy: supabase.com/privacy'),
                  _bullet('Google Gemini API — AI text parsing (only data you explicitly submit; processed server-side, not stored by Google beyond processing). Privacy policy: policies.google.com/privacy'),
                  _para('We share only the minimum necessary data with each service.'),
                ]),
                _section('8. Children\'s Privacy', Icons.child_care_rounded, const Color(0xFFEF4444), [
                  _para('WAI is not intended for children under 18. We do not knowingly collect personal data from minors. If you believe a minor has provided data, contact us immediately.'),
                ]),
                _section('9. Changes to This Policy', Icons.update_rounded, const Color(0xFF06B6D4), [
                  _para('We may update this policy from time to time. Material changes will be notified in-app. Continued use of the app after notification constitutes acceptance of the updated policy.'),
                ]),
                _section('10. Grievance Officer', Icons.support_agent_rounded, AppColors.primary, [
                  _para('As required under the DPDP Act, you may contact our Grievance Officer for any data-related concerns:'),
                  _para('Email: successsathiya@gmail.com\nResponse time: Within 7 business days'),
                  _para('To exercise your right to erasure, use the "Delete My Account" option in Privacy & Security settings, or contact us at the above email.'),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _handle() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _sub.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 10),
        child: Row(
          children: [
            Text(
              '🛡️  Privacy Policy',
              style: TextStyle(
                fontSize: 17,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                color: _tc,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close_rounded, color: _sub, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

  Widget _lastUpdated() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withAlpha(40)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Last updated: June 2026  ·  Compliant with DPDP Act 2023 (India)',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _section(String title, IconData icon, Color color, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      color: _tc,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );

  Widget _para(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontFamily: 'Nunito',
            height: 1.55,
            color: _sub,
          ),
        ),
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5, right: 8),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: _sub.withAlpha(160),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  fontFamily: 'Nunito',
                  height: 1.55,
                  color: _sub,
                ),
              ),
            ),
          ],
        ),
      );
}
