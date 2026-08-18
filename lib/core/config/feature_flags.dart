/// Build-time feature flags, injected per-environment via
/// `--dart-define-from-file=env/<env>.json`, same mechanism as
/// SupabaseConfig and RevenueCatConfig.
///
/// healthSpaceEnabled defaults to true so dev/qa/uat builds are unaffected;
/// prod sets it false because declaring Health features on Play Console
/// requires a verified Organization developer account, which this app
/// doesn't have yet. Re-enable once that's resolved.
class FeatureFlags {
  FeatureFlags._();

  static const bool healthSpaceEnabled = bool.fromEnvironment(
    'HEALTH_SPACE_ENABLED',
    defaultValue: true,
  );
}
