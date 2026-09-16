import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/nutrition_adapter.dart';
import '../../domain/hydration.dart';
import '../../providers/app_providers.dart';
import 'journal_providers.dart';

/// The selected day's water row.
///
/// The one live stream in this feature. A widget test must override *this*
/// rather than let a drift stream run: a query stream schedules a zero-duration
/// timer when it is cancelled, which the test binding reports as a leak. See
/// CLAUDE.md §2.
final waterLogProvider = StreamProvider<WaterLog?>((ref) {
  final day = ref.watch(journalDayProvider);
  return ref.watch(databaseProvider).trackingDao.watchWater(day);
});

/// The day's hydration, from both sources.
///
/// Computed in exactly one place so the waterskin panel and the Yrden glyph
/// cannot disagree about how much someone has drunk.
final hydrationProvider = Provider<Hydration>((ref) {
  final log = ref.watch(waterLogProvider).valueOrNull;
  final items = ref.watch(journalEntriesProvider).valueOrNull ?? const [];

  return Hydration(
    loggedMl: log?.ml ?? 0,
    fromDrinksMl: hydrationFromDrinks(items.drinks),
  );
});
