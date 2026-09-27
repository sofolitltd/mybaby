import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/tap_scale.dart';

/// Floating icon+label pill action, meant to sit `Positioned` above a
/// scrolling list (bottom-right) rather than docked as a full-width bar —
/// used by Health, Growth, and Memories' primary "add" actions. See
/// docs/DESIGN_SYSTEM.md#6-radii-borders--elevation for the [AppShadows.nav]
/// elevation level this borrows.
class AppExtendedFab extends StatelessWidget {
  const AppExtendedFab({
    super.key,
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
    final colors = theme.colors;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: AppShadows.nav,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: colors.onPrimary),
            const SizedBox(width: AppSpacing.s),
            Text(
              label,
              style: theme.typography.label.copyWith(color: colors.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
