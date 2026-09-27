import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale named for what it's used for, not Material's
/// displayLarge…labelSmall ladder — see docs/DESIGN_SYSTEM.md#4-typography.
/// Styles carry no color; callers apply [AppColors] explicitly.
class AppTypography {
  const AppTypography({
    required this.numeralXL,
    required this.numeralL,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.caption,
    required this.label,
  });

  final TextStyle numeralXL;
  final TextStyle numeralL;
  final TextStyle title;
  final TextStyle subtitle;
  final TextStyle body;
  final TextStyle caption;
  final TextStyle label;

  factory AppTypography.standard() {
    TextStyle jakarta(double size, FontWeight weight, double height) =>
        GoogleFonts.plusJakartaSans(
          fontSize: size,
          fontWeight: weight,
          height: height,
        );

    return AppTypography(
      numeralXL: jakarta(28, FontWeight.w800, 1.1),
      numeralL: jakarta(22, FontWeight.w800, 1.15),
      title: jakarta(16, FontWeight.w800, 1.25),
      subtitle: jakarta(14, FontWeight.w700, 1.3),
      body: jakarta(12, FontWeight.w500, 1.45),
      caption: jakarta(11, FontWeight.w600, 1.4),
      label: jakarta(12, FontWeight.w700, 1.3),
    );
  }
}
