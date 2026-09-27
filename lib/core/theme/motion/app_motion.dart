import 'package:flutter/animation.dart';

/// Motion tokens — calm and elegant, not playful: longer-than-Material
/// durations, one consistent easing family, never bounce/overshoot. See
/// docs/DESIGN_SYSTEM.md#7-motion.
class AppMotion {
  const AppMotion._();

  /// Steeper deceleration than [Curves.easeOut], no overshoot.
  static const Curve curveStandard = Cubic(0.2, 0.0, 0, 1.0);

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 260);
  static const Duration durationSlow = Duration(milliseconds: 420);
}
