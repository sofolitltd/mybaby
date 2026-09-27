import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';

/// Small label with an optional trailing action, used atop grouped content.
/// See docs/DESIGN_SYSTEM.md#8-components.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(this.title, {super.key, this.badge, this.trailing});

  final String title;
  final Widget? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.label.copyWith(
                      color: theme.colors.primary,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: AppSpacing.s),
                  badge!,
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Muted, uppercase variant of [AppSectionHeader] — settings' label style
/// (used there as `_SettingsSectionHeader`). No horizontal padding, since
/// callers already pad their scroll view by the same amount as the cards
/// below, and this header's own inset would double up against it and knock
/// the label out of alignment with those cards.
class AppMutedSectionHeader extends StatelessWidget {
  const AppMutedSectionHeader(
    this.title, {
    super.key,
    this.badge,
    this.trailing,
  });

  final String title;
  final Widget? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.s),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.label.copyWith(
                      color: theme.colors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: AppSpacing.s),
                  badge!,
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
