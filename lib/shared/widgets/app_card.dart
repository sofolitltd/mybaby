import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/tap_scale.dart';
import 'app_glass_surface.dart';

/// Frosted-glass surface (blur + tinted fill + highlight border), optional
/// tap feedback via [TapScale]. Replaces `Card` + `InkWell`. See
/// docs/DESIGN_SYSTEM.md#8-components.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final card = AppGlassSurface(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadii.m)),
      padding: padding,
      child: child,
    );

    if (onTap == null) return card;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.m),
      child: card,
    );
  }
}
