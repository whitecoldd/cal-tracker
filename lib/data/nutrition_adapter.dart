import 'dart:convert';

import '../domain/harm.dart';
import '../domain/hydration.dart';
import '../domain/nutrition.dart';
import '../domain/portion.dart';
import 'daos/journal_dao.dart';
import 'database.dart';

/// Adapts stored rows into the pure types the nutrition engine works on.
///
/// The engine in `domain/` must not know that drift exists — that is what makes
/// the scoring maths testable against hand-written fixtures with no database in
/// the room. The cost of that is this file, and it is a cheap one.
extension FoodPanelRow on Food {
  FoodPanel get panel => FoodPanel(
        kcal: kcal,
        proteinG: proteinG,
        carbsG: carbsG,
        sugarG: sugarG,
        addedSugarG: addedSugarG,
        fatG: fatG,
        satFatG: satFatG,
        transFatG: transFatG,
        fibreG: fibreG,
        sodiumMg: sodiumMg,
        alcoholG: alcoholG,
        glycemicIndex: glycemicIndex,
        novaGroup: novaGroup,
        additives: _additives(additivesJson),
      );
}

extension ServingRow on LoggedItem {
  Serving get serving => Serving(food: food.panel, grams: entry.grams);
}

extension ServingRows on Iterable<LoggedItem> {
  Iterable<Serving> get servings => map((i) => i.serving);

  /// The entries that were logged as a volume.
  ///
  /// A food counts as a drink because of **how it was logged**, not because of
  /// anything on the food row — nothing there marks a food as a liquid, and
  /// the same row can be a splash of milk or a glass of it.
  ///
  /// Grams and millilitres are the same number here, which is not a fudge:
  /// [PortionUnit.millilitres] already declares one gram per millilitre, so the
  /// app has been treating the two as interchangeable since T4 and `grams` on
  /// one of these entries *is* the volume.
  Iterable<Drink> get drinks => where(
        (i) => i.entry.unit == PortionUnit.millilitres,
      ).map(
        (i) => Drink(
          millilitres: i.entry.grams,
          // alcoholG on the food is per 100g; the serving scales it.
          alcoholG: i.serving.alcoholG,
        ),
      );
}

/// Reads the additive tags out of the stored JSON array, as E-numbers.
///
/// Returns an empty list for anything unreadable rather than throwing. This
/// column is written from Open Food Facts, whose data is crowd-sourced; a
/// malformed value should cost one food its additive list, not bring down the
/// Alchemy screen.
///
/// Normalising here rather than at the point of display is deliberate: it is
/// the boundary where a stored tag becomes a domain value, and doing it once
/// means nothing downstream has to know that `en:e150d` and `E150d` are the
/// same additive.
List<String> _additives(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];

    final seen = <String>{};
    for (final tag in decoded) {
      if (tag is! String) continue;
      final code = additiveCode(tag);
      if (code.isNotEmpty) seen.add(code);
    }
    return List.unmodifiable(seen);
  } on FormatException {
    return const [];
  }
}
