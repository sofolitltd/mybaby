import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/sheet_transition.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../data/models/memory.dart';
import 'confirm_delete_dialog.dart';

enum _MemoryAction { edit, delete }

/// Opens the Edit/Delete sheet for a single memory — mirrors
/// `showCareLogEntryActions` so memories get the same edit/delete pattern
/// as care log entries and health records.
Future<void> showMemoryActions(
  BuildContext context,
  WidgetRef ref,
  Memory memory,
) async {
  final repo = ref.read(memoriesRepositoryProvider);
  if (repo == null) return;

  final action = await showAppSheet<_MemoryAction>(
    context: context,
    builder: (context) {
      final theme = AppTheme.of(context);
      final heading = memory.title.isNotEmpty ? memory.title : memory.caption;
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
              heading,
              style: theme.typography.title.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            _ActionRow(
              icon: LucideIcons.pencil,
              label: 'Edit',
              color: theme.colors.textPrimary,
              onTap: () => Navigator.of(context).pop(_MemoryAction.edit),
            ),
            _ActionRow(
              icon: LucideIcons.trash,
              label: 'Delete',
              color: theme.colors.status.overdue,
              onTap: () => Navigator.of(context).pop(_MemoryAction.delete),
            ),
          ],
        ),
      );
    },
  );

  if (action == null || !context.mounted) return;
  switch (action) {
    case _MemoryAction.edit:
      context.push('/add-memory', extra: memory);
    case _MemoryAction.delete:
      final confirmed = await showConfirmDeleteDialog(
        context,
        title: 'Delete this memory?',
        message: 'This memory will be permanently removed.',
      );
      if (confirmed == true) await repo.delete(memory.id);
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
