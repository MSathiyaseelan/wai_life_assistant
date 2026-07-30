import 'user_facing_exception.dart';
import 'ui_error_message.dart';

/// Converts any caught exception into a message safe to show the user.
///
/// Exceptions implementing [UserFacingException] (plan-limit errors, etc.)
/// already have a toString() written for display and pass through
/// unchanged. Everything else — PostgrestException, AuthException, a raw
/// Postgres constraint violation, whatever — falls back to [fallback] (or
/// a generic default), since their toString()/message carries technical
/// detail (table names, SQL error codes, stack-shaped text) that means
/// nothing to a user and shouldn't be shown to one.
///
/// This is purely about what the UI displays — the original exception
/// should still be passed to ErrorLogger.log() for diagnosis; this
/// function doesn't replace that.
String friendlyError(Object e, [String? fallback]) {
  if (e is UserFacingException) return e.toString();
  return fallback ?? UiErrorMessage.unknown;
}
