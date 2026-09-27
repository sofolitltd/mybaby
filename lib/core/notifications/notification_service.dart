import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Stable notification ids, one per reminder category, so re-scheduling a
/// category (toggle off/on, time change) replaces rather than stacks.
enum ReminderCategory {
  vaccination(100, 'vaccination_reminders', 'Vaccination reminders'),
  growthCheckIn(200, 'growth_checkin_reminders', 'Growth check-ins'),
  careLog(300, 'care_log_reminders', 'Feeding & diaper alerts');

  const ReminderCategory(this.notificationId, this.channelId, this.channelName);

  final int notificationId;
  final String channelId;
  final String channelName;
}

/// Thin wrapper around `flutter_local_notifications` for reminder
/// scheduling (vaccinations, growth check-ins, care log alerts — see
/// docs/PRD.md and docs/ARCHITECTURE.md's notifications section). Settings
/// toggles call [requestPermission] + [scheduleDaily]/[cancel]; feature
/// code can layer smarter scheduling (e.g. actual vaccination due dates) on
/// top of the same categories later.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName.identifier));
    } catch (_) {
      // Falls back to UTC scheduling if the platform timezone lookup fails.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings: initSettings);

    _initialized = true;
  }

  /// Requests OS notification permission (Android 13+ runtime prompt).
  /// Returns whether permission is granted.
  Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return true;
    final granted = await androidPlugin.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Schedules a daily reminder at [hour]:[minute] local time for
  /// [category], replacing any previously scheduled reminder in the same
  /// category.
  Future<void> scheduleDaily({
    required ReminderCategory category,
    required String title,
    required String body,
    int hour = 9,
    int minute = 0,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        category.channelId,
        category.channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

    await _plugin.zonedSchedule(
      id: category.notificationId,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOf(hour, minute),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(ReminderCategory category) =>
      _plugin.cancel(id: category.notificationId);

  Future<void> cancelAll() => _plugin.cancelAll();

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
