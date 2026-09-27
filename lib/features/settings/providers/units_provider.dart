import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local display-unit preferences for Growth measurements. In-memory only,
/// same pattern as `themeModeProvider` — not yet persisted or synced to
/// Firestore (see docs/DESIGN_SYSTEM.md#11-adoption-tracker).
enum WeightUnit { kg, lb }

enum LengthUnit { cm, inch }

class WeightUnitNotifier extends Notifier<WeightUnit> {
  @override
  WeightUnit build() => WeightUnit.kg;

  void set(WeightUnit unit) => state = unit;
}

class LengthUnitNotifier extends Notifier<LengthUnit> {
  @override
  LengthUnit build() => LengthUnit.cm;

  void set(LengthUnit unit) => state = unit;
}

final weightUnitProvider = NotifierProvider<WeightUnitNotifier, WeightUnit>(
  WeightUnitNotifier.new,
);

final lengthUnitProvider = NotifierProvider<LengthUnitNotifier, LengthUnit>(
  LengthUnitNotifier.new,
);
