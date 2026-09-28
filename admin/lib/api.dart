import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over the admin_* RPCs from migration 201. Every call is
/// checked server-side against dashboard_admins.
class AdminApi {
  AdminApi._();
  static final instance = AdminApi._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _rows(String fn, [Map<String, dynamic>? params]) async {
    final res = await _db.rpc(fn, params: params);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<String?> whoami() async => await _db.rpc('admin_whoami') as String?;

  Future<Map<String, dynamic>> overview() async =>
      Map<String, dynamic>.from(await _db.rpc('admin_overview') as Map);

  Future<List<Map<String, dynamic>>> dailySeries(int days) =>
      _rows('admin_daily_series', {'p_days': days});

  // ── Issues ────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> issues({String? status, String? category, int limit = 50, int offset = 0}) =>
      _rows('admin_list_issues', {
        'p_status': status,
        'p_category': category,
        'p_limit': limit,
        'p_offset': offset,
      });

  Future<void> updateIssue(String id, {required String status, required String priority, String? note}) =>
      _db.rpc('admin_update_issue', params: {
        'p_id': id,
        'p_status': status,
        'p_priority': priority,
        'p_admin_note': note,
      });

  // ── Errors ────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> errorGroups({int days = 7, String? severity, String? status}) =>
      _rows('admin_error_groups', {'p_days': days, 'p_severity': severity, 'p_status': status});

  Map<String, dynamic> _groupKey(Map<String, dynamic> g) => {
        'p_error_type': g['error_type'],
        'p_error_message': g['error_message'],
        'p_screen_name': g['screen_name'],
        'p_action': g['action'],
      };

  Future<List<Map<String, dynamic>>> errorOccurrences(Map<String, dynamic> group) =>
      _rows('admin_error_occurrences', _groupKey(group));

  Future<int> setErrorStatus(Map<String, dynamic> group, String status) async =>
      await _db.rpc('admin_set_error_status', params: {..._groupKey(group), 'p_status': status}) as int;

  // ── Users / subscriptions / AI / config ───────────────────────────────────
  Future<List<Map<String, dynamic>>> users({String? search, int limit = 50, int offset = 0}) =>
      _rows('admin_list_users', {'p_search': search, 'p_limit': limit, 'p_offset': offset});

  Future<List<Map<String, dynamic>>> subscriptions({String? status}) =>
      _rows('admin_list_subscriptions', {'p_status': status});

  Future<List<Map<String, dynamic>>> aiStats(int days) => _rows('admin_ai_stats', {'p_days': days});

  Future<List<Map<String, dynamic>>> aiRecentErrors() => _rows('admin_ai_recent_errors');

  Future<List<Map<String, dynamic>>> config() => _rows('admin_list_config');

  Future<void> setConfig(String key, String value) =>
      _db.rpc('admin_set_config', params: {'p_key': key, 'p_value': value});
}
