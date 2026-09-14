import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/daos/journal_dao.dart';
import '../../data/database.dart';
import '../../data/tables.dart';
import '../../domain/day.dart';
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
class DailyTotals {
  const DailyTotals({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fibreG,
    required this.sugarG,
    required this.sodiumMg,
    required this.glycemicLoad,
    required this.itemCount,
    required this.lowConfidenceCount,
  });

  factory DailyTotals.of(List<LoggedItem> items) {
    var kcal = 0.0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    var fibre = 0.0;
    var sugar = 0.0;
    var sodium = 0.0;
    var load = 0.0;
    var vague = 0;

    for (final item in items) {
      kcal += item.kcal;
      protein += item.proteinG;
      carbs += item.carbsG;
      fat += item.fatG;
      fibre += item.food.fibreG * item.portions;
      sugar += item.sugarG;
      sodium += item.sodiumMg;
      load += item.glycemicLoad ?? 0;
      if (item.entry.confidence < 0.7) vague++;
    }

    return DailyTotals(
      kcal: kcal,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      fibreG: fibre,
      sugarG: sugar,
      sodiumMg: sodium,
      glycemicLoad: load,
      itemCount: items.length,
      lowConfidenceCount: vague,
    );
  }

  static const empty = DailyTotals(
    kcal: 0,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    fibreG: 0,
    sugarG: 0,
    sodiumMg: 0,
    glycemicLoad: 0,
    itemCount: 0,
    lowConfidenceCount: 0,
  );

  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fibreG;
  final double sugarG;
  final double sodiumMg;

  /// Sum of each item's glycemic load. Items with no GI contribute nothing,
  /// which understates rather than invents.
  final double glycemicLoad;

  final int itemCount;

  /// How many entries rest on a vague portion ("a handful", "a plate").
  final int lowConfidenceCount;
}

final dailyTotalsProvider = Provider<DailyTotals>((ref) {
  final entries = ref.watch(journalEntriesProvider);
  return entries.maybeWhen(
    data: DailyTotals.of,
    orElse: () => DailyTotals.empty,
  );
});

/// Local food search: the user's own library and the seeded staples.
///
/// This is steps one and two of the resolution order in CLAUDE.md §4. Anything
/// found here costs nothing, which is what keeps the AI budget survivable.
final foodSearchProvider =
    FutureProvider.family<List<Food>, String>((ref, query) async {
  if (query.trim().length < 2) return const [];
  return ref.watch(databaseProvider).foodsDao.search(query);
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
