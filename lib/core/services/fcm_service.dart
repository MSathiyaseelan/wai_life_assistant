import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/services/notification_prefs.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotifDeepLink — carries the destination from a notification tap.
// route  : logical section ('wallet', 'pantry', 'planit', 'myhub',
//           'lifestyle', 'dashboard', 'split', 'reminder', 'task', 'bill')
// id     : optional item ID for item-level navigation
// ─────────────────────────────────────────────────────────────────────────────

class NotifDeepLink {
  final String route;
  final String? id;
  const NotifDeepLink({required this.route, this.id});

  /// Serialise to payload string stored in local notification.
  String toPayload() => id != null ? 'deeplink:$route:$id' : 'deeplink:$route';

  /// Parse from payload string. Returns null if not a deep-link payload.
  static NotifDeepLink? fromPayload(String? payload) {
    if (payload == null || !payload.startsWith('deeplink:')) return null;
    final parts = payload.substring('deeplink:'.length).split(':');
    return NotifDeepLink(
      route: parts[0],
      id: parts.length > 1 ? parts.sublist(1).join(':') : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background handler — top-level, runs in a separate Dart isolate.
// Must not reference any Flutter UI or singletons; quiet hours are NOT checked
// here because SharedPreferences is unavailable in the background isolate.
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Messages carrying a `notification` payload are already auto-displayed by
  // the OS/FCM SDK while the app is backgrounded/terminated — showing them
  // again here via the local-notifications plugin would duplicate every push.
  // Only a true data-only message (no `notification` field) needs manual
  // display, since the OS never surfaces those on its own.
  if (message.notification != null) return;
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  await _showWith(plugin, message, checkQuiet: false);
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
  static final pendingTab = ValueNotifier<int?>(null);

  /// Emits the deep-link destination when a notification is tapped.
  /// BottomNavScreen (and individual screens) listen to navigate precisely.
  static final pendingDeepLink = ValueNotifier<NotifDeepLink?>(null);

  // ── Initialize ─────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _createFamilyChannel();
    await saveFcmToken();

    _messaging.onTokenRefresh.listen((_) => saveFcmToken());
    FirebaseMessaging.onMessage.listen((msg) => _showWith(_plugin, msg, checkQuiet: true));
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

    if (kDebugMode) debugPrint('[FCM] saving FCM token for current user');
    try {
      // Keyed on (user_id, platform, fcm_token) — not just (user_id,
      // platform) — so a second device on the same platform gets its own
      // row instead of silently overwriting the first device's token.
      await Supabase.instance.client.from('user_fcm_tokens').upsert(
        {
          'user_id': userId,
          'fcm_token': fcmToken,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id, platform, fcm_token',
      );
      debugPrint('[FCM] token saved OK');
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'fcm_save_token');
    }
  }

  // ── Navigation on tap ──────────────────────────────────────────────────────

  static void _handleTap(RemoteMessage message) {
    final route = message.data['route'] as String?;
    final id    = message.data['id']    as String?;

    final tab = routeToTab(route);
    if (tab != null) pendingTab.value = tab;

    if (route != null) {
      pendingDeepLink.value = NotifDeepLink(route: route, id: id);
    }
  }

  /// Maps a route string to the bottom-nav tab index.
  /// 0 = Dashboard, 1 = Wallet, 2 = Pantry, 3 = MyHub, 4 = PlanIt, 5 = MyLife
  static int? routeToTab(String? route) => switch (route) {
        'dashboard'                        => 0,
        'wallet' || 'split' || 'budget'   => 1,
        'pantry' || 'grocery' || 'recipe' => 2,
        'myhub'  || 'family'              => 3,
        'planit' || 'reminder' || 'task'
            || 'bill' || 'alert'          => 4,
        'lifestyle' || 'health'
            || 'wardrobe' || 'vehicle'    => 5,
        _                                 => null,
      };
}

// ── Shared notification display (foreground + background) ─────────────────────

Future<void> _showWith(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message, {
  required bool checkQuiet,
}) async {
  final notification = message.notification;
  if (notification == null) return;

  // Quiet-hours gate (foreground only; prefs unavailable in background isolate)
  if (checkQuiet) {
    await NotificationPrefs.instance.init();
    if (NotificationPrefs.instance.isQuietNow) {
      debugPrint('[FCM] quiet hours active — suppressing foreground notification');
      return;
    }
  }

  final route = message.data['route'] as String?;
  final id    = message.data['id']    as String?;
  final link  = route != null ? NotifDeepLink(route: route, id: id) : null;

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
    payload: link?.toPayload(),
  );
}
