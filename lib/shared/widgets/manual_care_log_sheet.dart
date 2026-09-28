import 'package:flutter/material.dart' show InputDecoration, OutlineInputBorder, TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/sheet_transition.dart';
import '../../data/firestore/care_log_repository.dart';
import '../../data/models/care_log_entry.dart';
import 'app_button.dart';
import 'app_chip.dart';
import 'quick_log_sheet.dart' show SheetGridOption;
import 'sheet_time_field.dart';

const sleepPeriodOptions = [
  ('Day', LucideIcons.sun),
  ('Night', LucideIcons.moon),
];

const feedMethodOptions = [
  ('Left', LucideIcons.arrow_left),
  ('Right', LucideIcons.arrow_right),
  ('Both', LucideIcons.arrow_left_right),
  ('Bottle', LucideIcons.milk),
];

/// Shared surfaceSunken-filled, borderless [TextField] look used by care
/// log's comment fields.
InputDecoration sheetFieldDecoration(BuildContext context, String hint) {
  final theme = AppTheme.of(context);
  return InputDecoration(
    hintText: hint,
    hintStyle: theme.typography.body.copyWith(color: theme.colors.textTertiary),
    filled: true,
    fillColor: theme.colors.surfaceSunken,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.m,
      vertical: AppSpacing.m,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.s),
      borderSide: BorderSide.none,
    ),
  );
}

enum _EndMode { ongoing, endTime }

/// Full manual log form shared by Feed and Sleep quick-log — Start/End,
/// a subtype tag (day/night for sleep; left/right/bottle for feed), and an
/// optional comment. Reached
/// from Quick Log when no timer of that type is already running; an
/// already-running timer still goes through the simpler stop sheet.
Future<void> showManualCareLogSheet(
  BuildContext context,
  CareLogRepository repo, {
  required CareLogType type,
  required String title,
  required String subtypeLabel,
  required List<(String, IconData)> subtypeOptions,
  required String defaultSubtype,
  required String ongoingChipLabel,
}) {
  return showAppSheet(
    context: context,
    builder: (context) => _ManualCareLogSheet(
      repo: repo,
      type: type,
      title: title,
      subtypeLabel: subtypeLabel,
      subtypeOptions: subtypeOptions,
      defaultSubtype: defaultSubtype,
      ongoingChipLabel: ongoingChipLabel,
    ),
  );
}

class _ManualCareLogSheet extends StatefulWidget {
  const _ManualCareLogSheet({
    required this.repo,
    required this.type,
    required this.title,
    required this.subtypeLabel,
    required this.subtypeOptions,
    required this.defaultSubtype,
    required this.ongoingChipLabel,
  });

  final CareLogRepository repo;
  final CareLogType type;
  final String title;
  final String subtypeLabel;
  final List<(String, IconData)> subtypeOptions;
  final String defaultSubtype;
  final String ongoingChipLabel;

  @override
  State<_ManualCareLogSheet> createState() => _ManualCareLogSheetState();
}

class _ManualCareLogSheetState extends State<_ManualCareLogSheet> {
  DateTime _start = DateTime.now();
  late String _subtype = widget.defaultSubtype;
  _EndMode _endMode = _EndMode.ongoing;
  DateTime? _end;
  final _commentController = TextEditingController();
  bool _saving = false;

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
    final DateTime? end = switch (_endMode) {
      _EndMode.ongoing => null,
      _EndMode.endTime => _end ?? _start,
    };
    final comment = _commentController.text.trim();
    await widget.repo.add(
      CareLogEntry(
        id: '',
        type: widget.type,
        startTime: _start,
        endTime: end,
        subtype: _subtype,
        note: comment.isEmpty ? null : comment,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
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
            widget.title,
            style: theme.typography.title.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          _SectionLabel(widget.subtypeLabel),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              for (final (label, icon) in widget.subtypeOptions) ...[
                if (label != widget.subtypeOptions.first.$1)
                  const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: SheetGridOption(
                    icon: icon,
                    label: label,
                    selected: _subtype == label,
                    onTap: () => setState(() => _subtype = label),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          _SectionLabel('START'),
          const SizedBox(height: AppSpacing.s),
          SheetTimeField(label: 'STARTED', value: _start, onTap: _pickStart),
          const SizedBox(height: AppSpacing.l),
          _SectionLabel('END'),
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              AppChip(
                label: widget.ongoingChipLabel,
                selected: _endMode == _EndMode.ongoing,
                onTap: () => setState(() => _endMode = _EndMode.ongoing),
              ),
              AppChip(
                label: 'End time',
                selected: _endMode == _EndMode.endTime,
                onTap: () => setState(() => _endMode = _EndMode.endTime),
              ),
            ],
          ),
          if (_endMode == _EndMode.endTime) ...[
            const SizedBox(height: AppSpacing.s),
            SheetTimeField(
              label: 'ENDED',
              value: _end ?? _start,
              onTap: _pickEnd,
            ),
          ],
          const SizedBox(height: AppSpacing.l),
          _SectionLabel('COMMENT'),
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
                'Save',
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Text(
      text,
      style: theme.typography.label.copyWith(color: theme.colors.textTertiary),
    );
  }
}

/// Simpler manual log form for instant, no-duration entries (diaper, bath)
/// — a start time, an optional subtype grid, and a comment, no end/duration
/// picker since these never run as a timer.
Future<void> showInstantCareLogSheet(
  BuildContext context,
  CareLogRepository repo, {
  required CareLogType type,
  required String title,
  String? subtypeLabel,
  List<(String, IconData)>? subtypeOptions,
  String? defaultSubtype,
}) {
  return showAppSheet(
    context: context,
    builder: (context) => _InstantCareLogSheet(
      repo: repo,
      type: type,
      title: title,
      subtypeLabel: subtypeLabel,
      subtypeOptions: subtypeOptions,
      defaultSubtype: defaultSubtype,
    ),
  );
}

class _InstantCareLogSheet extends StatefulWidget {
  const _InstantCareLogSheet({
    required this.repo,
    required this.type,
    required this.title,
    this.subtypeLabel,
    this.subtypeOptions,
    this.defaultSubtype,
  });

  final CareLogRepository repo;
  final CareLogType type;
  final String title;
  final String? subtypeLabel;
  final List<(String, IconData)>? subtypeOptions;
  final String? defaultSubtype;

  @override
  State<_InstantCareLogSheet> createState() => _InstantCareLogSheetState();
}

class _InstantCareLogSheetState extends State<_InstantCareLogSheet> {
  DateTime _start = DateTime.now();
  late String? _subtype = widget.defaultSubtype;
  final _commentController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await pickSheetDateTime(context, initial: _start);
    if (picked == null) return;
    setState(() => _start = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final comment = _commentController.text.trim();
    await widget.repo.add(
      CareLogEntry(
        id: '',
        type: widget.type,
        startTime: _start,
        subtype: _subtype,
        note: comment.isEmpty ? null : comment,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final options = widget.subtypeOptions;
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
            widget.title,
            style: theme.typography.title.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          if (options != null) ...[
            _SectionLabel(widget.subtypeLabel ?? 'TYPE'),
            const SizedBox(height: AppSpacing.s),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.s,
              crossAxisSpacing: AppSpacing.s,
              childAspectRatio: 2.4,
              children: [
                for (final (label, icon) in options)
                  SheetGridOption(
                    icon: icon,
                    label: label,
                    selected: _subtype == label,
                    onTap: () => setState(() => _subtype = label),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
          ],
          _SectionLabel('TIME'),
          const SizedBox(height: AppSpacing.s),
          SheetTimeField(label: 'LOGGED', value: _start, onTap: _pickStart),
          const SizedBox(height: AppSpacing.l),
          _SectionLabel('COMMENT'),
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
                'Save',
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
