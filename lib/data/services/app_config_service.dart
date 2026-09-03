import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';

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
