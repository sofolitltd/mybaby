import 'package:flutter/widgets.dart';

/// Status colors used for vaccination/health status pills and the sync
/// indicator. Deliberately warm/muted rather than alarm-style — see
/// docs/DESIGN_SYSTEM.md#3-color.
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
    dueSoon: Color(0xFFD97706),
    overdue: Color(0xFFE07A5F),
  );

  static const _dark = StatusColors(
    done: Color(0xFF6FBBB8),
    dueSoon: Color(0xFFF2A65A),
    overdue: Color(0xFFF0947D),
  );

  static const _night = StatusColors(
    done: Color(0xFF3C6664),
    dueSoon: Color(0xFF8A5A25),
    overdue: Color(0xFF8A5546),
  );
}

/// Bespoke color palette — hand-picked to match the "Serene Nurture" Stitch
/// design system, not derived from a Material `ColorScheme.fromSeed`. Three
/// explicit modes: light, dark, and a genuinely dimmer night mode (not just
/// "darker dark"). Only `light` comes directly from the Stitch spec; `dark`
/// and `night` are derived from the same eucalyptus/amber/coral hue family
/// (brightened for dark, dimmed for night) since the source design is
/// light-only. See docs/DESIGN_SYSTEM.md#3-color.
class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceSunken,
    required this.hairline,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.info,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.status,
  });

  /// Level 0 canvas — the flat background every screen renders behind its
  /// content.
  final Color background;

  /// Level 1 — flat white/near-white card fill.
  final Color surface;

  /// Secondary container tone (tracks, sunken fields, chip backgrounds).
  final Color surfaceSunken;

  /// 1px border color for cards/fields that need edge definition on a
  /// low-contrast background.
  final Color hairline;

  /// Eucalyptus/sage — primary CTA fill, active-nav color, sleep tinting.
  final Color primary;

  /// Warm amber — feed tinting, time-sensitive reminders.
  final Color secondary;

  /// Soft coral — diaper/health tinting, wellness alerts.
  final Color tertiary;

  /// Soft indigo/lavender — sleep tinting only. Not part of the Stitch
  /// spec's named token list, but consistently used for sleep icons across
  /// the Home and Care Log mockups, so it's carried as a fourth accent.
  final Color info;

  /// Label color on a `primary`-filled surface (e.g. `AppButton` primary).
  final Color onPrimary;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final StatusColors status;

  factory AppColors.light() => const AppColors(
    background: Color(0xFFF8F9FA),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF3F4F6),
    hairline: Color(0xFFE5E7EB),
    primary: Color(0xFF2D6A4F),
    secondary: Color(0xFFD97706),
    tertiary: Color(0xFFE07A5F),
    info: Color(0xFF6366F1),
    onPrimary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1F2937),
    textSecondary: Color(0xFF4B5563),
    textTertiary: Color(0xFF9CA3AF),
    status: StatusColors._light,
  );

  factory AppColors.dark() => const AppColors(
    background: Color(0xFF18181B),
    surface: Color(0xFF1F2422),
    surfaceSunken: Color(0xFF262B28),
    hairline: Color(0xFF32382F),
    primary: Color(0xFF52A37A),
    secondary: Color(0xFFF2A65A),
    tertiary: Color(0xFFF0947D),
    info: Color(0xFF8B87F0),
    onPrimary: Color(0xFF0B1F16),
    textPrimary: Color(0xFFECEFEA),
    textSecondary: Color(0xFFAEB6AA),
    textTertiary: Color(0xFF6E7568),
    status: StatusColors._dark,
  );

  /// True low-light mode — near-black background, dimmed accent and status
  /// colors, for logging at night without a bright flash. Distinct from
  /// [dark]; see docs/DESIGN_SYSTEM.md#8-dark-mode-vs-night-mode.
  factory AppColors.night() => const AppColors(
    background: Color(0xFF0A0A0B),
    surface: Color(0xFF141715),
    surfaceSunken: Color(0xFF1B1E1A),
    hairline: Color(0xFF24271F),
    primary: Color(0xFF3F6B54),
    secondary: Color(0xFF8A5A25),
    tertiary: Color(0xFF8A5546),
    info: Color(0xFF4B4894),
    onPrimary: Color(0xFFE9ECE6),
    textPrimary: Color(0xFFA9B0A6),
    textSecondary: Color(0xFF6B7268),
    textTertiary: Color(0xFF45493F),
    status: StatusColors._night,
  );
}
