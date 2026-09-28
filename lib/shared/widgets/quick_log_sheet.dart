import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/sheet_transition.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../data/firestore/care_log_repository.dart';
import '../../data/models/care_log_entry.dart';
import '../../features/care_log/providers/active_care_log_timers_provider.dart';
import '../care_log_type_style.dart';
import 'app_button.dart';
import 'manual_care_log_sheet.dart';

/// One-tap logging bottom sheet — no confirm step, but every type still
/// gets a form: diaper/bath open the instant-log form (time + comment, plus
/// a type grid for diaper); feed/sleep open the fuller manual-log form
/// (start, end time, a method/day-night tag, comment) unless a
/// timer of that type is already running, in which case it goes straight to
/// the stop sheet.
Future<void> showQuickLogSheet(
  BuildContext context,
  WidgetRef ref,
  CareLogType type,
) async {
  final repo = ref.read(careLogRepositoryProvider);
  if (repo == null) return;
  if (type == CareLogType.diaper) {
    return showInstantCareLogSheet(
      context,
      repo,
      type: CareLogType.diaper,
      title: 'Log Diaper',
      subtypeLabel: 'TYPE',
      subtypeOptions: diaperSubtypeOptions,
      defaultSubtype: diaperSubtypeOptions.first.$1,
    );
  }
  if (type == CareLogType.bath) {
    return showInstantCareLogSheet(
      context,
      repo,
      type: CareLogType.bath,
      title: 'Log Bath',
    );
  }

  CareLogEntry? existing;
  for (final e in ref.read(activeCareLogTimersProvider)) {
    if (e.type == type) {
      existing = e;
      break;
    }
  }

  if (existing == null) {
    final now = DateTime.now();
    return type == CareLogType.sleep
        ? showManualCareLogSheet(
            context,
            repo,
            type: CareLogType.sleep,
            title: 'Log Sleep',
            subtypeLabel: 'TYPE',
            subtypeOptions: sleepPeriodOptions,
            defaultSubtype: now.hour >= 6 && now.hour < 19 ? 'Day' : 'Night',
            ongoingChipLabel: 'Still sleeping',
          )
        : showManualCareLogSheet(
            context,
            repo,
            type: CareLogType.feed,
            title: 'Log Feed',
            subtypeLabel: 'METHOD',
            subtypeOptions: feedMethodOptions,
            defaultSubtype: feedMethodOptions.first.$1,
            ongoingChipLabel: 'Still feeding',
          );
  }

  final id = existing.id;
  final startedAt = existing.startTime;
  return _showTimerSheet(context, repo, type, id: id, startedAt: startedAt);
}

const diaperSubtypeOptions = [
  ('Wet', LucideIcons.droplet),
  ('Dirty', LucideIcons.leaf),
  ('Dry', LucideIcons.sun),
  ('Mixed', LucideIcons.check_check),
];

Future<void> _showTimerSheet(
  BuildContext context,
  CareLogRepository repo,
  CareLogType type, {
  required String id,
  required DateTime startedAt,
}) {
  final label = type == CareLogType.feed ? 'Feed' : 'Sleep';
  final icon = type == CareLogType.feed
      ? LucideIcons.glass_water
      : LucideIcons.moon;
  return showAppSheet(
    context: context,
    builder: (context) {
      final theme = AppTheme.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.s,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: theme.colors.primary),
            const SizedBox(height: AppSpacing.s),
            Text(
              '$label timer running',
              style: theme.typography.title.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Started ${DateFormat.jm().format(startedAt)} — leave the app, it keeps running.',
              textAlign: TextAlign.center,
              style: theme.typography.body.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            StreamBuilder<void>(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, _) {
                final elapsed = DateTime.now().difference(startedAt);
                return Text(
                  formatElapsedTimer(elapsed),
                  style: theme.typography.title.copyWith(
                    color: theme.colors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await repo.stop(id, DateTime.now());
                },
                child: Text(
                  'Stop and save',
                  style: theme.typography.label.copyWith(
                    color: theme.colors.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// A tappable grid cell — Diaper's quick-log options and its edit-sheet
/// subtype picker share this look. [selected] adds a `primary`-tinted fill
/// for use as a picker in the edit sheet; the quick-log sheet leaves it
/// false since every option there acts immediately.
class SheetGridOption extends StatelessWidget {
  const SheetGridOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final color = selected ? theme.colors.primary : theme.colors.textSecondary;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.s),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? theme.colors.primary.withValues(alpha: 0.12)
              : theme.colors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadii.s),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpacing.s),
            Text(
              label,
              style: theme.typography.subtitle.copyWith(
                color: selected ? color : theme.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
