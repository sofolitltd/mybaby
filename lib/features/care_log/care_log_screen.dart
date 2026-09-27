import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/sheet_transition.dart';
import '../../core/theme/motion/staggered_entrance.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../data/models/care_log_entry.dart';
import '../../shared/care_log_type_style.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_status_pill.dart';
import '../../shared/widgets/quick_log_sheet.dart';

class CareLogScreen extends ConsumerStatefulWidget {
  const CareLogScreen({super.key});

  @override
  ConsumerState<CareLogScreen> createState() => _CareLogScreenState();
}

class _CareLogScreenState extends ConsumerState<CareLogScreen> {
  CareLogType? _filter;

  Future<void> _addEntry() async {
    final type = await showAppSheet<CareLogType>(
      context: context,
      builder: (context) => const _AddEntryTypePicker(),
    );
    if (type != null && mounted) {
      await showQuickLogSheet(context, ref, type);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final entriesAsync = ref.watch(careLogProvider);

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Could not load care log: $e',
          style: theme.typography.body.copyWith(
            color: theme.colors.textSecondary,
          ),
        ),
      ),
      data: (entries) {
        final today = entries.where((e) => isToday(e.startTime)).toList();
        final stats = computeDailyStats(entries);
        final filtered = _filter == null
            ? today
            : today.where((e) => e.type == _filter).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.l,
            AppSpacing.xl,
            96,
          ),
          children: [
            _TodaysSummaryCard(stats: stats),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Text(
                  'Today',
                  style: theme.typography.subtitle.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
                const Spacer(),
                TapScale(
                  onTap: _addEntry,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.plus,
                        size: 16,
                        color: theme.colors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Add Entry',
                        style: theme.typography.label.copyWith(
                          color: theme.colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Wrap(
              spacing: AppSpacing.s,
              children: [
                AppChip(
                  label: 'All (${today.length})',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final type in CareLogType.values)
                  AppChip(
                    label: switch (type) {
                      CareLogType.feed => 'Feed',
                      CareLogType.sleep => 'Sleep',
                      CareLogType.diaper => 'Diaper',
                    },
                    selected: _filter == type,
                    onTap: () => setState(() => _filter = type),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            if (filtered.isEmpty)
              const AppEmptyState(
                icon: LucideIcons.list_checks,
                message: 'Nothing logged yet today — use the quick-log buttons on Home.',
              )
            else
              StaggeredListEntrance(
                children: [
                  for (final entry in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.m),
                      child: _CareLogTile(entry: entry),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _TodaysSummaryCard extends StatelessWidget {
  const _TodaysSummaryCard({required this.stats});

  final CareLogDailyStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Today's Summary",
                style: theme.typography.subtitle.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              AppStatusPill(
                label: 'Updated ${DateFormat.jm().format(DateTime.now())}',
                color: colors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  icon: LucideIcons.moon,
                  tint: colors.info,
                  label: 'Sleep',
                  value:
                      '${stats.sleepMinutes ~/ 60}h ${stats.sleepMinutes % 60}m',
                  caption: 'Target: 14h',
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  icon: LucideIcons.milk,
                  tint: colors.secondary,
                  label: 'Feeds',
                  value: '${stats.feedCount}',
                  caption: 'today',
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  icon: LucideIcons.baby,
                  tint: colors.primary,
                  label: 'Diapers',
                  value: '${stats.diaperCount}',
                  caption: 'today',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: tint),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: theme.typography.caption.copyWith(
            color: theme.colors.textSecondary,
          ),
        ),
        Text(
          value,
          style: theme.typography.subtitle.copyWith(
            color: theme.colors.textPrimary,
          ),
        ),
        Text(
          caption,
          style: theme.typography.caption.copyWith(
            color: theme.colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _AddEntryTypePicker extends StatelessWidget {
  const _AddEntryTypePicker();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.s,
        AppSpacing.xl,
        AppSpacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add entry',
            style: theme.typography.title.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
          for (final type in CareLogType.values) _TypeOption(type: type),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({required this.type});

  final CareLogType type;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final (icon, label) = careLogTypeIconLabel(type);
    final tint = careLogTypeColor(theme.colors, type);
    return TapScale(
      onTap: () => Navigator.of(context).pop(type),
      borderRadius: BorderRadius.circular(AppRadii.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: AppSpacing.m),
            Text(
              label,
              style: theme.typography.subtitle.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareLogTile extends StatelessWidget {
  const _CareLogTile({required this.entry});

  final CareLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final (icon, label) = careLogTypeIconLabel(entry.type);
    final tint = careLogTypeColor(theme.colors, entry.type);
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.typography.subtitle.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
                if (entry.summary.isNotEmpty)
                  Text(
                    entry.summary,
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            DateFormat.jm().format(entry.startTime),
            style: theme.typography.caption.copyWith(
              color: theme.colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
