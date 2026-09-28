import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/app_motion.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/app_scaffold.dart';

const _kRailCollapsedWidth = 100.0;
const _kRailExpandedWidth = 160.0;

/// Persistent nav shell — a floating glass pill nav on phones, a floating
/// glass rail on wide/web viewports — with no top app bar; each screen
/// shows its own title inline. See docs/UX.md "Navigation model" and
/// docs/DESIGN_SYSTEM.md#8-components.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (icon: LucideIcons.house, label: 'Home'),
    (icon: LucideIcons.list_checks, label: 'Care Log'),
    (icon: LucideIcons.book_open, label: 'Memories'),
    (icon: LucideIcons.heart_pulse, label: 'Health'),
    (icon: LucideIcons.clipboard_list, label: 'Tasks'),
    (icon: LucideIcons.settings, label: 'Settings'),
  ];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _railCollapsed = false;

  void _onSelect(int index) => widget.navigationShell.goBranch(
    index,
    initialLocation: index == widget.navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);
    final railWidth = _railCollapsed ? _kRailCollapsedWidth : _kRailExpandedWidth;

    return AppScaffold(
      body: wide
          ? Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: railWidth + AppSpacing.l),
                  child: ContentColumn(child: widget.navigationShell),
                ),
                Positioned(
                  left: AppSpacing.l,
                  top: AppSpacing.l,
                  bottom: AppSpacing.l,
                  child: _AppNavRail(
                    width: railWidth,
                    collapsed: _railCollapsed,
                    currentIndex: widget.navigationShell.currentIndex,
                    destinations: AppShell._destinations,
                    onSelect: _onSelect,
                    onToggleCollapsed: () =>
                        setState(() => _railCollapsed = !_railCollapsed),
                  ),
                ),
              ],
            )
          : ContentColumn(child: widget.navigationShell),
      bottomNavigationBar: wide
          ? null
          : _AppBottomNav(
              currentIndex: widget.navigationShell.currentIndex,
              destinations: AppShell._destinations,
              onSelect: _onSelect,
            ),
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
/// [_AppBottomNav], same margin-and-blur treatment. Collapses to an
/// icon-only strip or expands to icon+label rows via [onToggleCollapsed].
class _AppNavRail extends StatelessWidget {
  const _AppNavRail({
    required this.width,
    required this.collapsed,
    required this.currentIndex,
    required this.destinations,
    required this.onSelect,
    required this.onToggleCollapsed,
  });

  final double width;
  final bool collapsed;
  final int currentIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return AnimatedContainer(
      duration: AppMotion.durationFast,
      curve: AppMotion.curveStandard,
      width: width,
      child: AppGlassSurface(
        borderRadius: BorderRadius.circular(AppRadii.l),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < destinations.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: _NavItem(
                  destination: destinations[i],
                  selected: i == currentIndex,
                  onTap: () => onSelect(i),
                  horizontal: !collapsed,
                ),
              ),
            const SizedBox(height: AppSpacing.m),
            Spacer(),
            TapScale(
              onTap: onToggleCollapsed,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.m,
                  vertical: AppSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: Icon(
                    collapsed ? LucideIcons.panel_left_open : LucideIcons.panel_left_close,
                    size: 20,
                    color: colors.textTertiary,
                  ),
                ),
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
    this.horizontal = false,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  /// Row (icon + label side by side) for the wide nav rail; the default
  /// stacked column layout is used for the phone bottom nav.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final color = selected ? colors.textPrimary : colors.textTertiary;
    final label = Text(
      destination.label,
      style: theme.typography.label.copyWith(
        color: color,
        fontSize: horizontal ? 13 : 10,
      ),
      textAlign: TextAlign.center,
      overflow: horizontal ? TextOverflow.ellipsis : TextOverflow.visible,
    );

    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        curve: AppMotion.curveStandard,
        width: horizontal ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: horizontal ? AppSpacing.s : AppSpacing.m,
          vertical: horizontal ? AppSpacing.s : AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.surface : null,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: horizontal
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(destination.icon, size: 18, color: color),
                  const SizedBox(width: AppSpacing.s),
                  Flexible(child: label),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(destination.icon, size: 22, color: color),
                  const SizedBox(height: AppSpacing.xs / 2),
                  label,
                ],
              ),
      ),
    );
  }
}
