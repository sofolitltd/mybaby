import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/mime_utils.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/staggered_entrance.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../data/models/memory.dart';
import '../../data/models/milestone.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_extended_fab.dart';
import '../../shared/widgets/drive_image.dart';

class MemoriesScreen extends ConsumerWidget {
  const MemoriesScreen({super.key});

  Future<void> _toggleMilestone(
    WidgetRef ref,
    Milestone? current,
    String label,
  ) async {
    final repo = ref.read(milestonesRepositoryProvider);
    if (repo == null) return;
    await repo.setAchieved(
      label,
      current?.achieved == true ? null : DateTime.now(),
    );
  }

  void _addMemory(BuildContext context) => context.push('/add-memory');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestonesAsync = ref.watch(milestonesByLabelProvider);
    final memoriesAsync = ref.watch(memoriesProvider);
    final theme = AppTheme.of(context);

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.l,
                AppSpacing.l,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: milestonesAsync.when(
                  loading: () => Text(
                    'Milestones',
                    style: theme.typography.subtitle.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                  error: (e, _) => Text(
                    'Milestones',
                    style: theme.typography.subtitle.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                  data: (byLabel) {
                    final achievedCount = byLabel.values
                        .where((m) => m.achieved)
                        .length;
                    return Row(
                      children: [
                        Text(
                          'Milestones',
                          style: theme.typography.subtitle.copyWith(
                            color: theme.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        _CountBadge(label: '$achievedCount Achieved'),
                      ],
                    );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(
                top: AppSpacing.m,
                bottom: AppSpacing.l,
              ),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 128,
                  child: milestonesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.l,
                      ),
                      child: Text(
                        'Could not load milestones: $e',
                        style: theme.typography.body.copyWith(
                          color: theme.colors.textSecondary,
                        ),
                      ),
                    ),
                    data: (byLabel) => ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.l,
                      ),
                      itemCount: presetMilestoneLabels.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.m),
                      itemBuilder: (context, index) {
                        final label = presetMilestoneLabels[index];
                        final milestone = byLabel[label];
                        return _MilestoneCard(
                          label: label,
                          achievedDate: milestone?.achievedDate,
                          onTap: () => _toggleMilestone(ref, milestone, label),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                0,
                AppSpacing.l,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Memories',
                            style: theme.typography.subtitle.copyWith(
                              color: theme.colors.textPrimary,
                            ),
                          ),
                          memoriesAsync.maybeWhen(
                            data: (memories) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                memories.length == 1
                                    ? '1 moment'
                                    : '${memories.length} moments',
                                style: theme.typography.caption.copyWith(
                                  color: theme.colors.textSecondary,
                                ),
                              ),
                            ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    _NewEntryButton(onTap: () => _addMemory(context)),
                  ],
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(top: AppSpacing.m)),
            memoriesAsync.when(
              loading: () => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: theme.colors.primary,
                    ),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'Could not load memories: $e',
                    style: theme.typography.body.copyWith(
                      color: theme.colors.textSecondary,
                    ),
                  ),
                ),
              ),
              data: (memories) {
                if (memories.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: AppEmptyState(
                      icon: LucideIcons.book_open,
                      message: 'No memories yet — add your first one.',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  sliver: SliverList.list(
                    children: [
                      StaggeredListEntrance(
                        children: [
                          for (final memory in memories)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.m,
                              ),
                              child: _MemoryCard(memory: memory),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SliverPadding(
              padding: EdgeInsets.only(bottom: AppSpacing.xxxl),
            ),
          ],
        ),
        Positioned(
          right: AppSpacing.xl,
          bottom: AppSpacing.l,
          child: AppExtendedFab(
            icon: LucideIcons.camera,
            label: 'Capture Memory',
            onTap: () => _addMemory(context),
          ),
        ),
      ],
    );
  }
}

/// Small pill next to a section heading, e.g. "3 Achieved".
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: theme.typography.label.copyWith(color: colors.primary),
      ),
    );
  }
}

/// Standalone milestone card for the horizontal scroller — icon badge,
/// label, and either the achieved date or a "Not yet" placeholder. Replaces
/// the old boxed grid of tiles with cards that read like the rest of the
/// app's horizontally-scrolling summary rows (see Home's growth/milestone
/// strips).
class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
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

    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.m),
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(AppSpacing.m),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadii.m),
          border: Border.all(
            color: achieved
                ? colors.primary.withValues(alpha: 0.3)
                : colors.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: achieved
                        ? colors.primary.withValues(alpha: 0.14)
                        : colors.surfaceSunken,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    achieved ? LucideIcons.check : LucideIcons.circle_dashed,
                    size: 18,
                    color: tint,
                  ),
                ),
                if (achieved)
                  Icon(
                    LucideIcons.badge_check,
                    size: 16,
                    color: colors.primary,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              achieved ? DateFormat.MMMd().format(achievedDate!) : 'Not yet',
              style: theme.typography.label.copyWith(
                color: achieved ? colors.primary : colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewEntryButton extends StatelessWidget {
  const _NewEntryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colors.primary,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.plus, size: 14, color: theme.colors.onPrimary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'New Entry',
              style: theme.typography.label.copyWith(
                color: theme.colors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.memory});

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final fileId = memory.mediaDriveFileIds.firstOrNull;
    final fileMime = memory.mediaMimeTypes.firstOrNull ?? '';
    final isImage = fileId != null && isImageMimeType(fileMime);
    final heading = memory.title.isNotEmpty ? memory.title : memory.caption;
    final chips = [
      if (memory.milestoneLabel != null) memory.milestoneLabel!,
      ...memory.tags,
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadii.m),
                  ),
                  child: DriveImage(fileId: fileId, height: 220),
                ),
                if (chips.isNotEmpty)
                  Positioned(
                    top: AppSpacing.m,
                    left: AppSpacing.m,
                    right: AppSpacing.m,
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final chip in chips) _MemoryTagChip(label: chip),
                      ],
                    ),
                  ),
              ],
            )
          else if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.l,
                AppSpacing.l,
                0,
              ),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final chip in chips) _MemoryTagChip(label: chip),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        heading,
                        style: theme.typography.subtitle.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      DateFormat.MMMd().format(memory.date),
                      style: theme.typography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (memory.title.isNotEmpty && memory.caption.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    memory.caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                if (memory.location != null && memory.location!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.map_pin,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          memory.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (memory.mediaDriveFileIds.length > 1) ...[
                  const SizedBox(height: AppSpacing.s),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.images,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '+${memory.mediaDriveFileIds.length - 1} more attachment${memory.mediaDriveFileIds.length > 2 ? 's' : ''}',
                        style: theme.typography.caption.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (fileId != null && !isImage) ...[
                  const SizedBox(height: AppSpacing.s),
                  TapScale(
                    onTap: () => launchUrl(
                      Uri.parse('https://drive.google.com/file/d/$fileId/view'),
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.s),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.paperclip,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'View attachment in Drive',
                          style: theme.typography.caption.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small translucent pill for a memory's tags/milestone label, laid over
/// the photo like the reference mockup's "Outdoor" / "Milestone" badges.
class _MemoryTagChip extends StatelessWidget {
  const _MemoryTagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xCC1F2937),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: theme.typography.label.copyWith(color: const Color(0xFFFFFFFF)),
      ),
    );
  }
}
