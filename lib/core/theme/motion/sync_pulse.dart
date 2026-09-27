import 'package:flutter/widgets.dart';

import 'app_motion.dart';

/// Subtle breathing-opacity loop for the sync indicator dot (see
/// docs/UX.md "Sync indicator" — a dot, not a banner, that never interrupts).
/// See docs/DESIGN_SYSTEM.md#7-motion.
class SyncPulse extends StatefulWidget {
  const SyncPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SyncPulse> createState() => _SyncPulseState();
}

class _SyncPulseState extends State<SyncPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.5,
        end: 1.0,
      ).animate(
        CurvedAnimation(parent: _controller, curve: AppMotion.curveStandard),
      ),
      child: widget.child,
    );
  }
}
