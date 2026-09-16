import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/links/external_links.dart';
import '../../data/remote/food_remote.dart';
import '../../data/remote/remote_food.dart';
import '../../providers/app_providers.dart';
import 'barcode_scanner_screen.dart';

/// Opens a web page, for the Open Food Facts hand-off.
///
/// Overridden in tests, which have no platform channel and no browser.
final externalLinksProvider =
    Provider<ExternalLinks>((ref) => const PlatformExternalLinks());

/// The upstream food source.
///
/// Overridden in tests with a fake, which is the only way the offline and
/// throttled paths get covered.
final foodRemoteProvider = Provider<FoodRemote>((ref) => OffFoodRemote());

/// How a barcode is read, as a function rather than a screen.
///
/// Overridden in tests, which have no camera. Injecting it is what lets the
/// *reporting* of a scan be tested at all — the failure this indirection was
/// added for was in what the sheet does with a code, not in reading one.
final barcodeScannerProvider =
    Provider<Future<String?> Function(BuildContext)>(
  (ref) => BarcodeScannerScreen.scan,
);

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

/// How a scan ended.
///
/// Four outcomes, not one nullable [Food]. The scanner has always been able to
/// fail in these four ways; collapsing them into `null` plus a thrown exception
/// meant the caller could only say "nothing happened", and it said so into a
/// message nobody could see. A sealed type makes each one a branch the analyzer
/// insists on handling, and gives the user a sentence that is actually true.
sealed class BarcodeOutcome {
  const BarcodeOutcome();
}

/// Resolved to something loggable, from the library or from upstream.
final class BarcodeFound extends BarcodeOutcome {
  const BarcodeFound(this.food);

  final Food food;
}

/// Upstream has no record of this barcode.
final class BarcodeUnknown extends BarcodeOutcome {
  const BarcodeUnknown();
}

/// Upstream holds the product but it cannot be logged honestly.
///
/// [name] is whatever upstream did give, so an offer to record it by hand can
/// start from something rather than from a blank field.
final class BarcodeUnusable extends BarcodeOutcome {
  const BarcodeUnusable(this.reason, {this.name});

  final UnusableReason reason;
  final String? name;
}

/// Not in the library, and upstream could not be reached.
final class BarcodeOffline extends BarcodeOutcome {
  const BarcodeOffline();
}

/// Upstream answered with something loggable and writing it down failed.
///
/// Its own outcome rather than a reused one: it is the only branch here that
/// means the *app* is at fault, and telling the user to check their connection
/// or name the food themselves would both be lies.
final class BarcodeNotStored extends BarcodeOutcome {
  const BarcodeNotStored(this.error);

  final Object error;
}

/// Looks a barcode up locally first, then upstream.
///
/// The local check is not an optimisation: a barcode the user has already
/// scanned and then *corrected by hand* must resolve to their correction, not
/// to whatever Open Food Facts says this week.
///
/// Auto-disposing for the same reason: a cached result here would survive that
/// correction and keep handing back the row it replaced.
///
/// Every way a lookup can *report* a failure becomes a [BarcodeOutcome] rather
/// than a thrown error, because the one thing the caller must not be able to do
/// is treat a failure as nothing having happened. An `Error` thrown from inside
/// the remote still propagates — [OffFoodRemote] converts those to
/// [RemoteUnavailable] itself, which is where that belongs.
final barcodeLookupProvider = FutureProvider.autoDispose
    .family<BarcodeOutcome, String>((ref, barcode) async {
  final db = ref.read(databaseProvider);

  final known = await db.foodsDao.findByBarcode(barcode);
  if (known != null) return BarcodeFound(known);

  final ProductLookup lookup;
  try {
    lookup = await ref.read(foodRemoteProvider).byBarcode(barcode);
  } on RemoteUnavailable {
    return const BarcodeOffline();
  }

  switch (lookup) {
    case ProductUnknown():
      return const BarcodeUnknown();
    case ProductUnusable(:final reason, :final name):
      return BarcodeUnusable(reason, name: name);
    case ProductFound(:final food):
      // The write-back can fail on its own terms — a barcode colliding with a
      // row that already claims it, most plainly. That is still the app's
      // problem to report rather than to throw past the caller, which is how
      // this failed silently before.
      try {
        final stored = await saveRemoteFood(db, food);
        if (stored == null) {
          return const BarcodeNotStored('the row could not be read back');
        }
        return BarcodeFound(stored);
      } on Exception catch (e) {
        return BarcodeNotStored(e);
      }
  }
});
