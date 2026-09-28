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
import 'package:intl/intl.dart';

import '../../../core/mime_utils.dart';
import '../../../core/picked_file.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion/sheet_transition.dart';
import '../../../core/theme/motion/tap_scale.dart';
import '../../../data/drive/drive_repository.dart';
import '../../../data/models/doctor_visit.dart';
import '../../../data/models/document_item.dart';
import '../../../data/models/medication.dart';
import '../../../data/models/vaccination.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/baby_switcher_sheet.dart';
import '../../babies/widgets/baby_screen_header.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/drive_error_snackbar.dart';

enum _RecordType { vaccination, doctorVisit, medication, document }

enum _VaccineCategory { mandatory, optional, campaign }

/// One row of the standard schedule offered by the vaccine-name picker —
/// name plus enough context (category, typical age, regional relevance)
/// that a parent picking it actually learns something, not just a label.
/// Dose number is its own field elsewhere in the form, so multi-dose
/// vaccines (Pentavalent, PCV, ...) appear once here.
typedef _VaccineInfo = ({
  String name,
  _VaccineCategory category,
  String ageLabel,
  String relevance,
});

const _standardVaccines = <_VaccineInfo>[
  (
    name: 'BCG',
    category: _VaccineCategory.mandatory,
    ageLabel: 'At birth',
    relevance: 'Global and Bangladesh EPI schedule',
  ),
  (
    name: 'Pentavalent',
    category: _VaccineCategory.mandatory,
    ageLabel: '6, 10 & 14 weeks',
    relevance: 'Global and Bangladesh EPI schedule',
  ),
  (
    name: 'PCV',
    category: _VaccineCategory.mandatory,
    ageLabel: '6, 10 & 14 weeks',
    relevance: 'Global and Bangladesh EPI schedule',
  ),
  (
    name: 'OPV / IPV',
    category: _VaccineCategory.mandatory,
    ageLabel: 'Birth, 6, 10 & 14 weeks',
    relevance: 'Global and Bangladesh EPI schedule',
  ),
  (
    name: 'MR / Measles',
    category: _VaccineCategory.mandatory,
    ageLabel: '9 & 15 months',
    relevance: 'Global and Bangladesh EPI schedule',
  ),
  (
    name: 'Typhoid (TCV)',
    category: _VaccineCategory.mandatory,
    ageLabel: '9 months',
    relevance: 'Newly added to the Bangladesh EPI schedule',
  ),
  (
    name: 'Rotavirus',
    category: _VaccineCategory.optional,
    ageLabel: '6 & 10 weeks',
    relevance: 'Mandatory in many countries, private in Bangladesh',
  ),
  (
    name: 'Hepatitis A',
    category: _VaccineCategory.optional,
    ageLabel: '12 & 18 months',
    relevance: 'Global standard, private in Bangladesh',
  ),
  (
    name: 'Chickenpox (Varicella)',
    category: _VaccineCategory.optional,
    ageLabel: '12–15 months',
    relevance: 'Global standard, private in Bangladesh',
  ),
  (
    name: 'MMR',
    category: _VaccineCategory.optional,
    ageLabel: '15 months',
    relevance: 'Global standard, private in Bangladesh',
  ),
  (
    name: 'Influenza (Seasonal)',
    category: _VaccineCategory.optional,
    ageLabel: 'Yearly, starting at 6 months',
    relevance: 'Global standard, private in Bangladesh',
  ),
  (
    name: 'HPV',
    category: _VaccineCategory.campaign,
    ageLabel: '9+ years (girls)',
    relevance: 'School or campaign based',
  ),
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
    this.editingMedication,
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

  /// Same as [editingVaccination], for medications.
  final Medication? editingMedication;

  bool get _isEditing =>
      editingVaccination != null ||
      editingDoctorVisit != null ||
      editingMedication != null;

  @override
  ConsumerState<AddHealthRecordScreen> createState() =>
      _AddHealthRecordScreenState();
}

class _AddHealthRecordScreenState extends ConsumerState<AddHealthRecordScreen> {
  late _RecordType _type = widget.editingDoctorVisit != null
      ? _RecordType.doctorVisit
      : widget.editingMedication != null
      ? _RecordType.medication
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

  PickedFile? _vaccineCardFile;
  final List<PickedFile> _prescriptionFiles = [];

  late final _medicationNameController = TextEditingController(
    text: widget.editingMedication?.name,
  );
  late final _dosageController = TextEditingController(
    text: widget.editingMedication?.dosage,
  );
  late final _durationController = TextEditingController(
    text: (widget.editingMedication?.durationDays ?? 5).toString(),
  );
  late final _medicationNotesController = TextEditingController(
    text: widget.editingMedication?.notes,
  );
  late DateTime _medicationStartDate =
      widget.editingMedication?.startDate ?? DateTime.now();
  late List<String> _reminderTimes = List.of(
    widget.editingMedication?.reminderTimes ?? const [],
  );

  bool _saving = false;

  @override
  void dispose() {
    _vaccineNameController.dispose();
    _doseController.dispose();
    _doctorController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    _medicationNameController.dispose();
    _dosageController.dispose();
    _durationController.dispose();
    _medicationNotesController.dispose();
    super.dispose();
  }

  bool get _canSave => switch (_type) {
    _RecordType.vaccination =>
      _vaccineNameController.text.trim().isNotEmpty &&
          int.tryParse(_doseController.text.trim()) != null,
    _RecordType.doctorVisit =>
      _doctorController.text.trim().isNotEmpty &&
          _reasonController.text.trim().isNotEmpty,
    _RecordType.medication =>
      _medicationNameController.text.trim().isNotEmpty &&
          _dosageController.text.trim().isNotEmpty &&
          (int.tryParse(_durationController.text.trim()) ?? 0) > 0,
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

  Future<void> _pickVaccineCard() async {
    final file = await pickSingleFile();
    if (file == null) return;
    setState(() => _vaccineCardFile = file);
  }

  Future<void> _pickPrescriptionFiles() async {
    final files = await pickMultipleFiles();
    if (files.isEmpty) return;
    setState(() => _prescriptionFiles.addAll(files));
  }

  void _removePrescriptionFile(int index) {
    setState(() => _prescriptionFiles.removeAt(index));
  }

  Future<void> _pickMedicationStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _medicationStartDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _medicationStartDate = picked);
  }

  Future<void> _addReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (_reminderTimes.contains(formatted)) return;
    setState(() => _reminderTimes = [..._reminderTimes, formatted]..sort());
  }

  void _removeReminderTime(int index) {
    setState(() {
      _reminderTimes = [..._reminderTimes]..removeAt(index);
    });
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
        case _RecordType.medication:
          await _saveMedication();
        case _RecordType.document:
          await _saveDocument();
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        if (e is DriveAuthException) {
          showDriveErrorSnackBar(context, ref, e);
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Could not save: $e')));
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDeleteDialog(context);
    if (confirmed != true || !mounted) return;
    try {
      if (widget.editingVaccination case final v?) {
        await ref.read(vaccinationsRepositoryProvider)?.delete(v.id);
      } else if (widget.editingDoctorVisit case final v?) {
        await ref.read(doctorVisitsRepositoryProvider)?.delete(v.id);
      } else if (widget.editingMedication case final m?) {
        await ref
            .read(notificationServiceProvider)
            .cancelMedicationCourse(
              medicationId: m.id,
              durationDays: m.durationDays,
              reminderTimesCount: m.reminderTimes.length,
            );
        await ref.read(medicationsRepositoryProvider)?.delete(m.id);
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
    var cardDriveFileId = existing?.cardDriveFileId;
    var cardMimeType = existing?.cardMimeType;
    final cardFile = _vaccineCardFile;
    if (cardFile != null) {
      final mimeType = guessMimeType(cardFile.name);
      final drive = ref.read(driveRepositoryProvider);
      final folderId = await drive.ensureAppFolder();
      cardDriveFileId = await drive.uploadBytes(
        bytes: cardFile.bytes,
        filename: cardFile.name,
        mimeType: mimeType,
        folderId: folderId,
      );
      cardMimeType = mimeType;
    }
    final vaccination = Vaccination(
      id: existing?.id ?? '',
      name: _vaccineNameController.text.trim(),
      dose: int.parse(_doseController.text.trim()),
      scheduledDate: _vaccineDate,
      administeredDate: _administered ? _vaccineDate : null,
      cardDriveFileId: cardDriveFileId,
      cardMimeType: cardMimeType,
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
    var prescriptionIds =
        existing?.prescriptionDriveFileIds ?? const <String>[];
    if (_prescriptionFiles.isNotEmpty) {
      final drive = ref.read(driveRepositoryProvider);
      final folderId = await drive.ensureAppFolder();
      final uploadedIds = <String>[];
      for (final file in _prescriptionFiles) {
        final uploadedId = await drive.uploadBytes(
          bytes: file.bytes,
          filename: file.name,
          mimeType: guessMimeType(file.name),
          folderId: folderId,
        );
        uploadedIds.add(uploadedId);
      }
      prescriptionIds = [...prescriptionIds, ...uploadedIds];
    }
    final visit = DoctorVisit(
      id: existing?.id ?? '',
      date: _visitDate,
      doctorName: _doctorController.text.trim(),
      reason: _reasonController.text.trim(),
      notes: notes.isEmpty ? null : notes,
      prescriptionDriveFileIds: prescriptionIds,
    );
    if (existing != null) {
      await repo.updateFields(existing.id, visit.toFirestore());
      return;
    }
    await repo.add(visit);
  }

  Future<void> _saveMedication() async {
    final repo = ref.read(medicationsRepositoryProvider);
    if (repo == null) return;
    final existing = widget.editingMedication;
    final notifications = ref.read(notificationServiceProvider);
    if (existing != null) {
      await notifications.cancelMedicationCourse(
        medicationId: existing.id,
        durationDays: existing.durationDays,
        reminderTimesCount: existing.reminderTimes.length,
      );
    }
    final notes = _medicationNotesController.text.trim();
    final medication = Medication(
      id: existing?.id ?? '',
      name: _medicationNameController.text.trim(),
      dosage: _dosageController.text.trim(),
      startDate: _medicationStartDate,
      durationDays: int.parse(_durationController.text.trim()),
      reminderTimes: _reminderTimes,
      notes: notes.isEmpty ? null : notes,
    );
    final String medicationId;
    if (existing != null) {
      await repo.updateFields(existing.id, medication.toFirestore());
      medicationId = existing.id;
    } else {
      medicationId = await repo.add(medication);
    }
    if (_reminderTimes.isNotEmpty) {
      final granted = await notifications.requestPermission();
      if (granted) {
        await notifications.scheduleMedicationCourse(
          medicationId: medicationId,
          name: medication.name,
          dosage: medication.dosage,
          startDate: medication.startDate,
          durationDays: medication.durationDays,
          reminderTimes: medication.reminderTimes,
        );
      }
    }
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
                    _RecordTypeDropdown(
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
                      cardFile: _vaccineCardFile,
                      hasExistingCard:
                          widget.editingVaccination?.cardDriveFileId != null,
                      onFieldChanged: () => setState(() {}),
                      onPickDate: () => _pickDate(forVisit: false),
                      onAdministeredChanged: (v) =>
                          setState(() => _administered = v),
                      onReminderChanged: (v) =>
                          setState(() => _reminderEnabled = v),
                      onPickCard: _pickVaccineCard,
                    ),
                    _RecordType.doctorVisit => _DoctorVisitForm(
                      doctorController: _doctorController,
                      reasonController: _reasonController,
                      notesController: _notesController,
                      date: _visitDate,
                      prescriptionFiles: _prescriptionFiles,
                      existingPrescriptionCount:
                          widget.editingDoctorVisit?.prescriptionDriveFileIds
                              .length ??
                          0,
                      onFieldChanged: () => setState(() {}),
                      onPickDate: () => _pickDate(forVisit: true),
                      onPickPrescriptionFiles: _pickPrescriptionFiles,
                      onRemovePrescriptionFile: _removePrescriptionFile,
                    ),
                    _RecordType.medication => _MedicationForm(
                      nameController: _medicationNameController,
                      dosageController: _dosageController,
                      durationController: _durationController,
                      notesController: _medicationNotesController,
                      startDate: _medicationStartDate,
                      reminderTimes: _reminderTimes,
                      onFieldChanged: () => setState(() {}),
                      onPickStartDate: _pickMedicationStartDate,
                      onAddReminderTime: _addReminderTime,
                      onRemoveReminderTime: _removeReminderTime,
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

const _recordTypeOptions = [
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
    type: _RecordType.medication,
    icon: LucideIcons.pill,
    title: 'Medication',
    subtitle: 'Doses & reminders',
  ),
  (
    type: _RecordType.document,
    icon: LucideIcons.file_text,
    title: 'Document',
    subtitle: 'Cards & reports',
  ),
];

/// Record-type picker for the add-health-record flow — a single tappable
/// field (styled like the rest of the form's inputs) that opens a sheet
/// listing every type, rather than an always-visible horizontal card row.
class _RecordTypeDropdown extends StatelessWidget {
  const _RecordTypeDropdown({required this.selected, required this.onSelect});

  final _RecordType selected;
  final ValueChanged<_RecordType> onSelect;

  Future<void> _open(BuildContext context) async {
    final picked = await showAppSheet<_RecordType>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in _recordTypeOptions)
            _DropdownOptionRow(
              icon: option.icon,
              label: option.title,
              subtitle: option.subtitle,
              selected: option.type == selected,
              onTap: () => Navigator.of(context).pop(option.type),
            ),
          const SizedBox(height: AppSpacing.s),
        ],
      ),
    );
    if (picked != null) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final current = _recordTypeOptions.firstWhere((o) => o.type == selected);
    return TapScale(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(AppRadii.s),
      child: InputDecorator(
        decoration: _fieldDecoration(context, 'Record type'),
        child: Row(
          children: [
            Icon(current.icon, size: 18, color: colors.primary),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                current.title,
                style: theme.typography.body.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevron_down,
              size: 18,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// One row in a [showAppSheet] options list — used by [_RecordTypeDropdown]
/// and the vaccine-name picker.
class _DropdownOptionRow extends StatelessWidget {
  const _DropdownOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final fg = selected ? colors.primary : colors.textPrimary;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: selected ? colors.primary : colors.textSecondary),
              const SizedBox(width: AppSpacing.m),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.typography.body.copyWith(color: fg)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.typography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(LucideIcons.check, size: 18, color: colors.primary),
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

/// Reusable "Snap photo or attach file" tile used by every attachment
/// section in this screen (vaccine card, prescriptions, documents).
class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return TapScale(
      onTap: onTap,
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
            Icon(LucideIcons.camera, size: 28, color: colors.textSecondary),
            const SizedBox(height: AppSpacing.s),
            Text(
              label,
              style: theme.typography.body.copyWith(
                color: colors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: theme.typography.caption.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single attached-file row, with an optional remove action for files
/// picked locally (not yet-uploaded existing files, which can't be undone
/// from this screen).
class _AttachedFileRow extends StatelessWidget {
  const _AttachedFileRow({required this.name, this.onRemove});

  final String name;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Row(
        children: [
          Icon(LucideIcons.file_check, size: 18, color: colors.status.done),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              name,
              style: theme.typography.caption.copyWith(
                color: colors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRemove != null)
            TapScale(
              onTap: onRemove!,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(LucideIcons.x, size: 16, color: colors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

const _otherVaccineOption = 'Other';

/// Vaccine name picker — a dropdown of the common vaccines plus "Other",
/// which reveals a free-text field for anything not on the quick list.
class _VaccineNameField extends StatelessWidget {
  const _VaccineNameField({
    required this.controller,
    required this.onFieldChanged,
  });

  final TextEditingController controller;
  final VoidCallback onFieldChanged;

  /// The matching standard-schedule entry for the current text, or null if
  /// it's a custom ("Other") name.
  _VaccineInfo? get _selectedInfo {
    final current = controller.text.trim();
    for (final vaccine in _standardVaccines) {
      if (vaccine.name == current) return vaccine;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final selectedName = _selectedInfo?.name;
    final picked = await showAppSheet<String>(
      context: context,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.l),
              for (final vaccine in _standardVaccines)
                _DropdownOptionRow(
                  label: vaccine.name,
                  subtitle:
                      '${_vaccineCategoryLabel(vaccine.category)} · ${vaccine.ageLabel}',
                  selected: vaccine.name == selectedName,
                  onTap: () => Navigator.of(context).pop(vaccine.name),
                ),
              _DropdownOptionRow(
                label: _otherVaccineOption,
                subtitle: 'Not on the standard schedule',
                selected: selectedName == null,
                onTap: () => Navigator.of(context).pop(_otherVaccineOption),
              ),
              const SizedBox(height: AppSpacing.s),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    if (picked == _otherVaccineOption) {
      if (_selectedInfo != null) controller.clear();
    } else {
      controller.text = picked;
    }
    onFieldChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final info = _selectedInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TapScale(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(AppRadii.s),
          child: InputDecorator(
            decoration: _fieldDecoration(context, 'Vaccine name'),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    info?.name ?? _otherVaccineOption,
                    style: theme.typography.body.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.chevron_down,
                  size: 18,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        if (info == null)
          TextField(
            controller: controller,
            style: theme.typography.body.copyWith(color: colors.textPrimary),
            decoration: _fieldDecoration(context, 'Enter vaccine name'),
            onChanged: (_) => onFieldChanged(),
          )
        else
          _VaccineInfoCard(info: info),
      ],
    );
  }
}

String _vaccineCategoryLabel(_VaccineCategory category) => switch (category) {
  _VaccineCategory.mandatory => 'Mandatory / EPI',
  _VaccineCategory.optional => 'Optional / Private',
  _VaccineCategory.campaign => 'Campaign',
};

/// Shown once a standard-schedule vaccine is picked — surfaces category,
/// typical age, and regional relevance inline so choosing it also teaches
/// the parent something, per the standard EPI/WHO schedule this app ships
/// with (see [_standardVaccines]).
class _VaccineInfoCard extends StatelessWidget {
  const _VaccineInfoCard({required this.info});

  final _VaccineInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final categoryColor = switch (info.category) {
      _VaccineCategory.mandatory => colors.primary,
      _VaccineCategory.optional => colors.info,
      _VaccineCategory.campaign => colors.secondary,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.info, size: 14, color: categoryColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _vaccineCategoryLabel(info.category),
                style: theme.typography.label.copyWith(color: categoryColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.calendar_clock,
                size: 14,
                color: colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Typically given at ${info.ageLabel}',
                  style: theme.typography.caption.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            info.relevance,
            style: theme.typography.caption.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
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
    required this.cardFile,
    required this.hasExistingCard,
    required this.onFieldChanged,
    required this.onPickDate,
    required this.onAdministeredChanged,
    required this.onReminderChanged,
    required this.onPickCard,
  });

  final TextEditingController nameController;
  final TextEditingController doseController;
  final DateTime date;
  final bool administered;
  final bool reminderEnabled;
  final PickedFile? cardFile;
  final bool hasExistingCard;
  final VoidCallback onFieldChanged;
  final VoidCallback onPickDate;
  final ValueChanged<bool> onAdministeredChanged;
  final ValueChanged<bool> onReminderChanged;
  final VoidCallback onPickCard;

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
              _VaccineNameField(
                controller: nameController,
                onFieldChanged: onFieldChanged,
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
        _FormSection(
          icon: LucideIcons.paperclip,
          title: 'Vaccine Card',
          trailing: Text(
            cardFile != null || hasExistingCard ? '1 file added' : '0 files added',
            style: theme.typography.label.copyWith(color: colors.textTertiary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AttachmentTile(
                label: 'Snap photo or attach file',
                subtitle: 'Vaccination card or clinic receipt',
                onTap: onPickCard,
              ),
              if (cardFile != null)
                _AttachedFileRow(name: cardFile!.name)
              else if (hasExistingCard)
                _AttachedFileRow(name: 'Vaccine card on file'),
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
    required this.prescriptionFiles,
    required this.existingPrescriptionCount,
    required this.onFieldChanged,
    required this.onPickDate,
    required this.onPickPrescriptionFiles,
    required this.onRemovePrescriptionFile,
  });

  final TextEditingController doctorController;
  final TextEditingController reasonController;
  final TextEditingController notesController;
  final DateTime date;
  final List<PickedFile> prescriptionFiles;
  final int existingPrescriptionCount;
  final VoidCallback onFieldChanged;
  final VoidCallback onPickDate;
  final VoidCallback onPickPrescriptionFiles;
  final ValueChanged<int> onRemovePrescriptionFile;

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
        _FormSection(
          icon: LucideIcons.paperclip,
          title: 'Prescriptions & Documents',
          trailing: Text(
            '${existingPrescriptionCount + prescriptionFiles.length} files added',
            style: theme.typography.label.copyWith(color: colors.textTertiary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AttachmentTile(
                label: 'Snap photo or attach file',
                subtitle: 'Prescriptions, referrals, or lab results',
                onTap: onPickPrescriptionFiles,
              ),
              for (var i = 0; i < prescriptionFiles.length; i++)
                _AttachedFileRow(
                  name: prescriptionFiles[i].name,
                  onRemove: () => onRemovePrescriptionFile(i),
                ),
              if (existingPrescriptionCount > 0)
                _AttachedFileRow(
                  name: existingPrescriptionCount == 1
                      ? '1 file already on record'
                      : '$existingPrescriptionCount files already on record',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MedicationForm extends StatelessWidget {
  const _MedicationForm({
    required this.nameController,
    required this.dosageController,
    required this.durationController,
    required this.notesController,
    required this.startDate,
    required this.reminderTimes,
    required this.onFieldChanged,
    required this.onPickStartDate,
    required this.onAddReminderTime,
    required this.onRemoveReminderTime,
  });

  final TextEditingController nameController;
  final TextEditingController dosageController;
  final TextEditingController durationController;
  final TextEditingController notesController;
  final DateTime startDate;
  final List<String> reminderTimes;
  final VoidCallback onFieldChanged;
  final VoidCallback onPickStartDate;
  final VoidCallback onAddReminderTime;
  final ValueChanged<int> onRemoveReminderTime;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormSection(
          icon: LucideIcons.pill,
          title: 'Medication Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                style: theme.typography.body.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: _fieldDecoration(context, 'Medication name'),
                onChanged: (_) => onFieldChanged(),
              ),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: dosageController,
                style: theme.typography.body.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: _fieldDecoration(
                  context,
                  'Dosage (e.g. 5ml, 1 tablet)',
                ),
                onChanged: (_) => onFieldChanged(),
              ),
              const SizedBox(height: AppSpacing.m),
              _DateField(
                label: 'Start date',
                date: startDate,
                onTap: onPickStartDate,
              ),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                style: theme.typography.body.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: _fieldDecoration(context, 'Duration (days)'),
                onChanged: (_) => onFieldChanged(),
              ),
            ],
          ),
        ),
        _FormSection(
          icon: LucideIcons.bell,
          title: 'Reminder Times',
          trailing: TapScale(
            onTap: onAddReminderTime,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 14, color: colors.primary),
                const SizedBox(width: AppSpacing.xs / 2),
                Text(
                  'Add time',
                  style: theme.typography.label.copyWith(
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
          child: reminderTimes.isEmpty
              ? Text(
                  'No reminder times yet — add one so this medication '
                  'sends a notification.',
                  style: theme.typography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                )
              : Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (var i = 0; i < reminderTimes.length; i++)
                      _TimeChip(
                        time: reminderTimes[i],
                        onRemove: () => onRemoveReminderTime(i),
                      ),
                  ],
                ),
        ),
        _FormSection(
          icon: LucideIcons.clipboard_list,
          title: 'Notes',
          trailing: Text(
            'Optional',
            style: theme.typography.label.copyWith(color: colors.textTertiary),
          ),
          child: TextField(
            controller: notesController,
            minLines: 2,
            maxLines: 4,
            style: theme.typography.body.copyWith(color: colors.textPrimary),
            decoration: _fieldDecoration(context, 'Notes'),
          ),
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.time, required this.onRemove});

  /// 24h "HH:mm" — see [Medication.reminderTimes].
  final String time;
  final VoidCallback onRemove;

  static String _label(String hhmm) {
    final parts = hhmm.split(':');
    final dateTime = DateTime(
      2000,
      1,
      1,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    return DateFormat.jm().format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.bell, size: 14, color: colors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            _label(time),
            style: theme.typography.label.copyWith(color: colors.primary),
          ),
          const SizedBox(width: AppSpacing.xs),
          TapScale(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Icon(LucideIcons.x, size: 14, color: colors.primary),
          ),
        ],
      ),
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
          _AttachmentTile(
            label: 'Snap photo or attach file',
            subtitle: 'Vaccine card, growth report, or prescription',
            onTap: onPickFile,
          ),
          if (file != null) _AttachedFileRow(name: file!.name),
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
