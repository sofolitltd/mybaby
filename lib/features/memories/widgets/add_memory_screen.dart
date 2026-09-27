import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/material.dart'
    show
        InputDecoration,
        InputDecorator,
        OutlineInputBorder,
        ScaffoldMessenger,
        SnackBar,
        Switch,
        TextField,
        TimeOfDay,
        showDatePicker,
        showTimePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/mime_utils.dart';
import '../../../core/picked_file.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion/tap_scale.dart';
import '../../../data/models/memory.dart';
import '../../../data/models/milestone.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../babies/widgets/baby_screen_header.dart';

const _maxMedia = 6;

const _quickTitleIdeas = [
  'First Smile',
  'Bath time splash',
  'Morning cuddle',
  'Sleeping peacefully',
];

const _categories = [
  (label: 'Milestone', icon: LucideIcons.sparkles),
  (label: 'Outdoor & Play', icon: LucideIcons.trees),
  (label: 'Daily Routine', icon: LucideIcons.clock),
  (label: 'Family & Friends', icon: LucideIcons.users),
  (label: 'Sleepy Moment', icon: LucideIcons.moon),
];

const _moods = [
  'Pure Joy',
  'Sleepy',
  'Curious',
  'Well Fed',
  'Calm',
  'Wondrous',
];

/// Full-screen "Add Memory" flow, replacing the old add-memory bottom sheet
/// — styled after the Stitch mock. Only the fields the current `Memory`
/// model/schema support are wired to Firestore (title, story, photos/clips,
/// linked milestone, mood + category tags, date, location); the mock's
/// Family Circle / Keepsake Book sharing toggles and the weather auto-tag
/// and audio-note capture are rendered for visual parity but disabled —
/// v1 has no co-parent/shared-account support (see CLAUDE.md) and there's
/// no weather API or audio-recording package wired into the app.
class AddMemoryScreen extends ConsumerStatefulWidget {
  const AddMemoryScreen({super.key});

  @override
  ConsumerState<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends ConsumerState<AddMemoryScreen> {
  final _titleController = TextEditingController();
  final _storyController = TextEditingController();
  final _locationController = TextEditingController();

  final List<PickedFile> _media = [];
  DateTime _dateTime = DateTime.now();
  String? _category;
  String? _milestoneLabel;
  final Set<String> _moodSelection = {};
  bool _saving = false;

  bool get _canSave => _titleController.text.trim().isNotEmpty && !_saving;

  @override
  void dispose() {
    _titleController.dispose();
    _storyController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon')));
  }

  Future<void> _pickMedia() async {
    final remaining = _maxMedia - _media.length;
    if (remaining <= 0) return;
    final files = await pickMultipleFiles(type: FileType.media);
    setState(() {
      _media.addAll(files.take(remaining));
    });
  }

  void _removeMedia(PickedFile file) {
    setState(() => _media.remove(file));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final memoriesRepo = ref.read(memoriesRepositoryProvider);
    if (memoriesRepo == null) return;
    setState(() => _saving = true);
    try {
      final driveFileIds = <String>[];
      final mimeTypes = <String>[];
      if (_media.isNotEmpty) {
        final drive = ref.read(driveRepositoryProvider);
        final folderId = await drive.ensureAppFolder();
        for (final file in _media) {
          final mimeType = guessMimeType(file.name);
          final fileId = await drive.uploadBytes(
            bytes: file.bytes,
            filename: file.name,
            mimeType: mimeType,
            folderId: folderId,
          );
          driveFileIds.add(fileId);
          mimeTypes.add(mimeType);
        }
      }
      final tags = [?_category, ..._moodSelection];
      await memoriesRepo.add(
        Memory(
          id: '',
          date: _dateTime,
          title: _titleController.text.trim(),
          caption: _storyController.text.trim(),
          mediaDriveFileIds: driveFileIds,
          mediaMimeTypes: mimeTypes,
          milestoneLabel: _category == 'Milestone' ? _milestoneLabel : null,
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          tags: tags,
        ),
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save memory: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final baby = ref.watch(activeBabyProvider);

    String? ageAtMemory;
    if (baby != null) {
      final days = _dateTime.difference(baby.dob).inDays;
      if (days >= 0) {
        final weeks = days ~/ 7;
        final remDays = days % 7;
        ageAtMemory = 'Exact age: $weeks weeks and $remDays days';
      }
    }

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BabyScreenHeader(title: 'Add Memory'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  0,
                  AppSpacing.l,
                  AppSpacing.l,
                ),
                children: [
                  _FormSection(
                    icon: LucideIcons.image,
                    title: 'Photos & Video Clips',
                    trailing: Text(
                      '${_media.length} of $_maxMedia added',
                      style: theme.typography.label.copyWith(
                        color: theme.colors.textTertiary,
                      ),
                    ),
                    child: _MediaPicker(
                      media: _media,
                      onAdd: _pickMedia,
                      onRemove: _removeMedia,
                      onCamera: () => _showComingSoon('Camera capture'),
                      onRecordClip: () => _showComingSoon('Video recording'),
                    ),
                  ),
                  _FormSection(
                    icon: LucideIcons.pencil_line,
                    title: 'Memory Title',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _titleController,
                          style: theme.typography.body.copyWith(
                            color: theme.colors.textPrimary,
                          ),
                          decoration: _fieldDecoration(
                            context,
                            'e.g. First real giggle in the morning light',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: AppSpacing.s),
                        Text(
                          'Quick ideas',
                          style: theme.typography.label.copyWith(
                            color: theme.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final idea in _quickTitleIdeas)
                              AppChip(
                                label: '+ $idea',
                                selected: _titleController.text.trim() == idea,
                                onTap: () {
                                  _titleController.text = idea;
                                  setState(() {});
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _FormSection(
                    icon: LucideIcons.book_open,
                    title: 'The Story & Tiny Details',
                    trailing: TapScale(
                      onTap: () => _showComingSoon('Audio note'),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Icon(
                          LucideIcons.mic,
                          size: 16,
                          color: theme.colors.textTertiary,
                        ),
                      ),
                    ),
                    child: TextField(
                      controller: _storyController,
                      minLines: 4,
                      maxLines: 8,
                      style: theme.typography.body.copyWith(
                        color: theme.colors.textPrimary,
                      ),
                      decoration: _fieldDecoration(
                        context,
                        'What made this moment special?',
                      ),
                    ),
                  ),
                  _FormSection(
                    icon: LucideIcons.tag,
                    title: 'Category & Milestone',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final category in _categories)
                              AppChip(
                                label: category.label,
                                icon: category.icon,
                                selected: _category == category.label,
                                onTap: () => setState(() {
                                  _category = _category == category.label
                                      ? null
                                      : category.label;
                                }),
                              ),
                          ],
                        ),
                        if (_category == 'Milestone') ...[
                          const SizedBox(height: AppSpacing.m),
                          Text(
                            'Linked developmental milestone',
                            style: theme.typography.label.copyWith(
                              color: theme.colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final label in presetMilestoneLabels)
                                AppChip(
                                  label: label,
                                  selected: _milestoneLabel == label,
                                  onTap: () => setState(() {
                                    _milestoneLabel = _milestoneLabel == label
                                        ? null
                                        : label;
                                  }),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  _FormSection(
                    icon: LucideIcons.face_grinning,
                    title: "Baby's Mood",
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final mood in _moods)
                          AppChip(
                            label: mood,
                            selected: _moodSelection.contains(mood),
                            onTap: () => setState(() {
                              if (!_moodSelection.remove(mood)) {
                                _moodSelection.add(mood);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  _FormSection(
                    icon: LucideIcons.map_pin,
                    title: 'Time & Surroundings',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TapScale(
                          onTap: _pickDateTime,
                          borderRadius: BorderRadius.circular(AppRadii.s),
                          child: InputDecorator(
                            decoration: _fieldDecoration(context, 'Date & time'),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.calendar,
                                  size: 18,
                                  color: theme.colors.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.s),
                                Expanded(
                                  child: Text(
                                    DateFormat.yMMMd().add_jm().format(
                                      _dateTime,
                                    ),
                                    style: theme.typography.body.copyWith(
                                      color: theme.colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (ageAtMemory != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            ageAtMemory,
                            style: theme.typography.caption.copyWith(
                              color: theme.colors.primary,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.m),
                        TextField(
                          controller: _locationController,
                          style: theme.typography.body.copyWith(
                            color: theme.colors.textPrimary,
                          ),
                          decoration: _fieldDecoration(
                            context,
                            'Location (optional)',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.m),
                        Row(
                          children: [
                            Icon(
                              LucideIcons.cloud_sun,
                              size: 18,
                              color: theme.colors.textTertiary,
                            ),
                            const SizedBox(width: AppSpacing.s),
                            Expanded(
                              child: Text(
                                'Weather auto-tag — coming soon',
                                style: theme.typography.caption.copyWith(
                                  color: theme.colors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _FormSection(
                    icon: LucideIcons.heart_handshake,
                    title: 'Sharing & Keepsake',
                    child: Column(
                      children: [
                        _DisabledToggleRow(
                          icon: LucideIcons.users,
                          title: 'Family Circle',
                          subtitle:
                              'Coming soon — shared/co-parent accounts aren\'t supported yet',
                        ),
                        const SizedBox(height: AppSpacing.m),
                        _DisabledToggleRow(
                          icon: LucideIcons.book_heart,
                          title: 'Baby Keepsake Book',
                          subtitle: 'Coming soon — queue this for a printed album',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.s,
                  AppSpacing.l,
                  AppSpacing.l,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        onPressed: _canSave ? _save : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.circle_check,
                              size: 18,
                              color: theme.colors.onPrimary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Save Memory',
                              style: theme.typography.label.copyWith(
                                color: theme.colors.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TapScale(
                          onTap: () => _showComingSoon('Saving as a draft'),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            child: Text(
                              'Save as Draft',
                              style: theme.typography.label.copyWith(
                                color: theme.colors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '  •  ',
                          style: theme.typography.label.copyWith(
                            color: theme.colors.textTertiary,
                          ),
                        ),
                        TapScale(
                          onTap: () => context.pop(),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            child: Text(
                              'Discard',
                              style: theme.typography.label.copyWith(
                                color: theme.colors.status.overdue,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section container — icon + title heading above a card, matching the
/// pattern in `add_health_record_screen.dart`'s `_FormSection`.
class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colors.textPrimary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: theme.typography.subtitle.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          AppCard(child: child),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration(BuildContext context, String label) {
  final theme = AppTheme.of(context);
  return InputDecoration(
    labelText: label,
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
  );
}

class _MediaPicker extends StatelessWidget {
  const _MediaPicker({
    required this.media,
    required this.onAdd,
    required this.onRemove,
    required this.onCamera,
    required this.onRecordClip,
  });

  final List<PickedFile> media;
  final VoidCallback onAdd;
  final ValueChanged<PickedFile> onRemove;
  final VoidCallback onCamera;
  final VoidCallback onRecordClip;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < media.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s),
                  child: _MediaThumbnail(
                    file: media[i],
                    isCover: i == 0,
                    onRemove: () => onRemove(media[i]),
                  ),
                ),
              if (media.length < _maxMedia)
                TapScale(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(AppRadii.s),
                  child: Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(AppRadii.s),
                      border: Border.all(color: colors.hairline),
                    ),
                    child: Icon(
                      LucideIcons.plus,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        Row(
          children: [
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.secondary,
                onPressed: onCamera,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.camera,
                      size: 16,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Open Camera',
                      style: theme.typography.label.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.secondary,
                onPressed: onRecordClip,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.video,
                      size: 16,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Record Clip',
                      style: theme.typography.label.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({
    required this.file,
    required this.isCover,
    required this.onRemove,
  });

  final PickedFile file;
  final bool isCover;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final mimeType = guessMimeType(file.name);
    final isImage = isImageMimeType(mimeType);

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.s),
            child: SizedBox(
              width: 96,
              height: 96,
              child: isImage
                  ? Image.memory(file.bytes, fit: BoxFit.cover)
                  : Container(
                      color: colors.surfaceSunken,
                      alignment: Alignment.center,
                      child: Icon(
                        isVideoMimeType(mimeType)
                            ? LucideIcons.video
                            : LucideIcons.file,
                        color: colors.textSecondary,
                      ),
                    ),
            ),
          ),
          if (isCover)
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(AppRadii.s),
                ),
                child: Text(
                  'Cover',
                  style: theme.typography.label.copyWith(
                    color: colors.onPrimary,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.xs,
            child: TapScale(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xCC000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.x,
                  size: 12,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A visually-disabled sharing/keepsake toggle row — the switch is inert
/// (`onChanged: null`) since neither feature exists yet (see class doc on
/// [AddMemoryScreen]).
class _DisabledToggleRow extends StatelessWidget {
  const _DisabledToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.textTertiary),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.typography.body.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: theme.typography.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Switch(value: false, onChanged: null),
      ],
    );
  }
}
