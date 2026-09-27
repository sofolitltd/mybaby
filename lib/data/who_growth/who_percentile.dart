import 'dart:math' as math;

import 'who_lms_data.dart';

/// Sex as used by the WHO Child Growth Standards LMS tables (no "unknown"
/// table exists — callers default to [male] when a baby's sex isn't set).
enum GrowthSex { male, female }

enum GrowthMeasure { weight, height, headCircumference }

/// Standard-normal Z-scores for the percentile curves drawn on the chart —
/// fixed points defined by the WHO tables themselves, so no inverse-CDF is
/// needed to place them.
const kWhoNormalRangeLowZ = -1.881; // ~3rd percentile
const kWhoNormalRangeHighZ = 1.881; // ~97th percentile
const kWhoMedianZ = 0.0;

List<WhoLmsPoint> _table(GrowthMeasure measure, GrowthSex sex) {
  final male = sex == GrowthSex.male;
  return switch (measure) {
    GrowthMeasure.weight => male ? whoWeightMale : whoWeightFemale,
    GrowthMeasure.height => male ? whoHeightMale : whoHeightFemale,
    GrowthMeasure.headCircumference =>
      male ? whoHeadCircumferenceMale : whoHeadCircumferenceFemale,
  };
}

/// Interpolated L/M/S at a fractional age in months, clamped to the table's
/// 0–24 month range (the WHO 0–2yr reference set the app ships).
WhoLmsPoint lmsAt(GrowthMeasure measure, GrowthSex sex, double ageMonths) {
  final table = _table(measure, sex);
  final clamped = ageMonths.clamp(0, table.last.months.toDouble());
  final lower = clamped.floor();
  final upper = math.min(lower + 1, table.last.months);
  final a = table[lower];
  if (lower == upper) return a;
  final b = table[upper];
  final t = clamped - lower;
  return WhoLmsPoint(
    lower,
    a.l + (b.l - a.l) * t,
    a.m + (b.m - a.m) * t,
    a.s + (b.s - a.s) * t,
  );
}

/// Value at a given LMS point and standard-normal Z-score (the WHO
/// Box-Cox-power-exponential inverse transform).
double valueForZ(WhoLmsPoint lms, double z) {
  if (lms.l == 0) return lms.m * math.exp(lms.s * z);
  return lms.m * math.pow(1 + lms.l * lms.s * z, 1 / lms.l);
}

/// Z-score for a measured value at a given LMS point.
double zForValue(WhoLmsPoint lms, double x) {
  if (lms.l == 0) return math.log(x / lms.m) / lms.s;
  return (math.pow(x / lms.m, lms.l) - 1) / (lms.l * lms.s);
}

/// Percentile (0–100) for a measured value at a given LMS point, via the
/// standard normal CDF (Abramowitz & Stegun 26.2.17 approximation).
double percentileForValue(WhoLmsPoint lms, double x) {
  final z = zForValue(lms, x);
  return _standardNormalCdf(z) * 100;
}

double _standardNormalCdf(double z) {
  const b1 = 0.319381530;
  const b2 = -0.356563782;
  const b3 = 1.781477937;
  const b4 = -1.821255978;
  const b5 = 1.330274429;
  const p = 0.2316419;
  final absZ = z.abs();
  final t = 1 / (1 + p * absZ);
  final poly = ((((b5 * t + b4) * t + b3) * t + b2) * t + b1) * t;
  final density = math.exp(-absZ * absZ / 2) / math.sqrt(2 * math.pi);
  final cdf = 1 - density * poly;
  return z >= 0 ? cdf : 1 - cdf;
}

/// Nearest-ordinal label for a percentile, e.g. 52 -> "52nd", 50 -> "50th".
String ordinalPercentile(double percentile) {
  final rounded = percentile.round().clamp(1, 99);
  if (rounded % 100 >= 11 && rounded % 100 <= 13) return '${rounded}th';
  return switch (rounded % 10) {
    1 => '${rounded}st',
    2 => '${rounded}nd',
    3 => '${rounded}rd',
    _ => '${rounded}th',
  };
}
