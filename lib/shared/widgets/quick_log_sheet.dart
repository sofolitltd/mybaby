import 'package:flutter/material.dart'
    show ScaffoldMessenger, ScaffoldMessengerState, SnackBar, SnackBarAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/sheet_transition.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../data/firestore/care_log_repository.dart';
import '../../data/models/care_log_entry.dart';
import '../../features/care_log/providers/active_care_log_timers_provider.dart';
import 'app_button.dart';

/// One-tap logging bottom sheet — no confirm step, per docs/UX.md
/// "Undo, not confirm". Diaper logs instantly on tap; feed/sleep start a
/// timer that's persisted immediately (so it survives dismissing this
/// sheet) and shown on Home until stopped.
Future<void> showQuickLogSheet(
  BuildContext context,
  WidgetRef ref,
  CareLogType type,
) async {
  final repo = ref.read(careLogRepositoryProvider);
  if (repo == null) return;
  if (type == CareLogType.diaper) {
    return _showDiaperSheet(context, repo);
  }

  CareLogEntry? existing;
  for (final e in ref.read(activeCareLogTimersProvider)) {
    if (e.type == type) {
      existing = e;
      break;
    }
  }

  final String id;
  final DateTime startedAt;
  if (existing != null) {
    id = existing.id;
    startedAt = existing.startTime;
  } else {
    startedAt = DateTime.now();
    id = await repo.add(
      CareLogEntry(id: '', type: type, startTime: startedAt),
    );
  }

  if (!context.mounted) return;
  return _showTimerSheet(context, repo, type, id: id, startedAt: startedAt);
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
          // Captured before popping: the sheet's context is unmounted mid
          // pop-animation, and calling ScaffoldMessenger.of(context) after
          // that leaves the SnackBar's dismiss timer tied to a disposed
          // ticker, so it shows but never auto-closes.
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(context).pop();
          final id = await repo.add(
            CareLogEntry(
              id: '',
              type: CareLogType.diaper,
              startTime: DateTime.now(),
              subtype: label,
            ),
          );
          _snack(messenger, 'Diaper logged — $label', () => repo.delete(id));
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
  CareLogType type, {
  required String id,
  required DateTime startedAt,
}) {
  final label = type == CareLogType.feed ? 'Feed' : 'Sleep';
  final icon = type == CareLogType.feed
      ? LucideIcons.glass_water
      : LucideIcons.moon;
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
              'Started ${DateFormat.jm().format(startedAt)} — leave the app, it keeps running.',
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
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(context).pop();
                  await repo.stop(id, DateTime.now());
                  _snack(messenger, '$label logged', () => repo.resume(id));
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
void _snack(
  ScaffoldMessengerState messenger,
  String message,
  VoidCallback onUndo,
) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(label: 'Undo', onPressed: onUndo),
      showCloseIcon: true,
    ),
  );
}
