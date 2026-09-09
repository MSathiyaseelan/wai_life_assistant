import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UPDATE READY SHEET
// Shown by AppUpdateService once a flexible update has finished downloading —
// a proper blocking prompt (title, message, version, Restart Now / Restart
// Later) instead of a passive SnackBar, so the restart action is impossible
// to miss. Dismissing either way (X or "Restart Later") just closes it; the
// next app resume/launch re-checks Play Core and shows it again as long as
// the update is still pending, so nothing is lost by deferring.
// ─────────────────────────────────────────────────────────────────────────────

class UpdateReadySheet extends StatelessWidget {
  final String versionLabel;
  final VoidCallback onRestartNow;

  const UpdateReadySheet({
    super.key,
    required this.versionLabel,
    required this.onRestartNow,
  });

  static Future<void> show(
    BuildContext context, {
    required String versionLabel,
    required VoidCallback onRestartNow,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => UpdateReadySheet(
        versionLabel: versionLabel,
        onRestartNow: onRestartNow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Update your App',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 22, color: sub),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Restart app to complete the update',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: tc,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        versionLabel,
                        style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🚀', style: TextStyle(fontSize: 26)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  onRestartNow();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text(
                  'RESTART NOW',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    letterSpacing: 0.3,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: BorderSide(color: sub.withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: Text(
                  'RESTART LATER',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    letterSpacing: 0.3,
                    color: tc,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
