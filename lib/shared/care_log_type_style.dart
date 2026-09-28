import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../core/theme/app_theme.dart';
import '../data/models/care_log_entry.dart';

/// Per-activity icon + tint shared by Home's quick-log bar and the Care Log
/// timeline — amber for feed, indigo for sleep, eucalyptus for diaper. This
/// matches the actual Stitch mockups (not the design doc's prose, which
/// describes a different mapping the rendered screens don't follow).
(IconData, String) careLogTypeIconLabel(CareLogType type) => switch (type) {
  CareLogType.feed => (LucideIcons.milk, 'Feed'),
  CareLogType.sleep => (LucideIcons.moon, 'Sleep'),
  CareLogType.diaper => (LucideIcons.baby, 'Diaper'),
  CareLogType.bath => (LucideIcons.bath, 'Bath'),
};

Color careLogTypeColor(AppColors colors, CareLogType type) => switch (type) {
  CareLogType.feed => colors.secondary,
  CareLogType.sleep => colors.info,
  CareLogType.diaper => colors.primary,
  CareLogType.bath => colors.tertiary,
};

/// True for a feed/sleep entry that's an actively running timer. Diaper and
/// bath entries also have `endTime == null` (they're instant, never timed),
/// so checking the type keeps them from being mistaken for a running timer.
bool isRunningTimer(CareLogEntry entry) =>
    entry.endTime == null &&
    (entry.type == CareLogType.feed || entry.type == CareLogType.sleep);

/// `H:MM:SS` (or `MM:SS` under an hour) for a live-running timer's elapsed
/// duration — used wherever a feed/sleep timer's countdown is displayed.
String formatElapsedTimer(Duration elapsed) {
  final hours = elapsed.inHours;
  final minutes = elapsed.inMinutes.remainder(60);
  final seconds = elapsed.inSeconds.remainder(60);
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

bool isToday(DateTime time) {
  final now = DateTime.now();
  return time.year == now.year &&
      time.month == now.month &&
      time.day == now.day;
}

/// Today's totals — shared by Home's growth/stats card and the Care Log
/// screen's stats card so the two never disagree.
class CareLogDailyStats {
  const CareLogDailyStats({
    required this.sleepMinutes,
    required this.feedCount,
    required this.diaperCount,
  });

  final int sleepMinutes;
  final int feedCount;
  final int diaperCount;
}

CareLogDailyStats computeDailyStats(List<CareLogEntry> allEntries) {
  final today = allEntries.where((e) => isToday(e.startTime));
  final feedCount = today.where((e) => e.type == CareLogType.feed).length;
  final diaperCount = today.where((e) => e.type == CareLogType.diaper).length;
  final sleepMinutes = today
      .where((e) => e.type == CareLogType.sleep)
      .fold<int>(0, (sum, e) => sum + (e.duration?.inMinutes ?? 0));
  return CareLogDailyStats(
    sleepMinutes: sleepMinutes,
    feedCount: feedCount,
    diaperCount: diaperCount,
  );
}
