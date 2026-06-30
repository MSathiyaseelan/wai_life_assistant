import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Priority;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln show Priority;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:wai_life_assistant/core/services/fcm_service.dart';
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

  // Deep-link notification tap — route to the appropriate tab/screen.
  if (response.actionId == null) {
    final link = NotifDeepLink.fromPayload(response.payload);
    if (link != null) {
      final tab = FcmService.routeToTab(link.route);
      if (tab != null) FcmService.pendingTab.value = tab;
      FcmService.pendingDeepLink.value = link;
      return;
    }
  }

  // SMS notification tap — route payload to SMSParserService via SharedPreferences
  // (avoids cross-isolate ValueNotifier issues; app checks on resume)
  const smsPrefix = 'sms:';
  if (response.actionId == null &&
      (response.payload?.startsWith(smsPrefix) ?? false)) {
    final body = response.payload!.substring(smsPrefix.length);
    await const FlutterSecureStorage().write(key: 'pending_sms_body', value: body);
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
    final tzName   = (await FlutterTimezone.getLocalTimezone()).identifier;
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

    final tzName = (await FlutterTimezone.getLocalTimezone()).identifier;
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

    final tzName   = (await FlutterTimezone.getLocalTimezone()).identifier;
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

    final payload = jsonEncode({
      'id':    r.id,
      'emoji': r.emoji,
      'title': r.title,
      'note':  r.note,
    });
    final body = r.note ?? _priorityLabel(r.priority);
    final title = '${r.emoji} ${r.title}';

    // Bounded repeat: schedule each occurrence individually so alerts stop
    // automatically at repeatEndDate without needing the app to be open.
    if (r.repeat != RepeatMode.none && r.repeatEndDate != null) {
      var current = scheduledDate;
      int idx = 0;
      const maxOccurrences = 500; // safety cap (~40 years of monthly)
      while (!current.isAfter(tz.TZDateTime.from(
        r.repeatEndDate!.add(const Duration(days: 1)), location,
      )) && idx < maxOccurrences) {
        if (!current.isBefore(now)) {
          await _plugin.zonedSchedule(
            _id(r) + idx,
            title,
            body,
            current,
            NotificationDetails(
              android: _alarmAndroidDetails(body: body),
              iOS: _alarmIosDetails,
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
        }
        current = _nextOccurrence(current, r.repeat);
        idx++;
      }
      return;
    }

    // Unbounded repeat: use matchDateTimeComponents (fires indefinitely).
    DateTimeComponents? repeat;
    if (r.repeat == RepeatMode.daily)        repeat = DateTimeComponents.time;
    else if (r.repeat == RepeatMode.weekly)  repeat = DateTimeComponents.dayOfWeekAndTime;
    else if (r.repeat == RepeatMode.monthly) repeat = DateTimeComponents.dayOfMonthAndTime;
    else if (r.repeat == RepeatMode.yearly)  repeat = DateTimeComponents.dateAndTime;

    await _plugin.zonedSchedule(
      _id(r),
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: _alarmAndroidDetails(body: body),
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
    if (r.repeat != RepeatMode.none && r.repeatEndDate != null) {
      // Cancel all individually-scheduled occurrence notifications.
      final count = _boundedOccurrenceCount(r);
      for (int i = 0; i < count; i++) {
        await _plugin.cancel(_id(r) + i);
      }
    } else {
      await _plugin.cancel(_id(r));
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  tz.TZDateTime _nextOccurrence(tz.TZDateTime d, RepeatMode repeat) {
    switch (repeat) {
      case RepeatMode.daily:   return d.add(const Duration(days: 1));
      case RepeatMode.weekly:  return d.add(const Duration(days: 7));
      case RepeatMode.monthly: return tz.TZDateTime(d.location, d.year, d.month + 1, d.day, d.hour, d.minute);
      case RepeatMode.yearly:  return tz.TZDateTime(d.location, d.year + 1, d.month, d.day, d.hour, d.minute);
      case RepeatMode.none:    return d;
    }
  }

  int _boundedOccurrenceCount(ReminderModel r) {
    if (r.repeatEndDate == null || r.repeat == RepeatMode.none) return 1;
    int count = 0;
    var current = DateTime(r.dueDate.year, r.dueDate.month, r.dueDate.day);
    final end = r.repeatEndDate!;
    while (!current.isAfter(end) && count < 500) {
      count++;
      switch (r.repeat) {
        case RepeatMode.daily:   current = current.add(const Duration(days: 1));
        case RepeatMode.weekly:  current = current.add(const Duration(days: 7));
        case RepeatMode.monthly: current = DateTime(current.year, current.month + 1, current.day);
        case RepeatMode.yearly:  current = DateTime(current.year + 1, current.month, current.day);
        case RepeatMode.none:    break;
      }
    }
    return count;
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
