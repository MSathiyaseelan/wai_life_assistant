import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FAMILY GROUP BANNER
// Shown on the Dashboard to users who aren't a member of any family group
// yet, so they know the feature exists. Dismissible; the dismissed state is
// persisted by the caller (see AppPrefs.familyBannerDismissed).
// ─────────────────────────────────────────────────────────────────────────────

class FamilyGroupBanner extends StatelessWidget {
  final bool isDark;
  final VoidCallback onCreateOrJoin;
  final VoidCallback onDismiss;

  const FamilyGroupBanner({
    super.key,
    required this.isDark,
    required this.onCreateOrJoin,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: isDark ? 0.20 : 0.12),
            AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add your family to WAI',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                // const SizedBox(height: 3),
                // Text(
                //   'Create or join a family group to share wallets, plans, and reminders with the people you live with.',
                //   style: TextStyle(
                //     fontSize: 12,
                //     fontFamily: 'Nunito',
                //     color: sub,
                //     height: 1.3,
                //   ),
                // ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onCreateOrJoin,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Create or Join Family Group',
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
