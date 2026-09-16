import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/nutrition_adapter.dart';
import '../../domain/bestiary.dart';
import '../../providers/app_providers.dart';
import '../journal/journal_providers.dart';

/// How the collection is arranged.
final bestiaryOrderProvider =
    NotifierProvider<BestiaryOrderNotifier, BestiaryOrder>(
  BestiaryOrderNotifier.new,
);

class BestiaryOrderNotifier extends Notifier<BestiaryOrder> {
  @override
  BestiaryOrder build() => BestiaryOrder.recent;

  void set(BestiaryOrder order) => state = order;
}

/// Whether to show the whole library or only what has been eaten.
final bestiaryFilterProvider =
    NotifierProvider<BestiaryFilterNotifier, BestiaryFilter>(
  BestiaryFilterNotifier.new,
);

class BestiaryFilterNotifier extends Notifier<BestiaryFilter> {
  @override
  BestiaryFilter build() => BestiaryFilter.caught;

  void set(BestiaryFilter filter) => state = filter;
}

final bestiaryQueryProvider =
    NotifierProvider<BestiaryQueryNotifier, String>(BestiaryQueryNotifier.new);

class BestiaryQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

/// Every food the app knows, as a creature entry.
///
/// Three queries rather than one per food: the screen shows the whole library
/// at once, and a per-row lookup would make its cost grow with the size of the
/// collection it exists to celebrate.
final creaturesProvider = FutureProvider<List<Creature>>((ref) async {
  // Re-read as food is logged, so a first-ever meal appears in the collection
  // without a restart.
  ref.watch(journalEntriesProvider);

  final db = ref.watch(databaseProvider);

  final foods = await db.foodsDao.all();
  final counts = await db.journalDao.timesEatenByFood();
  final firstSeen = await db.journalDao.firstSeenByFood();

  return [
    for (final food in foods)
      Creature.of(
        id: food.id,
        name: food.name,
        brand: food.brand,
        panel: food.panel,
        timesEaten: counts[food.id] ?? 0,
        firstSeen: firstSeen[food.id],
        imagePath: food.imagePath,
      ),
  ];
});

/// The collection as the screen should show it.
final arrangedBestiaryProvider = Provider<AsyncValue<List<Creature>>>((ref) {
  final order = ref.watch(bestiaryOrderProvider);
  final filter = ref.watch(bestiaryFilterProvider);
  final query = ref.watch(bestiaryQueryProvider);

  return ref.watch(creaturesProvider).whenData(
        (creatures) =>
            arrange(creatures, order: order, filter: filter, query: query),
      );
});

/// How full the collection is.
final bestiaryProgressProvider = Provider<BestiaryProgress>((ref) {
  final creatures = ref.watch(creaturesProvider).valueOrNull ?? const [];
  return progressOf(creatures);
});
