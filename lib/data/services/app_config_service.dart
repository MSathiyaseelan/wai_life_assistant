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
}
