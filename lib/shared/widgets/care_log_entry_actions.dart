import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/sheet_transition.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../data/models/care_log_entry.dart';
import '../care_log_type_style.dart';
import 'confirm_delete_dialog.dart';
import 'edit_care_log_sheet.dart';

enum _EntryAction { stop, edit, delete }

/// Opens the Stop/Edit/Delete sheet for a single care log entry — shared by
/// Home's Today's Activity list and the Care Log screen so both surfaces
/// offer the same actions per entry.
Future<void> showCareLogEntryActions(
  BuildContext context,
  WidgetRef ref,
  CareLogEntry entry,
) async {
  final repo = ref.read(careLogRepositoryProvider);
  if (repo == null) return;
  final running = isRunningTimer(entry);

  final action = await showAppSheet<_EntryAction>(
    context: context,
    builder: (context) {
      final theme = AppTheme.of(context);
      final (_, label) = careLogTypeIconLabel(entry.type);
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.s,
          AppSpacing.xl,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.typography.title.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            if (running)
              _ActionRow(
                icon: LucideIcons.square,
                label: 'Stop timer',
                color: theme.colors.primary,
                onTap: () => Navigator.of(context).pop(_EntryAction.stop),
              ),
            _ActionRow(
              icon: LucideIcons.pencil,
              label: 'Edit',
              color: theme.colors.textPrimary,
              onTap: () => Navigator.of(context).pop(_EntryAction.edit),
            ),
            _ActionRow(
              icon: LucideIcons.trash,
              label: 'Delete',
              color: theme.colors.status.overdue,
              onTap: () => Navigator.of(context).pop(_EntryAction.delete),
            ),
          ],
        ),
      );
    },
  );

  if (action == null || !context.mounted) return;
  switch (action) {
    case _EntryAction.stop:
      await repo.stop(entry.id, DateTime.now());
    case _EntryAction.edit:
      await showEditCareLogSheet(context, repo, entry);
    case _EntryAction.delete:
      final confirmed = await showConfirmDeleteDialog(
        context,
        title: 'Delete this log?',
        message: 'This care log entry will be permanently removed.',
      );
      if (confirmed == true) await repo.delete(entry.id);
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.l),
            Text(label, style: theme.typography.subtitle.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
