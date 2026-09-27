import 'package:flutter/widgets.dart';

/// Elevation levels for the flat "Serene Nurture" surface system — visual
/// separation comes from soft ambient shadows, not borders or blur. See
/// docs/DESIGN_SYSTEM.md#6-radii-borders--elevation.
class AppShadows {
  const AppShadows._();

  /// Level 1 — cards resting on the canvas.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A111827), blurRadius: 20, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x05111827), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// Level 2 — docked/floating navigation and floating action surfaces.
  static const List<BoxShadow> nav = [
    BoxShadow(color: Color(0x14111827), blurRadius: 32, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x08111827), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Level 3 — modals and bottom sheets, shadow diffused upward.
  static const List<BoxShadow> modal = [
    BoxShadow(color: Color(0x14000000), blurRadius: 30, offset: Offset(0, -8)),
  ];
}
