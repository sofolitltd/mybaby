import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' show FileType;
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
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/mime_utils.dart';
import '../../core/picked_file.dart';
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
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_extended_fab.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/app_section_header.dart';
import '../../shared/widgets/app_status_pill.dart';
import '../../shared/widgets/drive_image.dart';
import 'widgets/record_delete_confirm.dart';
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
    final file = await pickSingleFile();
    if (file == null) return;
    try {
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
          category: 'Other',
          driveFileId: driveFileId,
          mimeType: mimeType,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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

    final file = await pickSingleFile(type: FileType.image);
    if (file == null) return;
    if (!context.mounted) return;

    final cropped = await Navigator.of(context).push<Uint8List>(
      _NoTransitionRoute(
        builder: (_) => VaccineCardEditorScreen(sourceBytes: file.bytes),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  void _addHealthRecord(BuildContext context) {
    context.push('/add-health-record');
  }

  void _editVaccination(BuildContext context, Vaccination vaccination) {
    context.push('/add-health-record', extra: vaccination);
  }

  Future<void> _deleteVaccination(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final confirmed = await showRecordDeleteConfirm(context);
    if (confirmed == true) {
      await ref.read(vaccinationsRepositoryProvider)?.delete(id);
    }
  }

  void _editDoctorVisit(BuildContext context, DoctorVisit visit) {
    context.push('/add-health-record', extra: visit);
  }

  Future<void> _deleteDoctorVisit(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final confirmed = await showRecordDeleteConfirm(context);
    if (confirmed == true) {
      await ref.read(doctorVisitsRepositoryProvider)?.delete(id);
    }
  }

  Future<void> _editDocument(
    BuildContext context,
    WidgetRef ref,
    DocumentItem document,
  ) async {
    final repo = ref.read(documentsRepositoryProvider);
    if (repo == null) return;
    final updated = await showAppSheet<DocumentItem>(
      context: context,
      builder: (context) => _EditDocumentSheet(document: document),
    );
    if (updated != null) {
      await repo.updateFields(document.id, updated.toFirestore());
    }
  }

  Future<void> _deleteDocument(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final confirmed = await showRecordDeleteConfirm(
      context,
      message:
          'This removes the record here — the file stays in your Google Drive.',
    );
    if (confirmed == true) {
      await ref.read(documentsRepositoryProvider)?.delete(id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final vaccinationsAsync = ref.watch(vaccinationsProvider);
    final visitsAsync = ref.watch(doctorVisitsProvider);
    final documentsAsync = ref.watch(documentsProvider);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.l,
            AppSpacing.xl,
            AppSpacing.xxl + 64,
          ),
          children: [
            _HealthStatusCard(
              vaccinations: vaccinationsAsync.value ?? const [],
            ),
            const SizedBox(height: AppSpacing.l),
            AppMutedSectionHeader(
              'Vaccinations',
              badge: _SectionBadge(
                '${vaccinationsAsync.value?.length ?? 0} Records',
              ),
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
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.m,
                            ),
                            child: _VaccinationTile(
                              vaccination: v,
                              onAddCard: () =>
                                  _addVaccineCard(context, ref, v.id),
                              onMarkDone: () => ref
                                  .read(vaccinationsRepositoryProvider)
                                  ?.markAdministered(v.id),
                              onEdit: () => _editVaccination(context, v),
                              onDelete: () =>
                                  _deleteVaccination(context, ref, v.id),
                            ),
                          ),
                      ],
                    ),
            ),
            AppMutedSectionHeader(
              'Doctor visits',
              badge: const _SectionBadge('Upcoming & Past'),
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
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.m,
                            ),
                            child: _DoctorVisitTile(
                              visit: v,
                              onEdit: () => _editDoctorVisit(context, v),
                              onDelete: () =>
                                  _deleteDoctorVisit(context, ref, v.id),
                            ),
                          ),
                      ],
                    ),
            ),
            AppMutedSectionHeader(
              'Documents',
              badge: _SectionBadge(
                '${documentsAsync.value?.length ?? 0} Files',
              ),
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
                    mainAxisExtent: 236,
                  ),
                  itemBuilder: (context, i) => _DocumentTile(
                    document: documents[i],
                    onEdit: () => _editDocument(context, ref, documents[i]),
                    onDelete: () =>
                        _deleteDocument(context, ref, documents[i].id),
                  ),
                );
              },
            ),
          ],
        ),
        Positioned(
          right: AppSpacing.xl,
          bottom: AppSpacing.l,
          child: AppExtendedFab(
            icon: LucideIcons.plus,
            label: 'Add Health Record',
            onTap: () => _addHealthRecord(context),
          ),
        ),
      ],
    );
  }
}

class _HealthStatusCard extends StatelessWidget {
  const _HealthStatusCard({required this.vaccinations});

  final List<Vaccination> vaccinations;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final overdue = vaccinations.where(
      (v) => v.status == VaccinationStatus.overdue,
    );
    final protected = overdue.isEmpty;
    final color = protected ? colors.primary : colors.status.overdue;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              protected ? LucideIcons.shield_check : LucideIcons.shield_alert,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Status',
                  style: theme.typography.subtitle.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  protected
                      ? 'Immunizations up to date'
                      : '${overdue.length} vaccination${overdue.length == 1 ? '' : 's'} overdue',
                  style: theme.typography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AppStatusPill(
            label: protected ? 'Protected' : 'Action needed',
            color: color,
          ),
        ],
      ),
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

/// Opens a small "Edit"/"Delete" action sheet for a record tile, returning
/// which one was tapped (or null if dismissed).
Future<_RecordAction?> _showRecordActions(BuildContext context) {
  return showAppSheet<_RecordAction>(
    context: context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RecordActionOption(
          icon: LucideIcons.pencil,
          label: 'Edit',
          onTap: () => Navigator.of(context).pop(_RecordAction.edit),
        ),
        _RecordActionOption(
          icon: LucideIcons.trash,
          label: 'Delete',
          destructive: true,
          onTap: () => Navigator.of(context).pop(_RecordAction.delete),
        ),
        const SizedBox(height: AppSpacing.s),
      ],
    ),
  );
}

enum _RecordAction { edit, delete }

class _RecordActionOption extends StatelessWidget {
  const _RecordActionOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final color = destructive
        ? theme.colors.status.overdue
        : theme.colors.textPrimary;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.m,
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpacing.l),
            Text(
              label,
              style: theme.typography.subtitle.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small "..." trigger for [_showRecordActions], meant to sit in a tile's
/// corner without stealing the tile's own tap target.
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.s),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Icon(
          LucideIcons.ellipsis_vertical,
          size: 18,
          color: colors.textTertiary,
        ),
      ),
    );
  }
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

class _SectionBadge extends StatelessWidget {
  const _SectionBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: theme.colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: theme.typography.label.copyWith(
          color: theme.colors.textSecondary,
        ),
      ),
    );
  }
}

class _RecordAvatar extends StatelessWidget {
  const _RecordAvatar({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _VaccinationTile extends StatelessWidget {
  const _VaccinationTile({
    required this.vaccination,
    required this.onMarkDone,
    required this.onAddCard,
    required this.onEdit,
    required this.onDelete,
  });

  final Vaccination vaccination;
  final VoidCallback onMarkDone;
  final VoidCallback onAddCard;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Future<void> _showActions(BuildContext context) async {
    final action = await _showRecordActions(context);
    switch (action) {
      case _RecordAction.edit:
        onEdit();
      case _RecordAction.delete:
        onDelete();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final status = colors.status;
    final (color, label, icon) = switch (vaccination.status) {
      VaccinationStatus.done => (status.done, 'Done', LucideIcons.check),
      VaccinationStatus.dueSoon => (
        status.dueSoon,
        'Due soon',
        LucideIcons.syringe,
      ),
      VaccinationStatus.overdue => (
        status.overdue,
        'Overdue',
        LucideIcons.syringe,
      ),
    };
    final cardFileId = vaccination.cardDriveFileId;
    final done = vaccination.status == VaccinationStatus.done;

    return AppCard(
      onTap: done ? null : onMarkDone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RecordAvatar(icon: icon, color: color),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text(
                  '${vaccination.name} (Dose ${vaccination.dose})',
                  style: theme.typography.subtitle.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              AppStatusPill(label: label, color: color),
              _MoreButton(onTap: () => _showActions(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Icon(LucideIcons.calendar, size: 14, color: colors.textTertiary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                DateFormat.yMMMd().format(vaccination.scheduledDate),
                style: theme.typography.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const Spacer(),
              TapScale(
                onTap: onAddCard,
                borderRadius: BorderRadius.circular(AppRadii.s),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(AppRadii.s),
                  ),
                  child: Icon(
                    cardFileId == null ? LucideIcons.camera : LucideIcons.image,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (cardFileId != null) ...[
            const SizedBox(height: AppSpacing.s),
            Row(
              children: [
                Icon(LucideIcons.badge_check, size: 14, color: status.done),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Document attached',
                  style: theme.typography.caption.copyWith(color: status.done),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            DriveImage(fileId: cardFileId, height: 140),
          ],
        ],
      ),
    );
  }
}

class _DoctorVisitTile extends StatelessWidget {
  const _DoctorVisitTile({
    required this.visit,
    required this.onEdit,
    required this.onDelete,
  });

  final DoctorVisit visit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Future<void> _showActions(BuildContext context) async {
    final action = await _showRecordActions(context);
    switch (action) {
      case _RecordAction.edit:
        onEdit();
      case _RecordAction.delete:
        onDelete();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final notes = visit.notes?.trim();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RecordAvatar(icon: LucideIcons.stethoscope, color: colors.info),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.reason,
                      style: theme.typography.subtitle.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs / 2),
                    Text(
                      visit.doctorName,
                      style: theme.typography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              AppStatusPill(
                label: DateFormat.yMMMd().format(visit.date),
                color: colors.secondary,
              ),
              _MoreButton(onTap: () => _showActions(context)),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.m),
              decoration: BoxDecoration(
                color: colors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadii.s),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.clipboard_list,
                        size: 14,
                        color: colors.info,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'PEDIATRICIAN NOTES',
                        style: theme.typography.label.copyWith(
                          color: colors.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    notes,
                    style: theme.typography.body.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentTile extends ConsumerWidget {
  const _DocumentTile({
    required this.document,
    required this.onEdit,
    required this.onDelete,
  });

  final DocumentItem document;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  void _openExternally() => launchUrl(
    Uri.parse('https://drive.google.com/file/d/${document.driveFileId}/view'),
  );

  Future<void> _showActions(BuildContext context) async {
    final action = await _showRecordActions(context);
    switch (action) {
      case _RecordAction.edit:
        onEdit();
      case _RecordAction.delete:
        onDelete();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final isImage = isImageMimeType(document.mimeType);
    final isVideo = isVideoMimeType(document.mimeType);
    final imageBytes = isImage
        ? ref.watch(driveImageBytesProvider(document.driveFileId)).value
        : null;

    // Images are viewed in-app (the zoomable viewer DriveImage already uses)
    // rather than sent out to Drive — video and other file types have no
    // in-app renderer (no video/PDF package pulled in for this), so those
    // fall back to opening in the browser/Drive app.
    void open() {
      if (isImage) {
        if (imageBytes != null) showDriveImageViewer(context, imageBytes);
      } else {
        _openExternally();
      }
    }

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.m),
            ),
            child: Stack(
              children: [
                if (isImage)
                  DriveImage(fileId: document.driveFileId, height: 110)
                else
                  Container(
                    height: 110,
                    width: double.infinity,
                    color: colors.surfaceSunken,
                    alignment: Alignment.center,
                    child: Icon(
                      isVideo ? LucideIcons.video : LucideIcons.file_text,
                      size: 32,
                      color: colors.textTertiary,
                    ),
                  ),
                Positioned(
                  left: AppSpacing.s,
                  top: AppSpacing.s,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s,
                      vertical: AppSpacing.xs / 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppRadii.s),
                    ),
                    child: Text(
                      document.category,
                      style: theme.typography.label.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: AppSpacing.xs,
                  top: AppSpacing.xs,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: _MoreButton(onTap: () => _showActions(context)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.s,
              AppSpacing.m,
              AppSpacing.m,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title,
                  style: theme.typography.body.copyWith(
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  'Uploaded ${DateFormat.MMMd().format(document.date)}',
                  style: theme.typography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    variant: AppButtonVariant.secondary,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    onPressed: open,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.eye,
                          size: 14,
                          color: colors.textPrimary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'View',
                          style: theme.typography.label.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
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

/// Flat filled field style shared by every add-sheet in the app (Growth,
/// Memories use the equivalent `TextField` decoration inline; this is
/// Health's, which layers plain-Material `TextField`/`InputDecorator`
/// instead of the shared date-field widgets). No visible border — the
/// `surfaceSunken` fill alone signals "editable" against `colors.surface`
/// sheets, per the Serene Nurture spec.
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

/// Editing a document only lets you rename its title or recategorize it —
/// not re-upload the file itself, which is a new-document flow, not an edit.
class _EditDocumentSheet extends StatefulWidget {
  const _EditDocumentSheet({required this.document});

  final DocumentItem document;

  @override
  State<_EditDocumentSheet> createState() => _EditDocumentSheetState();
}

class _EditDocumentSheetState extends State<_EditDocumentSheet> {
  late final _titleController = TextEditingController(
    text: widget.document.title,
  );
  late String _category = widget.document.category;

  bool get _canSave => _titleController.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      DocumentItem(
        id: widget.document.id,
        date: widget.document.date,
        title: _titleController.text.trim(),
        category: _category,
        driveFileId: widget.document.driveFileId,
        mimeType: widget.document.mimeType,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
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
            'Edit document',
            style: theme.typography.title.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          TextField(
            controller: _titleController,
            style: theme.typography.body.copyWith(
              color: theme.colors.textPrimary,
            ),
            decoration: _fieldDecoration(context, 'Title'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final option in documentCategories)
                AppChip(
                  label: option,
                  selected: _category == option,
                  onTap: () => setState(() => _category = option),
                ),
            ],
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
