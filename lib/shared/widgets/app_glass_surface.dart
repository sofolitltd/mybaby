import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';

/// The single elevated-surface primitive every card, button, nav bar, and
/// sheet in the app is built from — opaque fill, optional hairline border,
/// and one of [AppShadows]'s elevation levels. Replaces the old v2
/// frosted-glass material; see docs/DESIGN_SYSTEM.md#6-radii-borders--elevation.
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.m)),
    this.padding,
    this.shadows = AppShadows.card,
    this.fill,
    this.border = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadows;

  /// Overrides the theme's ambient `colors.surface` — used by [AppButton]'s
  /// primary variant to fill with `colors.primary` instead.
  final Color? fill;

  /// Whether to paint the hairline border — off for surfaces (like the
  /// primary button) that already stand out by fill color alone.
  final bool border;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill ?? colors.surface,
        borderRadius: borderRadius,
        border: border ? Border.all(color: colors.hairline) : null,
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}
