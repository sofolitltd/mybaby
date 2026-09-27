import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';

/// Icon + a **required** text label on a soft status-tinted background.
/// Replaces `Chip`. The label is required so color is never the app's only
/// signal for status — see docs/DESIGN_SYSTEM.md#8-components.
class AppStatusPill extends StatelessWidget {
  const AppStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final typography = AppTheme.of(context).typography;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: typography.label.copyWith(color: color)),
        ],
      ),
    );
  }
}
