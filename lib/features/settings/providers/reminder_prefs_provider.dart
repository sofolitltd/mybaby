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
    ReminderCategory.careLog: true,
  };

  /// Toggles [category] on/off, requesting notification permission and
  /// scheduling/cancelling the underlying local reminder. Returns whether
  /// the toggle actually applied (false if permission was denied).
  Future<bool> toggle(ReminderCategory category, bool enabled) async {
    final service = ref.read(notificationServiceProvider);

    if (enabled) {
      final granted = await service.requestPermission();
      if (!granted) return false;
      await service.scheduleDaily(
        category: category,
        title: _titleFor(category),
        body: _bodyFor(category),
      );
    } else {
      await service.cancel(category);
    }

    state = {...state, category: enabled};
    return true;
  }

  String _titleFor(ReminderCategory category) => switch (category) {
    ReminderCategory.vaccination => 'Vaccination reminder',
    ReminderCategory.growthCheckIn => 'Growth check-in',
    ReminderCategory.careLog => 'Feeding & diaper check',
  };

  String _bodyFor(ReminderCategory category) => switch (category) {
    ReminderCategory.vaccination => 'Check for upcoming immunizations & shots.',
    ReminderCategory.growthCheckIn => 'Time to log weight & height.',
    ReminderCategory.careLog => 'Don\'t forget to log the last feed or change.',
  };
}

final reminderPrefsProvider =
    NotifierProvider<ReminderPrefsNotifier, Map<ReminderCategory, bool>>(
      ReminderPrefsNotifier.new,
    );
