import 'package:flutter/material.dart' show Divider;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/staggered_entrance.dart';
import '../../data/models/task.dart';
import '../babies/widgets/baby_screen_header.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_extended_fab.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_status_pill.dart';
import '../../shared/widgets/edit_task_sheet.dart';
import '../../shared/widgets/task_entry_actions.dart';
import '../../shared/widgets/task_row.dart';

/// Full task list, reached from Home's Tasks section "See all" — open tasks
/// first (soonest due date first), then completed ones. The FAB (matching
/// Health/Growth/Memories' "add" pattern) opens the add-task sheet.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  void _addTask(BuildContext context, WidgetRef ref) {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    showEditTaskSheet(context, ref, repo);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final tasks = ref.watch(tasksProvider).value ?? const [];

    final open = [for (final t in tasks) if (!t.completed) t]
      ..sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
    final completed = [for (final t in tasks) if (t.completed) t]
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            BabyScreenHeader(
              title: 'Tasks',
              showBackButton: false,
              trailing: AppStatusPill(
                label: '${open.length} open',
                color: colors.primary,
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.xxxl,
                    ),
                    children: [
                      StaggeredListEntrance(
                        children: [
                          if (open.isEmpty && completed.isEmpty)
                            const AppEmptyState(
                              icon: LucideIcons.list_checks,
                              message:
                                  'No tasks yet — add one for an errand or appointment.',
                            )
                          else ...[
                            if (open.isNotEmpty)
                              _TaskGroup(title: 'Open', tasks: open, ref: ref),
                            if (completed.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.l),
                              _TaskGroup(
                                title: 'Completed',
                                tasks: completed,
                                ref: ref,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: AppSpacing.xl,
                    bottom: AppSpacing.l,
                    child: AppExtendedFab(
                      icon: LucideIcons.plus,
                      label: 'Add Task',
                      onTap: () => _addTask(context, ref),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskGroup extends StatelessWidget {
  const _TaskGroup({required this.title, required this.tasks, required this.ref});

  final String title;
  final List<Task> tasks;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: theme.typography.label.copyWith(color: colors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.s),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.m),
          child: Column(
            children: [
              for (var i = 0; i < tasks.length; i++) ...[
                if (i != 0) Divider(height: 1, color: colors.hairline),
                TaskRow(
                  task: tasks[i],
                  onToggle: () async {
                    final repo = ref.read(taskRepositoryProvider);
                    if (repo == null) return;
                    final completing = !tasks[i].completed;
                    await repo.toggleComplete(tasks[i].id, completing);
                    final notifications = ref.read(notificationServiceProvider);
                    final id = notifications.taskNotificationId(tasks[i].id);
                    if (completing) {
                      await notifications.cancelById(id);
                    } else if (tasks[i].dueDate != null && tasks[i].notify) {
                      await notifications.requestPermission();
                      await notifications.scheduleAt(
                        id: id,
                        title: 'Task due: ${tasks[i].title}',
                        body: tasks[i].note?.isNotEmpty == true
                            ? tasks[i].note!
                            : 'Tap to open MyBaby',
                        dateTime: tasks[i].dueDate!,
                      );
                    }
                  },
                  onTap: () {
                    final repo = ref.read(taskRepositoryProvider);
                    if (repo == null) return;
                    showEditTaskSheet(context, ref, repo, editing: tasks[i]);
                  },
                  onOpenActions: () => showTaskEntryActions(context, ref, tasks[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
