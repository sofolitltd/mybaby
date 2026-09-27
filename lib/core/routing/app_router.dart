import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/babies/add_baby_screen.dart';
import '../../features/babies/edit_baby_screen.dart';
import '../../data/models/baby.dart';
import '../../data/models/doctor_visit.dart';
import '../../data/models/vaccination.dart';
import '../../features/care_log/care_log_screen.dart';
import '../../features/growth/growth_screen.dart';
import '../../features/health/health_screen.dart';
import '../../features/health/widgets/add_health_record_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/memories/memories_screen.dart';
import '../../features/memories/widgets/add_memory_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../shared/widgets/web_selection_area.dart';
import '../theme/motion/page_transition.dart';

/// Routes for the signed-in app only — the signed-out / not-yet-onboarded
/// states are handled entirely by app.dart's AuthGate, outside this router.
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return WebSelectionArea(
            child: AppShell(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) =>
                    const _Titled(title: 'Home', child: HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/growth',
                builder: (context, state) =>
                    const _Titled(title: 'Growth', child: GrowthScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/memories',
                builder: (context, state) =>
                    const _Titled(title: 'Memories', child: MemoriesScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/health',
                builder: (context, state) =>
                    const _Titled(title: 'Health', child: HealthScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/care-log',
                builder: (context, state) =>
                    const _Titled(title: 'Care Log', child: CareLogScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => appPageTransition(
          key: state.pageKey,
          child: const _Titled(
            title: 'Settings',
            child: WebSelectionArea(child: SettingsScreen()),
          ),
        ),
      ),
      GoRoute(
        path: '/add-baby',
        pageBuilder: (context, state) => appPageTransition(
          key: state.pageKey,
          child: const _Titled(
            title: 'Add Baby',
            child: WebSelectionArea(child: AddBabyScreen()),
          ),
        ),
      ),
      GoRoute(
        path: '/edit-baby',
        pageBuilder: (context, state) => appPageTransition(
          key: state.pageKey,
          child: _Titled(
            title: 'Edit Baby',
            child: WebSelectionArea(
              child: EditBabyScreen(baby: state.extra as Baby),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/add-health-record',
        pageBuilder: (context, state) {
          final extra = state.extra;
          return appPageTransition(
            key: state.pageKey,
            child: _Titled(
              title: extra == null ? 'Add Health Record' : 'Edit Health Record',
              child: WebSelectionArea(
                child: AddHealthRecordScreen(
                  editingVaccination: extra is Vaccination ? extra : null,
                  editingDoctorVisit: extra is DoctorVisit ? extra : null,
                ),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/add-memory',
        pageBuilder: (context, state) => appPageTransition(
          key: state.pageKey,
          child: const _Titled(
            title: 'Add Memory',
            child: WebSelectionArea(child: AddMemoryScreen()),
          ),
        ),
      ),
    ],
  );
}

/// Sets the browser tab title per page on web; a no-op wrapper elsewhere.
class _Titled extends StatelessWidget {
  const _Titled({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Title(
      title: '$title · MyBaby',
      // Only used by the OS (browser tab / recent-apps tint), not rendered —
      // but Title asserts its color is fully opaque, so this can't be
      // Colors.transparent.
      color: Colors.black,
      child: child,
    );
  }
}
