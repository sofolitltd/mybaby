import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When the Drive folder check last succeeded, for the Settings screen's
/// "Last backup" subtitle. In-memory only (same pattern as
/// `themeModeProvider`) — resets on app restart since there's no real
/// backup-history model yet, see docs/DESIGN_SYSTEM.md#11-adoption-tracker.
class LastBackupNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void markSyncedNow() => state = DateTime.now();
}

final lastBackupProvider = NotifierProvider<LastBackupNotifier, DateTime?>(
  LastBackupNotifier.new,
);
