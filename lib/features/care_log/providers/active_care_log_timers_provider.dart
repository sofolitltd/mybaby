import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/models/care_log_entry.dart';

/// Entries that have been started but not stopped (`endTime == null`) —
/// currently-running feed/sleep timers. Diaper entries never appear here
/// since they log instantly. Pure derived view over [careLogProvider]'s
/// live stream; writes stay as direct repository calls.
final activeCareLogTimersProvider = Provider<List<CareLogEntry>>((ref) {
  final entries = ref.watch(careLogProvider).value ?? const [];
  return [for (final e in entries) if (e.endTime == null) e];
});
