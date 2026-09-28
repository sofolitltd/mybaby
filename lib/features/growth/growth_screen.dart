import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart'
    show
        CircularProgressIndicator,
        InputDecoration,
        OutlineInputBorder,
        TextField,
        showDatePicker;
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
import '../../data/models/baby.dart';
import '../../data/models/growth_entry.dart';
import '../../data/who_growth/who_percentile.dart';
import '../babies/widgets/baby_screen_header.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_extended_fab.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_section_header.dart';
import '../../shared/widgets/app_status_pill.dart';

enum _Measure { weight, height, headCircumference }

GrowthMeasure _whoMeasure(_Measure measure) =>
    GrowthMeasure.values[measure.index];

GrowthSex _sexOf(Baby? baby) =>
    baby?.sex == 'Girl' ? GrowthSex.female : GrowthSex.male;

/// Fractional age in months at [at] — the unit the WHO LMS tables are keyed
/// by. Used to interpolate L/M/S for a percentile lookup at any date.
double _ageInMonths(DateTime dob, DateTime at) =>
    at.difference(dob).inDays / 30.4368;

double _ageInWeeks(DateTime dob, DateTime at) => at.difference(dob).inDays / 7;

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

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BabyScreenHeader(title: 'Growth'),
            Expanded(
              child: Stack(
                children: [
                  entriesAsync.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        color: theme.colors.primary,
                      ),
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
                          message:
                              'No growth entries yet — add your first measurement.',
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
                    right: AppSpacing.xl,
                    bottom: AppSpacing.l,
                    child: AppExtendedFab(
                      icon: LucideIcons.plus,
                      label: 'Add Measurement',
                      onTap: _addEntry,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                _WhoPercentileCard(entries: entries, measure: measure),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AppSectionHeader(
            'ENTRIES',
            trailing: Text(
              '${reversed.length} Total',
              style: AppTheme.of(context).typography.label
                  .copyWith(color: AppTheme.of(context).colors.textTertiary),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          sliver: SliverList.list(
            children: [
              StaggeredListEntrance(
                children: [
                  for (var i = 0; i < reversed.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s),
                      child: _GrowthEntryCard(
                        entry: reversed[i],
                        previous: i + 1 < reversed.length
                            ? reversed[i + 1]
                            : null,
                        measure: measure,
                        isLatest: i == 0,
                        isBirth: i == reversed.length - 1,
                      ),
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

double? _measureValue(GrowthEntry e, _Measure measure) => switch (measure) {
  _Measure.weight => e.weightKg,
  _Measure.height => e.heightCm,
  _Measure.headCircumference => e.headCircumferenceCm,
};

String _measureUnit(_Measure measure) =>
    measure == _Measure.weight ? 'kg' : 'cm';

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
    final colors = AppTheme.of(context).colors;
    return AppGlassSurface(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      padding: const EdgeInsets.all(AppSpacing.xs),
      shadows: null,
      border: false,
      fill: colors.surfaceSunken,
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
          boxShadow: selected ? AppShadows.card : null,
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

/// The Stitch Growth mockup's single white card: a "WHO PERCENTILE CURVE"
/// tag + sex/age-window caption, the current-value readout with its
/// percentile pill, the chart itself (baby's own line over the WHO normal
/// range band + 50th-percentile median), and a swatch legend underneath.
class _WhoPercentileCard extends ConsumerWidget {
  const _WhoPercentileCard({required this.entries, required this.measure});

  final List<GrowthEntry> entries;
  final _Measure measure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final baby = ref.watch(activeBabyProvider);
    final sex = _sexOf(baby);
    final sexLabel = baby?.sex == 'Girl' ? 'Girls' : 'Boys';
    final whoMeasure = _whoMeasure(measure);

    final latest = entries.reversed.firstWhere(
      (e) => _measureValue(e, measure) != null,
      orElse: () => entries.last,
    );
    final value = _measureValue(latest, measure);
    final ageWeeks = baby == null ? null : _ageInWeeks(baby.dob, latest.date);
    double? percentile;
    if (baby != null && value != null) {
      final lms = lmsAt(whoMeasure, sex, _ageInMonths(baby.dob, latest.date));
      percentile = percentileForValue(lms, value);
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppStatusPill(
                label: 'WHO PERCENTILE CURVE',
                color: colors.primary,
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ageWeeks != null && ageWeeks <= 13
                        ? '$sexLabel 0–13 Wks'
                        : '$sexLabel 0–24 Months',
                    style: theme.typography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  if (baby != null) ...[
                    const SizedBox(height: AppSpacing.xs / 2),
                    Text(
                      'Current Age',
                      style: theme.typography.label.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                    Text(
                      '${baby.ageInWeeks} Weeks',
                      style: theme.typography.subtitle.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                value == null ? '—' : value.toStringAsFixed(1),
                style: theme.typography.numeralL.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              if (percentile != null) ...[
                const SizedBox(width: AppSpacing.s),
                AppStatusPill(
                  label: '${ordinalPercentile(percentile)} %ile',
                  color: colors.primary,
                ),
              ],
            ],
          ),
          Text(
            _measureUnit(measure),
            style: theme.typography.caption.copyWith(
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          SizedBox(
            height: 220,
            child: entries.isEmpty || baby == null
                ? _GrowthChartEmpty(measure: measure)
                : _GrowthChart(
                    entries: entries,
                    measure: measure,
                    dob: baby.dob,
                    sex: sex,
                  ),
          ),
          const SizedBox(height: AppSpacing.m),
          _ChartLegend(babyName: baby?.name ?? 'Baby'),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.babyName});

  final String babyName;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Wrap(
      spacing: AppSpacing.l,
      runSpacing: AppSpacing.xs,
      children: [
        _LegendItem(
          swatch: Container(width: 16, height: 3, color: colors.primary),
          label: babyName,
        ),
        _LegendItem(
          swatch: CustomPaint(
            size: const Size(16, 3),
            painter: _DashedLinePainter(color: colors.textTertiary),
          ),
          label: '50th Percentile',
        ),
        _LegendItem(
          swatch: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: colors.textTertiary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          label: 'Normal Range',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.swatch, required this.label});

  final Widget swatch;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.typography.caption.copyWith(
            color: theme.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dashWidth = 3.0;
    const gapWidth = 2.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _GrowthChartEmpty extends StatelessWidget {
  const _GrowthChartEmpty({required this.measure});

  final _Measure measure;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
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
}

class _GrowthEntryCard extends ConsumerWidget {
  const _GrowthEntryCard({
    required this.entry,
    required this.previous,
    required this.measure,
    required this.isLatest,
    required this.isBirth,
  });

  final GrowthEntry entry;
  final GrowthEntry? previous;
  final _Measure measure;
  final bool isLatest;
  final bool isBirth;

  /// "+0.4 kg since 2w" — delta from the prior entry for the selected
  /// measure, matching the Stitch Growth mockup's entry rows. `null` when
  /// there's no earlier entry with this measure to compare against.
  String? get _deltaLabel {
    final current = _measureValue(entry, measure);
    final prior = previous == null ? null : _measureValue(previous!, measure);
    if (current == null || prior == null) return null;
    final delta = current - prior;
    if (delta == 0) return null;
    final sign = delta > 0 ? '+' : '';
    final weeks = entry.date.difference(previous!.date).inDays ~/ 7;
    final since = weeks >= 1
        ? '${weeks}w'
        : '${entry.date.difference(previous!.date).inDays}d';
    return '$sign${delta.toStringAsFixed(1)} ${_measureUnit(measure)} since $since';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final delta = _deltaLabel;
    final baby = ref.watch(activeBabyProvider);
    final value = _measureValue(entry, measure);
    double? percentile;
    if (baby != null && value != null) {
      final lms = lmsAt(
        _whoMeasure(measure),
        _sexOf(baby),
        _ageInMonths(baby.dob, entry.date),
      );
      percentile = percentileForValue(lms, value);
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat.yMMMd().format(entry.date),
                style: theme.typography.subtitle.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              if (isLatest || isBirth) ...[
                const SizedBox(width: AppSpacing.s),
                AppStatusPill(
                  label: isLatest ? 'Latest' : 'Birth',
                  color: isLatest ? colors.primary : colors.textTertiary,
                ),
              ],
              const Spacer(),
              if (percentile != null)
                AppStatusPill(
                  label: '${ordinalPercentile(percentile)} %ile',
                  color: colors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              '${entry.weightKg.toStringAsFixed(1)} kg',
              '${entry.heightCm.toStringAsFixed(0)} cm',
              if (entry.headCircumferenceCm != null)
                '${entry.headCircumferenceCm!.toStringAsFixed(0)} cm Head',
            ].join(' · '),
            style: theme.typography.body.copyWith(color: colors.textSecondary),
          ),
          if (entry.note != null) ...[
            const SizedBox(height: AppSpacing.xs / 2),
            Text(
              entry.note!,
              style: theme.typography.caption.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ],
          if (delta != null) ...[
            const SizedBox(height: AppSpacing.xs / 2),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                delta,
                style: theme.typography.caption.copyWith(color: colors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Baby's own measurements plotted against the WHO Child Growth Standards:
/// a shaded "normal range" band (~3rd–97th percentile), a dashed 50th
/// percentile median, and the baby's solid line with a tooltip on the
/// latest point. See docs/DESIGN_SYSTEM.md#8-components (Growth — "Known
/// gap" note, now resolved via lib/data/who_growth).
class _GrowthChart extends StatelessWidget {
  const _GrowthChart({
    required this.entries,
    required this.measure,
    required this.dob,
    required this.sex,
  });

  final List<GrowthEntry> entries;
  final _Measure measure;
  final DateTime dob;
  final GrowthSex sex;

  double? _value(GrowthEntry e) => _measureValue(e, measure);

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final plotted = entries.where((e) => _value(e) != null).toList();
    if (plotted.isEmpty) {
      return _GrowthChartEmpty(measure: measure);
    }

    final whoMeasure = _whoMeasure(measure);
    final babySpots = [
      for (final e in plotted) FlSpot(_ageInWeeks(dob, e.date), _value(e)!),
    ];
    final currentAgeWeeks = _ageInWeeks(dob, DateTime.now());
    final domainEndWeeks =
        [
          babySpots.last.x,
          currentAgeWeeks,
          12.0,
        ].reduce((a, b) => a > b ? a : b) *
        1.15;

    const steps = 24;
    final lowSpots = <FlSpot>[];
    final medianSpots = <FlSpot>[];
    final highSpots = <FlSpot>[];
    for (var i = 0; i <= steps; i++) {
      final weeks = domainEndWeeks * i / steps;
      final lms = lmsAt(whoMeasure, sex, weeks / 4.34524);
      lowSpots.add(FlSpot(weeks, valueForZ(lms, kWhoNormalRangeLowZ)));
      medianSpots.add(FlSpot(weeks, valueForZ(lms, kWhoMedianZ)));
      highSpots.add(FlSpot(weeks, valueForZ(lms, kWhoNormalRangeHighZ)));
    }

    const lowIndex = 0;
    const highIndex = 1;
    const babyIndex = 3;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: domainEndWeeks,
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
              interval: (domainEndWeeks / 5).clamp(1, double.infinity),
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  value <= 0 ? 'Birth' : '${value.round()}w',
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            VerticalLine(
              x: currentAgeWeeks.clamp(0, domainEndWeeks),
              color: colors.hairline,
              strokeWidth: 1,
              dashArray: [3, 3],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: theme.typography.label.copyWith(color: colors.primary),
                labelResolver: (_) => 'Now',
              ),
            ),
          ],
        ),
        lineTouchData: LineTouchData(
          enabled: false,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.textPrimary,
            tooltipBorderRadius: BorderRadius.circular(AppRadii.s),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s,
              vertical: AppSpacing.xs,
            ),
            getTooltipItems: (spots) => spots.map((spot) {
              if (spot.barIndex != babyIndex) return null;
              final lms = lmsAt(whoMeasure, sex, spot.x / 4.34524);
              final pct = percentileForValue(lms, spot.y);
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(1)} ${_measureUnit(measure)} · ${ordinalPercentile(pct)} %',
                theme.typography.caption.copyWith(color: colors.onPrimary),
              );
            }).toList(),
          ),
        ),
        showingTooltipIndicators: [
          ShowingTooltipIndicators([
            LineBarSpot(
              LineChartBarData(spots: babySpots),
              babyIndex,
              babySpots.last,
            ),
          ]),
        ],
        betweenBarsData: [
          BetweenBarsData(
            fromIndex: lowIndex,
            toIndex: highIndex,
            color: colors.textTertiary.withValues(alpha: 0.14),
          ),
        ],
        lineBarsData: [
          LineChartBarData(
            spots: lowSpots,
            isCurved: true,
            color: colors.textTertiary.withValues(alpha: 0.3),
            barWidth: 1,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: highSpots,
            isCurved: true,
            color: colors.textTertiary.withValues(alpha: 0.3),
            barWidth: 1,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: medianSpots,
            isCurved: true,
            color: colors.textTertiary,
            barWidth: 1.5,
            dashArray: [4, 4],
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: babySpots,
            isCurved: true,
            color: colors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
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
            Icon(
              LucideIcons.calendar,
              size: 18,
              color: theme.colors.textSecondary,
            ),
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
