import 'package:flutter/material.dart' show TextField;
import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/sheet_transition.dart';
import '../../data/firestore/care_log_repository.dart';
import '../../data/models/care_log_entry.dart';
import '../care_log_type_style.dart';
import 'app_button.dart';
import 'manual_care_log_sheet.dart'
    show sleepPeriodOptions, feedMethodOptions, sheetFieldDecoration;
import 'quick_log_sheet.dart';
import 'sheet_time_field.dart';

/// Lets a saved care log entry's start/end time (and, for diaper, subtype;
/// for sleep, the day/night tag and a comment) be corrected after the fact
/// — for typos or a timer started/stopped a few minutes late.
Future<void> showEditCareLogSheet(
  BuildContext context,
  CareLogRepository repo,
  CareLogEntry entry,
) {
  return showAppSheet(
    context: context,
    builder: (context) => _EditCareLogSheet(repo: repo, entry: entry),
  );
}

class _EditCareLogSheet extends StatefulWidget {
  const _EditCareLogSheet({required this.repo, required this.entry});

  final CareLogRepository repo;
  final CareLogEntry entry;

  @override
  State<_EditCareLogSheet> createState() => _EditCareLogSheetState();
}

class _EditCareLogSheetState extends State<_EditCareLogSheet> {
  late DateTime _start = widget.entry.startTime;
  late DateTime? _end = widget.entry.endTime;
  late String? _subtype = widget.entry.subtype;
  late final _commentController = TextEditingController(
    text: widget.entry.note,
  );
  bool _saving = false;

  List<(String, IconData)>? get _subtypeOptions => switch (widget.entry.type) {
    CareLogType.diaper => diaperSubtypeOptions,
    CareLogType.sleep => sleepPeriodOptions,
    CareLogType.feed => feedMethodOptions,
    CareLogType.bath => null,
  };

  String get _subtypeLabel =>
      widget.entry.type == CareLogType.feed ? 'METHOD' : 'TYPE';

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await pickSheetDateTime(context, initial: _start);
    if (picked == null) return;
    setState(() {
      _start = picked;
      if (_end != null && _end!.isBefore(_start)) _end = _start;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await pickSheetDateTime(context, initial: _end ?? _start);
    if (picked == null) return;
    setState(() => _end = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final comment = _commentController.text.trim();
    await widget.repo.updateDetails(
      widget.entry.id,
      startTime: _start,
      endTime: _end,
      subtype: _subtype,
      note: comment.isEmpty ? null : comment,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final (_, label) = careLogTypeIconLabel(widget.entry.type);
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
            'Edit $label',
            style: theme.typography.title.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          if (_subtypeOptions != null) ...[
            Text(
              _subtypeLabel,
              style: theme.typography.label.copyWith(
                color: theme.colors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Row(
              children: [
                for (final (optionLabel, icon) in _subtypeOptions!) ...[
                  if (optionLabel != _subtypeOptions!.first.$1)
                    const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: SheetGridOption(
                      icon: icon,
                      label: optionLabel,
                      selected: _subtype == optionLabel,
                      onTap: () => setState(() => _subtype = optionLabel),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.l),
          ],
          SheetTimeField(
            label: widget.entry.endTime == null ? 'TIME' : 'STARTED',
            value: _start,
            onTap: _pickStart,
          ),
          if (_end != null) ...[
            const SizedBox(height: AppSpacing.m),
            SheetTimeField(label: 'ENDED', value: _end!, onTap: _pickEnd),
          ],
          const SizedBox(height: AppSpacing.l),
          Text(
            'COMMENT',
            style: theme.typography.label.copyWith(
              color: theme.colors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          TextField(
            controller: _commentController,
            maxLines: 3,
            style: theme.typography.body.copyWith(
              color: theme.colors.textPrimary,
            ),
            decoration: sheetFieldDecoration(context, 'Optional note'),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: _saving ? null : _save,
              child: Text(
                'Save changes',
                style: theme.typography.label.copyWith(
                  color: theme.colors.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
