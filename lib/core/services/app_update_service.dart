import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import 'error_logger.dart';

/// Checks Play Store for a newer version and, if available, downloads it as
/// a flexible (dismissible) update — the app keeps working normally while it
/// downloads in the background, and the user is prompted to restart once
/// it's ready. Android-only (Play Core); a no-op everywhere else.
class AppUpdateService {
  AppUpdateService._();

  static StreamSubscription<InstallStatus>? _sub;

  /// Call once from a long-lived screen (e.g. the dashboard, right after
  /// login) so the "restart to update" prompt has a stable place to show.
  static Future<void> checkAndStartFlexibleUpdate(BuildContext context) async {
    if (!Platform.isAndroid) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }
      if (!info.flexibleUpdateAllowed) return;

      await InAppUpdate.startFlexibleUpdate();

      _sub?.cancel();
      _sub = InAppUpdate.installUpdateListener.listen((status) {
        if (status == InstallStatus.downloaded && context.mounted) {
          _promptRestart(context);
        }
      });
    } catch (e, stack) {
      // Never let a failed update check affect the app — this is a
      // best-effort background nicety, not something that should surface
      // an error to the user.
      ErrorLogger.log(e, stackTrace: stack, action: 'in_app_update_check');
    }
  }

  static void _promptRestart(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Update downloaded — restart to apply it.'),
        duration: const Duration(days: 1),
        action: SnackBarAction(
          label: 'Restart',
          onPressed: () async {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (e, stack) {
              ErrorLogger.log(e, stackTrace: stack, action: 'in_app_update_complete');
            }
          },
        ),
      ),
    );
  }
}
