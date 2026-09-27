import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/babies/add_baby_screen.dart';
import '../../features/babies/edit_baby_screen.dart';
import '../../data/models/baby.dart';
import '../../features/care_log/care_log_screen.dart';
import '../../features/growth/growth_screen.dart';
import '../../features/health/health_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/memories/memories_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../theme/motion/page_transition.dart';

/// Routes for the signed-in app only — the signed-out / not-yet-onboarded
/// states are handled entirely by app.dart's AuthGate, outside this router.
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return SelectionArea(
            child: AppShell(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/growth',
                builder: (context, state) => const GrowthScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/memories',
                builder: (context, state) => const MemoriesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/health',
                builder: (context, state) => const HealthScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/care-log',
                builder: (context, state) => const CareLogScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => appPageTransition(
          key: state.pageKey,
          child: const SelectionArea(child: SettingsScreen()),
        ),
      ),
      GoRoute(
        path: '/add-baby',
        pageBuilder: (context, state) => appPageTransition(
          key: state.pageKey,
          child: const SelectionArea(child: AddBabyScreen()),
        ),
      ),
      GoRoute(
        path: '/edit-baby',
        pageBuilder: (context, state) => appPageTransition(
          key: state.pageKey,
          child: SelectionArea(child: EditBabyScreen(baby: state.extra as Baby)),
        ),
      ),
    ],
  );
}
