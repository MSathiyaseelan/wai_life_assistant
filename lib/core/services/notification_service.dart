import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Priority;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln show Priority;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    // Set local timezone so scheduled times match the device clock
    final tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName));
    debugPrint('[Notifications] timezone=$tzName');

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    _initialized = true;
  }

  // ── Request permissions (call from a live widget, not before runApp) ─────
  Future<void> requestPermissions() async {
    await init();
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  // ── Schedule ──────────────────────────────────────────────────────────────
  Future<void> schedule(ReminderModel r) async {
    await init();

    // Always resolve the device timezone at schedule time — don't rely on tz.local
    final tzName = await FlutterTimezone.getLocalTimezone();
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
    debugPrint('[Notifications] tz=$tzName schedule "${r.title}" at $scheduledDate (now=$now)');
    if (scheduledDate.isBefore(now)) {
      debugPrint('[Notifications] SKIPPED — time already past');
      return;
    }

    DateTimeComponents? repeat;
    if (r.repeat == RepeatMode.daily) {
      repeat = DateTimeComponents.time;
    } else if (r.repeat == RepeatMode.weekly) {
      repeat = DateTimeComponents.dayOfWeekAndTime;
    } else if (r.repeat == RepeatMode.monthly) {
      repeat = DateTimeComponents.dayOfMonthAndTime;
    } else if (r.repeat == RepeatMode.yearly) {
      repeat = DateTimeComponents.dateAndTime;
    }

    await _plugin.zonedSchedule(
      _id(r),
      '${r.emoji} ${r.title}',
      r.note ?? _priorityLabel(r.priority),
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'wai_reminders',
          'WAI Reminders',
          channelDescription: 'Reminders from WAI Life Assistant',
          importance: _importance(r.priority),
          priority: _priority(r.priority),
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: repeat,
    );
  }

  // ── Cancel ────────────────────────────────────────────────────────────────
  Future<void> cancel(ReminderModel r) async {
    await init();
    await _plugin.cancel(_id(r));
  }

  // ── Reschedule all on app start ───────────────────────────────────────────
  Future<void> rescheduleAll(List<ReminderModel> reminders) async {
    await init();
    await _plugin.cancelAll();
    for (final r in reminders) {
      if (!r.done) await schedule(r);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  int _id(ReminderModel r) => r.id.hashCode.abs() % 2147483647;

  String _priorityLabel(Priority p) {
    if (p == Priority.urgent) return 'Urgent reminder';
    if (p == Priority.high) return 'High priority';
    return 'Reminder';
  }

  Importance _importance(Priority p) {
    if (p == Priority.urgent) return Importance.max;
    if (p == Priority.high) return Importance.high;
    if (p == Priority.low) return Importance.low;
    return Importance.defaultImportance;
  }

  fln.Priority _priority(Priority p) {
    if (p == Priority.urgent) return fln.Priority.max;
    if (p == Priority.high) return fln.Priority.high;
    if (p == Priority.low) return fln.Priority.low;
    return fln.Priority.defaultPriority;
  }
}
