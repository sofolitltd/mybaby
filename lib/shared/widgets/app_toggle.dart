import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/app_motion.dart';
import '../../core/theme/motion/tap_scale.dart';

/// Custom on/off pill — replaces Material `Switch`. `primary` (eucalyptus)
/// track when on, `surfaceSunken` when off. See docs/DESIGN_SYSTEM.md#8-components.
class AppToggle extends StatelessWidget {
  const AppToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return TapScale(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        curve: AppMotion.curveStandard,
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          color: value ? colors.primary : colors.surfaceSunken,
        ),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
