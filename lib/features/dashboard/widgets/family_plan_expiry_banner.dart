import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FAMILY PLAN EXPIRY BANNER
// Shown in the same dashboard slot as FamilyGroupBanner, but for the
// opposite audience: a family-plan admin whose paid plan was cancelled
// (auto_renew=false) and is about to lapse. Mirrors the urgency tiers of
// the notify-plan-expiry push notification, but as a persistent in-app
// nudge while the plan is still within its recycle window. Dismissible per
// billing cycle — see AppPrefs.dismissFamilyExpiry. Copy (title/subtitle/
// CTA) comes from app_config via AppConfigService.fetchPlanExpiryBannerCopy
// — see AppStateNotifier.planExpiryBannerCopy — so wording can be changed
// without an app release.
// ─────────────────────────────────────────────────────────────────────────────

class FamilyPlanExpiryBanner extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onRenew;
  final VoidCallback onDismiss;

  const FamilyPlanExpiryBanner({
    super.key,
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onRenew,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    const warn = Color(0xFFFFAA2C);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            warn.withValues(alpha: isDark ? 0.20 : 0.12),
            warn.withValues(alpha: isDark ? 0.08 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: warn.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: warn.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text('⏳', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onRenew,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: warn,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      ctaLabel,
                      style: const TextStyle(
                        fontSize: 12,
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
          GestureDetector(
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 18, color: sub),
            ),
          ),
        ],
      ),
    );
  }
}
