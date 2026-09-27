import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'app_motion.dart';

/// Shows a bottom sheet with a slide-up + fade entrance and no Material
/// chrome — a frosted-glass sheet (same blur/fill/border every other glass
/// surface uses, [AppShadows.floating]) — replacing Material's default sheet
/// motion/styling. See docs/DESIGN_SYSTEM.md#7-motion.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final theme = AppTheme.of(context);
  const radius = BorderRadius.vertical(top: Radius.circular(AppRadii.l));
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: const Color(0x66000000),
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: AppMotion.durationSlow,
      reverseDuration: AppMotion.durationSlow,
    ),
    builder: (sheetContext) => Container(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: AppShadows.floating,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppGlass.blurSigma,
            sigmaY: AppGlass.blurSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colors.glass.fill,
              borderRadius: radius,
              border: Border.all(color: theme.colors.glass.border),
            ),
            child: SafeArea(top: false, child: builder(sheetContext)),
          ),
        ),
      ),
    ),
  );
}
