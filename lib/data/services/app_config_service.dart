import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';

/// Wording for the dashboard's "plan about to expire" renewal banner, as
/// returned by [AppConfigService.fetchPlanExpiryBannerCopy]. [titleTemplate]
/// is used for anything beyond tomorrow and must contain a `{days}`
/// placeholder.
class PlanExpiryBannerCopy {
  final String titleToday;
  final String titleTomorrow;
  final String titleTemplate;
  final String subtitle;
  final String cta;

  const PlanExpiryBannerCopy({
    required this.titleToday,
    required this.titleTomorrow,
    required this.titleTemplate,
    required this.subtitle,
    required this.cta,
  });

  static const defaults = PlanExpiryBannerCopy(
    titleToday: 'Your family plan expires today',
    titleTomorrow: 'Your family plan expires tomorrow',
    titleTemplate: 'Your family plan expires in {days} days',
    subtitle: 'Renew to keep your family group\'s features active.',
    cta: 'Renew Now',
  );

  /// Resolves the right title for [daysLeft] (0 = today, 1 = tomorrow,
  /// otherwise [titleTemplate] with `{days}` substituted).
  String title(int daysLeft) {
    if (daysLeft <= 0) return titleToday;
    if (daysLeft == 1) return titleTomorrow;
    return titleTemplate.replaceAll('{days}', '$daysLeft');
  }
}

/// Fetches server-controlled configuration from the `app_config` table.
/// Values default to their V1 safe values if the table is unreachable.
class AppConfigService {
  AppConfigService._();
  static final instance = AppConfigService._();

  SupabaseClient get _db => Supabase.instance.client;

  /// Maximum number of family/group wallets a user may create.
  /// Returns 1 (V1 default) on any error or when not configured.
  Future<int> fetchMaxFamilyGroups() async {
    try {
      final row = await _db
          .from('app_config')
          .select('value')
          .eq('key', 'max_family_groups')
          .maybeSingle();
      return int.tryParse(row?['value'] as String? ?? '') ?? 1;
    } catch (e) {
      ErrorLogger.warning(e, action: 'fetch_max_family_groups');
      return 1;
    }
  }

  /// Days a soft-deleted record stays recoverable before the daily purge
  /// job hard-deletes it. Returns 30 (current default) on any error or
  /// when not configured.
  Future<int> fetchRecycleBinRetentionDays() async {
    try {
      final row = await _db
          .from('app_config')
          .select('value')
          .eq('key', 'recycle_bin_retention_days')
          .maybeSingle();
      return int.tryParse(row?['value'] as String? ?? '') ?? 30;
    } catch (e) {
      ErrorLogger.warning(e, action: 'fetch_recycle_bin_retention_days');
      return 30;
    }
  }

  /// How many days before a cancelled family plan's expiry the dashboard's
  /// renewal reminder banner starts showing. Wider than the 3/1/0-day
  /// notify-plan-expiry push schedule since a persistent in-app banner is
  /// less intrusive and can give earlier notice. Returns 7 (current
  /// default) on any error or when not configured.
  Future<int> fetchPlanExpiryBannerDays() async {
    try {
      final row = await _db
          .from('app_config')
          .select('value')
          .eq('key', 'plan_expiry_banner_days')
          .maybeSingle();
      return int.tryParse(row?['value'] as String? ?? '') ?? 7;
    } catch (e) {
      ErrorLogger.warning(e, action: 'fetch_plan_expiry_banner_days');
      return 7;
    }
  }

  /// Copy shown on the dashboard's "plan about to expire" renewal banner —
  /// kept in app_config (rather than hardcoded) so wording can be tuned or
  /// A/B'd without an app release. Falls back to [PlanExpiryBannerCopy.defaults]
  /// per-field when a key is missing, and entirely on any error.
  Future<PlanExpiryBannerCopy> fetchPlanExpiryBannerCopy() async {
    const keys = [
      'plan_expiry_banner_title_today',
      'plan_expiry_banner_title_tomorrow',
      'plan_expiry_banner_title_template',
      'plan_expiry_banner_subtitle',
      'plan_expiry_banner_cta',
    ];
    try {
      final rows = await _db.from('app_config').select('key, value').inFilter('key', keys);
      final map = {for (final r in rows as List) r['key'] as String: r['value'] as String};
      const d = PlanExpiryBannerCopy.defaults;
      return PlanExpiryBannerCopy(
        titleToday: map['plan_expiry_banner_title_today'] ?? d.titleToday,
        titleTomorrow: map['plan_expiry_banner_title_tomorrow'] ?? d.titleTomorrow,
        titleTemplate: map['plan_expiry_banner_title_template'] ?? d.titleTemplate,
        subtitle: map['plan_expiry_banner_subtitle'] ?? d.subtitle,
        cta: map['plan_expiry_banner_cta'] ?? d.cta,
      );
    } catch (e) {
      ErrorLogger.warning(e, action: 'fetch_plan_expiry_banner_copy');
      return PlanExpiryBannerCopy.defaults;
    }
  }

  /// Runtime override for FeatureFlags.healthSpaceEnabled — lets ops
  /// disable Health Space in prod (e.g. a Play Console compliance issue)
  /// instantly, without shipping a build, while the build-time
  /// --dart-define default still protects prod if this table is ever
  /// unreachable. Returns null (no override — caller should fall back to
  /// the build-time flag) when the row is absent, its value is the
  /// sentinel 'inherit', or the fetch fails.
  Future<bool?> fetchHealthSpaceEnabledOverride() async {
    try {
      final row = await _db
          .from('app_config')
          .select('value')
          .eq('key', 'health_space_enabled_override')
          .maybeSingle();
      final v = row?['value'] as String?;
      if (v == null || v == 'inherit') return null;
      return v == 'true';
    } catch (e) {
      ErrorLogger.warning(e, action: 'fetch_health_space_enabled_override');
      return null;
    }
  }

  /// Whether the local deterministic NLP parser (Dashboard AI Assistant's
  /// and Wallet quick-add's pre-AI shortcut, and Wallet's on-AI-failure
  /// fallback) is allowed to run at all. Defaults to false (AI-only) on
  /// any error, when not configured, and as the seeded default — flip to
  /// 'true' in app_config once the local parser has been validated enough
  /// to trust again.
  Future<bool> fetchNlpParserEnabled() async {
    try {
      final row = await _db
          .from('app_config')
          .select('value')
          .eq('key', 'nlp_parser_enabled')
          .maybeSingle();
      return (row?['value'] as String?) == 'true';
    } catch (e) {
      ErrorLogger.warning(e, action: 'fetch_nlp_parser_enabled');
      return false;
    }
  }
}
