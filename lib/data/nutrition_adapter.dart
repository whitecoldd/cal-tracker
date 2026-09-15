import 'dart:convert';

import '../domain/nutrition.dart';
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
        additiveCount: _additiveCount(additivesJson),
      );
}

extension ServingRow on LoggedItem {
  Serving get serving => Serving(food: food.panel, grams: entry.grams);
}

extension ServingRows on Iterable<LoggedItem> {
  Iterable<Serving> get servings => map((i) => i.serving);
}

/// Counts additive tags in the stored JSON array.
///
/// Returns zero for anything unreadable rather than throwing. This column is
/// written from Open Food Facts, whose data is crowd-sourced; a malformed value
/// should cost one food its additive count, not bring down the Alchemy screen.
int _additiveCount(String? json) {
  if (json == null || json.isEmpty) return 0;
  try {
    final decoded = jsonDecode(json);
    return decoded is List ? decoded.length : 0;
  } on FormatException {
    return 0;
  }
}
