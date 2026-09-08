/// Build-time feature flags, injected per-environment via
/// `--dart-define-from-file=env/<env>.json`, same mechanism as
/// SupabaseConfig and RevenueCatConfig.
///
/// healthSpaceEnabled defaults to true so dev/qa/uat builds are unaffected;
/// prod sets it false because declaring Health features on Play Console
/// requires a verified Organization developer account, which this app
/// doesn't have yet. Re-enable once that's resolved.
///
/// The build-time value is also the safe fallback for
/// [applyHealthSpaceEnabledOverride]'s runtime override (see there) — so if
/// app_config is ever unreachable, prod still resolves to `false` exactly
/// as before this override existed.
class FeatureFlags {
  FeatureFlags._();

  static const bool _buildTimeHealthSpaceEnabled = bool.fromEnvironment(
    'HEALTH_SPACE_ENABLED',
    defaultValue: true,
  );

  static bool _healthSpaceEnabled = _buildTimeHealthSpaceEnabled;

  /// Whether Health Space is enabled. Existing call sites read this exactly
  /// as before — the value can now also be flipped at runtime, see
  /// [applyHealthSpaceEnabledOverride].
  static bool get healthSpaceEnabled => _healthSpaceEnabled;

  /// Applies a runtime override fetched from app_config
  /// (AppConfigService.fetchHealthSpaceEnabledOverride) — called once from
  /// AppStateNotifier's init, after login, before Dashboard/MyHub/etc. read
  /// [healthSpaceEnabled]. Lets ops disable Health Space in prod instantly
  /// (e.g. a Play Console compliance issue) without shipping a new build.
  /// A null [override] (config row absent/set to 'inherit', not logged in
  /// yet, or the fetch failed) leaves the safe build-time default in place.
  static void applyHealthSpaceEnabledOverride(bool? override) {
    _healthSpaceEnabled = override ?? _buildTimeHealthSpaceEnabled;
  }
}
