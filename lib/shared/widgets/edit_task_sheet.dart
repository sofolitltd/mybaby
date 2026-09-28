import 'package:flutter/material.dart' show TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/sheet_transition.dart';
import '../../data/firestore/task_repository.dart';
import '../../data/models/task.dart';
import 'app_button.dart';
import 'app_toggle.dart';
import 'manual_care_log_sheet.dart' show sheetFieldDecoration;
import 'sheet_time_field.dart';

/// Add/edit sheet for a Task: title, optional note, optional due date+time.
/// Schedules (or cancels/reschedules) the due-date notification on save.
Future<void> showEditTaskSheet(
  BuildContext context,
  WidgetRef ref,
  TaskRepository repo, {
  Task? editing,
}) {
  return showAppSheet(
    context: context,
    builder: (context) => _EditTaskSheet(ref: ref, repo: repo, editing: editing),
  );
}

class _EditTaskSheet extends StatefulWidget {
  const _EditTaskSheet({required this.ref, required this.repo, this.editing});

  final WidgetRef ref;
  final TaskRepository repo;
  final Task? editing;

  @override
  State<_EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends State<_EditTaskSheet> {
  late final _titleController = TextEditingController(
    text: widget.editing?.title,
  );
  late final _noteController = TextEditingController(text: widget.editing?.note);
  DateTime? _dueDate;
  late bool _notify = widget.editing?.notify ?? true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.editing?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await pickSheetDateTime(
      context,
      initial: _dueDate ?? DateTime.now().add(const Duration(hours: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      timeOptional: true,
    );
    if (picked == null) return;
    setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);

    final note = _noteController.text.trim();
    final notifications = widget.ref.read(notificationServiceProvider);
    final editing = widget.editing;

    String taskId;
    if (editing == null) {
      taskId = await widget.repo.add(
        Task(
          id: '',
          title: title,
          note: note.isEmpty ? null : note,
          dueDate: _dueDate,
          notify: _notify,
          createdAt: DateTime.now(),
        ),
      );
    } else {
      taskId = editing.id;
      await widget.repo.updateDetails(
        taskId,
        title: title,
        note: note.isEmpty ? null : note,
        dueDate: _dueDate,
        notify: _notify,
      );
    }

    final notificationId = notifications.taskNotificationId(taskId);
    await notifications.cancelById(notificationId);
    if (_dueDate != null && _notify && editing?.completed != true) {
      await notifications.requestPermission();
      await notifications.scheduleAt(
        id: notificationId,
        title: 'Task due: $title',
        body: note.isEmpty ? 'Tap to open MyBaby' : note,
        dateTime: _dueDate!,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.s,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.editing == null ? 'Add Task' : 'Edit Task',
            style: theme.typography.title.copyWith(color: theme.colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            'TITLE',
            style: theme.typography.label.copyWith(color: theme.colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.s),
          TextField(
            controller: _titleController,
            autofocus: widget.editing == null,
            style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
            decoration: sheetFieldDecoration(context, 'e.g. Buy diapers'),
          ),
          const SizedBox(height: AppSpacing.l),
          SheetTimeField(
            label: _dueDate == null ? 'ADD DUE DATE' : 'DUE',
            value: _dueDate ?? DateTime.now(),
            onTap: _pickDueDate,
          ),
          if (_dueDate != null) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButtonLike(
                label: 'Clear due date',
                onTap: () => setState(() => _dueDate = null),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Remind me',
                    style: theme.typography.body.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                ),
                AppToggle(
                  value: _notify,
                  onChanged: (value) => setState(() => _notify = value),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.l),
          Text(
            'NOTE',
            style: theme.typography.label.copyWith(color: theme.colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.s),
          TextField(
            controller: _noteController,
            maxLines: 3,
            style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
            decoration: sheetFieldDecoration(context, 'Optional note'),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: _saving ? null : _save,
              child: Text(
                'Save',
                style: theme.typography.label.copyWith(color: theme.colors.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TextButtonLike extends StatelessWidget {
  const TextButtonLike({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(
          label,
          style: theme.typography.label.copyWith(color: theme.colors.primary),
        ),
      ),
    );
  }
}
