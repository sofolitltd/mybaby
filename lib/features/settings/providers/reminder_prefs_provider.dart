import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/providers.dart';

/// On/off state for each reminder category shown on the Settings screen.
/// In-memory only, same pattern as `themeModeProvider` — not yet persisted
/// or synced to Firestore (see docs/DESIGN_SYSTEM.md#11-adoption-tracker).
class ReminderPrefsNotifier extends Notifier<Map<ReminderCategory, bool>> {
  @override
  Map<ReminderCategory, bool> build() => const {
    ReminderCategory.vaccination: true,
    ReminderCategory.growthCheckIn: false,
  };

  /// Toggles [category] on/off, requesting notification permission and
  /// scheduling/cancelling the underlying local reminder. Returns whether
  /// the toggle actually applied (false if permission was denied).
  ///
  /// Vaccination and growth check-in reminders aren't a generic daily
  /// nudge — they're derived from real per-baby data (each vaccination's
  /// `scheduledDate`, the baby's `dob`) rather than [NotificationService
  /// .scheduleDaily], so this reads the current baby/vaccination state and
  /// schedules one reminder per upcoming vaccination, or a reminder that
  /// lands monthly on the baby's birth day-of-month.
  Future<bool> toggle(ReminderCategory category, bool enabled) async {
    final service = ref.read(notificationServiceProvider);

    if (enabled) {
      final granted = await service.requestPermission();
      if (!granted) return false;

      switch (category) {
        case ReminderCategory.vaccination:
          final vaccinations = await ref.read(vaccinationsProvider.future);
          await service.scheduleVaccinationReminders(vaccinations);
        case ReminderCategory.growthCheckIn:
          final baby = ref.read(activeBabyProvider);
          if (baby != null) {
            await service.scheduleMonthlyGrowthCheckIn(baby.dob);
          }
        case ReminderCategory.medication:
        case ReminderCategory.feedAlert:
          await service.scheduleDaily(
            category: category,
            title: _titleFor(category),
            body: _bodyFor(category),
          );
      }
    } else {
      switch (category) {
        case ReminderCategory.vaccination:
          final vaccinations = await ref.read(vaccinationsProvider.future);
          await service.cancelVaccinationReminders(
            vaccinations.map((v) => v.id),
          );
        case ReminderCategory.growthCheckIn:
        case ReminderCategory.medication:
        case ReminderCategory.feedAlert:
          await service.cancel(category);
      }
    }

    state = {...state, category: enabled};
    return true;
  }

  String _titleFor(ReminderCategory category) => switch (category) {
    ReminderCategory.vaccination => 'Vaccination reminder',
    ReminderCategory.growthCheckIn => 'Growth check-in',
    ReminderCategory.medication => 'Medication reminder',
    ReminderCategory.feedAlert => 'Feeding time',
  };

  String _bodyFor(ReminderCategory category) => switch (category) {
    ReminderCategory.vaccination => 'Check for upcoming immunizations & shots.',
    ReminderCategory.growthCheckIn => 'Time to log weight & height.',
    ReminderCategory.feedAlert => 'Time for the next feed.',
    // Not toggled from here — each medication schedules its own reminders
    // (see NotificationService.scheduleMedicationCourse) rather than one
    // blanket on/off switch like the categories above.
    ReminderCategory.medication => 'Time for a dose.',
  };
}

final reminderPrefsProvider =
    NotifierProvider<ReminderPrefsNotifier, Map<ReminderCategory, bool>>(
      ReminderPrefsNotifier.new,
    );
