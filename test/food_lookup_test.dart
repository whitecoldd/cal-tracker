import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/remote/food_remote.dart';
import 'package:cal_tracker/data/remote/remote_food.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/features/journal/food_lookup_providers.dart';
import 'package:cal_tracker/providers/app_providers.dart';
import 'package:clock/clock.dart';
// drift exports `isNull`/`isNotNull` query expressions that shadow the matchers.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-09-15T10:00:00.000';

/// A stand-in for Open Food Facts that counts its calls.
///
/// The call count is the whole point: CLAUDE.md §4 says a given food costs at
/// most one network call ever, and that is a claim about how often this is
/// reached, which no amount of checking the returned data would prove.
class FakeRemote implements FoodRemote {
  FakeRemote({
    RemoteFood? byBarcodeResult,
    ProductLookup? lookup,
    this.searchResult = const [],
    this.failure,
  }) : lookup = lookup ??
            (byBarcodeResult == null
                ? const ProductUnknown()
                : ProductFound(byBarcodeResult));

  /// What a barcode lookup answers with.
  final ProductLookup lookup;
  final List<RemoteFood> searchResult;

  /// When set, every call throws this instead of answering.
  final Object? failure;

  int barcodeCalls = 0;
  int searchCalls = 0;

  @override
  Future<ProductLookup> byBarcode(String barcode) async {
    barcodeCalls++;
    if (failure != null) throw failure!;
    return lookup;
  }

  @override
  Future<List<RemoteFood>> search(String query, {int limit = 20}) async {
    searchCalls++;
    if (failure != null) throw failure!;
    return searchResult;
  }
}

RemoteFood _remote({
  String name = 'Chocolate bar',
  String? barcode = '7622300336738',
  double kcal = 534,
  double confidence = 0.95,
}) {
  return RemoteFood(
    name: name,
    barcode: barcode,
    brand: 'Milka',
    kcal: kcal,
    proteinG: 6.3,
    carbsG: 59,
    fatG: 29.5,
    novaGroup: 4,
    additives: const ['en:e476'],
    source: FoodSource.openFoodFacts,
    confidence: confidence,
  );
}

FoodsCompanion _localFood(
  String name, {
  required FoodSource source,
  String? barcode,
  double kcal = 100,
}) {
  return FoodsCompanion.insert(
    name: name,
    searchKey: name,
    kcal: kcal,
    barcode: Value(barcode),
    source: source,
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// A container wired to the in-memory database and a fake upstream.
  ProviderContainer containerWith(FakeRemote remote) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        foodRemoteProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('barcode lookup', () {
    test('answers from the library without touching the network', () async {
      await db.foodsDao.upsert(
        _localFood('Own chocolate', source: FoodSource.manual, barcode: '7622300336738'),
      );

      final remote = FakeRemote(byBarcodeResult: _remote());
      final container = containerWith(remote);

      final outcome = await container.read(
        barcodeLookupProvider('7622300336738').future,
      );

      expect(outcome, isA<BarcodeFound>());
      expect((outcome as BarcodeFound).food.name, 'Own chocolate');
      // The user's own correction wins. Going upstream here would quietly
      // replace it with whatever Open Food Facts says this week.
      expect(remote.barcodeCalls, 0);
    });

    test('falls through to upstream for an unknown barcode', () async {
      final remote = FakeRemote(byBarcodeResult: _remote());
      final container = containerWith(remote);

      final outcome = await container.read(
        barcodeLookupProvider('7622300336738').future,
      );

      expect((outcome as BarcodeFound).food.name, 'Chocolate bar');
      expect(remote.barcodeCalls, 1);
    });

    test('writes the upstream result into the library', () async {
      final remote = FakeRemote(byBarcodeResult: _remote());
      final container = containerWith(remote);

      await container.read(barcodeLookupProvider('7622300336738').future);

      final stored = await db.foodsDao.findByBarcode('7622300336738');
      expect(stored, isNotNull);
      expect(stored!.name, 'Chocolate bar');
      expect(stored.brand, 'Milka');
      expect(stored.source, FoodSource.openFoodFacts);
      expect(stored.novaGroup, 4);
      expect(stored.additivesJson, contains('en:e476'));
      // upsert recomputes this rather than trusting the caller.
      expect(stored.searchKey, 'chocolate bar milka');
    });

    test('a second lookup of the same barcode costs no second call', () async {
      final remote = FakeRemote(byBarcodeResult: _remote());
      final container = containerWith(remote);

      await container.read(barcodeLookupProvider('7622300336738').future);

      // A fresh container, as if the sheet were reopened: the saving is in the
      // library, not in the provider cache.
      final second = containerWith(remote);
      final outcome = await second.read(
        barcodeLookupProvider('7622300336738').future,
      );

      expect((outcome as BarcodeFound).food.name, 'Chocolate bar');
      expect(remote.barcodeCalls, 1);
    });

    test('says so when upstream has never heard of the barcode', () async {
      final container = containerWith(FakeRemote());

      final outcome = await container.read(
        barcodeLookupProvider('0000000000000').future,
      );

      expect(outcome, isA<BarcodeUnknown>());
    });

    test('distinguishes a product it cannot use from one it cannot find',
        () async {
      // The old nullable return collapsed these two into one silent null, and
      // the caller could only say "nothing happened". Both are recoverable, in
      // different ways, and the user can only pick the right one if told which.
      final container = containerWith(
        FakeRemote(
          lookup: const ProductUnusable(
            UnusableReason.noEnergy,
            name: 'Salted almonds',
          ),
        ),
      );

      final outcome = await container.read(
        barcodeLookupProvider('7622300336738').future,
      );

      expect(outcome, isA<BarcodeUnusable>());
      final unusable = outcome as BarcodeUnusable;
      expect(unusable.reason, UnusableReason.noEnergy);
      // Carried through so an offer to record it by hand can be prefilled.
      expect(unusable.name, 'Salted almonds');
      expect(await db.foodsDao.count(), 0);
    });

    test('reports an unreachable upstream instead of throwing', () async {
      final container = containerWith(
        FakeRemote(failure: const RemoteUnavailable('no connection')),
      );

      final outcome = await container.read(
        barcodeLookupProvider('7622300336738').future,
      );

      expect(outcome, isA<BarcodeOffline>());

      // And nothing half-written was left behind.
      expect(await db.foodsDao.count(), 0);
    });

    test('an Error from upstream is an outcome, not an unhandled throw',
        () async {
      // Open Food Facts is crowd-sourced: a string where the schema says a
      // number surfaces as a TypeError, which is not an Exception. One of
      // those escaping is a failure with no output at all in a release build.
      final container = containerWith(
        FakeRemote(failure: TypeError()),
      );

      await expectLater(
        container.read(barcodeLookupProvider('7622300336738').future),
        throwsA(isA<TypeError>()),
      );
    });

    test('never resolves to a food the user cannot see the reason for',
        () async {
      // The guarantee this whole type exists for: every path returns an
      // outcome that says something, and the analyzer enforces the switch.
      for (final remote in [
        FakeRemote(byBarcodeResult: _remote()),
        FakeRemote(),
        FakeRemote(lookup: const ProductUnusable(UnusableReason.noName)),
        FakeRemote(failure: const RemoteUnavailable('down')),
      ]) {
        final outcome = await containerWith(remote).read(
          barcodeLookupProvider('7622300336738').future,
        );
        expect(outcome, isA<BarcodeOutcome>());
      }
    });
  });

  group('remote search', () {
    test('does not call upstream for a query under three characters', () async {
      final remote = FakeRemote(searchResult: [_remote()]);
      final container = containerWith(remote);

      expect(await container.read(remoteFoodSearchProvider('ry').future), isEmpty);
      expect(remote.searchCalls, 0);
    });

    test('calls upstream once a query is long enough', () async {
      final remote = FakeRemote(searchResult: [_remote()]);
      final container = containerWith(remote);

      final results = await container.read(
        remoteFoodSearchProvider('chocolate').future,
      );

      expect(results.single.name, 'Chocolate bar');
      expect(remote.searchCalls, 1);
    });

    test('an unreachable upstream does not write anything', () async {
      final container = containerWith(
        FakeRemote(failure: const RemoteUnavailable('timed out')),
      );

      await expectLater(
        container.read(remoteFoodSearchProvider('chocolate').future),
        throwsA(isA<RemoteUnavailable>()),
      );
      expect(await db.foodsDao.count(), 0);
    });
  });

  group('saveRemoteFood', () {
    test('stores the food and returns the row that can be logged', () async {
      final stored = await withClock(
        Clock.fixed(DateTime(2026, 9, 15, 10)),
        () => saveRemoteFood(db, _remote()),
      );

      expect(stored!.id, greaterThan(0));
      expect(stored.name, 'Chocolate bar');
      expect(stored.createdAt, '2026-09-15T10:00:00.000');
    });

    test('does not overwrite a food the user corrected by hand', () async {
      await db.foodsDao.upsert(
        _localFood(
          'Chocolate bar',
          source: FoodSource.manual,
          barcode: '7622300336738',
          kcal: 500,
        ),
      );

      final stored = await saveRemoteFood(db, _remote(kcal: 534));

      // The upsert guard holds: a better source already owns this row.
      expect(stored!.kcal, 500);
      expect(stored.source, FoodSource.manual);
      expect(await db.foodsDao.count(), 1);
    });

    test('saving the same food twice leaves one row', () async {
      await saveRemoteFood(db, _remote());
      await saveRemoteFood(db, _remote());

      expect(await db.foodsDao.count(), 1);
    });
  });
}
