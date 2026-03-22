import 'package:supabase_flutter/supabase_flutter.dart';

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
    } catch (_) {
      return 1;
    }
  }
}
