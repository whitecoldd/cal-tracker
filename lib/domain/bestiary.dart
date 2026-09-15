/// The Bestiary — every food ever logged, as a creature entry. Pure Dart.
///
/// A food's entry is built from the scoring that already exists: `rankFood`
/// for rarity, `readFoodToxins` for its weaknesses. Nothing new is invented
/// here, which is the point — a food must not read Epic in the picker and
/// Rare in the collection.
library;

import 'day.dart';
import 'harm.dart';
import 'nutrition.dart';
import 'rarity.dart';

/// One creature: a food, with what the app knows about it.
class Creature {
  const Creature({
    required this.id,
    required this.name,
    required this.panel,
    required this.rarity,
    required this.toxins,
    this.brand,
    this.timesEaten = 0,
    this.firstSeen,
    this.imagePath,
  });

  /// Builds an entry from a food and how often it has been logged.
  factory Creature.of({
    required int id,
    required String name,
    required FoodPanel panel,
    String? brand,
    int timesEaten = 0,
    Day? firstSeen,
    String? imagePath,
  }) {
    return Creature(
      id: id,
      name: name,
      brand: brand,
      panel: panel,
      // The same two calls the food picker makes. One rule each, in one place.
      rarity: rankFood(panel),
      toxins: readFoodToxins(panel),
      timesEaten: timesEaten,
      firstSeen: firstSeen,
      imagePath: imagePath,
    );
  }

  final int id;
  final String name;
  final String? brand;
  final FoodPanel panel;
  final FoodRarity rarity;

  /// Its weaknesses, read per 100 g.
  final Toxins toxins;

  final int timesEaten;
  final Day? firstSeen;
  final String? imagePath;

  /// Whether this food has actually been eaten, or only ever looked up.
  ///
  /// The library holds the whole seed table from the first launch, so "in the
  /// library" and "in the collection" are different things — and a Bestiary
  /// that claimed 132 creatures on day one would mean nothing.
  bool get isCaught => timesEaten > 0;

  /// The harm readings worth showing on the card.
  List<HarmFlag> get weaknesses => toxins.notable;

  /// 0..100, for the card's strip.
  double get toxicity => toxins.load;
}

/// How the collection can be arranged.
enum BestiaryOrder {
  recent('Newest'),
  mostEaten('Most eaten'),
  rarity('Rarity'),
  name('Name'),
  toxicity('Most toxic');

  const BestiaryOrder(this.label);

  final String label;
}

/// What the Bestiary is showing.
enum BestiaryFilter {
  caught('Caught'),
  all('All known');

  const BestiaryFilter(this.label);

  final String label;
}

/// Arranges the collection.
///
/// Sorting happens here rather than in SQL because rarity and toxicity are
/// *derived* — they do not exist as columns, and pushing them into the
/// database would mean storing a score that the scoring engine could later
/// disagree with.
List<Creature> arrange(
  Iterable<Creature> creatures, {
  BestiaryOrder order = BestiaryOrder.recent,
  BestiaryFilter filter = BestiaryFilter.caught,
  String query = '',
}) {
  final needle = query.trim().toLowerCase();

  final kept = [
    for (final creature in creatures)
      if (filter == BestiaryFilter.all || creature.isCaught)
        if (needle.isEmpty ||
            creature.name.toLowerCase().contains(needle) ||
            (creature.brand?.toLowerCase().contains(needle) ?? false))
          creature,
  ];

  int byName(Creature a, Creature b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  kept.sort(switch (order) {
    // Ties break by name throughout, so the order is stable and a redraw does
    // not shuffle the page under the reader.
    BestiaryOrder.name => byName,
    BestiaryOrder.mostEaten => (a, b) {
        final byCount = b.timesEaten.compareTo(a.timesEaten);
        return byCount != 0 ? byCount : byName(a, b);
      },
    BestiaryOrder.rarity => (a, b) {
        final byTier = b.rarity.index.compareTo(a.rarity.index);
        return byTier != 0 ? byTier : byName(a, b);
      },
    BestiaryOrder.toxicity => (a, b) {
        final byLoad = b.toxicity.compareTo(a.toxicity);
        return byLoad != 0 ? byLoad : byName(a, b);
      },
    BestiaryOrder.recent => (a, b) {
        final first = a.firstSeen;
        final second = b.firstSeen;
        if (first == null && second == null) return byName(a, b);
        // Never caught sorts last: the collection is about what was found.
        if (first == null) return 1;
        if (second == null) return -1;
        final byDay = second.compareTo(first);
        return byDay != 0 ? byDay : byName(a, b);
      },
  });

  return kept;
}

/// How full the collection is.
class BestiaryProgress {
  const BestiaryProgress({required this.caught, required this.known});

  final int caught;
  final int known;

  double get fraction => known <= 0 ? 0 : (caught / known).clamp(0.0, 1.0);

  /// How many of each tier have actually been eaten.
  static Map<FoodRarity, int> byRarity(Iterable<Creature> creatures) {
    final counts = {for (final tier in FoodRarity.values) tier: 0};
    for (final creature in creatures) {
      if (!creature.isCaught) continue;
      counts[creature.rarity] = counts[creature.rarity]! + 1;
    }
    return counts;
  }
}

/// Counts the collection.
BestiaryProgress progressOf(Iterable<Creature> creatures) {
  var caught = 0;
  var known = 0;

  for (final creature in creatures) {
    known++;
    if (creature.isCaught) caught++;
  }

  return BestiaryProgress(caught: caught, known: known);
}
