import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion/sheet_transition.dart';
import '../../../core/theme/motion/tap_scale.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_chip.dart';
import '../providers/feed_reminder_provider.dart';

const _intervalPresetsMinutes = [60, 120, 180, 240, 360];
const _leadMinuteOptions = [0, 5, 10, 15, 30];
const _minIntervalMinutes = 15;
const _maxIntervalMinutes = 12 * 60;
const _intervalStepMinutes = 15;

String _formatInterval(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (mins == 0) return '$hours hr${hours == 1 ? '' : 's'}';
  if (hours == 0) return '$mins min';
  return '${hours}h ${mins}m';
}

/// A "remind me every N hours/minutes" picker, with a custom stepper for
/// times the fixed presets don't cover, plus an optional "before" nudge —
/// schedules the repeating local notification (and its lead heads-up)
/// backing Settings' "Feed alert" toggle. Reached by tapping that row.
Future<void> showFeedAlertSheet(BuildContext context, WidgetRef ref) {
  return showAppSheet(
    context: context,
    builder: (context) => const _FeedAlertSheet(),
  );
}

class _FeedAlertSheet extends ConsumerStatefulWidget {
  const _FeedAlertSheet();

  @override
  ConsumerState<_FeedAlertSheet> createState() => _FeedAlertSheetState();
}

class _FeedAlertSheetState extends ConsumerState<_FeedAlertSheet> {
  late int _intervalMinutes =
      ref.read(feedAlertProvider).interval?.inMinutes ?? 180;
  late int _leadMinutes = ref.read(feedAlertProvider).leadMinutes;
  bool _saving = false;

  void _adjustInterval(int deltaMinutes) {
    setState(() {
      _intervalMinutes = (_intervalMinutes + deltaMinutes).clamp(
        _minIntervalMinutes,
        _maxIntervalMinutes,
      );
      if (_leadMinutes >= _intervalMinutes) _leadMinutes = 0;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final applied = await ref
        .read(feedAlertProvider.notifier)
        .setInterval(
          Duration(minutes: _intervalMinutes),
          leadMinutes: _leadMinutes,
        );
    if (!mounted) return;
    if (!applied) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Enable notifications for MyBaby in system settings'),
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _turnOff() async {
    await ref.read(feedAlertProvider.notifier).cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final isSet = ref.watch(feedAlertProvider).isSet;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.s,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Feed Alert',
            style: theme.typography.title.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Get a repeating reminder to feed your baby.',
            style: theme.typography.body.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            'REMIND ME EVERY',
            style: theme.typography.label.copyWith(
              color: theme.colors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              for (final minutes in _intervalPresetsMinutes)
                AppChip(
                  label: _formatInterval(minutes),
                  selected: _intervalMinutes == minutes,
                  onTap: () => setState(() {
                    _intervalMinutes = minutes;
                    if (_leadMinutes >= _intervalMinutes) _leadMinutes = 0;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            'Or set a custom time',
            style: theme.typography.caption.copyWith(
              color: theme.colors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          _IntervalStepper(
            minutes: _intervalMinutes,
            onDecrease: () => _adjustInterval(-_intervalStepMinutes),
            onIncrease: () => _adjustInterval(_intervalStepMinutes),
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            'NOTIFY ME BEFORE',
            style: theme.typography.label.copyWith(
              color: theme.colors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              for (final minutes in _leadMinuteOptions)
                if (minutes < _intervalMinutes)
                  AppChip(
                    label: minutes == 0 ? 'At alert time' : '$minutes min',
                    selected: _leadMinutes == minutes,
                    onTap: () => setState(() => _leadMinutes = minutes),
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: _saving ? null : _save,
              child: Text(
                isSet ? 'Update alert' : 'Turn on alert',
                style: theme.typography.label.copyWith(
                  color: theme.colors.onPrimary,
                ),
              ),
            ),
          ),
          if (isSet) ...[
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.secondary,
                onPressed: _saving ? null : _turnOff,
                child: Text(
                  'Turn off alert',
                  style: theme.typography.label.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// +/- stepper in [_intervalStepMinutes] increments, formatting the value
/// as e.g. "2h 30m" — used for feed-alert intervals the fixed presets
/// don't cover.
class _IntervalStepper extends StatelessWidget {
  const _IntervalStepper({
    required this.minutes,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int minutes;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: theme.colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.s),
      ),
      child: Row(
        children: [
          _StepperButton(icon: LucideIcons.minus, onTap: onDecrease),
          Expanded(
            child: Text(
              _formatInterval(minutes),
              textAlign: TextAlign.center,
              style: theme.typography.subtitle.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
          ),
          _StepperButton(icon: LucideIcons.plus, onTap: onIncrease),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: theme.colors.textPrimary),
      ),
    );
  }
}
