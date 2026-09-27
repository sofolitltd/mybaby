import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show SelectionArea;
import 'package:flutter/widgets.dart';

/// Wraps [child] in a [SelectionArea] on web only — text selection is a
/// desktop-browser affordance (copy a growth number, a note, etc.); on
/// mobile/desktop app builds it just fights with scroll/drag gestures and
/// long-press context menus, so native builds get [child] unchanged.
class WebSelectionArea extends StatelessWidget {
  const WebSelectionArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return kIsWeb ? SelectionArea(child: child) : child;
  }
}
