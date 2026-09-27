import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator, InputDecoration, OutlineInputBorder, TextField, showDatePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion/app_motion.dart';
import '../../core/theme/motion/sheet_transition.dart';
import '../../core/theme/motion/staggered_entrance.dart';
import '../../core/theme/motion/tap_scale.dart';
import '../../data/models/growth_entry.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/app_section_header.dart';

enum _Measure { weight, height, headCircumference }

class GrowthScreen extends ConsumerStatefulWidget {
  const GrowthScreen({super.key});

  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen> {
  _Measure _measure = _Measure.weight;

  Future<void> _addEntry() async {
    final repo = ref.read(growthRepositoryProvider);
    if (repo == null) return;
    final result = await showAppSheet<GrowthEntry>(
      context: context,
      builder: (context) => const _AddGrowthEntrySheet(),
    );
    if (result != null) {
      await repo.add(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(growthEntriesProvider);
    final theme = AppTheme.of(context);

    return Stack(
      children: [
        entriesAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: theme.colors.primary),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Could not load growth data: $e',
                textAlign: TextAlign.center,
                style: theme.typography.body.copyWith(
                  color: theme.colors.textSecondary,
                ),
              ),
            ),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return const AppEmptyState(
                icon: LucideIcons.ruler,
                message: 'No growth entries yet — add your first measurement.',
              );
            }
            return _GrowthBody(
              entries: entries,
              measure: _measure,
              onMeasureChanged: (m) => setState(() => _measure = m),
            );
          },
        ),
        Positioned(
          right: AppSpacing.l,
          bottom: AppSpacing.l,
          child: AppButton(
            onPressed: _addEntry,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.plus, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Add entry',
                  style: theme.typography.label.copyWith(
                    color: theme.colors.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GrowthBody extends StatelessWidget {
  const _GrowthBody({
    required this.entries,
    required this.measure,
    required this.onMeasureChanged,
  });

  final List<GrowthEntry> entries;
  final _Measure measure;
  final ValueChanged<_Measure> onMeasureChanged;

  @override
  Widget build(BuildContext context) {
    final reversed = [for (var i = entries.length - 1; i >= 0; i--) entries[i]];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.s,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MeasureSegmentedControl(
                  measure: measure,
                  onChanged: onMeasureChanged,
                ),
                const SizedBox(height: AppSpacing.l),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.s,
                  ),
                  child: SizedBox(
                    height: 220,
                    child: _GrowthChart(entries: entries, measure: measure),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: AppSectionHeader('Entries')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          sliver: SliverList.list(
            children: [
              StaggeredListEntrance(
                children: [
                  for (final entry in reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s),
                      child: _GrowthEntryCard(entry: entry),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.xxxl)),
      ],
    );
  }
}

class _MeasureSegmentedControl extends StatelessWidget {
  const _MeasureSegmentedControl({
    required this.measure,
    required this.onChanged,
  });

  final _Measure measure;
  final ValueChanged<_Measure> onChanged;

  static const _segments = [
    (value: _Measure.weight, label: 'Weight'),
    (value: _Measure.height, label: 'Height'),
    (value: _Measure.headCircumference, label: 'Head'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      padding: const EdgeInsets.all(AppSpacing.xs),
      shadows: null,
      child: Row(
        children: [
          for (final segment in _segments)
            Expanded(
              child: _MeasureSegment(
                label: segment.label,
                selected: measure == segment.value,
                onTap: () => onChanged(segment.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _MeasureSegment extends StatelessWidget {
  const _MeasureSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    final typography = AppTheme.of(context).typography;
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        curve: AppMotion.curveStandard,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.surface : null,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          style: typography.label.copyWith(
            color: selected ? colors.textPrimary : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _GrowthEntryCard extends StatelessWidget {
  const _GrowthEntryCard({required this.entry});

  final GrowthEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMd().format(entry.date),
                  style: theme.typography.subtitle.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
                if (entry.note != null) ...[
                  const SizedBox(height: AppSpacing.xs / 2),
                  Text(
                    entry.note!,
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${entry.weightKg.toStringAsFixed(1)} kg · ${entry.heightCm.toStringAsFixed(0)} cm',
            style: theme.typography.body.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthChart extends StatelessWidget {
  const _GrowthChart({required this.entries, required this.measure});

  final List<GrowthEntry> entries;
  final _Measure measure;

  double? _value(GrowthEntry e) {
    switch (measure) {
      case _Measure.weight:
        return e.weightKg;
      case _Measure.height:
        return e.heightCm;
      case _Measure.headCircumference:
        return e.headCircumferenceCm;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final plotted = entries.where((e) => _value(e) != null).toList();
    if (plotted.isEmpty) {
      return Center(
        child: Text(
          measure == _Measure.headCircumference
              ? 'No head circumference entries yet.'
              : 'Not enough data yet.',
          style: theme.typography.body.copyWith(
            color: theme.colors.textSecondary,
          ),
        ),
      );
    }
    final first = plotted.first.date;
    final spots = [
      for (final e in plotted)
        FlSpot(e.date.difference(first).inDays.toDouble(), _value(e)!),
    ];
    final color = theme.colors.primary;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: theme.typography.caption.copyWith(
                  color: theme.colors.textTertiary,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  DateFormat.Md().format(
                    first.add(Duration(days: value.toInt())),
                  ),
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddGrowthEntrySheet extends StatefulWidget {
  const _AddGrowthEntrySheet();

  @override
  State<_AddGrowthEntrySheet> createState() => _AddGrowthEntrySheetState();
}

class _AddGrowthEntrySheetState extends State<_AddGrowthEntrySheet> {
  DateTime _date = DateTime.now();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _headController = TextEditingController();

  bool get _canSave =>
      double.tryParse(_weightController.text) != null &&
      double.tryParse(_heightController.text) != null;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      GrowthEntry(
        id: '',
        date: _date,
        weightKg: double.parse(_weightController.text),
        heightCm: double.parse(_heightController.text),
        headCircumferenceCm: double.tryParse(_headController.text),
      ),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _headController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.l,
        AppSpacing.xxl,
        AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add growth entry',
            style: theme.typography.title.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          _DateField(date: _date, onTap: _pickDate),
          const SizedBox(height: AppSpacing.m),
          _NumberField(
            controller: _weightController,
            label: 'Weight (kg)',
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.m),
          _NumberField(
            controller: _heightController,
            label: 'Height (cm)',
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.m),
          _NumberField(
            controller: _headController,
            label: 'Head circumference (cm) — optional',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            onPressed: _canSave ? _save : null,
            child: Text(
              'Save',
              style: theme.typography.label.copyWith(
                color: theme.colors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.s),
      child: AppGlassSurface(
        borderRadius: BorderRadius.circular(AppRadii.s),
        shadows: null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Row(
          children: [
            Icon(LucideIcons.calendar, size: 18, color: theme.colors.textSecondary),
            const SizedBox(width: AppSpacing.s),
            Text(
              DateFormat.yMMMd().format(date),
              style: theme.typography.body.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
      cursorColor: theme.colors.primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: theme.typography.body.copyWith(
          color: theme.colors.textSecondary,
        ),
        filled: true,
        fillColor: theme.colors.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.s),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: onChanged == null ? null : (_) => onChanged!(),
    );
  }
}
