import 'dart:async';

import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReviewPromptService — asks for a Play Store / App Store rating after the
// user has had a few successful saves (transactions, tasks, reminders).
//
// Ratings feed store search ranking, so the native in-app review sheet is
// worth showing — but only to someone who's actually using the app, and
// rarely. The OS also enforces its own quota and may silently show nothing,
// so this never assumes the sheet appeared.
// ─────────────────────────────────────────────────────────────────────────────

class ReviewPromptService {
  ReviewPromptService._();
  static final ReviewPromptService instance = ReviewPromptService._();

  static const _kWins       = 'review_wins';
  static const _kFirstSeen  = 'review_first_seen';
  static const _kLastAsked  = 'review_last_asked';

  /// Successful saves needed before the first ask.
  static const _minWins = 8;
  /// Days since first use before the first ask — skips the "just
  /// installed, still exploring" window.
  static const _minDaysInstalled = 3;
  /// Days between asks.
  static const _cooldownDays = 120;
  /// Wait this long after the last save before asking. Bulk saves (SMS
  /// history import) call [recordWin] in a loop; the debounce collapses
  /// them into one ask after the batch finishes instead of mid-import.
  static const _settle = Duration(seconds: 2);

  Timer? _debounce;

  /// Call after a user-visible save succeeds. Fire-and-forget; never throws.
  void recordWin() {
    unawaited(_recordWin());
  }

  Future<void> _recordWin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      if (!prefs.containsKey(_kFirstSeen)) {
        await prefs.setString(_kFirstSeen, now.toIso8601String());
      }
      await prefs.setInt(_kWins, (prefs.getInt(_kWins) ?? 0) + 1);

      _debounce?.cancel();
      _debounce = Timer(_settle, () => unawaited(_maybeAsk()));
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'review_record_win');
    }
  }

  Future<void> _maybeAsk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      if ((prefs.getInt(_kWins) ?? 0) < _minWins) return;

      final firstSeen = DateTime.tryParse(prefs.getString(_kFirstSeen) ?? '');
      if (firstSeen == null ||
          now.difference(firstSeen).inDays < _minDaysInstalled) {
        return;
      }

      final lastAsked = DateTime.tryParse(prefs.getString(_kLastAsked) ?? '');
      if (lastAsked != null &&
          now.difference(lastAsked).inDays < _cooldownDays) {
        return;
      }

      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;

      // Record before requesting so a crash/kill mid-sheet can't cause a
      // repeat ask on the next save.
      await prefs.setString(_kLastAsked, now.toIso8601String());
      await review.requestReview();
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'review_request');
    }
  }
}
