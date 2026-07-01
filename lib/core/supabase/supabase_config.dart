/// Supabase project credentials, injected per-environment via
/// `--dart-define-from-file=env/<env>.json` (see env/*.json.example).
/// Defaults fall back to the original dev project so `flutter run` keeps
/// working without a define file.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oeclczbamrnouuzooitx.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lY2xjemJhbXJub3V1em9vaXR4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5NjY3OTAsImV4cCI6MjA4ODU0Mjc5MH0.Hy8saiWTLl9TA8g2AZxQYX18RQvgmwa0p5y6m666fzA',
  );
}
