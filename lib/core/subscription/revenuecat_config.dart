/// RevenueCat public SDK key, injected per-environment via
/// `--dart-define-from-file=env/<env>.json` (see env/*.json.example),
/// same mechanism as SupabaseConfig.
///
/// Empty by default so builds without a RevenueCat project configured yet
/// still compile and run — SubscriptionService checks [isConfigured] before
/// calling into the SDK, rather than crashing on an empty key.
///
/// NOTE: RevenueCat issues a separate public key per platform app. This is
/// currently Android-only (the app hasn't shipped on iOS yet) — add a
/// REVENUECAT_API_KEY_IOS define here once an iOS RevenueCat app exists.
class RevenueCatConfig {
  RevenueCatConfig._();

  static const String androidApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => androidApiKey.isNotEmpty;
}
