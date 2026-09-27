import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/staggered_entrance.dart';
import '../../data/models/care_log_entry.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_section_header.dart';

bool _isToday(DateTime time) {
  final now = DateTime.now();
  return time.year == now.year &&
      time.month == now.month &&
      time.day == now.day;
}

class CareLogScreen extends ConsumerWidget {
  const CareLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final entriesAsync = ref.watch(careLogProvider);

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Could not load care log: $e',
          style: theme.typography.body.copyWith(color: theme.colors.textSecondary),
        ),
      ),
      data: (entries) {
        final today = entries.where((e) => _isToday(e.startTime)).toList();
        final feeds = today.where((e) => e.type == CareLogType.feed).length;
        final diapers = today
            .where((e) => e.type == CareLogType.diaper)
            .length;
        final sleepMinutes = today
            .where((e) => e.type == CareLogType.sleep)
            .fold<int>(0, (sum, e) => sum + (e.duration?.inMinutes ?? 0));

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.l,
            AppSpacing.xl,
            96,
          ),
          children: [
            AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatItem(
                    label: 'Sleep',
                    value: '${sleepMinutes ~/ 60}h ${sleepMinutes % 60}m',
                  ),
                  _StatItem(label: 'Feeds', value: '$feeds today'),
                  _StatItem(label: 'Diapers', value: '$diapers today'),
                ],
              ),
            ),
            const AppSectionHeader('Today'),
            if (today.isEmpty)
              const AppEmptyState(
                icon: LucideIcons.list_checks,
                message:
                    'Nothing logged yet today — use the quick-log buttons on Home.',
              )
            else
              StaggeredListEntrance(
                children: [
                  for (final entry in today)
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

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.typography.numeralL.copyWith(
            color: theme.colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs / 2),
        Text(
          label,
          style: theme.typography.caption.copyWith(
            color: theme.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CareLogTile extends StatelessWidget {
  const _CareLogTile({required this.entry});

  final CareLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final (icon, label) = switch (entry.type) {
      CareLogType.feed => (LucideIcons.milk, 'Feed'),
      CareLogType.sleep => (LucideIcons.moon, 'Sleep'),
      CareLogType.diaper => (LucideIcons.baby, 'Diaper'),
    };
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colors.surfaceSunken,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: theme.colors.textPrimary),
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
