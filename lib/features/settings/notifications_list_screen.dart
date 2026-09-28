import 'package:flutter/material.dart'
    show CircularProgressIndicator, RefreshIndicator;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../babies/widgets/baby_screen_header.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_status_pill.dart';
import 'providers/pending_notifications_provider.dart';

/// Detail screen reached from Settings' "Reminders & Alerts" section —
/// lists every local notification currently scheduled on the device
/// (vaccination/growth/care-log/medication reminders, the next-feed pair,
/// and task due-date alerts), sourced live from the OS via
/// [pendingNotificationsProvider] rather than app state, since that's the
/// only place all of them are tracked together.
class NotificationsListScreen extends ConsumerWidget {
  const NotificationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final pending = ref.watch(pendingNotificationsProvider);

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            BabyScreenHeader(
              title: 'Reminders & Alerts',
              trailing: pending.maybeWhen(
                data: (items) => AppStatusPill(
                  label: '${items.length} scheduled',
                  color: theme.colors.primary,
                ),
                orElse: () => null,
              ),
            ),
            Expanded(
              child: pending.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: AppEmptyState(
                      icon: LucideIcons.circle_alert,
                      message: 'Could not load scheduled reminders.',
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: AppEmptyState(
                          icon: LucideIcons.bell_off,
                          message:
                              'No reminders scheduled — turn one on from Settings.',
                        ),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(pendingNotificationsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.l,
                        AppSpacing.xl,
                        AppSpacing.xxl,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.m,
                          ),
                          child: AppCard(
                            child: _PendingNotificationRow(item: item),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingNotificationRow extends StatelessWidget {
  const _PendingNotificationRow({required this.item});

  final PendingNotificationRequest item;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(LucideIcons.bell, size: 18, color: colors.primary),
        ),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.title ?? 'Reminder',
                style: theme.typography.subtitle.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              if (item.body != null && item.body!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  item.body!,
                  style: theme.typography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
