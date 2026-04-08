import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/data/models/notification/notification_models.dart';

/// Service for reading and managing in-app family notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  RealtimeChannel? _channel;

  // ── Public signal ────────────────────────────────────────────────────────────

  /// Fires whenever unread count may have changed (new notification arrived or marked read).
  static final changeSignal = ValueNotifier<int>(0);

  // ── Fetch ────────────────────────────────────────────────────────────────────

  /// Returns up to [limit] most recent notifications for the current user.
  Future<List<AppNotification>> fetchAll({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _db
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => AppNotification.fromRow(r as Map<String, dynamic>)).toList();
  }

  /// Returns the count of unread notifications for the current user.
  Future<int> fetchUnreadCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    final result = await _db
        .from('notifications')
        .select('id')
        .eq('user_id', uid)
        .eq('is_read', false);
    return (result as List).length;
  }

  // ── Mark read ────────────────────────────────────────────────────────────────

  Future<void> markRead(String notificationId) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', uid);
    _bump();
  }

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
    _bump();
  }

  // ── Realtime subscription ────────────────────────────────────────────────────

  /// Subscribe to INSERT events on the notifications table for the current user.
  /// Call [unsubscribe] when the widget is disposed.
  void subscribe() {
    final uid = _uid;
    if (uid == null) return;
    _channel ??= _db
        .channel('notifications:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) => _bump(),
        )
        .subscribe();
  }

  void unsubscribe() {
    if (_channel != null) {
      _db.removeChannel(_channel!);
      _channel = null;
    }
  }

  void _bump() => changeSignal.value++;
}
