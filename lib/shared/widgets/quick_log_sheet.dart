import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar, SnackBarAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/sheet_transition.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../data/firestore/care_log_repository.dart';
import '../../data/models/care_log_entry.dart';
import 'app_button.dart';

/// One-tap logging bottom sheet — no confirm step, per docs/UX.md
/// "Undo, not confirm". Diaper logs instantly on tap; feed/sleep start a timer.
Future<void> showQuickLogSheet(
  BuildContext context,
  WidgetRef ref,
  CareLogType type,
) {
  final repo = ref.read(careLogRepositoryProvider);
  if (repo == null) return Future.value();
  if (type == CareLogType.diaper) {
    return _showDiaperSheet(context, repo);
  }
  return _showTimerSheet(context, repo, type);
}

Future<void> _showDiaperSheet(BuildContext context, CareLogRepository repo) {
  return showAppSheet(
    context: context,
    builder: (context) {
      final theme = AppTheme.of(context);
      Widget option(String label, IconData icon) => _SheetOption(
        icon: icon,
        label: label,
        onTap: () async {
          Navigator.of(context).pop();
          final id = await repo.add(
            CareLogEntry(
              id: '',
              type: CareLogType.diaper,
              startTime: DateTime.now(),
              subtype: label,
            ),
          );
          if (context.mounted) {
            _snack(context, 'Diaper logged — $label', () => repo.delete(id));
          }
        },
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.s,
              AppSpacing.xl,
              AppSpacing.s,
            ),
            child: Text(
              'Diaper',
              style: theme.typography.title.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
          ),
          option('Wet', LucideIcons.droplet),
          option('Dirty', LucideIcons.leaf),
          option('Both', LucideIcons.check_check),
          const SizedBox(height: AppSpacing.s),
        ],
      );
    },
  );
}

Future<void> _showTimerSheet(
  BuildContext context,
  CareLogRepository repo,
  CareLogType type,
) {
  final label = type == CareLogType.feed ? 'Feed' : 'Sleep';
  final icon = type == CareLogType.feed
      ? LucideIcons.glass_water
      : LucideIcons.moon;
  final startedAt = DateTime.now();
  return showAppSheet(
    context: context,
    builder: (context) {
      final theme = AppTheme.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.s,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: theme.colors.primary),
            const SizedBox(height: AppSpacing.s),
            Text(
              '$label timer running',
              style: theme.typography.title.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Started just now — leave the app, it keeps running.',
              textAlign: TextAlign.center,
              style: theme.typography.body.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final id = await repo.add(
                    CareLogEntry(
                      id: '',
                      type: type,
                      startTime: startedAt,
                      endTime: DateTime.now(),
                    ),
                  );
                  if (context.mounted) {
                    _snack(context, '$label logged', () => repo.delete(id));
                  }
                },
                child: Text(
                  'Stop and save',
                  style: theme.typography.label.copyWith(
                    color: theme.colors.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
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
            Icon(icon, color: theme.colors.textSecondary),
            const SizedBox(width: AppSpacing.l),
            Text(
              label,
              style: theme.typography.subtitle.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// AppSnackbar isn't built yet (see docs/DESIGN_SYSTEM.md#8-components) — the
// Material SnackBar is the documented interim fallback.
void _snack(BuildContext context, String message, VoidCallback onUndo) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(label: 'Undo', onPressed: onUndo),
    ),
  );
}
