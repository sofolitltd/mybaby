import 'package:flutter/material.dart' show Divider;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/staggered_entrance.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../data/models/care_log_entry.dart';
import '../../data/models/growth_entry.dart';
import '../../shared/care_log_type_style.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/app_status_pill.dart';
import '../../shared/widgets/quick_log_sheet.dart';
import '../care_log/providers/active_care_log_timers_provider.dart';

/// Mirrors the Stitch "My Baby - Home" mockup: one scrollable page — a
/// combined growth+today's-stats card, the quick-log section, then a live
/// feed of today's care log entries — no fixed bottom bar. See
/// docs/UX.md "Home (dashboard)".
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final growth = ref.watch(growthEntriesProvider).value ?? const [];
    final careLog = ref.watch(careLogProvider).value ?? const [];
    final activeTimers = ref.watch(activeCareLogTimersProvider);
    final latestGrowth = growth.isEmpty ? null : growth.last;
    final stats = computeDailyStats(careLog);
    final todayEntries = [
      for (final e in careLog)
        if (isToday(e.startTime) && e.endTime != null) e,
    ]..sort((a, b) => b.startTime.compareTo(a.startTime));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      children: [
        StaggeredListEntrance(
          children: [
            if (activeTimers.isNotEmpty) ...[
              for (final timer in activeTimers)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: _ActiveTimerBanner(entry: timer),
                ),
              const SizedBox(height: AppSpacing.s),
            ],
            _CurrentGrowthCard(entry: latestGrowth, stats: stats),
            const SizedBox(height: AppSpacing.xl),
            _QuickLogSection(),
            const SizedBox(height: AppSpacing.xl),
            _TodaysActivitySection(entries: todayEntries),
          ],
        ),
      ],
    );
  }
}

class _CurrentGrowthCard extends StatelessWidget {
  const _CurrentGrowthCard({required this.entry, required this.stats});

  final GrowthEntry? entry;
  final CareLogDailyStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return AppCard(
      onTap: () => context.go('/growth'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT GROWTH',
            style: theme.typography.label.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            entry == null
                ? 'Add your first measurement'
                : '${entry!.weightKg.toStringAsFixed(1)} kg  ·  ${entry!.heightCm.toStringAsFixed(0)} cm',
            style: theme.typography.numeralL.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: _GrowthStat(
                  label: 'SLEEP',
                  value:
                      '${stats.sleepMinutes ~/ 60}h ${stats.sleepMinutes % 60}m',
                ),
              ),
              Expanded(
                child: _GrowthStat(
                  label: 'FEEDS',
                  value: '${stats.feedCount} today',
                ),
              ),
              Expanded(
                child: _GrowthStat(
                  label: 'DIAPERS',
                  value: '${stats.diaperCount} today',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GrowthStat extends StatelessWidget {
  const _GrowthStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      padding: .symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colors.surfaceSunken.withValues(alpha: .5),
        borderRadius: .circular(10),
      
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.typography.label.copyWith(
              color: theme.colors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            value,
            style: theme.typography.subtitle.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLogSection extends StatelessWidget {
  const _QuickLogSection();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Quick Log',
              style: theme.typography.subtitle.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              'Tap to record',
              style: theme.typography.caption.copyWith(
                color: theme.colors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        Row(
          children: [
            for (final type in CareLogType.values) ...[
              if (type != CareLogType.values.first)
                const SizedBox(width: AppSpacing.m),
              Expanded(child: _QuickLogButton(type: type)),
            ],
          ],
        ),
      ],
    );
  }
}

class _QuickLogButton extends ConsumerWidget {
  const _QuickLogButton({required this.type});

  final CareLogType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final (icon, label) = careLogTypeIconLabel(type);
    final tint = careLogTypeColor(theme.colors, type);
    return TapScale(
      onTap: () => showQuickLogSheet(context, ref, type),
      borderRadius: BorderRadius.circular(AppRadii.m),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 88),
        child: AppGlassSurface(
          borderRadius: BorderRadius.circular(AppRadii.m),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.s),
                ),
                child: Icon(icon, size: 20, color: tint),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                label,
                style: theme.typography.label.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveTimerBanner extends ConsumerWidget {
  const _ActiveTimerBanner({required this.entry});

  final CareLogEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final (icon, label) = careLogTypeIconLabel(entry.type);
    final tint = careLogTypeColor(theme.colors, entry.type);
    return TapScale(
      onTap: () => showQuickLogSheet(context, ref, entry.type),
      borderRadius: BorderRadius.circular(AppRadii.m),
      child: AppGlassSurface(
        borderRadius: BorderRadius.circular(AppRadii.m),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Row(
          children: [
            Icon(icon, color: tint),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label timer running',
                    style: theme.typography.subtitle.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                  StreamBuilder<void>(
                    stream: Stream.periodic(const Duration(seconds: 30)),
                    builder: (context, _) {
                      final elapsed = DateTime.now().difference(
                        entry.startTime,
                      );
                      return Text(
                        '${elapsed.inMinutes}m elapsed',
                        style: theme.typography.caption.copyWith(
                          color: theme.colors.textSecondary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            AppStatusPill(label: 'Tap to stop', color: tint),
          ],
        ),
      ),
    );
  }
}

class _TodaysActivitySection extends StatelessWidget {
  const _TodaysActivitySection({required this.entries});

  final List<CareLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final shown = entries.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Today's Activity",
              style: theme.typography.subtitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            if (entries.isNotEmpty)
              AppStatusPill(
                label: '${entries.length} Logs',
                color: colors.primary,
              ),
            const Spacer(),
            TapScale(
              onTap: () => context.go('/care-log'),
              child: Text(
                'See all',
                style: theme.typography.label.copyWith(color: colors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        if (shown.isEmpty)
          const AppEmptyState(
            icon: LucideIcons.house,
            message: 'Nothing logged yet today — use Quick Log above.',
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.m),
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i != 0) Divider(height: 1, color: colors.hairline),
                  _ActivityRow(entry: shown[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final CareLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final (icon, label) = careLogTypeIconLabel(entry.type);
    final tint = careLogTypeColor(colors, entry.type);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
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
                    color: colors.textPrimary,
                  ),
                ),
                if (entry.summary.isNotEmpty)
                  Text(
                    entry.summary,
                    style: theme.typography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            DateFormat.jm().format(entry.startTime),
            style: theme.typography.caption.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
