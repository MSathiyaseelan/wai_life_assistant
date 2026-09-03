import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../../main.dart';
import 'error_logger.dart';

/// Checks Play Store for a newer version and, if available, downloads it as
/// a flexible (dismissible) update — the app keeps working normally while it
/// downloads in the background, and the user is prompted to restart once
/// it's ready. Android-only (Play Core); a no-op everywhere else.
class AppUpdateService {
  AppUpdateService._();

  static StreamSubscription<InstallStatus>? _sub;

  /// [context] only needs to be valid for the initial "downloading" toast —
  /// the actual restart prompt goes through
  /// [LifeAssistanceApp.scaffoldMessengerKey] instead of this context, since
  /// a flexible update's download can take anywhere from seconds to
  /// minutes and the caller's screen may no longer be mounted or visible
  /// (buried under other pushed screens) by the time it finishes. Using a
  /// context tied to one screen was silently dropping the restart prompt —
  /// it either never showed (context disposed) or showed on a hidden
  /// scaffold the user had already navigated away from.
  static Future<void> checkAndStartFlexibleUpdate(BuildContext context) async {
    if (!Platform.isAndroid) return;
    try {
      final info = await InAppUpdate.checkForUpdate();

      // A flexible update from a PREVIOUS app session may already be
      // downloading, or fully downloaded — Play Core reports this as
      // developerTriggeredUpdateInProgress, not updateAvailable. The
      // static `_sub` listener that would normally catch the `downloaded`
      // event doesn't survive the app process being backgrounded/killed
      // mid-download, so without this check the restart prompt is lost
      // forever: the user taps "Update" once, the app is backgrounded
      // before the download finishes, and reopening it never re-offers
      // the restart — the only way out is manually updating via Play
      // Store. `installStatus` is only meaningful in this branch.
      if (info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress) {
        if (info.installStatus == InstallStatus.downloaded) {
          _promptRestart();
        } else {
          _listenForDownloadCompletion();
        }
        return;
      }

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }
      if (!info.flexibleUpdateAllowed) return;

      await InAppUpdate.startFlexibleUpdate();
      if (context.mounted) _promptDownloading(context);
      _listenForDownloadCompletion();
    } catch (e, stack) {
      // Never let a failed update check affect the app — this is a
      // best-effort background nicety, not something that should surface
      // an error to the user.
      ErrorLogger.log(e, stackTrace: stack, action: 'in_app_update_check');
    }
  }

  static void _listenForDownloadCompletion() {
    _sub?.cancel();
    _sub = InAppUpdate.installUpdateListener.listen((status) {
      if (status == InstallStatus.downloaded) _promptRestart();
    });
  }

  static void _promptDownloading(BuildContext context) {
    // Flexible updates download silently with no OS-level progress UI, so
    // without this the app just looks like nothing happened after tapping
    // "Update" in Play's own dialog — this is purely a feedback cue, the
    // actual download proceeds in the background regardless.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloading update in the background…'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  static void _promptRestart() {
    final messenger = LifeAssistanceApp.scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
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
