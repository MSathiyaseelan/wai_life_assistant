import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import '_prefs_sheet_base.dart';
import 'privacy_policy_sheet.dart';
import 'terms_of_service_sheet.dart';

const _supportEmail = 'riyasailabs@gmail.com';
const _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.wai.lifeassistant';

class AboutWaiSheet extends StatelessWidget {
  final bool isDark;
  const AboutWaiSheet({super.key, required this.isDark});

  Color get _surf => isDark ? AppColors.surfDark   : const Color(0xFFEDEEF5);
  Color get _tc   => isDark ? AppColors.textDark   : AppColors.textLight;
  Color get _sub  => isDark ? AppColors.subDark    : AppColors.subLight;
  Color get _div  => isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(18);

  Future<void> _contactSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=${Uri.encodeComponent('WAI Support Request')}',
    );
    try {
      final launched = await launchUrl(uri);
      if (!launched) throw Exception('launchUrl returned false');
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'about_contact_support');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open email app. Contact us at $_supportEmail')),
      );
    }
  }

  Future<void> _rateApp(BuildContext context) async {
    final uri = Uri.parse(_playStoreUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('launchUrl returned false');
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'about_rate_wai');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Play Store.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrefsSheetBase(
      isDark: isDark,
      title: 'About WAI',
      loading: false,
      child: Column(
        children: [
          // App identity block
          Center(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: const Text('✦', style: TextStyle(fontSize: 34)),
                ),
                const SizedBox(height: 12),
                Text('RiyasHome Life Assistance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: _tc,
                    )),
                const SizedBox(height: 4),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (_, snap) {
                    final info = snap.data;
                    final label = info == null
                        ? 'Version…'
                        : 'Version ${info.version} (Build ${info.buildNumber})';
                    return Text(label,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Nunito',
                          color: _sub,
                        ));
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Info rows
          _InfoCard(
            isDark: isDark,
            surf: _surf,
            div: _div,
            rows: [
              _InfoRow(
                emoji: '📄',
                label: 'Terms of Service',
                sub: _sub,
                tc: _tc,
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => DraggableScrollableSheet(
                    initialChildSize: 0.92,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    builder: (_, ctrl) => TermsOfServiceSheet(isDark: isDark),
                  ),
                ),
              ),
              _InfoRow(
                emoji: '🔒',
                label: 'Privacy Policy',
                sub: _sub,
                tc: _tc,
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => DraggableScrollableSheet(
                    initialChildSize: 0.92,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    builder: (_, ctrl) => PrivacyPolicySheet(isDark: isDark),
                  ),
                ),
              ),
              _InfoRow(
                emoji: '📦',
                label: 'Open Source Licences',
                sub: _sub,
                tc: _tc,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'RiyasHome Life Assistance',
                  applicationVersion: '1.0.0',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _InfoCard(
            isDark: isDark,
            surf: _surf,
            div: _div,
            rows: [
              _InfoRow(
                emoji: '✉️',
                label: 'Contact Support',
                sub: _sub,
                tc: _tc,
                onTap: () => _contactSupport(context),
              ),
              _InfoRow(
                emoji: '⭐',
                label: 'Rate WAI',
                sub: _sub,
                tc: _tc,
                onTap: () => _rateApp(context),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Text('Made with ♥ by the WAI Team',
              style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: _sub)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final Color surf, div;
  final List<Widget> rows;
  const _InfoCard({required this.isDark, required this.surf, required this.div, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: surf, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: rows.asMap().entries.expand((e) {
          return [
            if (e.key > 0) Divider(height: 1, color: div, indent: 52),
            e.value,
          ];
        }).toList(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String emoji, label;
  final Color tc, sub;
  final VoidCallback onTap;
  const _InfoRow({required this.emoji, required this.label, required this.tc, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                    color: tc,
                  )),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: sub),
          ],
        ),
      ),
    );
  }
}
