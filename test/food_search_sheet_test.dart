import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/remote/food_remote.dart';
import 'package:cal_tracker/data/remote/remote_food.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/features/journal/food_lookup_providers.dart';
import 'package:cal_tracker/features/journal/food_search_sheet.dart';
import 'package:cal_tracker/features/journal/journal_providers.dart';
import 'package:cal_tracker/providers/app_providers.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-09-14T10:00:00.000';
final _today = Day.of(2026, 9, 14);

/// An upstream that answers a barcode however the test asks it to.
class _Remote implements FoodRemote {
  _Remote({this.lookup = const ProductUnknown(), this.failure});

  final ProductLookup lookup;

  /// When set, a lookup throws this instead of answering.
  final Object? failure;

  @override
  Future<ProductLookup> byBarcode(String barcode) async {
    if (failure != null) throw failure!;
    return lookup;
  }

  @override
  Future<List<RemoteFood>> search(String query, {int limit = 20}) async =>
      const [];
}

void main() {
  late AppDatabase db;

  Future<void> addFood(String name) => db.foodsDao.upsert(
        FoodsCompanion.insert(
          name: name,
          searchKey: name.toLowerCase(),
          kcal: 100,
          source: FoodSource.seed,
          createdAt: _now,
          updatedAt: _now,
        ),
      );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// Pumps the sheet inside a Journal-shaped scaffold.
  ///
  /// The scaffold matters: it is what a SnackBar from the sheet would be
  /// painted into, underneath the sheet, which is the bug these tests guard.
  Future<void> pump(
    WidgetTester tester, {
    ProductLookup lookup = const ProductUnknown(),
    Object? failure,
    String scanned = '7622300336738',
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          foodRemoteProvider
              .overrideWithValue(_Remote(lookup: lookup, failure: failure)),
          // No camera in a widget test. The failure this all exists for was
          // in what the sheet does with a code, not in reading one.
          barcodeScannerProvider.overrideWithValue((_) async => scanned),
          // A settled snapshot rather than a live drift stream: a stream
          // schedules a zero-duration timer on cancel that the binding
          // reports as a leak. See CLAUDE.md §2.
          recentFoodsProvider.overrideWith((ref) async => const []),
          remoteFoodSearchProvider
              .overrideWith((ref, query) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => FoodSearchSheet.show(context, day: _today),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('a barcode that resolves to nothing', () {
    // Before this, every message the sheet produced went to the root
    // ScaffoldMessenger, which paints into the scaffold *below* this sheet.
    // The sheet is opaque from 48px to the bottom of the screen, so a failed
    // scan looked exactly like a scan that did nothing at all.

    testWidgets('says so where the user can actually see it', (tester) async {
      await pump(tester, lookup: const ProductUnknown());

      await tester.tap(find.byTooltip('Scan a barcode'));
      await tester.pumpAndSettle();

      expect(find.textContaining('in no ledger'), findsOneWidget);
      // Visible is not enough — it has to be on top of the sheet, not behind
      // it. hitTestable() is the assertion the old SnackBar would fail.
      expect(
        find.textContaining('in no ledger').hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('a product it cannot use names the product', (tester) async {
      await pump(
        tester,
        lookup: const ProductUnusable(
          UnusableReason.noEnergy,
          name: 'Salted almonds',
        ),
      );

      await tester.tap(find.byTooltip('Scan a barcode'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Salted almonds').hitTestable(), findsOneWidget);
      expect(find.textContaining('records no energy'), findsOneWidget);
    });

    testWidgets('an unreachable upstream says that, not something else',
        (tester) async {
      await pump(tester, failure: const RemoteUnavailable('no connection'));

      await tester.tap(find.byTooltip('Scan a barcode'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('out of reach').hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('the notice can be dismissed', (tester) async {
      await pump(tester, lookup: const ProductUnknown());

      await tester.tap(find.byTooltip('Scan a barcode'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.textContaining('in no ledger'), findsNothing);
    });

    testWidgets('a found product is logged rather than announced',
        (tester) async {
      final id = await db.foodsDao.upsert(
        FoodsCompanion.insert(
          name: 'Chocolate bar',
          searchKey: 'chocolate bar',
          kcal: 534,
          barcode: const Value('7622300336738'),
          source: FoodSource.openFoodFacts,
          createdAt: _now,
          updatedAt: _now,
        ),
      );
      expect(id, greaterThan(0));

      await pump(tester);

      await tester.tap(find.byTooltip('Scan a barcode'));
      // Explicit pumps rather than pumpAndSettle: a hit opens the portion
      // sheet, which stays open waiting for the user.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // It came from the library, so nothing went wrong and nothing is said.
      expect(find.byTooltip('Dismiss'), findsNothing);
      expect(find.textContaining('ledger'), findsNothing);
    });
  });

  group('the search box', () {
    testWidgets('finds a food whose words were typed out of order',
        (tester) async {
      await tester.runAsync(() => addFood('Monster Energy Ultra White'));
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'white monster');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Monster Energy Ultra White'), findsOneWidget);
    });

    testWidgets('a leading count does not stop the food being found',
        (tester) async {
      await tester.runAsync(() => addFood('Egg, whole'));
      await pump(tester);

      await tester.enterText(find.byType(TextField), '5 eggs');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Egg, whole'), findsOneWidget);
    });

    testWidgets('clearing cannot be undone by an in-flight debounce',
        (tester) async {
      await tester.runAsync(() => addFood('Egg, whole'));
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'egg');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Egg, whole'), findsOneWidget);

      // Type, then clear before the debounce fires. The old code set the query
      // directly without cancelling, so the timer put the query back.
      await tester.enterText(find.byType(TextField), 'eggs');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip('Clear'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('EATEN LATELY'), findsOneWidget);
      expect(find.text('IN THE LIBRARY'), findsNothing);
    });

    testWidgets('a food saved while the sheet is open shows up',
        (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'borscht');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Borscht'), findsNothing);

      // As a write-back would: the row lands, and the tick says so.
      await tester.runAsync(() => addFood('Borscht'));
      final element = tester.element(find.byType(FoodSearchSheet));
      ProviderScope.containerOf(element)
          .read(foodLibraryTickProvider.notifier)
          .changed();
      await tester.pumpAndSettle();

      expect(find.text('Borscht'), findsOneWidget);
    });
  });
}
