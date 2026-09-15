import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/remote/food_remote.dart';
import '../../data/remote/remote_food.dart';
import '../../providers/app_providers.dart';

/// The upstream food source.
///
/// Overridden in tests with a fake, which is the only way the offline and
/// throttled paths get covered.
final foodRemoteProvider = Provider<FoodRemote>((ref) => OffFoodRemote());

/// Step three of the resolution order: Open Food Facts, for names the device
/// has never seen.
///
/// Kept in its own provider rather than folded into [foodSearchProvider] so the
/// local results can paint immediately and the remote ones arrive underneath
/// them. Merging the two would make every search as slow as the network.
/// Auto-disposing, and keyed by query: without that, every distinct string
/// ever typed would be cached for the life of the app. Results live as long as
/// the sheet watches them and are released when it closes — the food itself is
/// not lost, because picking one writes it to the library.
final remoteFoodSearchProvider =
    FutureProvider.autoDispose.family<List<RemoteFood>, String>(
        (ref, query) async {
  // Below three characters upstream would only return noise, and every settled
  // query is a request. Together with the sheet's debounce this makes typing a
  // food name cost one lookup rather than one per keystroke.
  if (query.trim().length < 3) return const [];

  return ref.watch(foodRemoteProvider).search(query);
});

/// Writes a food found upstream into the library and returns the stored row.
///
/// This is the write-back that CLAUDE.md §4 requires — every resolution is
/// permanent, so a given food costs at most one network call ever. It also
/// converts a [RemoteFood], which cannot be logged, into a [Food], which can.
///
/// Takes the database rather than a `Ref` so it can be called from both a
/// provider and a widget: in Riverpod 2.x a `WidgetRef` is not a `Ref`, and
/// keeping one copy of this means one place for the write-back to live.
Future<Food?> saveRemoteFood(AppDatabase db, RemoteFood remote) async {
  final id = await db.foodsDao.upsert(remote.toCompanion(now: clock.now()));
  return db.foodsDao.findById(id);
}

/// Looks a barcode up locally first, then upstream.
///
/// The local check is not an optimisation: a barcode the user has already
/// scanned and then *corrected by hand* must resolve to their correction, not
/// to whatever Open Food Facts says this week.
///
/// Auto-disposing for the same reason: a cached result here would survive that
/// correction and keep handing back the row it replaced.
final barcodeLookupProvider =
    FutureProvider.autoDispose.family<Food?, String>((ref, barcode) async {
  final db = ref.read(databaseProvider);

  final known = await db.foodsDao.findByBarcode(barcode);
  if (known != null) return known;

  final remote = await ref.read(foodRemoteProvider).byBarcode(barcode);
  if (remote == null) return null;

  return saveRemoteFood(db, remote);
});
