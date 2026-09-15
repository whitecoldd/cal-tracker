import 'signs.dart';

/// A logged drink, in the only terms hydration cares about.
///
/// Deliberately not a `Food`: hydration is a property of what was drunk and how
/// much, and nothing else on a food row is relevant to it.
class Drink {
  const Drink({required this.millilitres, this.alcoholG = 0});

  final double millilitres;

  /// Grams of alcohol in the volume drunk — not per 100ml.
  final double alcoholG;
}

/// How much of a drink's volume counts towards hydration, 0..1.
///
/// One rule, and it is deliberately the only one: **alcohol credits nothing.**
///
/// The temptation is to discount coffee and tea as well, but no caffeine figure
/// is stored on a food anywhere in this app, so any such discount would be a
/// number with no source behind it — and the current evidence is that
/// caffeinated drinks hydrate about as well as water anyway. Alcohol is
/// different on both counts: it is stored, and it is a genuine diuretic.
/// Crediting it as nothing is the simplification that can never *overstate* how
/// much someone has drunk, which is the only direction that matters here.
///
/// Lore, not a physician — see CLAUDE.md §7.
double hydrationFactor(Drink drink) => drink.alcoholG > 0 ? 0 : 1;

/// Hydration credited by drinks that were logged as food, in millilitres.
int hydrationFromDrinks(Iterable<Drink> drinks) {
  var total = 0.0;
  for (final drink in drinks) {
    total += drink.millilitres * hydrationFactor(drink);
  }
  return total.round();
}

/// A day's hydration: what was tapped in, plus what was drunk as food.
///
/// The two sources are disjoint by construction — the tapped figure is a
/// `water_logs` row and the drink figure derives from `entries` — so they
/// cannot double count. Someone who both taps +500 and logs "Water, 500ml" has
/// recorded the same glass twice, which is a thing they did, not a thing the
/// app did.
class Hydration {
  const Hydration({required this.loggedMl, required this.fromDrinksMl});

  static const empty = Hydration(loggedMl: 0, fromDrinksMl: 0);

  /// Tapped into the waterskin directly.
  final int loggedMl;

  /// Derived from drinks logged as food.
  final int fromDrinksMl;

  int get totalMl => loggedMl + fromDrinksMl;

  /// Progress towards [waterTargetMl], clamped. Not a target the app enforces —
  /// it is what charges the Yrden glyph, and nothing else.
  double get fraction => (totalMl / waterTargetMl).clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) =>
      other is Hydration &&
      other.loggedMl == loggedMl &&
      other.fromDrinksMl == fromDrinksMl;

  @override
  int get hashCode => Object.hash(loggedMl, fromDrinksMl);

  @override
  String toString() => 'Hydration($loggedMl + $fromDrinksMl ml)';
}
