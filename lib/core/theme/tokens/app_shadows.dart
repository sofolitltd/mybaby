import 'package:flutter/widgets.dart';

/// Shadows for surfaces genuinely above the flow — sheets/snackbars, and
/// (v2) every frosted-glass surface, which floats over the background
/// gradient by design. Never used for flat/solid content. See
/// docs/DESIGN_SYSTEM.md#6-radii-borders--elevation.
class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 32, offset: Offset(0, 8)),
  ];

  /// Softer, wider spread than [floating] — used behind glass cards and the
  /// floating pill nav so they read as sitting just above the gradient.
  static const List<BoxShadow> glass = [
    BoxShadow(color: Color(0x21000000), blurRadius: 44, offset: Offset(0, 18)),
  ];
}
