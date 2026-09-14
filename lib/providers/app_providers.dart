import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/seed_loader.dart';
import '../domain/day.dart';

/// The database.
///
/// Overridden in tests with an in-memory instance, which is why every consumer
/// goes through this provider rather than constructing [AppDatabase] directly.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final seedLoaderProvider = Provider<SeedLoader>(
  (ref) => SeedLoader(ref.watch(databaseProvider).foodsDao),
);

/// Work that must finish before the first screen renders.
///
/// Loading the seed here means a brand new install can search food offline
/// immediately, instead of the first search being the one that discovers there
/// is nothing to search.
final startupProvider = FutureProvider<void>((ref) async {
  await ref.watch(seedLoaderProvider).ensureLoaded();
});

/// The user's profile, or null if onboarding has not run.
final profileProvider = StreamProvider<Profile?>(
  (ref) => ref.watch(databaseProvider).profileDao.watch(),
);

/// The most recent weigh-in, whenever it was.
///
/// Energy figures need a weight, and the profile does not carry one — weight
/// lives in its own day-keyed table so it can be logged daily.
final latestWeightProvider = FutureProvider<double?>((ref) async {
  // Re-read whenever the profile changes, which covers the initial weigh-in
  // written during onboarding.
  ref.watch(profileProvider);
  final db = ref.watch(databaseProvider);
  final weight = await db.trackingDao.latestWeightOnOrBefore(
    // A far-future day, so this is simply "the latest weight there is".
    const Day(99991231),
  );
  return weight?.kg;
});
