import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';

/// Shows a confirmation dialog before a swipe-to-delete completes.
/// Use as the `confirmDismiss` callback on every [Dismissible].
///
/// Returns `true` → proceed with delete, `false` → snap back.
Future<bool> confirmDelete(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete?',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900)),
      content: const Text('This item will be permanently deleted.',
          style: TextStyle(fontFamily: 'Nunito')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel',
              style: TextStyle(fontFamily: 'Nunito')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.expense),
          child: const Text('Delete',
              style: TextStyle(
                  fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return result ?? false;
}
