import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart'
    show
        CircularProgressIndicator,
        OutlineInputBorder,
        TextField,
        InputDecoration,
        showDatePicker;
import 'package:flutter/services.dart' show TextCapitalization;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/app_motion.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../shared/widgets/app_button.dart';

/// Shared name + DOB (+ optional sex) form used by onboarding's "add first
/// baby" step and the "add another baby" screen. See docs/UX.md
/// "Onboarding": only name + DOB are required, everything else skippable.
class BabyForm extends StatefulWidget {
  const BabyForm({
    super.key,
    required this.onSubmit,
    required this.submitting,
    required this.submitLabel,
    this.title,
    this.subtitle,
    this.initialName,
    this.initialDob,
    this.initialSex,
  });

  final Future<void> Function({
    required String name,
    required DateTime dob,
    String? sex,
    PlatformFile? photo,
  })
  onSubmit;
  final bool submitting;
  final String submitLabel;
  final String? title;
  final String? subtitle;
  final String? initialName;
  final DateTime? initialDob;
  final String? initialSex;

  @override
  State<BabyForm> createState() => _BabyFormState();
}

class _BabyFormState extends State<BabyForm> {
  late final _nameController = TextEditingController(
    text: widget.initialName ?? '',
  );
  late DateTime? _dob = widget.initialDob;
  late String? _sex = widget.initialSex;
  late bool _showMore = widget.initialSex != null;
  PlatformFile? _photo;

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _dob != null &&
      !widget.submitting;

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );
    final file = result?.files.firstOrNull;
    if (file != null) setState(() => _photo = file);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 6)),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _submit() {
    if (!_canSubmit) return;
    widget.onSubmit(
      name: _nameController.text.trim(),
      dob: _dob!,
      sex: _sex,
      photo: _photo,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
      ),
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: theme.typography.title.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (widget.subtitle != null)
          Text(
            widget.subtitle!,
            style: theme.typography.body.copyWith(color: colors.textSecondary),
          ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          style: theme.typography.body.copyWith(color: colors.textPrimary),
          decoration: _fieldDecoration(theme, label: 'Name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.m),
        _DobField(dob: _dob, onTap: _pickDob),
        const SizedBox(height: AppSpacing.s),
        TapScale(
          onTap: () => setState(() => _showMore = !_showMore),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showMore ? LucideIcons.chevron_up : LucideIcons.chevron_down,
                  size: 18,
                  color: colors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _showMore ? 'Fewer details' : 'Add more details (optional)',
                  style: theme.typography.label.copyWith(color: colors.primary),
                ),
              ],
            ),
          ),
        ),
        if (_showMore) ...[
          const SizedBox(height: AppSpacing.xs),
          _SexPicker(
            value: _sex,
            onChanged: (s) => setState(() => _sex = s),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              if (_photo?.bytes != null) ...[
                ClipOval(
                  child: Image.memory(
                    _photo!.bytes!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
              ],
              AppButton(
                variant: AppButtonVariant.secondary,
                onPressed: _pickPhoto,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.image_up, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Text(_photo == null ? 'Add a photo' : 'Change photo'),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
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
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration(AppTheme theme, {required String label}) {
  final colors = theme.colors;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.s),
    borderSide: BorderSide(color: colors.hairline),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: theme.typography.body.copyWith(color: colors.textSecondary),
    filled: true,
    fillColor: colors.surface,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    ),
  );
}

class _DobField extends StatelessWidget {
  const _DobField({required this.dob, required this.onTap});

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
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadii.s),
          border: Border.all(color: colors.hairline),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.calendar, size: 18, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.m),
            Text(
              dob == null ? 'Date of birth' : DateFormat.yMMMd().format(dob!),
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

typedef _SexOption = ({String value, IconData icon, String label});

class _SexPicker extends StatelessWidget {
  const _SexPicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  static const _options = [
    (value: 'Girl', icon: LucideIcons.venus, label: 'Girl'),
    (value: 'Boy', icon: LucideIcons.mars, label: 'Boy'),
    (value: 'Other', icon: LucideIcons.circle_dot, label: 'Other'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: [
        for (final _SexOption option in _options)
          _SexChip(
            icon: option.icon,
            label: option.label,
            selected: option.value == value,
            onTap: () =>
                onChanged(option.value == value ? null : option.value),
          ),
      ],
    );
  }
}

class _SexChip extends StatelessWidget {
  const _SexChip({
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
    final color = selected ? colors.textPrimary : colors.textSecondary;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        curve: AppMotion.curveStandard,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.surface : colors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: theme.typography.label.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
