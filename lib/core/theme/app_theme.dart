import 'package:flutter/widgets.dart';

import 'tokens/app_colors.dart';
import 'tokens/app_typography.dart';

export 'tokens/app_colors.dart';
export 'tokens/app_glass.dart';
export 'tokens/app_radii.dart';
export 'tokens/app_shadows.dart';
export 'tokens/app_spacing.dart';
export 'tokens/app_typography.dart';

/// The bespoke design-system token bundle — colors and typography vary by
/// mode; spacing/radii/motion are static consts read directly from their own
/// token classes. See docs/DESIGN_SYSTEM.md.
class AppTheme {
  const AppTheme({
    required this.colors,
    required this.typography,
    required this.isDark,
  });

  final AppColors colors;
  final AppTypography typography;
  final bool isDark;

  factory AppTheme.light() =>
      AppTheme(colors: AppColors.light(), typography: _typography, isDark: false);

  factory AppTheme.dark() =>
      AppTheme(colors: AppColors.dark(), typography: _typography, isDark: true);

  factory AppTheme.night() =>
      AppTheme(colors: AppColors.night(), typography: _typography, isDark: true);

  static final AppTypography _typography = AppTypography.standard();

  static AppTheme of(BuildContext context) => AppThemeScope.of(context);
}

/// Cheap `InheritedWidget` lookup for [AppTheme] — widgets call
/// `AppTheme.of(context)` instead of `Theme.of(context)`.
class AppThemeScope extends InheritedWidget {
  const AppThemeScope({super.key, required this.theme, required super.child});

  final AppTheme theme;

  static AppTheme of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'No AppThemeScope found in context');
    return scope!.theme;
  }

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) =>
      oldWidget.theme.isDark != theme.isDark ||
      oldWidget.theme.colors != theme.colors;
}
