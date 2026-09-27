import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/app_motion.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/baby_switcher_sheet.dart';

const _kRailWidth = 88.0;

/// Persistent nav shell — a floating glass pill nav on phones, a floating
/// glass rail on wide/web viewports — plus the always-visible baby switcher.
/// See docs/UX.md "Navigation model" and docs/DESIGN_SYSTEM.md#8-components.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (icon: LucideIcons.house, label: 'Home'),
    (icon: LucideIcons.scale, label: 'Growth'),
    (icon: LucideIcons.book_open, label: 'Memories'),
    (icon: LucideIcons.heart_pulse, label: 'Health'),
    (icon: LucideIcons.list_checks, label: 'Care Log'),
  ];

  void _onSelect(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = isWideLayout(context);
    final baby = ref.watch(activeBabyProvider);

    final nav = wide
        ? _AppNavRail(
            currentIndex: navigationShell.currentIndex,
            destinations: _destinations,
            onSelect: _onSelect,
          )
        : _AppBottomNav(
            currentIndex: navigationShell.currentIndex,
            destinations: _destinations,
            onSelect: _onSelect,
          );

    return AppScaffold(
      appBar: _AppTopBar(
        babyName: baby?.name,
        babyAgeWeeks: baby?.ageInWeeks,
        babyEmoji: baby?.avatarEmoji,
      ),
      body: wide
          ? Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: _kRailWidth + AppSpacing.l,
                  ),
                  child: ContentColumn(child: navigationShell),
                ),
                Positioned(
                  left: AppSpacing.l,
                  top: AppSpacing.l,
                  bottom: AppSpacing.l,
                  child: nav,
                ),
              ],
            )
          : Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 84),
                  child: ContentColumn(child: navigationShell),
                ),
                Positioned(
                  left: AppSpacing.xl,
                  right: AppSpacing.xl,
                  bottom: AppSpacing.l,
                  child: nav,
                ),
              ],
            ),
    );
  }
}

class _AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppTopBar({this.babyName, this.babyAgeWeeks, this.babyEmoji});

  final String? babyName;
  final int? babyAgeWeeks;
  final String? babyEmoji;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final glass = AppTheme.of(context).colors.glass;
    final theme = AppTheme.of(context);
    return SafeArea(
      bottom: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppGlass.blurSigma,
            sigmaY: AppGlass.blurSigma,
          ),
          child: Container(
            height: preferredSize.height,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            decoration: BoxDecoration(
              color: glass.fill,
              border: Border(bottom: BorderSide(color: glass.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TapScale(
                    onTap: () => showBabySwitcherSheet(context),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colors.surfaceSunken,
                            shape: BoxShape.circle,
                          ),
                          child: Text(babyEmoji ?? '👶'),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              babyName ?? '—',
                              style: theme.typography.subtitle.copyWith(
                                color: theme.colors.textPrimary,
                              ),
                            ),
                            if (babyAgeWeeks != null)
                              Text(
                                '$babyAgeWeeks weeks old',
                                style: theme.typography.caption.copyWith(
                                  color: theme.colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          LucideIcons.chevron_down,
                          size: 18,
                          color: theme.colors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                TapScale(
                  onTap: () => context.push('/settings'),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s),
                    child: Icon(
                      LucideIcons.settings,
                      color: theme.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

typedef _Destination = ({IconData icon, String label});

/// Floating glass pill — margin on every side so the gradient background
/// shows around it, content scrolls underneath. See
/// docs/DESIGN_SYSTEM.md#8-components.
class _AppBottomNav extends StatelessWidget {
  const _AppBottomNav({
    required this.currentIndex,
    required this.destinations,
    required this.onSelect,
  });

  final int currentIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.s,
      ),
      child: Row(
        children: [
          for (var i = 0; i < destinations.length; i++)
            Expanded(
              child: _NavItem(
                destination: destinations[i],
                selected: i == currentIndex,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// Floating glass rail for wide/web viewports — the rail equivalent of
/// [_AppBottomNav], same margin-and-blur treatment.
class _AppNavRail extends StatelessWidget {
  const _AppNavRail({
    required this.currentIndex,
    required this.destinations,
    required this.onSelect,
  });

  final int currentIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kRailWidth,
      child: AppGlassSurface(
        borderRadius: BorderRadius.circular(AppRadii.l),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < destinations.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: _NavItem(
                  destination: destinations[i],
                  selected: i == currentIndex,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final color = selected ? colors.textPrimary : colors.textTertiary;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        curve: AppMotion.curveStandard,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.surface : null,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(destination.icon, size: 22, color: color),
            const SizedBox(height: AppSpacing.xs / 2),
            Text(
              destination.label,
              style: theme.typography.label.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
