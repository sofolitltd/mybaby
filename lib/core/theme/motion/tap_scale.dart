import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Wraps any tappable and scales it down slightly on press, replacing
/// Material's `InkWell` ripple everywhere in the custom design system. See
/// docs/DESIGN_SYSTEM.md#7-motion.
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppMotion.durationFast,
        curve: AppMotion.curveStandard,
        child: widget.child,
      ),
    );
  }
}
