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
const _kExpandedRailWidth = 120.0;

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
    final expanded = MediaQuery.sizeOf(context).width >= kExpandedRailBreakpoint;
    final railWidth = expanded ? _kExpandedRailWidth : _kRailWidth;
    final baby = ref.watch(activeBabyProvider);

    return AppScaffold(
      appBar: _AppTopBar(
        babyName: baby?.name,
        babyAgeWeeks: baby?.ageInWeeks,
        babyEmoji: baby?.avatarEmoji,
        babyAvatarDriveFileId: baby?.avatarDriveFileId,
      ),
      body: wide
          ? Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: railWidth + AppSpacing.l),
                  child: ContentColumn(child: navigationShell),
                ),
                Positioned(
                  left: AppSpacing.l,
                  top: AppSpacing.l,
                  bottom: AppSpacing.l,
                  child: _AppNavRail(
                    width: railWidth,
                    currentIndex: navigationShell.currentIndex,
                    destinations: _destinations,
                    onSelect: _onSelect,
                  ),
                ),
              ],
            )
          : ContentColumn(child: navigationShell),
      bottomNavigationBar: wide
          ? null
          : _AppBottomNav(
              currentIndex: navigationShell.currentIndex,
              destinations: _destinations,
              onSelect: _onSelect,
            ),
    );
  }
}

class _AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppTopBar({
    this.babyName,
    this.babyAgeWeeks,
    this.babyEmoji,
    this.babyAvatarDriveFileId,
  });

  final String? babyName;
  final int? babyAgeWeeks;
  final String? babyEmoji;
  final String? babyAvatarDriveFileId;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SafeArea(
      bottom: false,
      child: Container(
        height: preferredSize.height,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        decoration: BoxDecoration(
          color: theme.colors.surface,
          border: Border(bottom: BorderSide(color: theme.colors.hairline)),
        ),
        child: Row(
          children: [
                Expanded(
                  child: TapScale(
                    onTap: () => showBabySwitcherSheet(context),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: Row(
                      crossAxisAlignment: .start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BabyAvatar(
                          driveFileId: babyAvatarDriveFileId,
                          emoji: babyEmoji ?? '👶',
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
                                fontSize: 12,
                              ),
                            ),
                            if (babyAgeWeeks != null)
                              Text(
                                '$babyAgeWeeks weeks old',
                                style: theme.typography.caption.copyWith(
                                  color: theme.colors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          LucideIcons.chevron_down,
                          size: 18,
                          // color: theme.colors.textTertiary,
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
    );
  }
}

/// 32x32 circular baby avatar in the top bar — shows the Drive-backed photo
/// once it's loaded, falling back to the sex emoji while loading, on error,
/// or when no photo was ever uploaded.
class _BabyAvatar extends ConsumerWidget {
  const _BabyAvatar({required this.driveFileId, required this.emoji});

  final String? driveFileId;
  final String emoji;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppTheme.of(context).colors;
    final fileId = driveFileId;
    final bytes = fileId == null
        ? null
        : ref.watch(driveImageBytesProvider(fileId)).value;

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        shape: BoxShape.circle,
        image: bytes == null
            ? null
            : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
      child: bytes == null ? Text(emoji) : null,
    );
  }
}

typedef _Destination = ({IconData icon, String label});

/// Standard full-width bottom nav bar, docked flush to the screen edge —
/// the phone equivalent of [_AppNavRail]. Passed to `Scaffold`'s own
/// `bottomNavigationBar` slot (via [AppScaffold]) rather than floated over
/// [ContentColumn], so it gets real edge-to-edge placement and Scaffold's
/// automatic body-height accounting for free. See
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
    final colors = AppTheme.of(context).colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            // horizontal: AppSpacing.s,
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
        ),
      ),
    );
  }
}

/// Floating glass rail for wide/web viewports — the rail equivalent of
/// [_AppBottomNav], same margin-and-blur treatment.
class _AppNavRail extends StatelessWidget {
  const _AppNavRail({
    required this.width,
    required this.currentIndex,
    required this.destinations,
    required this.onSelect,
  });

  final double width;
  final int currentIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
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
              style: theme.typography.label.copyWith(color: color, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
