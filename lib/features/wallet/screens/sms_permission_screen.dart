import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/features/wallet/screens/sms_history_import_screen.dart';
import 'package:wai_life_assistant/features/wallet/services/sms_parser_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SMSPermissionScreen
// Shows before requesting READ_SMS / RECEIVE_SMS so the user understands
// what the app reads and why. Nothing is read without explicit consent.
// ─────────────────────────────────────────────────────────────────────────────

class SMSPermissionScreen extends StatelessWidget {
  final String? walletId;
  final VoidCallback? onImported;

  const SMSPermissionScreen({super.key, this.walletId, this.onImported});

  static Future<void> show(
    BuildContext context, {
    String? walletId,
    VoidCallback? onImported,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SMSPermissionScreen(walletId: walletId, onImported: onImported),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : Colors.white;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: sub.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.sms_outlined,
              size: 36,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Auto-track your transactions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'WAI reads your bank SMS to suggest transactions automatically. '
            'No SMS is stored on our servers — everything is processed on your device.',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Nunito',
              color: sub,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          _point('🏦', 'Bank transaction alerts only',
              'We only process SMS from your bank'),
          _point('🔒', 'Never stored or shared',
              'SMS content never leaves your device'),
          _point('✅', 'You confirm every transaction',
              'Nothing is saved without your approval'),
          _point('🚫', 'You can disable anytime',
              'Turn off in Settings → SMS Tracking'),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await SMSParserService.initialize();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1e1b4b),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Enable Auto-tracking',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Not now',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
                color: sub,
              ),
            ),
          ),
          if (walletId != null) ...[
            const Divider(height: 24),
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await SmsHistoryImportScreen.show(
                  context,
                  walletId: walletId!,
                  onImported: onImported,
                );
              },
              icon: const Icon(Icons.history, size: 16, color: Color(0xFF6366F1)),
              label: const Text(
                'Import past transactions instead',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF6366F1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _point(String emoji, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
