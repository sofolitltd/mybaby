import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart'
    show
        CircularProgressIndicator,
        InputDecoration,
        InputDecorator,
        OutlineInputBorder,
        ScaffoldMessenger,
        SnackBar,
        TextField,
        showDatePicker,
        showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/mime_utils.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/sheet_transition.dart';
import '../../core/theme/motion/staggered_entrance.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../data/drive/drive_image_cache.dart';
import '../../data/models/doctor_visit.dart';
import '../../data/models/document_item.dart';
import '../../data/models/vaccination.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/app_section_header.dart';
import '../../shared/widgets/app_status_pill.dart';
import '../../shared/widgets/drive_image.dart';
import 'widgets/upload_progress_dialog.dart';
import 'widgets/vaccine_card_editor_screen.dart';

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  Future<void> _addVaccination(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(vaccinationsRepositoryProvider);
    if (repo == null) return;
    final result = await showAppSheet<Vaccination>(
      context: context,
      builder: (context) => const _AddVaccinationSheet(),
    );
    if (result != null) await repo.add(result);
  }

  Future<void> _addDoctorVisit(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(doctorVisitsRepositoryProvider);
    if (repo == null) return;
    final result = await showAppSheet<DoctorVisit>(
      context: context,
      builder: (context) => const _AddDoctorVisitSheet(),
    );
    if (result != null) await repo.add(result);
  }

  Future<void> _addDocument(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(documentsRepositoryProvider);
    if (repo == null) return;
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    try {
      final mimeType = guessMimeType(file.name);
      final drive = ref.read(driveRepositoryProvider);
      final folderId = await drive.ensureAppFolder();
      final driveFileId = await drive.uploadBytes(
        bytes: file.bytes!,
        filename: file.name,
        mimeType: mimeType,
        folderId: folderId,
      );
      await repo.add(
        DocumentItem(
          id: '',
          date: DateTime.now(),
          title: file.name,
          category: 'Other',
          driveFileId: driveFileId,
          mimeType: mimeType,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _addVaccineCard(
    BuildContext context,
    WidgetRef ref,
    String vaccinationId,
  ) async {
    final repo = ref.read(vaccinationsRepositoryProvider);
    if (repo == null) return;

    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    if (!context.mounted) return;

    final cropped = await Navigator.of(context).push<Uint8List>(
      _NoTransitionRoute(
        builder: (_) => VaccineCardEditorScreen(sourceBytes: file.bytes!),
      ),
    );
    if (cropped == null) return;
    if (!context.mounted) return;

    final confirmed = await _confirmVaccineCardPhoto(context, cropped);
    if (confirmed != true) return;
    if (!context.mounted) return;

    const mimeType = 'image/jpeg';
    final filename = 'vaccine-card-$vaccinationId.jpg';

    try {
      final driveFileId = await showUploadProgressDialog<String>(
        context,
        title: 'Uploading vaccine card',
        upload: (onProgress) async {
          final drive = ref.read(driveRepositoryProvider);
          final folderId = await drive.ensureAppFolder();
          return drive.uploadBytes(
            bytes: cropped,
            filename: filename,
            mimeType: mimeType,
            folderId: folderId,
            onProgress: onProgress,
          );
        },
      );
      await DriveImageCache.instance.write(driveFileId, cropped);
      await repo.setCard(vaccinationId, driveFileId, mimeType);
      ref.invalidate(driveImageBytesProvider(driveFileId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final vaccinationsAsync = ref.watch(vaccinationsProvider);
    final visitsAsync = ref.watch(doctorVisitsProvider);
    final documentsAsync = ref.watch(documentsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.xl,
        96,
      ),
      children: [
        AppSectionHeader(
          'Vaccinations',
          trailing: _AddAction(
            label: 'Add',
            onTap: () => _addVaccination(context, ref),
          ),
        ),
        vaccinationsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.m),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            'Could not load vaccinations: $e',
            style: theme.typography.body.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
          data: (list) => list.isEmpty
              ? const AppEmptyState(
                  icon: LucideIcons.syringe,
                  message: 'No vaccination schedule yet.',
                )
              : StaggeredListEntrance(
                  children: [
                    for (final v in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.m),
                        child: _VaccinationTile(
                          vaccination: v,
                          onAddCard: () => _addVaccineCard(context, ref, v.id),
                          onMarkDone: () => ref
                              .read(vaccinationsRepositoryProvider)
                              ?.markAdministered(v.id),
                        ),
                      ),
                  ],
                ),
        ),
        AppSectionHeader(
          'Doctor visits',
          trailing: _AddAction(
            label: 'Add',
            onTap: () => _addDoctorVisit(context, ref),
          ),
        ),
        visitsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text(
            'Could not load visits: $e',
            style: theme.typography.body.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
          data: (visits) => visits.isEmpty
              ? const AppEmptyState(
                  icon: LucideIcons.stethoscope,
                  message: 'No doctor visits logged yet.',
                )
              : StaggeredListEntrance(
                  children: [
                    for (final v in visits)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.m),
                        child: _DoctorVisitTile(visit: v),
                      ),
                  ],
                ),
        ),
        AppSectionHeader(
          'Documents',
          trailing: _AddAction(
            label: 'Add',
            onTap: () => _addDocument(context, ref),
          ),
        ),
        documentsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text(
            'Could not load documents: $e',
            style: theme.typography.body.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
          data: (documents) {
            if (documents.isEmpty) {
              return const AppEmptyState(
                icon: LucideIcons.file_text,
                message: 'No documents yet.',
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: documents.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.m,
                crossAxisSpacing: AppSpacing.m,
                childAspectRatio: 1.4,
              ),
              itemBuilder: (context, i) =>
                  _DocumentTile(document: documents[i]),
            );
          },
        ),
      ],
    );
  }
}

/// No Material page-route transition here — plain fade, kept out of
/// [AppMotion] since this is a one-off full-screen photo tool push rather
/// than a routed screen transition (see `core/routing/app_router.dart` for
/// the app's real `AppPageTransition`).
class _NoTransitionRoute<T> extends PageRouteBuilder<T> {
  _NoTransitionRoute({required WidgetBuilder builder})
    : super(
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      );
}

Future<bool?> _confirmVaccineCardPhoto(
  BuildContext context,
  Uint8List cropped,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = AppTheme.of(context);
      return Center(
        child: AppGlassSurface(
          borderRadius: BorderRadius.circular(AppRadii.m),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Use this photo?',
                  style: theme.typography.subtitle.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.s),
                  child: Image.memory(cropped, fit: BoxFit.contain),
                ),
                const SizedBox(height: AppSpacing.l),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        variant: AppButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          'Retake',
                          style: theme.typography.label.copyWith(
                            color: theme.colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: AppButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(
                          'Upload',
                          style: theme.typography.label.copyWith(
                            color: theme.colors.onPrimary,
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
      );
    },
  );
}

class _AddAction extends StatelessWidget {
  const _AddAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.plus, size: 16, color: theme.colors.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.typography.label.copyWith(
                color: theme.colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VaccinationTile extends StatelessWidget {
  const _VaccinationTile({
    required this.vaccination,
    required this.onMarkDone,
    required this.onAddCard,
  });

  final Vaccination vaccination;
  final VoidCallback onMarkDone;
  final VoidCallback onAddCard;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final status = theme.colors.status;
    final (color, label) = switch (vaccination.status) {
      VaccinationStatus.done => (status.done, 'Done'),
      VaccinationStatus.dueSoon => (status.dueSoon, 'Due soon'),
      VaccinationStatus.overdue => (status.overdue, 'Overdue'),
    };
    final cardFileId = vaccination.cardDriveFileId;
    final done = vaccination.status == VaccinationStatus.done;

    return AppCard(
      onTap: done ? null : onMarkDone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vaccination.name} — dose ${vaccination.dose}',
                      style: theme.typography.subtitle.copyWith(
                        color: theme.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      DateFormat.yMMMd().format(vaccination.scheduledDate),
                      style: theme.typography.caption.copyWith(
                        color: theme.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusPill(label: label, color: color),
              const SizedBox(width: AppSpacing.s),
              TapScale(
                onTap: onAddCard,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    cardFileId == null ? LucideIcons.camera : LucideIcons.image,
                    color: theme.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (cardFileId != null) ...[
            const SizedBox(height: AppSpacing.m),
            DriveImage(fileId: cardFileId, height: 140),
          ],
        ],
      ),
    );
  }
}

class _DoctorVisitTile extends StatelessWidget {
  const _DoctorVisitTile({required this.visit});

  final DoctorVisit visit;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AppCard(
      child: Row(
        children: [
          Icon(LucideIcons.stethoscope, color: theme.colors.textSecondary),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.reason,
                  style: theme.typography.subtitle.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  '${visit.doctorName} · ${DateFormat.yMMMd().format(visit.date)}',
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document});

  final DocumentItem document;

  @override
  Widget build(BuildContext context) {
    if (isImageMimeType(document.mimeType)) {
      return AppCard(
        padding: EdgeInsets.zero,
        child: DriveImage(
          fileId: document.driveFileId,
          height: double.infinity,
        ),
      );
    }

    final theme = AppTheme.of(context);
    return AppCard(
      onTap: () => launchUrl(
        Uri.parse(
          'https://drive.google.com/file/d/${document.driveFileId}/view',
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(LucideIcons.file_text, color: theme.colors.textSecondary),
          Text(
            document.title,
            style: theme.typography.body.copyWith(
              color: theme.colors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            document.category,
            style: theme.typography.caption.copyWith(
              color: theme.colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration(BuildContext context, String label) {
  final theme = AppTheme.of(context);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.s),
    borderSide: BorderSide(color: theme.colors.hairline),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: theme.typography.body.copyWith(
      color: theme.colors.textSecondary,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: theme.colors.primary, width: 1.5),
    ),
  );
}

class _AddVaccinationSheet extends StatefulWidget {
  const _AddVaccinationSheet();

  @override
  State<_AddVaccinationSheet> createState() => _AddVaccinationSheetState();
}

class _AddVaccinationSheetState extends State<_AddVaccinationSheet> {
  final _nameController = TextEditingController();
  final _doseController = TextEditingController(text: '1');
  DateTime _date = DateTime.now();

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      int.tryParse(_doseController.text.trim()) != null;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 6)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      Vaccination(
        id: '',
        name: _nameController.text.trim(),
        dose: int.parse(_doseController.text.trim()),
        scheduledDate: _date,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.s,
        AppSpacing.xxl,
        AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add vaccination',
            style: theme.typography.title.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          TextField(
            controller: _nameController,
            style: theme.typography.body.copyWith(
              color: theme.colors.textPrimary,
            ),
            decoration: _fieldDecoration(context, 'Vaccine name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            controller: _doseController,
            keyboardType: TextInputType.number,
            style: theme.typography.body.copyWith(
              color: theme.colors.textPrimary,
            ),
            decoration: _fieldDecoration(context, 'Dose'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.m),
          TapScale(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(AppRadii.s),
            child: InputDecorator(
              decoration: _fieldDecoration(context, 'Scheduled date'),
              child: Text(
                DateFormat.yMMMd().format(_date),
                style: theme.typography.body.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            onPressed: _canSave ? _save : null,
            child: Text(
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

class _AddDoctorVisitSheet extends StatefulWidget {
  const _AddDoctorVisitSheet();

  @override
  State<_AddDoctorVisitSheet> createState() => _AddDoctorVisitSheetState();
}

class _AddDoctorVisitSheetState extends State<_AddDoctorVisitSheet> {
  final _doctorController = TextEditingController();
  final _reasonController = TextEditingController();
  DateTime _date = DateTime.now();

  bool get _canSave =>
      _doctorController.text.trim().isNotEmpty &&
      _reasonController.text.trim().isNotEmpty;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      DoctorVisit(
        id: '',
        date: _date,
        doctorName: _doctorController.text.trim(),
        reason: _reasonController.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _doctorController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.s,
        AppSpacing.xxl,
        AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add doctor visit',
            style: theme.typography.title.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          TapScale(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(AppRadii.s),
            child: InputDecorator(
              decoration: _fieldDecoration(context, 'Date'),
              child: Text(
                DateFormat.yMMMd().format(_date),
                style: theme.typography.body.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            controller: _doctorController,
            style: theme.typography.body.copyWith(
              color: theme.colors.textPrimary,
            ),
            decoration: _fieldDecoration(context, 'Doctor'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            controller: _reasonController,
            style: theme.typography.body.copyWith(
              color: theme.colors.textPrimary,
            ),
            decoration: _fieldDecoration(context, 'Reason'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            onPressed: _canSave ? _save : null,
            child: Text(
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
