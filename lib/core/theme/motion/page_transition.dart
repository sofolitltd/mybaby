import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_motion.dart';

/// Cross-fade + subtle upward slide, replacing go_router/Material's default
/// slide-from-right page transition. See docs/DESIGN_SYSTEM.md#7-motion.
CustomTransitionPage<T> appPageTransition<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: AppMotion.durationMedium,
    reverseTransitionDuration: AppMotion.durationMedium,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.curveStandard,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
