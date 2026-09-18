import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../domain/parsed_meal.dart';
import '../../domain/portion.dart';
import '../daos/foods_dao.dart';
import '../database.dart';
import '../tables.dart';

/// A parsed item turned into something that can actually be logged.
class ResolvedItem {
  const ResolvedItem({
    required this.food,
    required this.quantity,
    required this.unit,
    required this.grams,
    required this.confidence,
    required this.wasAlreadyKnown,
  });

  /// A real row. An entry can reference it.
  final Food food;

  final double quantity;
  final PortionUnit unit;
  final double grams;

  /// 0..1 confidence in the portion.
  final double confidence;

  /// True when the food was already in the library and the model's guess at
  /// its nutrients was discarded.
  ///
  /// Surfaced so the confirm sheet can show which figures are the device's own
  /// and which are the model's — the two deserve different levels of trust.
  final bool wasAlreadyKnown;
}

/// Turns what the model said into rows, writing back everything new.
///
/// This is where CLAUDE.md §4's write-back rule is honoured for AI results: a
/// food the model described is stored permanently, so the same food never
/// costs a second call. It is also where the resolution order is applied *to
/// the model's own output* — if the device already knows the food, the model's
/// nutrients are thrown away in favour of the better local data, and only its
/// reading of the name and the portion survives.
class MealResolver {
  const MealResolver(this._foods);

  final FoodsDao _foods;

  /// Open Food Facts is deliberately **not** consulted here.
  ///
  /// It is a brand and barcode database, and a typed meal is almost entirely
  /// generic foods — "two eggs", "a slice of rye" — which the seed table and
  /// the user's own library already cover. Issuing a search per item would add
  /// a round trip each for answers that are usually worse than the seed's.
  /// The barcode path remains where Open Food Facts earns its place.
  Future<List<ResolvedItem>> resolve(ParsedMeal meal) async {
    final resolved = <ResolvedItem>[];

    for (final item in meal.items) {
      resolved.add(await _resolveOne(item));
    }

    return resolved;
  }

  Future<ResolvedItem> _resolveOne(ParsedItem item) async {
    final known = await _bestLocalMatch(item.food);
    final food = known ?? await _store(item.food);
    final portion = _grams(item, food);

    return ResolvedItem(
      food: food,
      quantity: item.quantity,
      unit: item.unit,
      grams: portion.grams,
      confidence: portion.confidence,
      wasAlreadyKnown: known != null,
    );
  }

  /// The library's own answer for this food, if it has a confident one.
  ///
  /// Exact search-key match only. A `LIKE` match is right for a search box,
  /// where the user is looking at the results and picking one, but wrong here:
  /// nothing is going to notice if "rye bread" silently resolves to "rye bread
  /// crackers" and the meal is logged against the wrong food.
  Future<Food?> _bestLocalMatch(ParsedFood parsed) async {
    final key = FoodsDao.searchKeyFor(parsed.name, parsed.brand);
    final matches = await _foods.search(parsed.name);

    for (final candidate in matches) {
      if (candidate.searchKey == key) return candidate;
    }

    // A named brand that did not match exactly is not worth guessing at.
    if (parsed.brand != null) return null;

    // Fall back to a name-only key, so "Egg, whole" typed by the user matches
    // the seed's "egg, whole" regardless of brand columns.
    final nameKey = FoodsDao.searchKeyFor(parsed.name);
    for (final candidate in matches) {
      if (candidate.searchKey == nameKey) return candidate;
    }

    return null;
  }

  /// Writes a food the model described into the library.
  ///
  /// `FoodSource.ai` is the weakest source, so a later barcode scan or hand
  /// correction is allowed to overwrite it — see [FoodsDao.upsert].
  Future<Food> _store(ParsedFood parsed) async {
    final stamp = clock.now().toIso8601String();
    final panel = parsed.panel;

    final id = await _foods.upsert(
      FoodsCompanion.insert(
        name: parsed.name,
        brand: Value(parsed.brand),
        // Recomputed by upsert; a placeholder keeps the normalisation rule in
        // one place.
        searchKey: '',
        kcal: panel.kcal,
        proteinG: Value(panel.proteinG),
        carbsG: Value(panel.carbsG),
        sugarG: Value(panel.sugarG),
        fatG: Value(panel.fatG),
        satFatG: Value(panel.satFatG),
        fibreG: Value(panel.fibreG),
        sodiumMg: Value(panel.sodiumMg),
        glycemicIndex: Value(panel.glycemicIndex),
        novaGroup: Value(panel.novaGroup),
        source: FoodSource.ai,
        confidence: Value(parsed.confidence),
        createdAt: stamp,
        updatedAt: stamp,
      ),
    );

    final stored = await _foods.findById(id);
    if (stored == null) {
      throw StateError('The food was written but could not be read back.');
    }
    return stored;
  }

  /// How many grams this item is, and how much to trust that.
  ///
  /// The model's own gram figure is used only when the device has nothing
  /// better. A food with a known piece weight resolves "2 eggs" more reliably
  /// than a language model does, and the unit table in `portion.dart` was
  /// written for exactly this.
  ({double grams, double confidence}) _grams(ParsedItem item, Food food) {
    final resolved = resolvePortion(
      quantity: item.quantity,
      unit: item.unit,
      gramsPerPiece: food.gramsPerPiece,
    );

    // A piece weight, or an exact unit, beats a guess.
    if (item.unit == PortionUnit.grams ||
        item.unit == PortionUnit.millilitres ||
        food.gramsPerPiece != null) {
      return (grams: resolved.grams, confidence: resolved.confidence);
    }

    final fromModel = item.grams;
    if (fromModel != null && fromModel >= _plausibleFor(item.unit)) {
      // The model committed to a figure and the device had nothing better.
      // Capped below the exact units' confidence: it is still a guess.
      return (
        grams: fromModel,
        confidence: item.confidence.clamp(0.0, 0.8),
      );
    }

    return (grams: resolved.grams, confidence: resolved.confidence);
  }

  /// The least a portion of one [unit] could weigh and still be that portion.
  ///
  /// A floor rather than a range, and a generous one: the point is not to
  /// second-guess the model but to catch the single failure seen in practice,
  /// which is a gram figure that is really the *quantity* wearing the wrong
  /// field. "chicken shawarma wrap, 1 piece, grams: 1" came back from a live
  /// call, and one gram of wrap logs as four kilocalories — a wrong entry that
  /// looks like a right one, in a journal whose whole worth is that the user
  /// trusts what they logged.
  ///
  /// Below the floor the unit's own default from `portion.dart` is used
  /// instead, which is what the app would have said with no model at all. The
  /// exact units never reach here: grams and millilitres are taken as given.
  static double _plausibleFor(PortionUnit unit) => switch (unit) {
        // Nothing a person calls a bowl, a plate or a piece weighs five grams.
        PortionUnit.piece ||
        PortionUnit.slice ||
        PortionUnit.handful ||
        PortionUnit.bowl ||
        PortionUnit.plate =>
          5,
        // A spoon of something can be genuinely tiny — a teaspoon of yeast is
        // about three grams — so these only have to be above nothing.
        PortionUnit.cup ||
        PortionUnit.tablespoon ||
        PortionUnit.teaspoon ||
        PortionUnit.grams ||
        PortionUnit.millilitres =>
          0.1,
      };
}
