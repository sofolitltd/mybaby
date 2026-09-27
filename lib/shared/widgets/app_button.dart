import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/tap_scale.dart';
import 'app_glass_surface.dart';

enum AppButtonVariant { primary, tonal, secondary }

/// Replaces `FilledButton`/`FilledButton.tonal` — 48×48dp minimum, [TapScale]
/// feedback instead of a ripple. Full pill geometry per the Serene Nurture
/// spec: `primary` is a solid `colors.primary` fill, `tonal` a soft tint of
/// it, `secondary` a hairline-bordered neutral fill. See
/// docs/DESIGN_SYSTEM.md#8-components.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = AppButtonVariant.primary,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.m,
    ),
  });

  final VoidCallback? onPressed;
  final Widget child;
  final AppButtonVariant variant;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    final radius = BorderRadius.circular(AppRadii.pill);
    final disabled = onPressed == null;

    final Color fill;
    final Color foreground;
    final bool border;
    switch (variant) {
      case AppButtonVariant.primary:
        fill = colors.primary;
        foreground = colors.onPrimary;
        border = false;
      case AppButtonVariant.tonal:
        fill = colors.primary.withValues(alpha: 0.12);
        foreground = colors.primary;
        border = false;
      case AppButtonVariant.secondary:
        fill = colors.surfaceSunken;
        foreground = colors.textPrimary;
        border = true;
    }

    final content = Container(
      padding: padding,
      alignment: Alignment.center,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: child,
        ),
      ),
    );

    return TapScale(
      onTap: onPressed,
      borderRadius: radius,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Opacity(
          opacity: disabled ? 0.5 : 1,
          child: AppGlassSurface(
            borderRadius: radius,
            shadows: null,
            fill: fill,
            border: border,
            child: content,
          ),
        ),
      ),
    );
  }
}
