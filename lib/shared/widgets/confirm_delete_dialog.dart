import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';
import 'app_button.dart';
import 'app_glass_surface.dart';

/// Confirm-before-delete dialog shared by health records and care log
/// entries — these are deliberate records someone typed in (or a running
/// timer someone is about to cancel), not the quick-log "Undo, not confirm"
/// taps docs/UX.md describes, so a confirm step (rather than
/// delete-then-offer-undo) is the safer default.
Future<bool?> showConfirmDeleteDialog(
  BuildContext context, {
  String title = 'Delete this record?',
  String message = 'This record will be permanently removed.',
}) {
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
                  title,
                  style: theme.typography.subtitle.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: theme.typography.body.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        variant: AppButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          'Cancel',
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
                          'Delete',
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
