/// Marker for exceptions whose toString() is deliberately written for
/// display to the user (e.g. "You've reached this month's transaction
/// limit... Upgrade to add more.") — implement this on any exception class
/// meant to be shown as-is via [friendlyError].
///
/// Everything else (PostgrestException, AuthException, generic Exception,
/// etc.) is assumed to carry technical detail that shouldn't reach the UI —
/// see friendly_error.dart.
abstract interface class UserFacingException implements Exception {}
