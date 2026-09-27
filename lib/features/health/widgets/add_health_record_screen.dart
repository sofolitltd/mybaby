import 'package:flutter/material.dart'
    show
        InputDecoration,
        InputDecorator,
        OutlineInputBorder,
        ScaffoldMessenger,
        SnackBar,
        Switch,
        TextField,
        showDatePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/mime_utils.dart';
import '../../../core/picked_file.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion/tap_scale.dart';
import '../../../data/models/doctor_visit.dart';
import '../../../data/models/document_item.dart';
import '../../../data/models/vaccination.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/baby_switcher_sheet.dart';
import '../../babies/widgets/baby_screen_header.dart';
import 'record_delete_confirm.dart';

enum _RecordType { vaccination, doctorVisit, document }

const _quickVaccineNames = [
  'DTaP',
  'Hepatitis B',
  'Polio (IPV)',
  'Rotavirus',
  'PCV13',
];

/// Full-screen "Add Health Record" flow — a single page covering
/// Vaccination / Doctor Visit / Document, styled after the Serene Nurture
/// health mock. Only surfaces fields that already exist on [Vaccination],
/// [DoctorVisit] and [DocumentItem]; the next-dose reminder toggle below is
/// local UI state only (no notifications package is wired into the app), so
/// it doesn't schedule anything — it just reflects intent for now.
class AddHealthRecordScreen extends ConsumerStatefulWidget {
  const AddHealthRecordScreen({
    super.key,
    this.editingVaccination,
    this.editingDoctorVisit,
  });

  /// When set, the screen edits this vaccination in place (updates the
  /// existing Firestore doc) instead of creating a new one — the record
  /// type selector is locked and a delete action is shown.
  final Vaccination? editingVaccination;

  /// Same as [editingVaccination], for doctor visits. Documents are edited
  /// through a separate lightweight sheet (see `_EditDocumentSheet` in
  /// health_screen.dart) since re-uploading a file isn't part of "editing"
  /// a document the way it is for the other two record types.
  final DoctorVisit? editingDoctorVisit;

  bool get _isEditing =>
      editingVaccination != null || editingDoctorVisit != null;

  @override
  ConsumerState<AddHealthRecordScreen> createState() =>
      _AddHealthRecordScreenState();
}

class _AddHealthRecordScreenState extends ConsumerState<AddHealthRecordScreen> {
  late _RecordType _type = widget.editingDoctorVisit != null
      ? _RecordType.doctorVisit
      : _RecordType.vaccination;

  late final _vaccineNameController = TextEditingController(
    text: widget.editingVaccination?.name,
  );
  late final _doseController = TextEditingController(
    text: (widget.editingVaccination?.dose ?? 1).toString(),
  );
  late DateTime _vaccineDate =
      widget.editingVaccination?.administeredDate ??
      widget.editingVaccination?.scheduledDate ??
      DateTime.now();
  late bool _administered = widget.editingVaccination?.administeredDate != null;
  bool _reminderEnabled = true;

  late final _doctorController = TextEditingController(
    text: widget.editingDoctorVisit?.doctorName,
  );
  late final _reasonController = TextEditingController(
    text: widget.editingDoctorVisit?.reason,
  );
  late final _notesController = TextEditingController(
    text: widget.editingDoctorVisit?.notes,
  );
  late DateTime _visitDate = widget.editingDoctorVisit?.date ?? DateTime.now();

  PickedFile? _pickedFile;
  String _documentCategory = documentCategories.first;

  bool _saving = false;

  @override
  void dispose() {
    _vaccineNameController.dispose();
    _doseController.dispose();
    _doctorController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _canSave => switch (_type) {
    _RecordType.vaccination =>
      _vaccineNameController.text.trim().isNotEmpty &&
          int.tryParse(_doseController.text.trim()) != null,
    _RecordType.doctorVisit =>
      _doctorController.text.trim().isNotEmpty &&
          _reasonController.text.trim().isNotEmpty,
    _RecordType.document => _pickedFile != null,
  };

  Future<void> _pickDate({required bool forVisit}) async {
    final current = forVisit ? _visitDate : _vaccineDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
      lastDate: forVisit
          ? DateTime.now()
          : DateTime.now().add(const Duration(days: 365 * 6)),
    );
    if (picked == null) return;
    setState(() => forVisit ? _visitDate = picked : _vaccineDate = picked);
  }

  Future<void> _pickDocument() async {
    final file = await pickSingleFile();
    if (file == null) return;
    setState(() => _pickedFile = file);
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    try {
      switch (_type) {
        case _RecordType.vaccination:
          await _saveVaccination();
        case _RecordType.doctorVisit:
          await _saveDoctorVisit();
        case _RecordType.document:
          await _saveDocument();
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showRecordDeleteConfirm(context);
    if (confirmed != true || !mounted) return;
    try {
      if (widget.editingVaccination case final v?) {
        await ref.read(vaccinationsRepositoryProvider)?.delete(v.id);
      } else if (widget.editingDoctorVisit case final v?) {
        await ref.read(doctorVisitsRepositoryProvider)?.delete(v.id);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  Future<void> _saveVaccination() async {
    final repo = ref.read(vaccinationsRepositoryProvider);
    if (repo == null) return;
    final existing = widget.editingVaccination;
    final vaccination = Vaccination(
      id: existing?.id ?? '',
      name: _vaccineNameController.text.trim(),
      dose: int.parse(_doseController.text.trim()),
      scheduledDate: _vaccineDate,
      administeredDate: _administered ? _vaccineDate : null,
      cardDriveFileId: existing?.cardDriveFileId,
      cardMimeType: existing?.cardMimeType,
    );
    if (existing != null) {
      await repo.updateFields(existing.id, vaccination.toFirestore());
    } else {
      await repo.add(vaccination);
    }
  }

  Future<void> _saveDoctorVisit() async {
    final repo = ref.read(doctorVisitsRepositoryProvider);
    if (repo == null) return;
    final existing = widget.editingDoctorVisit;
    final notes = _notesController.text.trim();
    final visit = DoctorVisit(
      id: existing?.id ?? '',
      date: _visitDate,
      doctorName: _doctorController.text.trim(),
      reason: _reasonController.text.trim(),
      notes: notes.isEmpty ? null : notes,
    );
    if (existing != null) {
      await repo.updateFields(existing.id, visit.toFirestore());
      return;
    }
    await repo.add(visit);
  }

  Future<void> _saveDocument() async {
    final repo = ref.read(documentsRepositoryProvider);
    final file = _pickedFile;
    if (repo == null || file == null) return;
    final mimeType = guessMimeType(file.name);
    final drive = ref.read(driveRepositoryProvider);
    final folderId = await drive.ensureAppFolder();
    final driveFileId = await drive.uploadBytes(
      bytes: file.bytes,
      filename: file.name,
      mimeType: mimeType,
      folderId: folderId,
    );
    await repo.add(
      DocumentItem(
        id: '',
        date: DateTime.now(),
        title: file.name,
        category: _documentCategory,
        driveFileId: driveFileId,
        mimeType: mimeType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final baby = ref.watch(activeBabyProvider);

    final isEditing = widget._isEditing;

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            BabyScreenHeader(
              title: isEditing ? 'Edit Health Record' : 'Add Health Record',
              trailing: isEditing
                  ? TapScale(
                      onTap: _delete,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s),
                        child: Icon(
                          LucideIcons.trash,
                          color: theme.colors.status.overdue,
                        ),
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  0,
                  AppSpacing.l,
                  AppSpacing.l,
                ),
                children: [
                  if (baby != null)
                    _BabyChip(
                      name: baby.name,
                      ageWeeks: baby.ageInWeeks,
                      emoji: baby.avatarEmoji,
                      onTap: () => showBabySwitcherSheet(context),
                    ),
                  const SizedBox(height: AppSpacing.l),
                  if (!isEditing) ...[
                    Text(
                      'SELECT RECORD TYPE',
                      style: theme.typography.label.copyWith(
                        color: theme.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    _RecordTypeGrid(
                      selected: _type,
                      onSelect: (type) => setState(() => _type = type),
                    ),
                    const SizedBox(height: AppSpacing.l),
                  ],
                  switch (_type) {
                    _RecordType.vaccination => _VaccinationForm(
                      nameController: _vaccineNameController,
                      doseController: _doseController,
                      date: _vaccineDate,
                      administered: _administered,
                      reminderEnabled: _reminderEnabled,
                      onFieldChanged: () => setState(() {}),
                      onPickDate: () => _pickDate(forVisit: false),
                      onAdministeredChanged: (v) =>
                          setState(() => _administered = v),
                      onReminderChanged: (v) =>
                          setState(() => _reminderEnabled = v),
                    ),
                    _RecordType.doctorVisit => _DoctorVisitForm(
                      doctorController: _doctorController,
                      reasonController: _reasonController,
                      notesController: _notesController,
                      date: _visitDate,
                      onFieldChanged: () => setState(() {}),
                      onPickDate: () => _pickDate(forVisit: true),
                    ),
                    _RecordType.document => _DocumentForm(
                      file: _pickedFile,
                      category: _documentCategory,
                      onPickFile: _pickDocument,
                      onCategoryChanged: (c) =>
                          setState(() => _documentCategory = c),
                    ),
                  },
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
                        onPressed: _canSave && !_saving ? _save : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.circle_check,
                              size: 16,
                              color: theme.colors.onPrimary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Save Health Record',
                              style: theme.typography.label.copyWith(
                                color: theme.colors.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    TapScale(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Text(
                          'Discard Changes',
                          style: theme.typography.label.copyWith(
                            color: theme.colors.textTertiary,
                          ),
                        ),
                      ),
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

class _BabyChip extends StatelessWidget {
  const _BabyChip({
    required this.name,
    required this.ageWeeks,
    required this.emoji,
    required this.onTap,
  });

  final String name;
  final int ageWeeks;
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              shape: BoxShape.circle,
            ),
            child: Text(emoji),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              name,
              style: theme.typography.subtitle.copyWith(
                color: colors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$ageWeeks weeks old',
            style: theme.typography.caption.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Icon(LucideIcons.repeat, size: 16, color: colors.textTertiary),
        ],
      ),
    );
  }
}

class _RecordTypeGrid extends StatelessWidget {
  const _RecordTypeGrid({required this.selected, required this.onSelect});

  final _RecordType selected;
  final ValueChanged<_RecordType> onSelect;

  @override
  Widget build(BuildContext context) {
    const options = [
      (
        type: _RecordType.vaccination,
        icon: LucideIcons.syringe,
        title: 'Vaccination',
        subtitle: 'Immunizations',
      ),
      (
        type: _RecordType.doctorVisit,
        icon: LucideIcons.stethoscope,
        title: 'Doctor Visit',
        subtitle: 'Routine checks',
      ),
      (
        type: _RecordType.document,
        icon: LucideIcons.file_text,
        title: 'Document',
        subtitle: 'Cards & reports',
      ),
    ];

    return Row(
      children: [
        for (final option in options) ...[
          Expanded(
            child: _RecordTypeCard(
              icon: option.icon,
              title: option.title,
              subtitle: option.subtitle,
              selected: option.type == selected,
              onTap: () => onSelect(option.type),
            ),
          ),
          if (option != options.last) const SizedBox(width: AppSpacing.s),
        ],
      ],
    );
  }
}

class _RecordTypeCard extends StatelessWidget {
  const _RecordTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final fg = selected ? colors.onPrimary : colors.textPrimary;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.m),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.m,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadii.m),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? colors.onPrimary : colors.primary,
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              title,
              style: theme.typography.caption.copyWith(color: fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: theme.typography.label.copyWith(
                color: selected
                    ? colors.onPrimary.withValues(alpha: 0.8)
                    : colors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Section container — icon + title heading above a card, matching the
/// mock's "Record Details" / "Status & Administration" groupings.
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

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.s),
      child: InputDecorator(
        decoration: _fieldDecoration(context, label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat.yMMMd().format(date),
                style: theme.typography.body.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
            ),
            Icon(
              LucideIcons.calendar,
              size: 18,
              color: theme.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _VaccinationForm extends StatelessWidget {
  const _VaccinationForm({
    required this.nameController,
    required this.doseController,
    required this.date,
    required this.administered,
    required this.reminderEnabled,
    required this.onFieldChanged,
    required this.onPickDate,
    required this.onAdministeredChanged,
    required this.onReminderChanged,
  });

  final TextEditingController nameController;
  final TextEditingController doseController;
  final DateTime date;
  final bool administered;
  final bool reminderEnabled;
  final VoidCallback onFieldChanged;
  final VoidCallback onPickDate;
  final ValueChanged<bool> onAdministeredChanged;
  final ValueChanged<bool> onReminderChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormSection(
          icon: LucideIcons.file_text,
          title: 'Record Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                style: theme.typography.body.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: _fieldDecoration(context, 'Vaccine name'),
                onChanged: (_) => onFieldChanged(),
              ),
              const SizedBox(height: AppSpacing.s),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final name in _quickVaccineNames)
                    AppChip(
                      label: name,
                      selected: nameController.text.trim() == name,
                      onTap: () {
                        nameController.text = name;
                        onFieldChanged();
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: doseController,
                keyboardType: TextInputType.number,
                style: theme.typography.body.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: _fieldDecoration(context, 'Dose #'),
                onChanged: (_) => onFieldChanged(),
              ),
              const SizedBox(height: AppSpacing.m),
              _DateField(
                label: administered ? 'Date administered' : 'Scheduled date',
                date: date,
                onTap: onPickDate,
              ),
            ],
          ),
        ),
        _FormSection(
          icon: LucideIcons.clipboard_check,
          title: 'Status & Administration',
          child: Row(
            children: [
              Expanded(
                child: _SegmentButton(
                  label: 'Given / Completed',
                  selected: administered,
                  onTap: () => onAdministeredChanged(true),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: _SegmentButton(
                  label: 'Scheduled',
                  selected: !administered,
                  onTap: () => onAdministeredChanged(false),
                ),
              ),
            ],
          ),
        ),
        if (!administered)
          _FormSection(
            icon: LucideIcons.bell,
            title: 'Reminder',
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next dose reminder',
                        style: theme.typography.body.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        DateFormat.yMMMd().format(date),
                        style: theme.typography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(value: reminderEnabled, onChanged: onReminderChanged),
              ],
            ),
          ),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
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
      borderRadius: BorderRadius.circular(AppRadii.s),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? colors.status.done.withValues(alpha: 0.14)
              : colors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadii.s),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.typography.caption.copyWith(
            color: selected ? colors.status.done : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DoctorVisitForm extends StatelessWidget {
  const _DoctorVisitForm({
    required this.doctorController,
    required this.reasonController,
    required this.notesController,
    required this.date,
    required this.onFieldChanged,
    required this.onPickDate,
  });

  final TextEditingController doctorController;
  final TextEditingController reasonController;
  final TextEditingController notesController;
  final DateTime date;
  final VoidCallback onFieldChanged;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormSection(
          icon: LucideIcons.file_text,
          title: 'Record Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateField(label: 'Visit date', date: date, onTap: onPickDate),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: doctorController,
                style: theme.typography.body.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: _fieldDecoration(context, 'Doctor'),
                onChanged: (_) => onFieldChanged(),
              ),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: reasonController,
                style: theme.typography.body.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: _fieldDecoration(context, 'Reason'),
                onChanged: (_) => onFieldChanged(),
              ),
            ],
          ),
        ),
        _FormSection(
          icon: LucideIcons.clipboard_list,
          title: 'Pediatrician Advice & Notes',
          trailing: Text(
            'Optional',
            style: theme.typography.label.copyWith(color: colors.textTertiary),
          ),
          child: TextField(
            controller: notesController,
            minLines: 3,
            maxLines: 5,
            style: theme.typography.body.copyWith(color: colors.textPrimary),
            decoration: _fieldDecoration(context, 'Notes'),
          ),
        ),
      ],
    );
  }
}

class _DocumentForm extends StatelessWidget {
  const _DocumentForm({
    required this.file,
    required this.category,
    required this.onPickFile,
    required this.onCategoryChanged,
  });

  final PickedFile? file;
  final String category;
  final VoidCallback onPickFile;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return _FormSection(
      icon: LucideIcons.paperclip,
      title: 'Documents & Certificates',
      trailing: Text(
        file == null ? '0 files added' : '1 file added',
        style: theme.typography.label.copyWith(color: colors.textTertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TapScale(
            onTap: onPickFile,
            borderRadius: BorderRadius.circular(AppRadii.s),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadii.s),
              ),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.camera,
                    size: 28,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'Snap photo or attach file',
                    style: theme.typography.body.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Vaccine card, growth report, or prescription',
                    style: theme.typography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (file != null) ...[
            const SizedBox(height: AppSpacing.m),
            Row(
              children: [
                Icon(
                  LucideIcons.file_check,
                  size: 18,
                  color: colors.status.done,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    file!.name,
                    style: theme.typography.caption.copyWith(
                      color: colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final option in documentCategories)
                AppChip(
                  label: option,
                  selected: category == option,
                  onTap: () => onCategoryChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
