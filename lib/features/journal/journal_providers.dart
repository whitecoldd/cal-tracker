import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/daos/journal_dao.dart';
import '../../data/database.dart';
import '../../data/nutrition_adapter.dart';
import '../../data/tables.dart';
import '../../domain/day.dart';
import '../../domain/food_query.dart';
import '../../domain/nutrition.dart';
import '../../providers/app_providers.dart';

/// The day the Journal is showing.
///
/// Defaults to today and can be walked backwards, so a meal can be added to
/// yesterday without lying about when it was eaten.
final journalDayProvider = NotifierProvider<JournalDayNotifier, Day>(
  JournalDayNotifier.new,
);

class JournalDayNotifier extends Notifier<Day> {
  @override
  Day build() => Day.today();

  void show(Day day) => state = day;

  void shift(int days) => state = state.addDays(days);

  void today() => state = Day.today();

  /// The Journal never shows the future: there is nothing to log there, and an
  /// empty tomorrow reads like data loss.
  bool get canGoForward => state.isBefore(Day.today());
}

/// Everything logged on the selected day, grouped by meal.
final journalEntriesProvider = StreamProvider<List<LoggedItem>>((ref) {
  final day = ref.watch(journalDayProvider);
  return ref.watch(databaseProvider).journalDao.watchDay(day);
});

/// A day's food, split into meal slots in serving order.
class JournalDay {
  const JournalDay({required this.day, required this.byMeal});

  factory JournalDay.from(Day day, List<LoggedItem> items) {
    final grouped = items.groupListsBy((i) => i.entry.mealSlot);
    return JournalDay(
      day: day,
      byMeal: {
        for (final slot in MealSlot.values) slot: grouped[slot] ?? const [],
      },
    );
  }

  final Day day;
  final Map<MealSlot, List<LoggedItem>> byMeal;

  List<LoggedItem> get all => byMeal.values.expand((e) => e).toList();

  bool get isEmpty => all.isEmpty;

  /// Meals that have something in them, in serving order. Empty slots are still
  /// offered as drop targets, but they do not clutter the totals.
  Iterable<MealSlot> get filledSlots =>
      MealSlot.values.where((s) => byMeal[s]!.isNotEmpty);
}

final journalDayViewProvider = Provider<AsyncValue<JournalDay>>((ref) {
  final day = ref.watch(journalDayProvider);
  return ref
      .watch(journalEntriesProvider)
      .whenData((items) => JournalDay.from(day, items));
});

/// What a day added up to.
///
/// Deliberately absolute figures only. There is no target, no percentage and
/// no remaining-calories number here: comparing intake against expenditure is
/// the verdict, and the verdict waits for the week to close. See CLAUDE.md §1.
///
/// Since T6 the arithmetic lives in `domain/nutrition.dart`; this carries the
/// result plus the one thing that is a storage concern rather than a
/// nutritional one — how many entries rest on a vague portion.
class DailyTotals {
  const DailyTotals({
    required this.nutrients,
    required this.lowConfidenceCount,
  });

  factory DailyTotals.of(List<LoggedItem> items) {
    var vague = 0;
    for (final item in items) {
      if (item.entry.confidence < 0.7) vague++;
    }

    return DailyTotals(
      nutrients: NutrientTotals.of(items.servings),
      lowConfidenceCount: vague,
    );
  }

  static const empty = DailyTotals(
    nutrients: NutrientTotals.empty,
    lowConfidenceCount: 0,
  );

  final NutrientTotals nutrients;

  /// How many entries rest on a vague portion ("a handful", "a plate").
  final int lowConfidenceCount;

  double get kcal => nutrients.kcal;
  double get proteinG => nutrients.proteinG;
  double get carbsG => nutrients.carbsG;
  double get fatG => nutrients.fatG;
  double get fibreG => nutrients.fibreG;
  double get sugarG => nutrients.sugarG;
  double get sodiumMg => nutrients.sodiumMg;

  /// Sum of each item's glycemic load. Items with no GI contribute nothing,
  /// which understates rather than invents.
  double get glycemicLoad => nutrients.glycemicLoad;

  int get itemCount => nutrients.itemCount;
}

final dailyTotalsProvider = Provider<DailyTotals>((ref) {
  final entries = ref.watch(journalEntriesProvider);
  return entries.maybeWhen(
    data: DailyTotals.of,
    orElse: () => DailyTotals.empty,
  );
});

/// Bumped whenever a food is written to the library.
///
/// Without it an open search sheet keeps serving a list assembled before the
/// write: pick an Open Food Facts result, back out of the portion sheet, retype
/// the same query, and the food that was just saved is not there. `autoDispose`
/// alone does not cover that — the sheet never closed.
final foodLibraryTickProvider =
    NotifierProvider<FoodLibraryTick, int>(FoodLibraryTick.new);

class FoodLibraryTick extends Notifier<int> {
  @override
  int build() => 0;

  void changed() => state++;
}

/// Local food search: the user's own library and the seeded staples.
///
/// This is steps one and two of the resolution order in CLAUDE.md §4. Anything
/// found here costs nothing, which is what keeps the AI budget survivable.
///
/// Auto-disposing and keyed by query, for the reason spelled out on
/// [remoteFoodSearchProvider]: without it every distinct string ever typed is
/// cached for the life of the app.
final foodSearchProvider =
    FutureProvider.autoDispose.family<List<Food>, String>((ref, query) async {
  ref.watch(foodLibraryTickProvider);

  final parsed = parseFoodQuery(query);
  if (parsed.isEmpty) return const [];
  return ref.watch(databaseProvider).foodsDao.searchFor(parsed);
});

/// Foods logged most often, offered before the user types anything.
///
/// Most days are made of the same dozen foods, so the fastest possible log is
/// one tap on something already eaten.
final recentFoodsProvider = FutureProvider<List<Food>>((ref) async {
  final db = ref.watch(databaseProvider);
  // Re-run when anything is logged, so the list stays current.
  ref.watch(journalEntriesProvider);

  final today = Day.from(clock.now());
  final recent = await db.journalDao.forRange(today.addDays(-30), today);

  final counts = <int, int>{};
  final foods = <int, Food>{};
  for (final item in recent) {
    counts.update(item.food.id, (n) => n + 1, ifAbsent: () => 1);
    foods[item.food.id] = item.food;
  }

  final ranked = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

  return [for (final id in ranked.take(12)) foods[id]!];
});
