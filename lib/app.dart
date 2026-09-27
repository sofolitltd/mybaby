import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/theme_controller.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'shared/widgets/web_selection_area.dart';

/// Built once — the signed-in app's routes don't depend on any state that
/// changes identity, so there's no need to rebuild the router itself.
final _goRouter = buildRouter();

/// Top-level auth/onboarding gate. Which screen shows is driven entirely by
/// real state — no user → onboarding step 0; signed in with no babies yet →
/// onboarding step 1; a baby exists in Firestore → the main app. See
/// docs/UX.md "Onboarding" and docs/ARCHITECTURE.md#layering.
class MyBabyApp extends ConsumerWidget {
  const MyBabyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => _plainApp(mode, const _LoadingBody()),
      error: (error, _) => _plainApp(mode, _ErrorBody(error: error)),
      data: (user) {
        if (user == null) {
          return _plainApp(
            mode,
            const OnboardingScreen(startAtBabyStep: false),
          );
        }

        final babiesState = ref.watch(babiesStreamProvider);
        return babiesState.when(
          loading: () => _plainApp(mode, const _LoadingBody()),
          error: (error, _) => _plainApp(mode, _ErrorBody(error: error)),
          data: (babies) {
            if (babies.isEmpty) {
              return _plainApp(
                mode,
                const OnboardingScreen(startAtBabyStep: true),
              );
            }
            return MaterialApp.router(
              title: 'MyBaby',
              debugShowCheckedModeBanner: false,
              theme: _blankLight,
              darkTheme: _blankDark,
              themeMode: mode.nativeFallback,
              // SelectionArea is applied per-route in app_router.dart, not
              // here: placed in this builder it would sit above the
              // Navigator's Overlay rather than inside it, which throws
              // "No Overlay widget found" — a currently-open Flutter bug
              // (flutter/flutter#193287).
              builder: (context, child) => AppThemeProvider(child: child!),
              routerConfig: _goRouter,
            );
          },
        );
      },
    );
  }
}

/// Not a design source — real styling comes from [AppThemeProvider] /
/// `AppTheme` below. These exist only so Material's internal plumbing
/// (Scrollbar, form-field defaults, unmigrated screens still on
/// `Theme.of(context)`) has a sane non-null theme to fall back on. See
/// docs/DESIGN_SYSTEM.md#1-purpose and #11-adoption-tracker.
final _blankLight = ThemeData(useMaterial3: true, brightness: Brightness.light);
final _blankDark = ThemeData(useMaterial3: true, brightness: Brightness.dark);

Widget _plainApp(AppThemeMode mode, Widget home) {
  return MaterialApp(
    title: 'MyBaby',
    debugShowCheckedModeBanner: false,
    theme: _blankLight,
    darkTheme: _blankDark,
    themeMode: mode.nativeFallback,
    builder: (context, child) => AppThemeProvider(child: child!),
    // Safe here (unlike the builder above): `home` is placed inside this
    // MaterialApp's own Navigator/Overlay, not above it.
    home: WebSelectionArea(child: home),
  );
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Something went wrong: $error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
