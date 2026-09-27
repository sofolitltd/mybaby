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
};

Color careLogTypeColor(AppColors colors, CareLogType type) => switch (type) {
  CareLogType.feed => colors.secondary,
  CareLogType.sleep => colors.info,
  CareLogType.diaper => colors.primary,
};

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
