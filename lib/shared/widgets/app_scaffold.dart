import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';

/// Thin wrapper around `Scaffold` applying the flat [AppColors.background]
/// canvas fill, safe-area handling, and a slot for the sync indicator —
/// still a real `Scaffold` underneath so keyboard/a11y plumbing is
/// unaffected. See docs/DESIGN_SYSTEM.md#8-components.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.syncIndicator,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;

  /// Optional sync-status widget (see docs/UX.md "Sync indicator") pinned to
  /// the top-right of the safe area, above [body]. Screens that don't need
  /// it (most, until sync status is wired up) leave this null.
  final Widget? syncIndicator;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: appBar,
      body: SafeArea(
        top: appBar == null,
        bottom: bottomNavigationBar == null,
        child: syncIndicator == null
            ? body
            : Stack(
                children: [
                  body,
                  Positioned(top: 0, right: 0, child: syncIndicator!),
                ],
              ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
