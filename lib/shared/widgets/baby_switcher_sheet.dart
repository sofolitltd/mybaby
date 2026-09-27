import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/sheet_transition.dart';
import '../../core/theme/motion/tap_scale.dart';

Future<void> showBabySwitcherSheet(BuildContext context) {
  return showAppSheet(
    context: context,
    builder: (context) => const _BabySwitcherSheetContent(),
  );
}

class _BabySwitcherSheetContent extends ConsumerWidget {
  const _BabySwitcherSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final babies = ref.watch(babiesStreamProvider).value ?? const [];
    final activeId = ref.watch(activeBabyProvider)?.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.s,
            AppSpacing.xl,
            AppSpacing.m,
          ),
          child: Text(
            'Babies',
            style: theme.typography.title.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
        ),
        for (final baby in babies)
          Row(
            children: [
              Expanded(
                child: TapScale(
                  onTap: () {
                    ref.read(activeBabyIdProvider.notifier).select(baby.id);
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.s,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colors.surfaceSunken,
                            shape: BoxShape.circle,
                          ),
                          child: Text(baby.avatarEmoji),
                        ),
                        const SizedBox(width: AppSpacing.l),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                baby.name,
                                style: theme.typography.subtitle.copyWith(
                                  color: theme.colors.textPrimary,
                                ),
                              ),
                              Text(
                                '${baby.ageInWeeks} weeks old',
                                style: theme.typography.caption.copyWith(
                                  color: theme.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (baby.id == activeId)
                          Icon(
                            LucideIcons.circle_check,
                            color: theme.colors.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              TapScale(
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/edit-baby', extra: baby);
                },
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Icon(
                    LucideIcons.pencil,
                    size: 18,
                    color: theme.colors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
            ],
          ),
        TapScale(
          onTap: () {
            Navigator.of(context).pop();
            context.push('/add-baby');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.s,
            ),
            child: Row(
              children: [
                Icon(LucideIcons.circle_plus, color: theme.colors.primary),
                const SizedBox(width: AppSpacing.l),
                Text(
                  'Add baby',
                  style: theme.typography.subtitle.copyWith(
                    color: theme.colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
      ],
    );
  }
}
