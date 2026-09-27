import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../app_theme.dart';
import 'app_motion.dart';
import 'tap_scale.dart';

/// Shows a bottom sheet with a slide-up + fade entrance and no Material
/// chrome — a flat, opaque sheet (`colors.surface`, [AppShadows.modal])
/// replacing Material's default sheet motion/styling, with a close "X"
/// pinned to the top-right corner of every sheet. See
/// docs/DESIGN_SYSTEM.md#6-motion.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final theme = AppTheme.of(context);
  const radius = BorderRadius.vertical(top: Radius.circular(AppRadii.l));
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: const Color(0x4D111827),
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: AppMotion.durationSlow,
      reverseDuration: AppMotion.durationSlow,
    ),
    builder: (sheetContext) => Container(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: radius,
        boxShadow: AppShadows.modal,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.s),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colors.surfaceSunken,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Stack(
              children: [
                builder(sheetContext),
                Positioned(
                  top: AppSpacing.s,
                  right: AppSpacing.s,
                  child: TapScale(
                    onTap: () => Navigator.of(sheetContext).pop(),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s),
                      child: Icon(
                        LucideIcons.x,
                        size: 20,
                        color: theme.colors.textSecondary,
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
}
