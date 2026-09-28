import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../data/models/task.dart';

/// A single task row — checkbox to toggle complete, title/note/due-date, and
/// a trailing "..." for edit/delete. Callback-driven (no provider reads) so
/// it's reused as-is by Home's Tasks section and the full Tasks screen, and
/// stays trivially widget-testable.
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onTap,
    required this.onOpenActions,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onOpenActions;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final completed = task.completed;
    final overdue =
        !completed && task.dueDate != null && task.dueDate!.isBefore(DateTime.now());

    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Row(
          children: [
            TapScale(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: completed
                      ? colors.primary.withValues(alpha: 0.14)
                      : colors.surfaceSunken,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  completed ? LucideIcons.check : LucideIcons.circle,
                  size: 14,
                  color: completed ? colors.primary : colors.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: theme.typography.subtitle.copyWith(
                      color: completed ? colors.textTertiary : colors.textPrimary,
                      decoration: completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  if (task.dueDate != null)
                    Text(
                      DateFormat('MMM d, ').add_jm().format(task.dueDate!),
                      style: theme.typography.caption.copyWith(
                        color: overdue ? colors.status.overdue : colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            TapScale(
              onTap: onOpenActions,
              borderRadius: BorderRadius.circular(AppRadii.s),
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s),
                child: Icon(
                  LucideIcons.ellipsis_vertical,
                  size: 18,
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
