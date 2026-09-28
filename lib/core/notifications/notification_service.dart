import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/vaccination.dart';

/// Stable notification ids, one per reminder category, so re-scheduling a
/// category (toggle off/on, time change) replaces rather than stacks.
enum ReminderCategory {
  vaccination(100, 'vaccination_reminders', 'Vaccination reminders'),
  growthCheckIn(200, 'growth_checkin_reminders', 'Growth check-ins'),
  medication(400, 'medication_reminders', 'Medication reminders'),
  feedAlert(500, 'feed_alert_reminders', 'Feed alerts');

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
    if (!_initialized) return false;
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
    if (!_initialized) return;
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
      _initialized ? _plugin.cancel(id: category.notificationId) : Future.value();

  Future<void> cancelAll() => _initialized ? _plugin.cancelAll() : Future.value();

  static const _taskChannelId = 'task_reminders';
  static const _taskChannelName = 'Task reminders';

  /// Id for the repeating "every N minutes/hours" feed alert — a single
  /// slot since only one interval can be active at a time (see
  /// [ReminderCategory.feedAlert]).
  static const int feedAlertId = 303;

  /// Id for the feed alert's optional one-off "coming up" heads-up, fired
  /// [FeedAlertState.leadMinutes] before the *next* feed alert occurrence
  /// (see [scheduleFeedAlertLead] for why it can't repeat every cycle the
  /// way the main alert does).
  static const int feedAlertLeadId = 304;

  /// Reserves ids well clear of the fixed 100/200/300 category ids above,
  /// one per task so scheduling a new due date replaces rather than stacks.
  int taskNotificationId(String taskId) =>
      10000 + taskId.hashCode.abs() % 1000000;

  /// Schedules a one-off notification at [dateTime] (not repeating, unlike
  /// [scheduleDaily]) — used for a task's due date or the next-feed
  /// reminder. A past [dateTime] is silently skipped rather than firing
  /// immediately. Defaults to the generic task channel; pass [category] to
  /// post under that category's channel instead (e.g. the care log channel
  /// for feed reminders).
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    ReminderCategory? category,
  }) async {
    if (!_initialized || dateTime.isBefore(DateTime.now())) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        category?.channelId ?? _taskChannelId,
        category?.channelName ?? _taskChannelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(dateTime, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelById(int id) =>
      _initialized ? _plugin.cancel(id: id) : Future.value();

  /// Schedules a repeating notification every [interval] under [category],
  /// replacing any previous repeat scheduled at [id] — this is the "global"
  /// feed alert (e.g. every 2/3 hours) rather than a one-off time.
  Future<void> schedulePeriodic({
    required int id,
    required String title,
    required String body,
    required Duration interval,
    required ReminderCategory category,
  }) async {
    if (!_initialized) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        category.channelId,
        category.channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.periodicallyShowWithDuration(
      id: id,
      title: title,
      body: body,
      repeatDurationInterval: interval,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Schedules a one-off "coming up" heads-up [leadTime] before the *next*
  /// feed alert occurrence — `flutter_local_notifications`'
  /// `periodicallyShowWithDuration` has no anchor-time parameter, so a lead
  /// notification can't be kept in sync with every future occurrence of a
  /// repeating alert the way [DiaperReminderState]'s one-off pair could;
  /// this covers the next one and is re-armed each time [schedulePeriodic]
  /// is called for the feed alert (see `FeedAlertNotifier.setInterval`).
  Future<void> scheduleFeedAlertLead({
    required Duration interval,
    required Duration leadTime,
  }) {
    return scheduleAt(
      id: feedAlertLeadId,
      title: 'Feed coming up',
      body: 'Next feed alert in ${leadTime.inMinutes} minutes.',
      dateTime: DateTime.now().add(interval - leadTime),
      category: ReminderCategory.feedAlert,
    );
  }

  /// Deterministic id for one vaccination's due-date reminder, derived from
  /// its Firestore doc id — recomputing this is how
  /// [cancelVaccinationReminders] finds ids to cancel without tracking what
  /// was scheduled separately (same pattern as
  /// [medicationDoseNotificationId]).
  int vaccinationReminderId(String vaccinationId) =>
      30000000 + vaccinationId.hashCode.abs() % 1000000;

  /// Schedules a due-date reminder for every not-yet-administered
  /// vaccination in [vaccinations], fired the day before its
  /// `scheduledDate` (or, if that's already past, at the scheduled date
  /// itself — [scheduleAt] silently skips anything still in the past).
  /// Administered vaccinations have any stale reminder cancelled instead.
  Future<void> scheduleVaccinationReminders(
    List<Vaccination> vaccinations,
  ) async {
    for (final vaccination in vaccinations) {
      final id = vaccinationReminderId(vaccination.id);
      if (vaccination.administeredDate != null) {
        await cancelById(id);
        continue;
      }
      final dayBefore = vaccination.scheduledDate.subtract(
        const Duration(days: 1),
      );
      final fireAt = DateTime(
        dayBefore.year,
        dayBefore.month,
        dayBefore.day,
        9,
      );
      await scheduleAt(
        id: id,
        title: 'Vaccination due: ${vaccination.name}',
        body:
            'Dose ${vaccination.dose} scheduled for '
            '${DateFormat.yMMMd().format(vaccination.scheduledDate)}.',
        dateTime: fireAt.isBefore(DateTime.now())
            ? vaccination.scheduledDate
            : fireAt,
        category: ReminderCategory.vaccination,
      );
    }
  }

  /// Cancels every reminder [scheduleVaccinationReminders] could have
  /// scheduled for these vaccination ids — call when turning the
  /// vaccination reminder toggle off.
  Future<void> cancelVaccinationReminders(
    Iterable<String> vaccinationIds,
  ) async {
    for (final id in vaccinationIds) {
      await cancelById(vaccinationReminderId(id));
    }
  }

  /// Schedules a monthly growth check-in reminder that lands on the baby's
  /// birth day-of-month (clamped to 28 so it fires every month, including
  /// February) at 9am local time, replacing any previously scheduled one.
  Future<void> scheduleMonthlyGrowthCheckIn(DateTime dob) async {
    if (!_initialized) return;
    final day = dob.day > 28 ? 28 : dob.day;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        ReminderCategory.growthCheckIn.channelId,
        ReminderCategory.growthCheckIn.channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.zonedSchedule(
      id: ReminderCategory.growthCheckIn.notificationId,
      title: 'Growth check-in',
      body: "It's been a month — time to log weight & height.",
      scheduledDate: _nextInstanceOfDayOfMonth(day, 9, 0),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  /// All local notifications currently scheduled (not yet fired or
  /// cancelled) across every category — vaccination/growth/care-log/
  /// medication reminders, the next-feed pair, and one-off task alerts.
  /// Backs the Settings "Reminders & Alerts" detail screen.
  Future<List<PendingNotificationRequest>> pendingNotifications() =>
      _initialized ? _plugin.pendingNotificationRequests() : Future.value(const []);

  /// Deterministic id for one scheduled dose of a medication course — day
  /// [dayIndex] (0-based from the course's start date) and time slot
  /// [timeIndex] (index into the medication's reminder times). Recomputing
  /// this from the same inputs is how [cancelMedicationCourse] finds ids to
  /// cancel without needing to track what was scheduled separately.
  int medicationDoseNotificationId(
    String medicationId,
    int dayIndex,
    int timeIndex,
  ) => 20000000 + '$medicationId-$dayIndex-$timeIndex'.hashCode.abs() % 1000000;

  /// Schedules one-off reminders for every dose of [medication] across its
  /// whole course (`durationDays` × `reminderTimes`) — each is a plain
  /// one-off notification rather than a repeating daily one, so the course
  /// naturally stops firing once it ends. Past doses are silently skipped
  /// (see [scheduleAt]).
  Future<void> scheduleMedicationCourse({
    required String medicationId,
    required String name,
    required String dosage,
    required DateTime startDate,
    required int durationDays,
    required List<String> reminderTimes,
  }) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    for (var day = 0; day < durationDays; day++) {
      final date = start.add(Duration(days: day));
      for (var t = 0; t < reminderTimes.length; t++) {
        final parts = reminderTimes[t].split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        await scheduleAt(
          id: medicationDoseNotificationId(medicationId, day, t),
          title: 'Medication: $name',
          body: 'Time for $dosage',
          dateTime: DateTime(date.year, date.month, date.day, hour, minute),
          category: ReminderCategory.medication,
        );
      }
    }
  }

  /// Cancels every dose id [scheduleMedicationCourse] could have scheduled
  /// for a course of this shape — call with the *old* duration/times before
  /// editing or deleting a medication so a shortened or retimed course
  /// doesn't leave stray reminders behind.
  Future<void> cancelMedicationCourse({
    required String medicationId,
    required int durationDays,
    required int reminderTimesCount,
  }) async {
    for (var day = 0; day < durationDays; day++) {
      for (var t = 0; t < reminderTimesCount; t++) {
        await cancelById(medicationDoseNotificationId(medicationId, day, t));
      }
    }
  }

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

  tz.TZDateTime _nextInstanceOfDayOfMonth(int day, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, day, hour, minute);
    if (scheduled.isBefore(now)) {
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      scheduled = tz.TZDateTime(tz.local, nextYear, nextMonth, day, hour, minute);
    }
    return scheduled;
  }
}
