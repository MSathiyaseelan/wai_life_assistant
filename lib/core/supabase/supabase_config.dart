import 'package:flutter/foundation.dart';

/// Supabase project credentials, injected per-environment via
/// `--dart-define-from-file=env/<env>.json` (see env/*.json.example).
///
/// Debug/profile builds without a define file fall back to the dev project
/// so a bare `flutter run` keeps working. Release builds get no fallback:
/// a release built without the define file would otherwise ship pointing
/// at dev, so [assertConfigured] stops it at launch instead.
class SupabaseConfig {
  SupabaseConfig._();

  static const String _devUrl = 'https://oeclczbamrnouuzooitx.supabase.co';
  static const String _devAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lY2xjemJhbXJub3V1em9vaXR4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5NjY3OTAsImV4cCI6MjA4ODU0Mjc5MH0.Hy8saiWTLl9TA8g2AZxQYX18RQvgmwa0p5y6m666fzA';

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: kReleaseMode ? '' : _devUrl,
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: kReleaseMode ? '' : _devAnonKey,
  );

  /// Throws when the credentials weren't injected (release build made
  /// without `--dart-define-from-file`).
  static void assertConfigured() {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_ANON_KEY missing — build with '
        '--dart-define-from-file=env/<env>.json',
      );
    }
  }
}
