import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';

/// Shows a confirmation bottom sheet before a swipe-to-delete completes.
/// Use as the `confirmDismiss` callback on every [Dismissible].
///
/// Returns `true` → proceed with delete, `false` → snap back.
Future<bool> confirmDelete(BuildContext context) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
  final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
  final tc = isDark ? AppColors.textDark : AppColors.textLight;
  final sub = isDark ? AppColors.subDark : AppColors.subLight;

  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.expense.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🗑️', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Delete?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'This item will be permanently deleted.',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: sub),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tc,
                      backgroundColor: surfBg,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.expense,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Delete',
                        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
