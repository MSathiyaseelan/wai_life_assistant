import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'network_service.dart';

class RealtimeSyncService {
  RealtimeSyncService._();
  static final RealtimeSyncService instance = RealtimeSyncService._();

  final revision = ValueNotifier<int>(0);

  final List<RealtimeChannel> _channels = [];
  String? _lastUserId;

  SupabaseClient get _db => Supabase.instance.client;

  void init() {
    NetworkService.instance.isOnline.addListener(_onNetworkChange);
  }

  void _onNetworkChange() {
    if (NetworkService.instance.isOnline.value && _lastUserId != null) {
      debugPrint('[Realtime] reconnected — resubscribing for $_lastUserId');
      subscribeAll(_lastUserId!);
    }
  }

  void subscribeAll(String userId) {
    unsubscribeAll();
    _lastUserId = userId;

    const tables = [
      'notes',
      'reminders',
      'wishes',
      'health_medications',
      'health_appointments',
      'wardrobe_items',
      'meal_entries',
      'item_locator_items',
    ];

    for (final table in tables) {
      final channel = _db
          .channel('user:$userId:$table')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (_) => revision.value++,
          )
          .subscribe();
      _channels.add(channel);
    }
  }

  /// Live-refresh family details (name/emoji/photo/permissions) for every
  /// family the user belongs to, so an admin's edit (e.g. the group photo)
  /// reaches other members immediately instead of waiting for their next
  /// natural refetch (app restart / manual pull-to-refresh).
  void subscribeFamilies(List<String> familyIds, VoidCallback onChange) {
    for (final familyId in familyIds) {
      final channel = _db
          .channel('family:$familyId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'families',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: familyId,
            ),
            callback: (_) => onChange(),
          )
          .subscribe();
      _channels.add(channel);
    }
  }

  void unsubscribeAll() {
    for (final channel in _channels) {
      _db.removeChannel(channel);
    }
    _channels.clear();
  }

  void dispose() {
    NetworkService.instance.isOnline.removeListener(_onNetworkChange);
    unsubscribeAll();
  }
}
