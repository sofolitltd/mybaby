import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/material.dart'
    show
        CircularProgressIndicator,
        InputBorder,
        OutlineInputBorder,
        TextField,
        TextEditingController,
        InputDecoration,
        TimeOfDay,
        showDatePicker,
        showTimePicker;
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextCapitalization, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../../core/picked_file.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion/app_motion.dart';
import '../../../core/theme/motion/tap_scale.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/app_status_pill.dart';

/// Result of a filled-out [AddBabyForm] — birth measurements are optional
/// and only meaningful once the baby has actually arrived, so they're left
/// null when [isExpecting] was selected. Values are always normalized to
/// metric (kg/cm) regardless of which unit the person entered them in.
typedef AddBabyFormResult = ({
  String name,
  DateTime dob,
  String? sex,
  PickedFile? photo,
  double? birthWeightKg,
  double? birthHeightCm,
  double? birthHeadCircumferenceCm,
  bool driveBackupEnabled,
});

/// Rich "Add Baby" intake form — name, gender, birth/due date, optional
/// birth measurements (seeded as the baby's first [GrowthEntry] so WHO
/// percentile curves have a day-zero baseline), and the Drive-backup toggle
/// that gates avatar upload. Distinct from the plain [BabyForm] used by
/// onboarding and edit-baby, which don't need this depth.
class AddBabyForm extends StatefulWidget {
  const AddBabyForm({
    super.key,
    required this.onSubmit,
    required this.submitting,
  });

  final Future<void> Function(AddBabyFormResult result) onSubmit;
  final bool submitting;

  @override
  State<AddBabyForm> createState() => _AddBabyFormState();
}

class _AddBabyFormState extends State<AddBabyForm> {
  final _nameController = TextEditingController();
  String? _sex;
  bool _isExpecting = false;
  DateTime? _dob;
  TimeOfDay? _timeOfBirth;
  PickedFile? _photo;

  double? _weightKg = 3.3;
  _WeightUnit _weightUnit = _WeightUnit.kg;
  double? _heightCm = 50.0;
  double? _headCm = 34.5;
  _LengthUnit _lengthUnit = _LengthUnit.cm;

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
    final firstDate = _isExpecting
        ? now
        : now.subtract(const Duration(days: 365 * 6));
    final lastDate = _isExpecting ? now.add(const Duration(days: 300)) : now;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _dob != null && _dob!.isAfter(firstDate) && _dob!.isBefore(lastDate)
          ? _dob!
          : (_isExpecting ? now.add(const Duration(days: 30)) : now),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() {
        _dob = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _timeOfBirth?.hour ?? 0,
          _timeOfBirth?.minute ?? 0,
        );
      });
    }
  }

  Future<void> _pickTimeOfBirth() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfBirth ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      _timeOfBirth = picked;
      final base = _dob ?? DateTime.now();
      _dob = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _setExpecting(bool expecting) {
    setState(() {
      _isExpecting = expecting;
      _dob = null;
      _timeOfBirth = null;
    });
  }

  void _submit() {
    if (!_canSubmit) return;
    final measurementsApply = !_isExpecting;
    widget.onSubmit((
      name: _nameController.text.trim(),
      dob: _dob!,
      sex: _sex,
      photo: _photo,
      birthWeightKg: measurementsApply ? _weightKg : null,
      birthHeightCm: measurementsApply ? _heightCm : null,
      birthHeadCircumferenceCm: measurementsApply ? _headCm : null,
      driveBackupEnabled: true,
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
        Center(
          child: AppStatusPill(
            label: 'New Journey',
            color: colors.primary,
            icon: LucideIcons.sparkles,
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        Text(
          'Welcome a new little one',
          textAlign: TextAlign.center,
          style: theme.typography.title.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "Set up your baby's profile to track growth, daily care, "
          'vaccinations, and precious memories.',
          textAlign: TextAlign.center,
          style: theme.typography.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: _PhotoPicker(photo: _photo, onTap: _pickPhoto),
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
              _Segmented(
                leftLabel: 'Baby is here',
                rightLabel: 'Expecting (Due date)',
                rightSelected: _isExpecting,
                onChanged: _setExpecting,
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                _isExpecting ? 'Due Date' : 'Date of Birth',
                style: theme.typography.label.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              _DateField(dob: _dob, onTap: _pickDob),
              if (!_isExpecting) ...[
                const SizedBox(height: AppSpacing.l),
                Text(
                  'Time of Birth (Optional)',
                  style: theme.typography.label.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                _TimeField(time: _timeOfBirth, onTap: _pickTimeOfBirth),
              ],
            ],
          ),
        ),

        if (!_isExpecting) ...[
          AppMutedSectionHeader(
            'Birth Measurements',
            trailing: AppStatusPill(
              label: 'WHO Baseline',
              color: colors.secondary,
            ),
          ),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              children: [
                Text(
                  "Used to calibrate your baby's standard WHO growth "
                  'percentiles and development curves.',
                  style: theme.typography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                _MeasurementRow(
                  icon: LucideIcons.weight,
                  label: 'Birth Weight',
                  sublabel: 'Standard avg: ~3.3 kg',
                  value: _weightKg,
                  onChanged: (v) => setState(() => _weightKg = v),
                  units: const ['kg', 'lb'],
                  unitIndex: _weightUnit.index,
                  onUnitChanged: (i) => setState(() {
                    final next = _WeightUnit.values[i];
                    if (_weightKg != null) {
                      _weightKg = next == _WeightUnit.lb
                          ? _weightKg! * 2.20462
                          : _weightKg! / 2.20462;
                    }
                    _weightUnit = next;
                  }),
                ),
                const SizedBox(height: AppSpacing.s),
                _MeasurementRow(
                  icon: LucideIcons.ruler,
                  label: 'Length / Height',
                  sublabel: 'Crown to heel',
                  value: _heightCm,
                  onChanged: (v) => setState(() => _heightCm = v),
                  units: const ['cm', 'in'],
                  unitIndex: _lengthUnit.index,
                  onUnitChanged: (i) => setState(() {
                    final next = _LengthUnit.values[i];
                    if (_heightCm != null) {
                      _heightCm = next == _LengthUnit.inch
                          ? _heightCm! / 2.54
                          : _heightCm! * 2.54;
                    }
                    if (_headCm != null) {
                      _headCm = next == _LengthUnit.inch
                          ? _headCm! / 2.54
                          : _headCm! * 2.54;
                    }
                    _lengthUnit = next;
                  }),
                ),
                const SizedBox(height: AppSpacing.s),
                _MeasurementRow(
                  icon: LucideIcons.circle,
                  label: 'Head Circumference',
                  sublabel: 'Cranial perimeter',
                  value: _headCm,
                  onChanged: (v) => setState(() => _headCm = v),
                  units: const ['cm', 'in'],
                  unitIndex: _lengthUnit.index,
                  onUnitChanged: (i) => setState(() {
                    final next = _LengthUnit.values[i];
                    if (_heightCm != null) {
                      _heightCm = next == _LengthUnit.inch
                          ? _heightCm! / 2.54
                          : _heightCm! * 2.54;
                    }
                    if (_headCm != null) {
                      _headCm = next == _LengthUnit.inch
                          ? _headCm! / 2.54
                          : _headCm! * 2.54;
                    }
                    _lengthUnit = next;
                  }),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.l),
        Row(
          children: [
            Icon(LucideIcons.lock, size: 14, color: colors.textTertiary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                "Your baby's data is end-to-end encrypted and private to your account.",
                style: theme.typography.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
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
              : const Text('Create Baby Profile'),
        ),
      ],
    );
  }
}

enum _WeightUnit { kg, lb }

enum _LengthUnit { cm, inch }

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

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.photo, required this.onTap});

  final PickedFile? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
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
            child: photo != null
                ? Image.memory(photo!.bytes, fit: BoxFit.cover)
                : Icon(LucideIcons.baby, size: 36, color: colors.textTertiary),
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

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.leftLabel,
    required this.rightLabel,
    required this.rightSelected,
    required this.onChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentedOption(
              label: leftLabel,
              selected: !rightSelected,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _SegmentedOption(
              label: rightLabel,
              selected: rightSelected,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedOption extends StatelessWidget {
  const _SegmentedOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        curve: AppMotion.curveStandard,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.surface : null,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.typography.label.copyWith(
            color: selected ? colors.textPrimary : colors.textSecondary,
          ),
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

class _TimeField extends StatelessWidget {
  const _TimeField({required this.time, required this.onTap});

  final TimeOfDay? time;
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
            Icon(LucideIcons.clock, size: 18, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.m),
            Text(
              time == null ? 'Select a time' : time!.format(context),
              style: theme.typography.body.copyWith(
                color: time == null ? colors.textSecondary : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementRow extends StatefulWidget {
  const _MeasurementRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
    required this.units,
    required this.unitIndex,
    required this.onUnitChanged,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final double? value;
  final ValueChanged<double?> onChanged;
  final List<String> units;
  final int unitIndex;
  final ValueChanged<int> onUnitChanged;

  @override
  State<_MeasurementRow> createState() => _MeasurementRowState();
}

class _MeasurementRowState extends State<_MeasurementRow> {
  late final _controller = TextEditingController(text: _format(widget.value));
  late int _lastUnitIndex = widget.unitIndex;

  @override
  void didUpdateWidget(_MeasurementRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only resync the field's text when the unit toggle converted the
    // underlying value — not on every keystroke, or the cursor would jump.
    if (widget.unitIndex != _lastUnitIndex) {
      _lastUnitIndex = widget.unitIndex;
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _format(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.s),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, size: 16, color: colors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: theme.typography.caption.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  widget.sublabel,
                  style: theme.typography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: TextField(
              controller: _controller,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: theme.typography.subtitle.copyWith(
                color: colors.textPrimary,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (text) => widget.onChanged(double.tryParse(text)),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          _UnitToggle(
            units: widget.units,
            index: widget.unitIndex,
            onChanged: widget.onUnitChanged,
          ),
        ],
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({
    required this.units,
    required this.index,
    required this.onChanged,
  });

  final List<String> units;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < units.length; i++)
            TapScale(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: AnimatedContainer(
                duration: AppMotion.durationFast,
                curve: AppMotion.curveStandard,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: i == index
                      ? colors.primary.withValues(alpha: 0.14)
                      : null,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  units[i],
                  style: theme.typography.label.copyWith(
                    color: i == index ? colors.primary : colors.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
