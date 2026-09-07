import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FAMILY PLAN EXPIRY BANNER
// Shown in the same dashboard slot as FamilyGroupBanner, but for the
// opposite audience: a family-plan admin whose paid plan was cancelled
// (auto_renew=false) and is about to lapse. Mirrors the copy/urgency tiers
// of the notify-plan-expiry push notification, but as a persistent in-app
// nudge while the plan is still within its recycle window. Dismissible per
// billing cycle — see AppPrefs.dismissFamilyExpiry.
// ─────────────────────────────────────────────────────────────────────────────

class FamilyPlanExpiryBanner extends StatelessWidget {
  final bool isDark;
  final int daysLeft; // 0 = expires today; negative won't be passed in
  final VoidCallback onRenew;
  final VoidCallback onDismiss;

  const FamilyPlanExpiryBanner({
    super.key,
    required this.isDark,
    required this.daysLeft,
    required this.onRenew,
    required this.onDismiss,
  });

  String get _title {
    if (daysLeft <= 0) return 'Your family plan expires today';
    if (daysLeft == 1) return 'Your family plan expires tomorrow';
    return 'Your family plan expires in $daysLeft days';
  }

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
                  _title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Renew to keep your family group\'s features active.',
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
                    child: const Text(
                      'Renew Now',
                      style: TextStyle(
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
