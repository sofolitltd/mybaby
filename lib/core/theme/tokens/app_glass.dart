import 'package:flutter/widgets.dart';

/// Frosted-glass fill/border pair for one theme mode. Every translucent
/// surface in the app (nav, sheets, cards, app bar) is built from the same
/// pair + [AppGlass.blurSigma] — see docs/DESIGN_SYSTEM.md#3-color.
class GlassColors {
  const GlassColors({
    required this.fill,
    required this.border,
    required this.prominentFill,
  });

  final Color fill;
  final Color border;

  /// A brighter white fill reserved for the primary CTA button — the
  /// iOS-26/27-style "Liquid Glass" prominent control: white and translucent
  /// rather than colored, standing out from ambient glass by brightness, not
  /// hue. See docs/DESIGN_SYSTEM.md#8-components (`AppButton`).
  final Color prominentFill;

  // Light mode's fill is a grey-tinted white (not pure white) at higher
  // opacity than v2's original 55% — against a near-white background,
  // translucency alone doesn't read as a distinct raised surface, so the
  // fill needs its own tint + more coverage to look like a container rather
  // than the same white as the page behind it.
  static const light = GlassColors(
    fill: Color(0xF0EDEDF1),
    border: Color(0xCCFFFFFF),
    prominentFill: Color(0xE6FFFFFF),
  );

  static const dark = GlassColors(
    fill: Color(0x40FFFFFF),
    border: Color(0x4DFFFFFF),
    prominentFill: Color(0xB3FFFFFF),
  );

  static const night = GlassColors(
    fill: Color(0x26FFFFFF),
    border: Color(0x30FFFFFF),
    prominentFill: Color(0x40FFFFFF),
  );
}

/// The single blur radius every frosted surface uses — one glass "material"
/// throughout the app rather than a one-off effect per screen. See
/// docs/DESIGN_SYSTEM.md#6-radii-borders--elevation.
class AppGlass {
  const AppGlass._();

  static const double blurSigma = 20;
}
