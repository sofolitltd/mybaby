import 'package:flutter/material.dart'
    show TimeOfDay, showDatePicker, showTimePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/tap_scale.dart';

/// Opens a date picker then a time picker and combines the result into one
/// [DateTime] — the shared date+time editing pattern for care log
/// start/end fields.
///
/// [lastDate] defaults to tomorrow (care log entries stay close to now);
/// pass a later bound for fields like a task's due date that can be set
/// further in the future. When [timeOptional] is true, dismissing the time
/// picker keeps the picked date with [initial]'s time-of-day instead of
/// discarding the whole pick — used where only the due date matters and a
/// specific time isn't required.
Future<DateTime?> pickSheetDateTime(
  BuildContext context, {
  required DateTime initial,
  DateTime? lastDate,
  bool timeOptional = false,
}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 365)),
    lastDate: lastDate ?? DateTime.now().add(const Duration(days: 1)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) {
    if (!timeOptional) return null;
    return DateTime(date.year, date.month, date.day, initial.hour, initial.minute);
  }
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// A tappable row showing a label + formatted date/time — Care Log's edit
/// and manual-log sheets share this for Start/End fields.
class SheetTimeField extends StatelessWidget {
  const SheetTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.s),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.m,
        ),
        decoration: BoxDecoration(
          color: theme.colors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadii.s),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.clock,
              size: 18,
              color: theme.colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                label,
                style: theme.typography.label.copyWith(
                  color: theme.colors.textTertiary,
                ),
              ),
            ),
            Text(
              DateFormat('MMM d, ').add_jm().format(value),
              style: theme.typography.subtitle.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
