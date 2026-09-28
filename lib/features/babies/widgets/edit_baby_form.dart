import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/material.dart'
    show
        CircularProgressIndicator,
        OutlineInputBorder,
        TextField,
        TextEditingController,
        InputDecoration,
        showDatePicker;
import 'package:flutter/services.dart' show TextCapitalization;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/picked_file.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion/app_motion.dart';
import '../../../core/theme/motion/tap_scale.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_section_header.dart';

/// Result of a filled-out [EditBabyForm].
typedef EditBabyFormResult = ({
  String name,
  DateTime dob,
  String? sex,
  PickedFile? photo,
});

/// "Edit Baby" form — mirrors [AddBabyForm]'s visual language (card
/// sections, borderless fields, gender chips, circular photo picker) but
/// scoped to what editing an existing profile needs: no expecting/due-date
/// toggle, no time of birth, and no birth-measurements section, since those
/// only make sense at intake time.
class EditBabyForm extends ConsumerStatefulWidget {
  const EditBabyForm({
    super.key,
    required this.onSubmit,
    required this.submitting,
    this.initialName,
    this.initialDob,
    this.initialSex,
    this.initialAvatarDriveFileId,
  });

  final Future<void> Function(EditBabyFormResult result) onSubmit;
  final bool submitting;
  final String? initialName;
  final DateTime? initialDob;
  final String? initialSex;
  final String? initialAvatarDriveFileId;

  @override
  ConsumerState<EditBabyForm> createState() => _EditBabyFormState();
}

class _EditBabyFormState extends ConsumerState<EditBabyForm> {
  late final _nameController = TextEditingController(
    text: widget.initialName ?? '',
  );
  late String? _sex = widget.initialSex;
  late DateTime? _dob = widget.initialDob;
  PickedFile? _photo;

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _dob != null &&
      !widget.submitting;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await pickSingleFile(type: FileType.image);
    if (file != null) setState(() => _photo = file);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 365 * 6));
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? now,
      firstDate: firstDate,
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _submit() {
    if (!_canSubmit) return;
    widget.onSubmit((
      name: _nameController.text.trim(),
      dob: _dob!,
      sex: _sex,
      photo: _photo,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.xxl,
      ),
      children: [
        const SizedBox(height: AppSpacing.m),
        Text(
          "Update ${widget.initialName ?? "baby"}'s profile",
          textAlign: TextAlign.center,
          style: theme.typography.title.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Keep name, photo, and birth details up to date.',
          textAlign: TextAlign.center,
          style: theme.typography.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: _PhotoPicker(
            photo: _photo,
            existingAvatarDriveFileId: widget.initialAvatarDriveFileId,
            onTap: _pickPhoto,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        const AppMutedSectionHeader("Baby's Details"),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: theme.typography.body.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: _fieldDecoration(theme, label: "Baby's Full Name"),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                'Gender',
                style: theme.typography.label.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              _GenderPicker(
                value: _sex,
                onChanged: (s) => setState(() => _sex = s),
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                'Date of Birth',
                style: theme.typography.label.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              _DateField(dob: _dob, onTap: _pickDob),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          onPressed: _canSubmit ? _submit : null,
          child: widget.submitting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onPrimary,
                  ),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration(AppTheme theme, {required String label}) {
  final colors = theme.colors;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.s),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    labelText: label,
    labelStyle: theme.typography.body.copyWith(color: colors.textSecondary),
    filled: true,
    fillColor: colors.surfaceSunken,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    ),
  );
}

class _PhotoPicker extends ConsumerWidget {
  const _PhotoPicker({
    required this.photo,
    required this.existingAvatarDriveFileId,
    required this.onTap,
  });

  final PickedFile? photo;
  final String? existingAvatarDriveFileId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppTheme.of(context).colors;

    Widget? image;
    if (photo != null) {
      image = Image.memory(photo!.bytes, fit: BoxFit.cover);
    } else if (existingAvatarDriveFileId != null) {
      final bytes = ref
          .watch(driveImageBytesProvider(existingAvatarDriveFileId!))
          .value;
      if (bytes != null) {
        image = Image.memory(bytes, fit: BoxFit.cover);
      }
    }

    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceSunken,
              border: Border.all(color: colors.hairline),
            ),
            clipBehavior: Clip.antiAlias,
            child:
                image ??
                Icon(LucideIcons.baby, size: 36, color: colors.textTertiary),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary,
                border: Border.all(color: colors.background, width: 2),
              ),
              child: Icon(
                LucideIcons.camera,
                size: 15,
                color: colors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _GenderOption = ({String value, IconData icon, String label});

class _GenderPicker extends StatelessWidget {
  const _GenderPicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  static const _options = [
    (value: 'Girl', icon: LucideIcons.venus, label: 'Girl'),
    (value: 'Boy', icon: LucideIcons.mars, label: 'Boy'),
    (value: 'Surprise', icon: LucideIcons.sparkles, label: 'Surprise'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final _GenderOption option in _options) ...[
          Expanded(
            child: _GenderChip(
              icon: option.icon,
              label: option.label,
              selected: option.value == value,
              onTap: () =>
                  onChanged(option.value == value ? null : option.value),
            ),
          ),
          if (option != _options.last) const SizedBox(width: AppSpacing.s),
        ],
      ],
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final color = selected ? colors.primary : colors.textSecondary;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        curve: AppMotion.curveStandard,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.12)
              : colors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: theme.typography.label.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.dob, required this.onTap});

  final DateTime? dob;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.s),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadii.s),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.calendar, size: 18, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.m),
            Text(
              dob == null
                  ? 'Select a date'
                  : DateFormat('dd/MM/yyyy').format(dob!),
              style: theme.typography.body.copyWith(
                color: dob == null ? colors.textSecondary : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
