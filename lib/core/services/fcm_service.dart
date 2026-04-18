import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Background handler — top-level, runs in a separate Dart isolate.
// Must not reference any Flutter UI; only show a local notification.
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Re-create the plugin in the background isolate — it is not shared.
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  await _showWith(plugin, message);
}

// ─────────────────────────────────────────────────────────────────────────────
// FcmService
// ─────────────────────────────────────────────────────────────────────────────

class FcmService {
  FcmService._();

  static final _messaging = FirebaseMessaging.instance;

  // Reuse the plugin already initialised by NotificationService — no double-init.
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Emits the tab index when a push notification is tapped.
  /// BottomNavScreen listens to this.
  static final pendingTab = ValueNotifier<int?>(null);

  // ── Initialize ─────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _createFamilyChannel();
    await saveFcmToken();

    _messaging.onTokenRefresh.listen((_) => saveFcmToken());
    FirebaseMessaging.onMessage.listen((msg) => _showWith(_plugin, msg));
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] auth: ${settings.authorizationStatus}');
  }

  // ── Create Android notification channel (idempotent) ───────────────────────

  static Future<void> _createFamilyChannel() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'wai_family_channel',
          'Family Updates',
          description: 'Updates from your family members',
          importance: Importance.high,
        ));
  }

  // ── Save FCM token → Supabase ───────────────────────────────────────────────

  static Future<void> saveFcmToken([String? token]) async {
    final fcmToken = token ?? await _messaging.getToken();
    if (fcmToken == null) {
      debugPrint('[FCM] token null — check google-services.json');
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[FCM] user not logged in — token not saved');
      return;
    }

    debugPrint('[FCM] saving token userId=$userId ${fcmToken.substring(0, 20)}...');
    try {
      await Supabase.instance.client.from('user_fcm_tokens').upsert(
        {
          'user_id': userId,
          'fcm_token': fcmToken,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id, platform',
      );
      debugPrint('[FCM] token saved OK');
    } catch (e) {
      debugPrint('[FCM] token save failed: $e');
    }
  }

  // ── Navigation on tap ──────────────────────────────────────────────────────

  static void _handleTap(RemoteMessage message) {
    final tab = _routeToTab(message.data['route'] as String?);
    if (tab != null) pendingTab.value = tab;
  }

  static int? _routeToTab(String? route) => switch (route) {
        'wallet' => 1,
        'pantry' => 2,
        'planit' => 3,
        _ => null,
      };
}

// ── Shared notification display (used by both foreground and background) ──────

Future<void> _showWith(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message,
) async {
  final notification = message.notification;
  if (notification == null) return;

  await plugin.show(
    notification.hashCode,
    notification.title,
    notification.body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'wai_family_channel',
        'Family Updates',
        channelDescription: 'Notifications from your family members',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: message.data['route'],
  );
}
