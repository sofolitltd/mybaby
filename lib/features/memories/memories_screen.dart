import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator, InputDecoration, OutlineInputBorder, ScaffoldMessenger, SnackBar, TextField, showDatePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/mime_utils.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/app_motion.dart';
import '../../core/theme/motion/sheet_transition.dart';
import '../../core/theme/motion/staggered_entrance.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../data/drive/drive_repository.dart';
import '../../data/models/memory.dart';
import '../../data/models/milestone.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/app_section_header.dart';
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

  Future<void> _addMemory(BuildContext context, WidgetRef ref) async {
    final memoriesRepo = ref.read(memoriesRepositoryProvider);
    if (memoriesRepo == null) return;
    final result = await showAppSheet<Memory>(
      context: context,
      builder: (context) =>
          _AddMemorySheet(driveRepository: ref.read(driveRepositoryProvider)),
    );
    if (result != null) {
      await memoriesRepo.add(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestonesAsync = ref.watch(milestonesByLabelProvider);
    final memoriesAsync = ref.watch(memoriesProvider);
    final theme = AppTheme.of(context);

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: AppSectionHeader('Milestones')),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: milestonesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => Text(
                      'Could not load milestones: $e',
                      style: theme.typography.body.copyWith(
                        color: theme.colors.textSecondary,
                      ),
                    ),
                    data: (byLabel) => ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: presetMilestoneLabels.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.s),
                      itemBuilder: (context, i) {
                        final label = presetMilestoneLabels[i];
                        final milestone = byLabel[label];
                        final achieved = milestone?.achieved == true;
                        return _MilestoneChip(
                          label: label,
                          achieved: achieved,
                          onTap: () => _toggleMilestone(ref, milestone, label),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: AppSectionHeader('Memories')),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.l,
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
          right: AppSpacing.l,
          bottom: AppSpacing.l,
          child: AppButton(
            onPressed: () => _addMemory(context, ref),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.plus, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Add memory',
                  style: theme.typography.label.copyWith(
                    color: theme.colors.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MilestoneChip extends StatelessWidget {
  const _MilestoneChip({
    required this.label,
    required this.achieved,
    required this.onTap,
  });

  final String label;
  final bool achieved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (achieved) ...[
            Icon(LucideIcons.check, size: 14, color: colors.textPrimary),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: theme.typography.label.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );

    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        curve: AppMotion.curveStandard,
        decoration: BoxDecoration(
          color: achieved ? colors.surface : null,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: achieved
            ? content
            : AppGlassSurface(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                shadows: null,
                padding: EdgeInsets.zero,
                child: content,
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
    final fileId = memory.driveFileId;
    final isImage = fileId != null && isImageMimeType(memory.mimeType ?? '');

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.m),
              ),
              child: DriveImage(fileId: fileId),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memory.caption,
                  style: theme.typography.subtitle.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  DateFormat.yMMMd().format(memory.date),
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
                if (fileId != null && !isImage) ...[
                  const SizedBox(height: AppSpacing.s),
                  TapScale(
                    onTap: () => launchUrl(
                      Uri.parse(
                        'https://drive.google.com/file/d/$fileId/view',
                      ),
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.s),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.paperclip,
                          size: 16,
                          color: theme.colors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'View attachment in Drive',
                          style: theme.typography.caption.copyWith(
                            color: theme.colors.primary,
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

class _AddMemorySheet extends StatefulWidget {
  const _AddMemorySheet({required this.driveRepository});

  final DriveRepository driveRepository;

  @override
  State<_AddMemorySheet> createState() => _AddMemorySheetState();
}

class _AddMemorySheetState extends State<_AddMemorySheet> {
  final _captionController = TextEditingController();
  DateTime _date = DateTime.now();
  PlatformFile? _attachment;
  bool _saving = false;

  bool get _canSave => _captionController.text.trim().isNotEmpty && !_saving;

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _attachment = result.files.first);
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      String? driveFileId;
      String? mimeType;
      final attachment = _attachment;
      if (attachment != null && attachment.bytes != null) {
        mimeType = guessMimeType(attachment.name);
        final folderId = await widget.driveRepository.ensureAppFolder();
        driveFileId = await widget.driveRepository.uploadBytes(
          bytes: attachment.bytes!,
          filename: attachment.name,
          mimeType: mimeType,
          folderId: folderId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        Memory(
          id: '',
          date: _date,
          caption: _captionController.text.trim(),
          driveFileId: driveFileId,
          mimeType: mimeType,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not attach file: $e')));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.l,
        AppSpacing.xxl,
        AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add memory',
            style: theme.typography.title.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          TextField(
            controller: _captionController,
            style: theme.typography.body.copyWith(
              color: theme.colors.textPrimary,
            ),
            cursorColor: theme.colors.primary,
            decoration: InputDecoration(
              labelText: 'What happened?',
              labelStyle: theme.typography.body.copyWith(
                color: theme.colors.textSecondary,
              ),
              filled: true,
              fillColor: theme.colors.surfaceSunken,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.m,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.s),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.m),
          _DateField(date: _date, onTap: _pickDate),
          const SizedBox(height: AppSpacing.m),
          AppButton(
            variant: AppButtonVariant.secondary,
            onPressed: _pickAttachment,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.paperclip,
                  size: 18,
                  color: theme.colors.textPrimary,
                ),
                const SizedBox(width: AppSpacing.s),
                Flexible(
                  child: Text(
                    _attachment == null
                        ? 'Attach a photo or file'
                        : _attachment!.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.label.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colors.onPrimary,
                    ),
                  )
                : Text(
                    'Save',
                    style: theme.typography.label.copyWith(
                      color: theme.colors.onPrimary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.s),
      child: AppGlassSurface(
        borderRadius: BorderRadius.circular(AppRadii.s),
        shadows: null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.calendar,
              size: 18,
              color: theme.colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s),
            Text(
              DateFormat.yMMMd().format(date),
              style: theme.typography.body.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
