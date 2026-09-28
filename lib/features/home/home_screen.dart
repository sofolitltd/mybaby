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
import '../../data/models/milestone.dart';
import '../../data/models/task.dart';
import '../../shared/care_log_type_style.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/app_status_pill.dart';
import '../../shared/widgets/care_log_entry_actions.dart';
import '../../shared/widgets/baby_switcher_sheet.dart';
import '../../shared/widgets/edit_task_sheet.dart';
import '../../shared/widgets/quick_log_sheet.dart';
import '../../shared/widgets/task_entry_actions.dart';
import '../../shared/widgets/task_row.dart';

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
    final milestonesByLabel = ref.watch(milestonesByLabelProvider).value ?? const {};
    final tasks = ref.watch(tasksProvider).value ?? const [];
    final openTasks = [for (final t in tasks) if (!t.completed) t]
      ..sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
    final latestGrowth = growth.isEmpty ? null : growth.last;
    final stats = computeDailyStats(careLog);
    // Running timers surface here regardless of when they started (a timer
    // begun yesterday and still going matters more than a same-day cutoff);
    // finished entries are scoped to today like the rest of this screen.
    final todayEntries = [
      for (final e in careLog)
        if (e.endTime == null || isToday(e.startTime)) e,
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
            const _BabySwitcherSection(),
            const SizedBox(height: AppSpacing.xl),
            _CurrentGrowthCard(entry: latestGrowth, stats: stats),
            const SizedBox(height: AppSpacing.xl),
            _QuickLogSection(),
            const SizedBox(height: AppSpacing.xl),
            _TodaysActivitySection(entries: todayEntries),
            const SizedBox(height: AppSpacing.xl),
            _TasksSection(tasks: openTasks),
            const SizedBox(height: AppSpacing.xl),
            _MilestonesCard(byLabel: milestonesByLabel),
            const SizedBox(height: AppSpacing.xl),
            _GrowthSection(entry: latestGrowth),
          ],
        ),
      ],
    );
  }
}

/// Tappable active-baby summary — avatar, name, age — opening the baby
/// switcher sheet. Moved here from the old app-bar top bar.
class _BabySwitcherSection extends ConsumerWidget {
  const _BabySwitcherSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final baby = ref.watch(activeBabyProvider);

    return TapScale(
      onTap: () => showBabySwitcherSheet(context),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BabyAvatar(
            driveFileId: baby?.avatarDriveFileId,
            emoji: baby?.avatarEmoji ?? '👶',
          ),
          const SizedBox(width: AppSpacing.s),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                baby?.name ?? '—',
                style: theme.typography.subtitle.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
              if (baby?.ageInWeeks != null)
                Text(
                  '${baby!.ageInWeeks} weeks old',
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(LucideIcons.chevron_down, size: 18),
        ],
      ),
    );
  }
}

/// 32x32 circular baby avatar — shows the Drive-backed photo once it's
/// loaded, falling back to the sex emoji while loading, on error, or when
/// no photo was ever uploaded.
class _BabyAvatar extends ConsumerWidget {
  const _BabyAvatar({required this.driveFileId, required this.emoji});

  final String? driveFileId;
  final String emoji;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppTheme.of(context).colors;
    final fileId = driveFileId;
    final bytes = fileId == null
        ? null
        : ref.watch(driveImageBytesProvider(fileId)).value;

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        shape: BoxShape.circle,
        image: bytes == null
            ? null
            : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
      child: bytes == null ? Text(emoji) : null,
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
      onTap: () => context.push('/growth'),
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

class _MilestonesCard extends StatelessWidget {
  const _MilestonesCard({required this.byLabel});

  final Map<String, Milestone> byLabel;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final achievedCount = byLabel.values.where((m) => m.achieved).length;
    final total = presetMilestoneLabels.length;
    final nextLabel = presetMilestoneLabels.firstWhere(
      (label) => byLabel[label]?.achieved != true,
      orElse: () => presetMilestoneLabels.last,
    );

    return AppCard(
      onTap: () => context.push('/milestones'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.badge_check,
              size: 20,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Milestones',
                      style: theme.typography.subtitle.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    AppStatusPill(
                      label: '$achievedCount / $total',
                      color: colors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  achievedCount == total
                      ? 'All milestones achieved'
                      : 'Next up: $nextLabel',
                  style: theme.typography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevron_right, size: 18, color: colors.textTertiary),
        ],
      ),
    );
  }
}

class _GrowthSection extends StatelessWidget {
  const _GrowthSection({required this.entry});

  final GrowthEntry? entry;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return AppCard(
      onTap: () => context.push('/growth'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.scale, size: 20, color: colors.primary),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Growth',
                  style: theme.typography.subtitle.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry == null
                      ? 'Add your first measurement'
                      : '${entry!.weightKg.toStringAsFixed(1)} kg  ·  ${entry!.heightCm.toStringAsFixed(0)} cm',
                  style: theme.typography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevron_right, size: 18, color: colors.textTertiary),
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

class _ActivityRow extends ConsumerWidget {
  const _ActivityRow({required this.entry});

  final CareLogEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final (icon, label) = careLogTypeIconLabel(entry.type);
    final tint = careLogTypeColor(colors, entry.type);
    final running = isRunningTimer(entry);

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
                if (running)
                  StreamBuilder<void>(
                    stream: Stream.periodic(const Duration(seconds: 1)),
                    builder: (context, _) {
                      final elapsed = DateTime.now().difference(
                        entry.startTime,
                      );
                      return Text(
                        formatElapsedTimer(elapsed),
                        style: theme.typography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      );
                    },
                  )
                else if (entry.summary.isNotEmpty)
                  Text(
                    entry.summary,
                    style: theme.typography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (running)
            TapScale(
              onTap: () => showQuickLogSheet(context, ref, entry.type),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: AppStatusPill(label: 'Tap to stop', color: tint),
            )
          else
            Text(
              DateFormat.jm().format(entry.startTime),
              style: theme.typography.caption.copyWith(
                color: colors.textTertiary,
              ),
            ),
          TapScale(
            onTap: () => showCareLogEntryActions(context, ref, entry),
            borderRadius: BorderRadius.circular(AppRadii.s),
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.s),
              child: Icon(
                LucideIcons.ellipsis_vertical,
                size: 18,
                color: colors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TasksSection extends ConsumerWidget {
  const _TasksSection({required this.tasks});

  final List<Task> tasks;

  Future<void> _complete(WidgetRef ref, Task task) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    await repo.toggleComplete(task.id, true);
    final notifications = ref.read(notificationServiceProvider);
    await notifications.cancelById(notifications.taskNotificationId(task.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final shown = tasks.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tasks',
              style: theme.typography.subtitle.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(width: AppSpacing.s),
            if (tasks.isNotEmpty)
              AppStatusPill(label: '${tasks.length} open', color: colors.primary),
            const Spacer(),
            TapScale(
              onTap: () {
                final repo = ref.read(taskRepositoryProvider);
                if (repo == null) return;
                showEditTaskSheet(context, ref, repo);
              },
              child: Text(
                'Add',
                style: theme.typography.label.copyWith(color: colors.primary),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            TapScale(
              onTap: () => context.go('/tasks'),
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
            icon: LucideIcons.list_checks,
            message: 'No tasks yet — add one for an errand or appointment.',
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.m),
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i != 0) Divider(height: 1, color: colors.hairline),
                  TaskRow(
                    task: shown[i],
                    onToggle: () => _complete(ref, shown[i]),
                    onTap: () {
                      final repo = ref.read(taskRepositoryProvider);
                      if (repo == null) return;
                      showEditTaskSheet(context, ref, repo, editing: shown[i]);
                    },
                    onOpenActions: () => showTaskEntryActions(context, ref, shown[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
