import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';

/// Small label with an optional trailing action, used atop grouped content.
/// See docs/DESIGN_SYSTEM.md#8-components.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(this.title, {super.key, this.trailing});

  final String title;
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
            child: Text(
              title,
              style: theme.typography.label.copyWith(
                color: theme.colors.primary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
