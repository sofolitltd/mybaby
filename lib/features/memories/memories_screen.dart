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
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_extended_fab.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_status_pill.dart';
import '../../shared/widgets/drive_image.dart';
import '../../shared/widgets/memory_actions.dart';
import '../babies/widgets/baby_screen_header.dart';

class MemoriesScreen extends ConsumerWidget {
  const MemoriesScreen({super.key});

  void _addMemory(BuildContext context) => context.push('/add-memory');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoriesAsync = ref.watch(memoriesProvider);
    final theme = AppTheme.of(context);

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            BabyScreenHeader(
              title: 'Memories',
              showBackButton: false,
              trailing: memoriesAsync.maybeWhen(
                data: (memories) => AppStatusPill(
                  label: memories.length == 1
                      ? '1 moment'
                      : '${memories.length} moments',
                  color: theme.colors.primary,
                ),
                orElse: () => null,
              ),
            ),
            Expanded(
              child: _MemoriesList(
                memoriesAsync: memoriesAsync,
                onAddMemory: () => _addMemory(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoriesList extends ConsumerWidget {
  const _MemoriesList({required this.memoriesAsync, required this.onAddMemory});

  final AsyncValue<List<Memory>> memoriesAsync;
  final VoidCallback onAddMemory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            const SliverPadding(padding: EdgeInsets.only(top: AppSpacing.s)),
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
                  return const SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    sliver: SliverToBoxAdapter(
                      child: AppEmptyState(
                        icon: LucideIcons.book_open,
                        message: 'No memories yet — add your first one.',
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  sliver: SliverList.list(
                    children: [
                      StaggeredListEntrance(
                        children: [
                          for (final memory in memories)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.m,
                              ),
                              child: _MemoryCard(
                                memory: memory,
                                onMore: () =>
                                    showMemoryActions(context, ref, memory),
                              ),
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
            onTap: onAddMemory,
          ),
        ),
      ],
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.memory, required this.onMore});

  final Memory memory;
  final VoidCallback onMore;

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
                    const SizedBox(width: AppSpacing.xs),
                    TapScale(
                      onTap: onMore,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          LucideIcons.ellipsis_vertical,
                          size: 18,
                          color: colors.textTertiary,
                        ),
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
