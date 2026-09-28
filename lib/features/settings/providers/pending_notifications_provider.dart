import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// Every local notification currently scheduled on the device, for the
/// Settings "Reminders & Alerts" detail screen. Not a stream — the plugin
/// only supports a one-off query, so this is re-fetched via
/// `ref.invalidate` (e.g. pull-to-refresh) rather than updating live.
final pendingNotificationsProvider =
    FutureProvider<List<PendingNotificationRequest>>((ref) {
      return ref.watch(notificationServiceProvider).pendingNotifications();
    });
