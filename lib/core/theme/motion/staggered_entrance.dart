import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'app_motion.dart';

/// Fades and slides each child in on screen load, staggered by [interval].
/// Used for list/card content appearing on a screen — see
/// docs/DESIGN_SYSTEM.md#7-motion.
class StaggeredListEntrance extends StatelessWidget {
  const StaggeredListEntrance({
    super.key,
    required this.children,
    this.interval = const Duration(milliseconds: 50),
  });

  final List<Widget> children;
  final Duration interval;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++)
          children[i]
              .animate(delay: interval * i)
              .fadeIn(
                duration: AppMotion.durationMedium,
                curve: AppMotion.curveStandard,
              )
              .slideY(
                begin: 0.06,
                end: 0,
                duration: AppMotion.durationMedium,
                curve: AppMotion.curveStandard,
              ),
      ],
    );
  }
}
