import 'package:flutter/widgets.dart';

import 'app_glass.dart';

/// Status colors used for vaccination/health status pills and the sync
/// indicator. Deliberately warm/muted rather than alarm-style — see
/// docs/DESIGN_SYSTEM.md#3-color. Semantic, so untouched by the v2 glass
/// redesign.
class StatusColors {
  const StatusColors({
    required this.done,
    required this.dueSoon,
    required this.overdue,
  });

  final Color done;
  final Color dueSoon;
  final Color overdue;

  static const _light = StatusColors(
    done: Color(0xFF4C8C8A),
    dueSoon: Color(0xFFDE9A3C),
    overdue: Color(0xFFC96A57),
  );

  static const _night = StatusColors(
    done: Color(0xFF375F5D),
    dueSoon: Color(0xFFA5722C),
    overdue: Color(0xFF95503F),
  );
}

/// Bespoke color palette — hand-picked per docs/DESIGN_SYSTEM.md, not derived
/// from a Material `ColorScheme.fromSeed`. Three explicit modes: light, dark,
/// and a genuinely dimmer night mode (not just "darker dark").
class AppColors {
  const AppColors({
    required this.backgroundGradient,
    required this.surface,
    required this.surfaceSunken,
    required this.hairline,
    required this.primary,
    required this.accent,
    required this.onPrimary,
    required this.onGlassProminent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.status,
    required this.glass,
  });

  /// Two-stop backdrop gradient every screen renders behind its content —
  /// the subtle depth that frosted glass surfaces blur against. Replaces the
  /// old flat `background` color.
  final List<Color> backgroundGradient;
  final Color surface;
  final Color surfaceSunken;
  final Color hairline;

  /// Quick-log accent and active-nav indicator. Paired with [accent] for the
  /// primary-CTA gradient — never used as a general fill color.
  final Color primary;

  /// Bold secondary accent introduced in the v2 glass redesign — pairs with
  /// [primary] in gradients (primary CTA, active nav pill); never used alone
  /// as a status color.
  final Color accent;
  final Color onPrimary;

  /// Label color for [AppButton]'s primary variant, whose fill is now a
  /// brightness-varying white glass rather than a colored gradient — so the
  /// legible label color depends on how light that mode's prominent glass
  /// reads, not on the mode's ambient `textPrimary`.
  final Color onGlassProminent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final StatusColors status;
  final GlassColors glass;

  /// Convenience solid fallback for contexts that can't render a gradient
  /// (e.g. the OS status bar). The gradient's first stop.
  Color get background => backgroundGradient.first;

  factory AppColors.light() => const AppColors(
    backgroundGradient: [Color(0xFFFFFFFF), Color(0xFFF2F2F4)],
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEFEAE0),
    hairline: Color(0xFFDEDAD0),
    primary: Color(0xFF2F7A54),
    accent: Color(0xFF6C5CE0),
    onPrimary: Color(0xFFFFFFFF),
    onGlassProminent: Color(0xFF23271F),
    textPrimary: Color(0xFF23271F),
    textSecondary: Color(0xFF5F6A5A),
    textTertiary: Color(0xFF93998C),
    status: StatusColors._light,
    glass: GlassColors.light,
  );

  factory AppColors.dark() => const AppColors(
    backgroundGradient: [Color(0xFF18181B), Color(0xFF1E1E21)],
    surface: Color(0xFF20241D),
    surfaceSunken: Color(0xFF12140F),
    hairline: Color(0xFF2E332A),
    primary: Color(0xFF6FBE95),
    accent: Color(0xFF9C8FFF),
    onPrimary: Color(0xFF12140F),
    onGlassProminent: Color(0xFF20241D),
    textPrimary: Color(0xFFECF0E6),
    textSecondary: Color(0xFFAAB3A0),
    textTertiary: Color(0xFF6E7568),
    status: StatusColors._light,
    glass: GlassColors.dark,
  );

  /// True low-light mode — near-black background, dimmed accent and status
  /// colors, minimal glass opacity, for logging at night without a bright
  /// flash. Distinct from [dark]; see
  /// docs/DESIGN_SYSTEM.md#9-dark-mode-vs-night-mode.
  factory AppColors.night() => const AppColors(
    backgroundGradient: [Color(0xFF0A0A0B), Color(0xFF0E0E10)],
    surface: Color(0xFF12140F),
    surfaceSunken: Color(0xFF060704),
    hairline: Color(0xFF1C1F18),
    primary: Color(0xFF3F6B54),
    accent: Color(0xFF4E4590),
    onPrimary: Color(0xFF0A0C08),
    onGlassProminent: Color(0xFFECF0E6),
    textPrimary: Color(0xFFB9C2AE),
    textSecondary: Color(0xFF6D7566),
    textTertiary: Color(0xFF454A40),
    status: StatusColors._night,
    glass: GlassColors.night,
  );
}
