import 'package:flutter/material.dart';

/// Material 3 window-size breakpoints, per docs/UX.md "left rail (web/tablet
/// width)". Below [wide], navigation is a bottom bar; at/above it, a side rail.
const double kWideBreakpoint = 840;
const double kExpandedRailBreakpoint = 1200;

/// Max width for readable content on large screens — an app this
/// information-dense shouldn't stretch edge-to-edge on a desktop monitor.
const double kContentMaxWidth = 720;

bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;

/// Centers [child] and caps its width on wide viewports; a no-op on phones.
class ContentColumn extends StatelessWidget {
  const ContentColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: child,
      ),
    );
  }
}
