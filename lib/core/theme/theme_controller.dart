import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';

/// Four explicit modes — `night` is a genuinely dimmer *true* low-light mode,
/// not derived from `dark`. See docs/DESIGN_SYSTEM.md#9-dark-mode-vs-night-mode.
enum AppThemeMode { light, dark, night, system }

extension AppThemeModeResolution on AppThemeMode {
  /// Resolves `system` against the platform brightness; other modes pass
  /// through unchanged.
  AppThemeMode resolve(Brightness platformBrightness) {
    if (this != AppThemeMode.system) return this;
    return platformBrightness == Brightness.dark
        ? AppThemeMode.dark
        : AppThemeMode.light;
  }

  /// A native Flutter [ThemeMode] fallback for screens not yet migrated off
  /// `Theme.of(context)` (see docs/DESIGN_SYSTEM.md#11-adoption-tracker) —
  /// `night` maps to `dark` since Material itself has no third mode.
  ThemeMode get nativeFallback => switch (this) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark || AppThemeMode.night => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };
}

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => AppThemeMode.system;

  void set(AppThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);

/// Resolves [themeModeProvider] against platform brightness and pushes the
/// resulting [AppTheme] into an [AppThemeScope] for the subtree. Wire this in
/// via `MaterialApp.builder` so it wraps the whole routed app.
class AppThemeProvider extends ConsumerWidget {
  const AppThemeProvider({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref
        .watch(themeModeProvider)
        .resolve(MediaQuery.platformBrightnessOf(context));

    final theme = switch (mode) {
      AppThemeMode.light => AppTheme.light(),
      AppThemeMode.dark => AppTheme.dark(),
      AppThemeMode.night => AppTheme.night(),
      AppThemeMode.system => AppTheme.light(), // unreachable after resolve()
    };

    return AppThemeScope(theme: theme, child: child);
  }
}
