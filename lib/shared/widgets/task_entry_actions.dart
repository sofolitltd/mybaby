import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/sheet_transition.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../data/models/task.dart';
import 'confirm_delete_dialog.dart';
import 'edit_task_sheet.dart';

enum _TaskAction { toggleComplete, edit, delete }

/// Opens the Complete/Edit/Delete sheet for a single task — shared by
/// Home's Tasks section and the full Tasks screen.
Future<void> showTaskEntryActions(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final repo = ref.read(taskRepositoryProvider);
  if (repo == null) return;

  final action = await showAppSheet<_TaskAction>(
    context: context,
    builder: (context) {
      final theme = AppTheme.of(context);
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
              task.title,
              style: theme.typography.title.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            _ActionRow(
              icon: task.completed ? LucideIcons.circle : LucideIcons.check,
              label: task.completed ? 'Mark incomplete' : 'Mark complete',
              color: theme.colors.primary,
              onTap: () => Navigator.of(context).pop(_TaskAction.toggleComplete),
            ),
            _ActionRow(
              icon: LucideIcons.pencil,
              label: 'Edit',
              color: theme.colors.textPrimary,
              onTap: () => Navigator.of(context).pop(_TaskAction.edit),
            ),
            _ActionRow(
              icon: LucideIcons.trash,
              label: 'Delete',
              color: theme.colors.status.overdue,
              onTap: () => Navigator.of(context).pop(_TaskAction.delete),
            ),
          ],
        ),
      );
    },
  );

  if (action == null || !context.mounted) return;
  final notifications = ref.read(notificationServiceProvider);
  final notificationId = notifications.taskNotificationId(task.id);

  switch (action) {
    case _TaskAction.toggleComplete:
      final completing = !task.completed;
      await repo.toggleComplete(task.id, completing);
      if (completing) {
        await notifications.cancelById(notificationId);
      } else if (task.dueDate != null) {
        await notifications.requestPermission();
        await notifications.scheduleAt(
          id: notificationId,
          title: 'Task due: ${task.title}',
          body: task.note?.isNotEmpty == true ? task.note! : 'Tap to open MyBaby',
          dateTime: task.dueDate!,
        );
      }
    case _TaskAction.edit:
      await showEditTaskSheet(context, ref, repo, editing: task);
    case _TaskAction.delete:
      final confirmed = await showConfirmDeleteDialog(
        context,
        title: 'Delete this task?',
        message: 'This task will be permanently removed.',
      );
      if (confirmed == true) {
        await notifications.cancelById(notificationId);
        await repo.delete(task.id);
      }
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
