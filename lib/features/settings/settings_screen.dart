import 'package:flutter/material.dart'
    show
        CircularProgressIndicator,
        Divider,
        ScaffoldMessenger,
        SnackBar,
        showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/providers.dart';
import '../../core/responsive/breakpoints.dart';
import '../../data/models/baby.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/app_motion.dart';
import '../../core/theme/motion/staggered_entrance.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../core/theme/theme_controller.dart';
import '../babies/widgets/baby_screen_header.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/drive_error_snackbar.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_section_header.dart';
import '../../shared/widgets/app_status_pill.dart';
import '../../shared/widgets/app_toggle.dart';
import 'providers/drive_usage_provider.dart';
import 'providers/feed_reminder_provider.dart';
import 'providers/last_backup_provider.dart';
import 'providers/reminder_prefs_provider.dart';
import 'providers/units_provider.dart';
import 'widgets/feed_reminder_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final theme = AppTheme.of(context);
    final babies = ref.watch(babiesStreamProvider).value ?? const [];
    final activeBaby = ref.watch(activeBabyProvider);
    final email = ref.watch(authStateProvider).value?.email;
    final weightUnit = ref.watch(weightUnitProvider);
    final lengthUnit = ref.watch(lengthUnitProvider);
    final reminderPrefs = ref.watch(reminderPrefsProvider);
    final feedAlert = ref.watch(feedAlertProvider);

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BabyScreenHeader(title: 'Settings', showBackButton: false),
            Expanded(
              child: ContentColumn(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  children: [
                    StaggeredListEntrance(
                      children: [
                        AppMutedSectionHeader(
                          'Baby profiles',
                          trailing: babies.isEmpty
                              ? null
                              : Text(
                                  '${babies.length} registered',
                                  style: theme.typography.caption.copyWith(
                                    color: theme.colors.textSecondary,
                                  ),
                                ),
                        ),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (activeBaby != null) ...[
                                Row(
                                  children: [
                                    _BabyAvatar(baby: activeBaby),
                                    const SizedBox(width: AppSpacing.m),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            activeBaby.name,
                                            style: theme.typography.subtitle
                                                .copyWith(
                                                  color:
                                                      theme.colors.textPrimary,
                                                ),
                                          ),
                                          const SizedBox(
                                            height: AppSpacing.xs / 2,
                                          ),
                                          Text(
                                            '${activeBaby.ageInWeeks} weeks old · Active profile',
                                            style: theme.typography.caption
                                                .copyWith(
                                                  color: theme
                                                      .colors
                                                      .textSecondary,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    TapScale(
                                      onTap: () => context.push(
                                        '/edit-baby',
                                        extra: activeBaby,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.s,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.s,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colors.surfaceSunken,
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.s,
                                          ),
                                        ),
                                        child: Icon(
                                          LucideIcons.square_pen,
                                          size: 16,
                                          color: theme.colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.m),
                              ],
                              _DashedAddCard(
                                label: 'Add another baby',
                                onTap: () => context.push('/add-baby'),
                              ),
                            ],
                          ),
                        ),
                        const AppMutedSectionHeader('Reminders & Alerts'),
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: _SettingsToggleRow(
                                  icon: LucideIcons.syringe,
                                  iconTint: theme.colors.primary,
                                  title: 'Vaccination reminders',
                                  subtitle: 'Upcoming immunizations & shots',
                                  value:
                                      reminderPrefs[ReminderCategory
                                          .vaccination] ??
                                      false,
                                  onChanged: (enabled) => _onReminderToggled(
                                    context,
                                    ref,
                                    ReminderCategory.vaccination,
                                    enabled,
                                  ),
                                ),
                              ),
                              Divider(height: 1, color: theme.colors.hairline),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: _SettingsToggleRow(
                                  icon: LucideIcons.chart_line,
                                  iconTint: theme.colors.info,
                                  title: 'Growth check-ins',
                                  subtitle: 'Weekly weight & height logging',
                                  value:
                                      reminderPrefs[ReminderCategory
                                          .growthCheckIn] ??
                                      false,
                                  onChanged: (enabled) => _onReminderToggled(
                                    context,
                                    ref,
                                    ReminderCategory.growthCheckIn,
                                    enabled,
                                  ),
                                ),
                              ),
                              Divider(height: 1, color: theme.colors.hairline),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: _FeedAlertRow(feedAlert: feedAlert),
                              ),
                              Divider(height: 1, color: theme.colors.hairline),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: TapScale(
                                  onTap: () =>
                                      context.push('/settings/reminders'),
                                  child: const _SettingsRow(
                                    icon: LucideIcons.list_checks,
                                    iconTint: null,
                                    title: 'View all scheduled reminders',
                                    subtitle: 'See every alarm currently set',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const AppMutedSectionHeader('Units & Preferences'),
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: _UnitRow(
                                  title: 'Weight unit',
                                  subtitle: 'Used in growth charts & records',
                                  leftLabel: 'kg',
                                  rightLabel: 'lb',
                                  selectedLeft: weightUnit == WeightUnit.kg,
                                  onSelectLeft: () => ref
                                      .read(weightUnitProvider.notifier)
                                      .set(WeightUnit.kg),
                                  onSelectRight: () => ref
                                      .read(weightUnitProvider.notifier)
                                      .set(WeightUnit.lb),
                                ),
                              ),
                              Divider(height: 1, color: theme.colors.hairline),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: _UnitRow(
                                  title: 'Height / length unit',
                                  subtitle:
                                      'Measurements for growth monitoring',
                                  leftLabel: 'cm',
                                  rightLabel: 'in',
                                  selectedLeft: lengthUnit == LengthUnit.cm,
                                  onSelectLeft: () => ref
                                      .read(lengthUnitProvider.notifier)
                                      .set(LengthUnit.cm),
                                  onSelectRight: () => ref
                                      .read(lengthUnitProvider.notifier)
                                      .set(LengthUnit.inch),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppMutedSectionHeader(
                          'Data & Cloud Backup',
                          trailing: AppStatusPill(
                            label: 'Synced today',
                            color: theme.colors.status.done,
                          ),
                        ),
                        const AppCard(child: _DriveRow()),
                        const AppMutedSectionHeader('Appearance'),
                        _ThemeModePicker(
                          mode: mode,
                          onChanged: (m) =>
                              ref.read(themeModeProvider.notifier).set(m),
                        ),
                        const AppMutedSectionHeader('Family & Export'),
                        AppCard(
                          onTap: () => _showComingSoon(
                            context,
                            'Caregiver & partner sharing',
                          ),
                          child: const _SettingsRow(
                            icon: LucideIcons.users,
                            iconTint: null,
                            title: 'Caregiver & Partner Sharing',
                            subtitle:
                                'Invite parents, nanny, or family members',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s),
                        AppCard(
                          onTap: () => _showComingSoon(
                            context,
                            'Export pediatric health summary',
                          ),
                          child: const _SettingsRow(
                            icon: LucideIcons.file_down,
                            iconTint: null,
                            title: 'Export Pediatric Health Summary',
                            subtitle:
                                'Generate PDF report for pediatrician visit',
                          ),
                        ),
                        const AppMutedSectionHeader('Account'),
                        AppCard(
                          onTap: () async {
                            final confirmed = await _confirmSignOut(context);
                            if (confirmed == true) {
                              ref.read(authRepositoryProvider).signOut();
                            }
                          },
                          child: _SettingsRow(
                            icon: LucideIcons.log_out,
                            title: 'Sign out',
                            subtitle: email == null
                                ? null
                                : 'Signed in as $email',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('$feature is coming soon')));
}

Future<void> _onReminderToggled(
  BuildContext context,
  WidgetRef ref,
  ReminderCategory category,
  bool enabled,
) async {
  final applied = await ref
      .read(reminderPrefsProvider.notifier)
      .toggle(category, enabled);
  if (!applied && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enable notifications for MyBaby in system settings'),
      ),
    );
  }
}

/// Same custom-dialog shape as health_screen.dart's `_confirmVaccineCardPhoto`
/// — a centered `AppGlassSurface`, not a Material `AlertDialog`, so it stays
/// on the app's own visual system.
Future<bool?> _confirmSignOut(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = AppTheme.of(context);
      return Center(
        child: AppGlassSurface(
          borderRadius: BorderRadius.circular(AppRadii.m),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sign out?',
                  style: theme.typography.subtitle.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  "You'll need to sign back in to see your babies' data.",
                  style: theme.typography.body.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        variant: AppButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          'Cancel',
                          style: theme.typography.label.copyWith(
                            color: theme.colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: AppButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(
                          'Sign out',
                          style: theme.typography.label.copyWith(
                            color: theme.colors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// A dashed-outline affordance for "add" actions — visually distinct from
/// the solid `AppCard`s used for content, matching the mockup's treatment
/// of "Add another baby".
class _DashedAddCard extends StatelessWidget {
  const _DashedAddCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.m),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: theme.colors.hairline,
          radius: AppRadii.m,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Row(
            children: [
              _IconBadge(icon: LucideIcons.plus, tint: theme.colors.primary),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text(
                  label,
                  style: theme.typography.subtitle.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
              ),
              Icon(LucideIcons.chevron_right, color: theme.colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  static const _strokeWidth = 1.5;
  static const _dashWidth = 6.0;
  static const _gapWidth = 4.0;

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        _strokeWidth / 2,
        _strokeWidth / 2,
        size.width - _strokeWidth,
        size.height - _strokeWidth,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconTint,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconTint;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
      children: [
        _IconBadge(icon: icon, tint: iconTint ?? theme.colors.textSecondary),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.typography.subtitle.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  subtitle!,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Icon(LucideIcons.chevron_right, color: theme.colors.textTertiary),
      ],
    );
  }
}

/// Active baby's emoji avatar on a warm tinted circle, with a small green
/// checkmark badge overlapping its bottom-right corner to signal "active
/// profile" — matches the Baby Profiles card mockup.
class _BabyAvatar extends StatelessWidget {
  const _BabyAvatar({required this.baby});

  final Baby baby;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.secondary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(baby.avatarEmoji, style: const TextStyle(fontSize: 22)),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.status.done,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 2),
              ),
              child: Icon(LucideIcons.check, size: 9, color: colors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small tinted circular badge behind list-row icons — matches the mockup's
/// soft-colored icon chips (green/blue/amber) instead of a bare glyph.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: tint),
    );
  }
}

/// "Feed alert" row — a simple global "every N hours" repeating reminder
/// ([feedAlertProvider]), independent of the diaper alert's one-off
/// pick-a-time reminder above. Tapping the row (or turning it on) opens the
/// interval picker sheet; the toggle turns it off directly.
String _formatFeedInterval(Duration interval) {
  final hours = interval.inHours;
  final minutes = interval.inMinutes % 60;
  if (minutes == 0) return '$hours hr${hours == 1 ? '' : 's'}';
  if (hours == 0) return '$minutes min';
  return '${hours}h ${minutes}m';
}

class _FeedAlertRow extends ConsumerWidget {
  const _FeedAlertRow({required this.feedAlert});

  final FeedAlertState feedAlert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final subtitle = feedAlert.isSet
        ? 'Every ${_formatFeedInterval(feedAlert.interval!)}'
              '${feedAlert.leadMinutes > 0 ? ' · notify ${feedAlert.leadMinutes}m before' : ''}'
        : 'Repeating reminder between feeds';

    return TapScale(
      onTap: () => showFeedAlertSheet(context, ref),
      child: Row(
        children: [
          _IconBadge(icon: LucideIcons.milk, tint: theme.colors.primary),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Feed alert',
                  style: theme.typography.subtitle.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  subtitle,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          AppToggle(
            value: feedAlert.isSet,
            onChanged: (enabled) => enabled
                ? showFeedAlertSheet(context, ref)
                : ref.read(feedAlertProvider.notifier).cancel(),
          ),
        ],
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.icon,
    required this.iconTint,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final Color iconTint;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
      children: [
        _IconBadge(icon: icon, tint: iconTint),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.typography.subtitle.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  subtitle!,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        AppToggle(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// A label + two-way segmented pill (e.g. kg/lb, cm/in) — used by the Units
/// & Preferences section.
class _UnitRow extends StatelessWidget {
  const _UnitRow({
    required this.title,
    required this.subtitle,
    required this.leftLabel,
    required this.rightLabel,
    required this.selectedLeft,
    required this.onSelectLeft,
    required this.onSelectRight,
  });

  final String title;
  final String subtitle;
  final String leftLabel;
  final String rightLabel;
  final bool selectedLeft;
  final VoidCallback onSelectLeft;
  final VoidCallback onSelectRight;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.typography.subtitle.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(
                subtitle,
                style: theme.typography.caption.copyWith(
                  color: theme.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        _SegmentedPair(
          leftLabel: leftLabel,
          rightLabel: rightLabel,
          selectedLeft: selectedLeft,
          onSelectLeft: onSelectLeft,
          onSelectRight: onSelectRight,
        ),
      ],
    );
  }
}

class _SegmentedPair extends StatelessWidget {
  const _SegmentedPair({
    required this.leftLabel,
    required this.rightLabel,
    required this.selectedLeft,
    required this.onSelectLeft,
    required this.onSelectRight,
  });

  final String leftLabel;
  final String rightLabel;
  final bool selectedLeft;
  final VoidCallback onSelectLeft;
  final VoidCallback onSelectRight;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentOption(
            label: leftLabel,
            selected: selectedLeft,
            onTap: onSelectLeft,
          ),
          _SegmentOption(
            label: rightLabel,
            selected: !selectedLeft,
            onTap: onSelectRight,
          ),
        ],
      ),
    );
  }
}

class _SegmentOption extends StatelessWidget {
  const _SegmentOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final color = selected ? colors.primary : colors.textSecondary;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        curve: AppMotion.curveStandard,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.surface : null,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          style: theme.typography.label.copyWith(color: color),
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
    final colors = theme.colors;
    final lastBackup = ref.watch(lastBackupProvider);
    final usage = ref.watch(driveUsageProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _IconBadge(icon: LucideIcons.cloud, tint: colors.info),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Google Drive Backup',
                    style: theme.typography.subtitle.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs / 2),
                  Text(
                    lastBackup == null
                        ? 'Not backed up yet'
                        : 'Last backup: ${_formatBackupTime(lastBackup)}',
                    style: theme.typography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            AppButton(
              variant: AppButtonVariant.secondary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.s,
              ),
              onPressed: () async {
                try {
                  await ref.read(driveRepositoryProvider).ensureAppFolder();
                  ref.read(lastBackupProvider.notifier).markSyncedNow();
                  ref.invalidate(driveUsageProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Drive folder is ready')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showDriveErrorSnackBar(context, ref, e);
                  }
                }
              },
              child: Text('Sync Now', style: theme.typography.label),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: Text(
                'App storage used',
                style: theme.typography.caption.copyWith(
                  color: colors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            usage.when(
              loading: () => SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.textTertiary,
                ),
              ),
              error: (_, _) => Text(
                'Unavailable',
                style: theme.typography.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
              data: (bytes) => Text(
                '${formatBytes(bytes)} in MyBaby folder',
                style: theme.typography.caption.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatBackupTime(DateTime time) {
    final now = DateTime.now();
    final isToday =
        time.year == now.year && time.month == now.month && time.day == now.day;
    final timeLabel = DateFormat('h:mm a').format(time);
    return isToday
        ? 'Today, $timeLabel'
        : DateFormat('MMM d, h:mm a').format(time);
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
      child: Row(
        children: [
          for (final _ThemeOption option in _options) ...[
            if (option != _options.first) const SizedBox(width: AppSpacing.s),
            Expanded(
              child: _ThemeModeTile(
                icon: option.icon,
                label: option.label,
                selected: option.mode == mode,
                onTap: () => onChanged(option.mode),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
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
    final color = selected ? colors.primary : colors.textSecondary;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.m),
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        curve: AppMotion.curveStandard,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.12)
              : colors.surface,
          borderRadius: BorderRadius.circular(AppRadii.m),
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.4)
                : colors.hairline,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: theme.typography.label.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
