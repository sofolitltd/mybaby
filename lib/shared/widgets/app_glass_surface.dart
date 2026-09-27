import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';

/// The one frosted-glass container every translucent surface in the app is
/// built from — backdrop blur + tinted fill + hairline-highlight border, all
/// pinned to [AppGlass.blurSigma] and the current mode's [AppColors.glass].
/// Used by [AppCard], the floating nav pill, and bottom sheets so "glass"
/// reads as one consistent material, never a one-off effect per screen. See
/// docs/DESIGN_SYSTEM.md#3-color.
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.m)),
    this.padding,
    this.shadows = AppShadows.glass,
    this.fill,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadows;

  /// Overrides the theme's ambient `colors.glass.fill` — used by
  /// [AppButton]'s primary variant to fill with `colors.glass.prominentFill`
  /// instead, without duplicating the blur/border/clip plumbing.
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final glass = AppTheme.of(context).colors.glass;
    return Container(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadows),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppGlass.blurSigma,
            sigmaY: AppGlass.blurSigma,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill ?? glass.fill,
              borderRadius: borderRadius,
              border: Border.all(color: glass.border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
