import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/app_motion.dart';
import '../../core/theme/motion/staggered_entrance.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../core/theme/theme_controller.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_section_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final theme = AppTheme.of(context);

    return AppScaffold(
      body: ContentColumn(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.l,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: [
            Row(
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
                  'Settings',
                  style: theme.typography.title.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
              ],
            ),
            StaggeredListEntrance(
              children: [
                const AppSectionHeader('Baby profiles'),
                AppCard(
                  onTap: () => context.push('/add-baby'),
                  child: const _SettingsRow(
                    icon: LucideIcons.baby,
                    title: 'Add another baby',
                  ),
                ),
                const AppSectionHeader('Notifications'),
                AppCard(
                  child: _SettingsToggleRow(
                    icon: LucideIcons.syringe,
                    title: 'Vaccination reminders',
                    value: true,
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                AppCard(
                  child: _SettingsToggleRow(
                    icon: LucideIcons.chart_line,
                    title: 'Growth check-in reminders',
                    value: true,
                    onChanged: (_) {},
                  ),
                ),
                const AppSectionHeader('Your data'),
                const AppCard(child: _DriveRow()),
                const AppSectionHeader('Appearance'),
                _ThemeModePicker(
                  mode: mode,
                  onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
                ),
                const AppSectionHeader('Account'),
                AppCard(
                  onTap: () => ref.read(authRepositoryProvider).signOut(),
                  child: const _SettingsRow(
                    icon: LucideIcons.log_out,
                    title: 'Sign out',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colors.textSecondary),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Text(
            title,
            style: theme.typography.subtitle.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
        ),
        Icon(LucideIcons.chevron_right, color: theme.colors.textTertiary),
      ],
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colors.textSecondary),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Text(
            title,
            style: theme.typography.subtitle.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
        ),
        _Toggle(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// Custom on/off pill — replaces Material `Switch` so the toggle stays in the
/// glass/gradient visual language. See docs/DESIGN_SYSTEM.md#8-components.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onChanged});

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
          color: value ? colors.textTertiary : colors.surfaceSunken,
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

class _DriveRow extends ConsumerWidget {
  const _DriveRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    return Row(
      children: [
        Icon(LucideIcons.cloud, color: theme.colors.textSecondary),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Drive storage & backup',
                style: theme.typography.subtitle.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(
                'MyBaby App folder in your Google Drive',
                style: theme.typography.caption.copyWith(
                  color: theme.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        AppButton(
          variant: AppButtonVariant.tonal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.s,
          ),
          onPressed: () async {
            try {
              await ref.read(driveRepositoryProvider).ensureAppFolder();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Drive folder is ready')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Drive error: $e')));
              }
            }
          },
          child: Text('Check Drive', style: theme.typography.label),
        ),
      ],
    );
  }
}

typedef _ThemeOption = ({AppThemeMode mode, IconData icon, String label});

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({required this.mode, required this.onChanged});

  final AppThemeMode mode;
  final ValueChanged<AppThemeMode> onChanged;

  static const _options = [
    (mode: AppThemeMode.light, icon: LucideIcons.sun, label: 'Light'),
    (mode: AppThemeMode.dark, icon: LucideIcons.moon, label: 'Dark'),
    (mode: AppThemeMode.night, icon: LucideIcons.moon_star, label: 'Night'),
    (mode: AppThemeMode.system, icon: LucideIcons.monitor, label: 'System'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Wrap(
        spacing: AppSpacing.s,
        runSpacing: AppSpacing.s,
        children: [
          for (final _ThemeOption option in _options)
            _ThemeModeChip(
              icon: option.icon,
              label: option.label,
              selected: option.mode == mode,
              onTap: () => onChanged(option.mode),
            ),
        ],
      ),
    );
  }
}

class _ThemeModeChip extends StatelessWidget {
  const _ThemeModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final color = selected ? colors.textPrimary : colors.textSecondary;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        curve: AppMotion.curveStandard,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.surface : colors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: theme.typography.label.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
