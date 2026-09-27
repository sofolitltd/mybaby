import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/staggered_entrance.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../data/models/care_log_entry.dart';
import '../../data/models/growth_entry.dart';
import '../../data/models/memory.dart';
import '../../data/models/vaccination.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/app_status_pill.dart';
import '../../shared/widgets/quick_log_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final growth = ref.watch(growthEntriesProvider).value ?? const [];
    final vaccinations = ref.watch(vaccinationsProvider).value ?? const [];
    final memories = ref.watch(memoriesProvider).value ?? const [];

    final latestGrowth = growth.isEmpty ? null : growth.last;
    final dueSoon = vaccinations
        .where((v) => v.status != VaccinationStatus.done)
        .toList();
    final latestMemory = memories.isEmpty ? null : memories.first;
    final isEmpty =
        latestGrowth == null && dueSoon.isEmpty && latestMemory == null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.l,
              AppSpacing.xl,
              AppSpacing.s,
            ),
            children: [
              StaggeredListEntrance(
                children: [
                  if (latestGrowth != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.m),
                      child: _GrowthSnapshotCard(
                        entry: latestGrowth,
                        onTap: () => context.go('/growth'),
                      ),
                    ),
                  if (dueSoon.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.m),
                      child: _VaccinationDueCard(
                        vaccination: dueSoon.first,
                        onTap: () => context.go('/health'),
                      ),
                    ),
                  if (latestMemory != null)
                    _RecentMemoryCard(
                      memory: latestMemory,
                      onTap: () => context.go('/memories'),
                    ),
                  if (isEmpty)
                    const AppEmptyState(
                      icon: LucideIcons.house,
                      message:
                          'Nothing to show yet — log a growth entry or memory to get started.',
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
            ],
          ),
        ),
        const _QuickLogBar(),
      ],
    );
  }
}

class _GrowthSnapshotCard extends StatelessWidget {
  const _GrowthSnapshotCard({required this.entry, required this.onTap});

  final GrowthEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Growth',
                  style: theme.typography.subtitle.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${entry.weightKg.toStringAsFixed(1)} kg · ${entry.heightCm.toStringAsFixed(0)} cm',
                  style: theme.typography.numeralL.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevron_right, color: theme.colors.textTertiary),
        ],
      ),
    );
  }
}

class _VaccinationDueCard extends StatelessWidget {
  const _VaccinationDueCard({required this.vaccination, required this.onTap});

  final Vaccination vaccination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final overdue = vaccination.status == VaccinationStatus.overdue;
    final color = overdue
        ? theme.colors.status.overdue
        : theme.colors.status.dueSoon;
    final days = vaccination.scheduledDate.difference(DateTime.now()).inDays;
    final label = overdue ? 'Overdue' : 'Due in ${days.abs()} days';

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.heart_pulse, color: color),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vaccination.name} — dose ${vaccination.dose}',
                  style: theme.typography.subtitle.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                AppStatusPill(label: label, color: color),
              ],
            ),
          ),
          Icon(LucideIcons.chevron_right, color: theme.colors.textTertiary),
        ],
      ),
    );
  }
}

class _RecentMemoryCard extends StatelessWidget {
  const _RecentMemoryCard({required this.memory, required this.onTap});

  final Memory memory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            LucideIcons.book_open,
            size: 28,
            color: theme.colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent memory',
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  memory.caption,
                  style: theme.typography.subtitle.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevron_right, color: theme.colors.textTertiary),
        ],
      ),
    );
  }
}

/// Fixed quick-log bar — the single most-used control, reachable one-handed.
/// Glass buttons floating on the background gradient, same material as
/// every other Home section's `AppCard`. See docs/UX.md "Home (dashboard)".
class _QuickLogBar extends StatelessWidget {
  const _QuickLogBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.s,
        AppSpacing.xl,
        AppSpacing.l,
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuickLogButton(
              icon: LucideIcons.milk,
              label: 'Feed',
              type: CareLogType.feed,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: _QuickLogButton(
              icon: LucideIcons.moon,
              label: 'Sleep',
              type: CareLogType.sleep,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: _QuickLogButton(
              icon: LucideIcons.baby,
              label: 'Diaper',
              type: CareLogType.diaper,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLogButton extends ConsumerWidget {
  const _QuickLogButton({
    required this.icon,
    required this.label,
    required this.type,
  });

  final IconData icon;
  final String label;
  final CareLogType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    return TapScale(
      onTap: () => showQuickLogSheet(context, ref, type),
      borderRadius: BorderRadius.circular(AppRadii.m),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: AppGlassSurface(
          borderRadius: BorderRadius.circular(AppRadii.m),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.colors.textPrimary),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(
                label,
                style: theme.typography.label.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
