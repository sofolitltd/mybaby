import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion/tap_scale.dart';

/// Back button + title row used atop the pushed baby add/edit screens (and
/// settings), since `AppAppBar` isn't built yet — see
/// docs/DESIGN_SYSTEM.md#8-components.
class BabyScreenHeader extends StatelessWidget {
  const BabyScreenHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: Row(
        children: [
          TapScale(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s),
              child: Icon(
                LucideIcons.chevron_left,
                color: theme.colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            title,
            style: theme.typography.title.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
