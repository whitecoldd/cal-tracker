import 'nutrition.dart';

/// How good a food is, as a collectable-card rarity.
///
/// Lives in `domain/` and carries no colour: the ranking is a nutrition
/// judgement and belongs with the rest of the maths, while what a rarity
/// *looks* like is the theme's business. Before T6 this enum sat in the widget
/// layer and the rule was duplicated at each call site, which is how the same
/// food could have read Epic in one list and Common in another.
enum FoodRarity {
  common('Common'),
  rare('Rare'),
  epic('Epic'),
  relic('Relic');

  const FoodRarity(this.title);

  final String title;
}

/// Nutrient density thresholds that lift a food a tier.
abstract final class _Dense {
  /// Grams of fibre per 100 g at which a food counts as fibre-rich.
  static const double fibreG = 5;

  /// Grams of protein per 100 g at which a food counts as protein-rich.
  static const double proteinG = 15;

  /// Fibre per 100 g for the top tier.
  static const double relicFibreG = 8;
}

/// Ranks a food from its processing level and nutrient density.
///
/// Processing leads because it is the more reliable signal: NOVA group comes
/// from the ingredient list, while density can be flattering for something
/// that is mostly one nutrient. So an ultra-processed protein bar does not
/// out-rank a lentil, which is the whole point of showing rarity before a food
/// is logged.
///
/// A food with no NOVA group is [FoodRarity.common]. Unknown is not a virtue,
/// and guessing upwards would make every hand-typed food look excellent.
FoodRarity rankFood(FoodPanel food) {
  final nova = food.novaGroup;
  if (nova == null) return FoodRarity.common;

  final fibreRich = food.fibreG >= _Dense.fibreG;
  final proteinRich = food.proteinG >= _Dense.proteinG;
  final dense = fibreRich || proteinRich;

  return switch (nova) {
    1 when food.fibreG >= _Dense.relicFibreG && proteinRich => FoodRarity.relic,
    1 when dense => FoodRarity.epic,
    1 => FoodRarity.rare,
    2 when dense => FoodRarity.rare,
    2 => FoodRarity.common,
    _ => FoodRarity.common,
  };
}
