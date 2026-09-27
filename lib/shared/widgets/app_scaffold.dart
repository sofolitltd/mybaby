import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';

/// Thin wrapper around `Scaffold` applying [AppColors.backgroundGradient],
/// safe-area handling, and a slot for the sync indicator — still a real
/// `Scaffold` underneath so keyboard/a11y plumbing is unaffected. The
/// gradient is what every frosted-glass surface (cards, nav, sheets) blurs
/// against. See docs/DESIGN_SYSTEM.md#8-components.
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
    // extendBodyBehindAppBar lets the gradient (and content, if the caller
    // wants it) show through the app bar's frosted blur, so the top bar
    // reads as a glass panel rather than an opaque strip.
    final topInset = appBar == null
        ? 0.0
        : appBar!.preferredSize.height + MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: colors.background,
      extendBodyBehindAppBar: appBar != null,
      appBar: appBar,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors.backgroundGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(top: topInset),
          child: SafeArea(
            top: false,
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
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
