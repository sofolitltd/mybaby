import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/providers.dart';

/// A "global" repeating feed alert — every [interval], not tied to a
/// specific next feed time. `null` interval means the alert is off.
/// [leadMinutes] (0 = no lead) is an optional heads-up before the next
/// occurrence — see [NotificationService.scheduleFeedAlertLead] for why it
/// only covers the next occurrence rather than every future one. In-memory
/// only, same pattern as `themeModeProvider`/`reminderPrefsProvider` — not
/// yet persisted or synced to Firestore.
class FeedAlertState {
  const FeedAlertState({this.interval, this.leadMinutes = 0});

  final Duration? interval;
  final int leadMinutes;

  bool get isSet => interval != null;
}

class FeedAlertNotifier extends Notifier<FeedAlertState> {
  @override
  FeedAlertState build() => const FeedAlertState();

  /// Starts (or replaces) a repeating alert firing every [interval], plus
  /// an optional heads-up [leadMinutes] before the next occurrence when
  /// that's > 0. Returns whether it applied (false if permission was
  /// denied).
  Future<bool> setInterval(Duration interval, {int leadMinutes = 0}) async {
    final service = ref.read(notificationServiceProvider);
    final granted = await service.requestPermission();
    if (!granted) return false;

    await service.schedulePeriodic(
      id: NotificationService.feedAlertId,
      title: 'Feeding time',
      body: 'Time for a feed?',
      interval: interval,
      category: ReminderCategory.feedAlert,
    );

    if (leadMinutes > 0) {
      await service.scheduleFeedAlertLead(
        interval: interval,
        leadTime: Duration(minutes: leadMinutes),
      );
    } else {
      await service.cancelById(NotificationService.feedAlertLeadId);
    }

    state = FeedAlertState(interval: interval, leadMinutes: leadMinutes);
    return true;
  }

  Future<void> cancel() async {
    final service = ref.read(notificationServiceProvider);
    await service.cancelById(NotificationService.feedAlertId);
    await service.cancelById(NotificationService.feedAlertLeadId);
    state = const FeedAlertState();
  }
}

final feedAlertProvider = NotifierProvider<FeedAlertNotifier, FeedAlertState>(
  FeedAlertNotifier.new,
);
