import 'package:flutter/material.dart' show LinearProgressIndicator, showDialog;
import 'package:flutter/widgets.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_glass_surface.dart';

/// Shows a non-dismissible upload progress dialog and runs [upload], which
/// reports 0.0–1.0 through the given callback. Always closes the dialog
/// before returning or rethrowing.
Future<T> showUploadProgressDialog<T>(
  BuildContext context, {
  required String title,
  required Future<T> Function(void Function(double progress) onProgress) upload,
}) async {
  final progress = ValueNotifier<double>(0);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final theme = AppTheme.of(context);
      return Center(
        child: AppGlassSurface(
          borderRadius: BorderRadius.circular(AppRadii.m),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (context, value, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.typography.subtitle.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: LinearProgressIndicator(
                      value: value == 0 ? null : value,
                      backgroundColor: theme.colors.surfaceSunken,
                      color: theme.colors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    '${(value * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  try {
    final result = await upload((value) => progress.value = value);
    return result;
  } finally {
    progress.dispose();
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
