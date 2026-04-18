import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Priority;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln show Priority;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';

// ── Top-level constants & helpers ─────────────────────────────────────────────

/// Vibration: wait → buzz 600ms → pause 300ms × 3
final _kAlarmVibration = Int64List.fromList([0, 600, 300, 600, 300, 600]);

AndroidNotificationDetails _alarmAndroidDetails({required String body, String? payload}) =>
    AndroidNotificationDetails(
      'wai_alarms',
      'WAI Alarms',
      channelDescription: 'Alarm-style alerts from WAI Life Assistant',
      importance: Importance.max,
      priority: fln.Priority.max,
      icon: '@mipmap/ic_launcher',
      sound: const UriAndroidNotificationSound(
        'content://settings/system/alarm_alert',
      ),
      enableVibration: true,
      vibrationPattern: _kAlarmVibration,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: false,
      actions: const [
        AndroidNotificationAction(
          'snooze',
          'Snooze 10 min',
          showsUserInterface: true,   // brings app to foreground — most reliable
        ),
        AndroidNotificationAction(
          'stop',
          'Stop',
          showsUserInterface: false,  // silent dismiss, no app needed
        ),
      ],
    );

const _alarmIosDetails = DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,
  categoryIdentifier: 'alarm',
  interruptionLevel: InterruptionLevel.timeSensitive,
);

// ── Background notification action handler ────────────────────────────────────
// Must be a top-level function and annotated so the Dart VM keeps it alive
// when the app is not running.

@pragma('vm:entry-point')
Future<void> _onBackgroundAction(NotificationResponse response) async {
  await _handleAction(response);
}

Future<void> _handleAction(NotificationResponse response) async {
  final plugin = FlutterLocalNotificationsPlugin();

  // SMS notification tap — route payload to SMSParserService via SharedPreferences
  // (avoids cross-isolate ValueNotifier issues; app checks on resume)
  const smsPrefix = 'sms:';
  if (response.actionId == null &&
      (response.payload?.startsWith(smsPrefix) ?? false)) {
    final body = response.payload!.substring(smsPrefix.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_sms_body', body);
    return;
  }

  // Stop: cancel the notification only
  if (response.actionId == 'stop') {
    await plugin.cancel(response.id ?? 0);
    return;
  }

  // Snooze: cancel + reschedule 10 minutes from now + update DB
  if (response.actionId == 'snooze' && response.payload != null) {
    await plugin.cancel(response.id ?? 0);

    final data       = jsonDecode(response.payload!) as Map<String, dynamic>;
    final emoji      = data['emoji'] as String? ?? '⏰';
    final title      = data['title'] as String? ?? 'Reminder';
    final note       = data['note']  as String?;
    final reminderId = data['id']    as String?;
    final notifId    = response.id ?? 0;

    tz.initializeTimeZones();
    final tzName   = await FlutterTimezone.getLocalTimezone();
    final location = tz.getLocation(tzName);
    final snoozeAt = tz.TZDateTime.now(location).add(const Duration(minutes: 10));

    // Reschedule the notification
    await plugin.zonedSchedule(
      notifId,
      '$emoji $title',
      '⏰ Snoozed · ${note ?? "Reminder"}',
      snoozeAt,
      NotificationDetails(
        android: _alarmAndroidDetails(body: note ?? '', payload: response.payload),
        iOS: _alarmIosDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: response.payload,
    );

    // Update the reminder's due date/time in the database
    if (reminderId != null) {
      try {
        String pad(int v) => v.toString().padLeft(2, '0');
        await Supabase.instance.client.from('reminders').update({
          'due_date': '${snoozeAt.year}-${pad(snoozeAt.month)}-${pad(snoozeAt.day)}',
          'due_time': '${pad(snoozeAt.hour)}:${pad(snoozeAt.minute)}',
          'snoozed': true,
        }).eq('id', reminderId);
        debugPrint('[Notifications] DB updated for snooze "$title" → $snoozeAt');
      } catch (e) {
        debugPrint('[Notifications] DB snooze update failed: $e');
      }
    }

    debugPrint('[Notifications] Snoozed "$title" until $snoozeAt');
  }
}

// ── NotificationService ───────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    final tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName));
    debugPrint('[Notifications] timezone=$tzName');

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Register iOS action category so Snooze/Stop buttons appear on iOS too
    final ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'alarm',
          actions: [
            DarwinNotificationAction.plain('snooze', 'Snooze 10 min'),
            DarwinNotificationAction.plain(
              'stop',
              'Stop',
              options: {DarwinNotificationActionOption.destructive},
            ),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _handleAction,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundAction,
    );

    // Create alarm channel up-front — channel settings are immutable after
    // first use, so we pin the alarm sound and vibration here.
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(
      AndroidNotificationChannel(
        'wai_alarms',
        'WAI Alarms',
        description: 'Alarm-style alerts from WAI Life Assistant',
        importance: Importance.max,
        sound: const UriAndroidNotificationSound(
          'content://settings/system/alarm_alert',
        ),
        enableVibration: true,
        vibrationPattern: _kAlarmVibration,
        playSound: true,
      ),
    );

    _initialized = true;
  }

  // ── Request permissions ────────────────────────────────────────────────────
  Future<void> requestPermissions() async {
    await init();
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  // ── Schedule ───────────────────────────────────────────────────────────────
  Future<void> schedule(ReminderModel r) async {
    await init();

    final tzName   = await FlutterTimezone.getLocalTimezone();
    final location = tz.getLocation(tzName);

    final scheduledDate = tz.TZDateTime(
      location,
      r.dueDate.year,
      r.dueDate.month,
      r.dueDate.day,
      r.dueTime.hour,
      r.dueTime.minute,
    );

    final now = tz.TZDateTime.now(location);
    debugPrint('[Notifications] schedule "${r.title}" at $scheduledDate (now=$now)');
    if (scheduledDate.isBefore(now)) {
      debugPrint('[Notifications] SKIPPED — time already past');
      return;
    }

    DateTimeComponents? repeat;
    if (r.repeat == RepeatMode.daily)        repeat = DateTimeComponents.time;
    else if (r.repeat == RepeatMode.weekly)  repeat = DateTimeComponents.dayOfWeekAndTime;
    else if (r.repeat == RepeatMode.monthly) repeat = DateTimeComponents.dayOfMonthAndTime;
    else if (r.repeat == RepeatMode.yearly)  repeat = DateTimeComponents.dateAndTime;

    // Encode reminder data so the background handler can reconstruct the
    // snooze notification without needing a DB call.
    final payload = jsonEncode({
      'id':    r.id,
      'emoji': r.emoji,
      'title': r.title,
      'note':  r.note,
    });

    await _plugin.zonedSchedule(
      _id(r),
      '${r.emoji} ${r.title}',
      r.note ?? _priorityLabel(r.priority),
      scheduledDate,
      NotificationDetails(
        android: _alarmAndroidDetails(body: r.note ?? _priorityLabel(r.priority)),
        iOS: _alarmIosDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: repeat,
      payload: payload,
    );
  }

  // ── Cancel ─────────────────────────────────────────────────────────────────
  Future<void> cancel(ReminderModel r) async {
    await init();
    await _plugin.cancel(_id(r));
  }

  // ── Reschedule all on app start ────────────────────────────────────────────
  Future<void> rescheduleAll(List<ReminderModel> reminders) async {
    await init();
    await _plugin.cancelAll();
    for (final r in reminders) {
      if (!r.done) await schedule(r);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  int _id(ReminderModel r) => r.id.hashCode.abs() % 2147483647;

  String _priorityLabel(Priority p) {
    if (p == Priority.urgent) return 'Urgent reminder';
    if (p == Priority.high)   return 'High priority';
    return 'Reminder';
  }
}
