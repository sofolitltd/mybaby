import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion/staggered_entrance.dart';
import '../../../data/models/milestone.dart';
import '../../../features/babies/widgets/baby_screen_header.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_status_pill.dart';

/// Full milestones list, promoted from a Memories sub-section to its own
/// page — see docs/UX.md "Memories" for why milestones now live behind
/// Home's "See all" rather than the Memories tab itself.
class MilestonesScreen extends ConsumerWidget {
  const MilestonesScreen({super.key});

  Future<void> _toggle(WidgetRef ref, Milestone? current, String label) async {
    final repo = ref.read(milestonesRepositoryProvider);
    if (repo == null) return;
    await repo.setAchieved(
      label,
      current?.achieved == true ? null : DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final milestonesAsync = ref.watch(milestonesByLabelProvider);

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            BabyScreenHeader(
              title: 'Milestones',
              trailing: milestonesAsync.maybeWhen(
                data: (byLabel) => AppStatusPill(
                  label:
                      '${byLabel.values.where((m) => m.achieved).length} / ${presetMilestoneLabels.length}',
                  color: colors.primary,
                ),
                orElse: () => null,
              ),
            ),
            Expanded(
              child: milestonesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'Could not load milestones: $e',
                    style: theme.typography.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                data: (byLabel) {
                  if (presetMilestoneLabels.isEmpty) {
                    return const AppEmptyState(
                      icon: LucideIcons.badge_check,
                      message: 'No milestones yet.',
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.xxxl,
                    ),
                    children: [
                      StaggeredListEntrance(
                        children: [
                          for (final label in presetMilestoneLabels)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.m,
                              ),
                              child: _MilestoneRow(
                                label: label,
                                achievedDate: byLabel[label]?.achievedDate,
                                onTap: () => _toggle(ref, byLabel[label], label),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.label,
    required this.achievedDate,
    required this.onTap,
  });

  final String label;
  final DateTime? achievedDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final achieved = achievedDate != null;
    final tint = achieved ? colors.primary : colors.textTertiary;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: achieved
                  ? colors.primary.withValues(alpha: 0.14)
                  : colors.surfaceSunken,
              shape: BoxShape.circle,
            ),
            child: Icon(
              achieved ? LucideIcons.check : LucideIcons.circle_dashed,
              size: 20,
              color: tint,
            ),
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
                const SizedBox(height: 2),
                Text(
                  achieved
                      ? 'Achieved ${DateFormat.yMMMd().format(achievedDate!)}'
                      : 'Not yet achieved',
                  style: theme.typography.caption.copyWith(
                    color: achieved ? colors.primary : colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            achieved ? LucideIcons.badge_check : LucideIcons.circle,
            size: 20,
            color: achieved ? colors.primary : colors.textTertiary,
          ),
        ],
      ),
    );
  }
}
