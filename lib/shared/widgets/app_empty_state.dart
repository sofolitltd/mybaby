import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';

/// Icon + one-line prompt, used for empty lists (growth entries, memories,
/// vaccinations) per docs/UX.md "Empty states". See
/// docs/DESIGN_SYSTEM.md#8-components.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        children: [
          Icon(icon, size: 32, color: theme.colors.textTertiary),
          const SizedBox(height: AppSpacing.m),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.typography.body.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
