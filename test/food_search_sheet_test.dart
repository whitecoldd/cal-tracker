import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/remote/food_remote.dart';
import 'package:cal_tracker/data/remote/remote_food.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/features/ai/ai_providers.dart';
import 'package:cal_tracker/features/journal/food_lookup_providers.dart';
import 'package:cal_tracker/features/journal/food_search_sheet.dart';
import 'package:cal_tracker/features/journal/journal_providers.dart';
import 'package:cal_tracker/features/journal/manual_food_sheet.dart';
import 'package:cal_tracker/providers/app_providers.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    bool hasKey = false,
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
          aiAvailableProvider.overrideWith((ref) async => hasKey),
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

    // A miss used to end with a sentence and nothing else: the digits the
    // camera had just read were discarded, so the user could not check the
    // packet against Open Food Facts, search for it elsewhere, or file it
    // upstream. These pin the number to the notice.

    testWidgets('shows the digits it read', (tester) async {
      await pump(
        tester,
        lookup: const ProductUnknown(),
        scanned: '4840811001867',
      );

      await tester.tap(find.byTooltip('Scan a barcode'));
      await tester.pumpAndSettle();

      expect(find.text('4840811001867').hitTestable(), findsOneWidget);
    });

    testWidgets('keeps the digits when upstream cannot be reached',
        (tester) async {
      // The branch with no food to offer to write down. It still read a
      // barcode, and that is the one thing worth keeping from the attempt.
      await pump(
        tester,
        failure: const RemoteUnavailable('no connection'),
        scanned: '5060947547162',
      );

      await tester.tap(find.byTooltip('Scan a barcode'));
      await tester.pumpAndSettle();

      expect(find.text('5060947547162').hitTestable(), findsOneWidget);
    });

    testWidgets('copying the digits puts them on the clipboard', (tester) async {
      // There is no clipboard behind a widget test, and `Clipboard.setData`
      // never completes without a handler — so the button's own state change
      // never runs. Standing one up is also what lets the test assert the
      // digits actually left the app rather than that a label flipped.
      final copied = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') copied.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await pump(
        tester,
        lookup: const ProductUnknown(),
        scanned: '4840811001867',
      );

      await tester.tap(find.byTooltip('Scan a barcode'));
      await tester.pumpAndSettle();

      expect(find.text('SIGIL — COPIED'), findsNothing);

      await tester.tap(find.byTooltip('Copy the barcode'));
      await tester.pumpAndSettle();

      final args = copied.single.arguments as Map<Object?, Object?>;
      expect(args['text'], '4840811001867');
      // A clipboard write is invisible. Without an acknowledgement the button
      // is indistinguishable from one that does nothing.
      expect(find.text('SIGIL — COPIED'), findsOneWidget);
    });

    testWidgets('typing again clears the digits of the last scan',
        (tester) async {
      await pump(
        tester,
        lookup: const ProductUnknown(),
        scanned: '4840811001867',
      );

      await tester.tap(find.byTooltip('Scan a barcode'));
      await tester.pumpAndSettle();
      expect(find.text('4840811001867'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'almonds');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('4840811001867'), findsNothing);
    });

    testWidgets('a name upstream gave can be searched for', (tester) async {
      // The barcode is one packet and upstream has failed it; the name reaches
      // the rest of the brand, which is often the same food under a code
      // somebody did fill in.
      await tester.runAsync(() => addFood('Salted almonds'));
      await pump(
        tester,
        lookup: const ProductUnusable(
          UnusableReason.noEnergy,
          name: 'Salted almonds',
        ),
      );

      await tester.tap(find.byTooltip('Scan a barcode'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SEEK "SALTED ALMONDS"'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Salted almonds');
      expect(find.text('IN THE LIBRARY'), findsOneWidget);
    });

    testWidgets('a nameless product offers nothing to search for',
        (tester) async {
      // What Open Food Facts actually holds for some barcodes: a code, a
      // country tag and nothing else. There is no name, so a search button
      // here would be a dead end wearing a way out.
      await pump(
        tester,
        lookup: const ProductUnusable(UnusableReason.noName),
        scanned: '5060947547162',
      );

      await tester.tap(find.byTooltip('Scan a barcode'));
      await tester.pumpAndSettle();

      expect(find.textContaining('SEEK'), findsNothing);
      expect(find.text('RECORD IT YOURSELF'), findsOneWidget);
      expect(find.text('5060947547162').hitTestable(), findsOneWidget);
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

  group('nothing found is never a dead end', () {
    // Before a food could be written down by hand, both of these were the end
    // of the road -- and FoodSource.manual, the top rung of upsert's trust
    // ladder, had nothing in the app that could write it.

    testWidgets('a search with no results offers to record the food',
        (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'borscht');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('WRITE IT DOWN').hitTestable(), findsOneWidget);
    });

    testWidgets('and starts from what was typed', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'borscht');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE IT DOWN'));
      await tester.pumpAndSettle();

      expect(find.text('WRITE IT DOWN YOURSELF'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'borscht'), findsOneWidget);
    });

    testWidgets('an unusable barcode offers it, prefilled with the name',
        (tester) async {
      await pump(
        tester,
        lookup: const ProductUnusable(
          UnusableReason.noEnergy,
          name: 'Salted almonds',
        ),
      );

      await tester.tap(find.byTooltip('Scan a barcode'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('RECORD IT YOURSELF'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextFormField, 'Salted almonds'),
        findsOneWidget,
      );
    });

    testWidgets('a food recorded by hand is stored and offered for logging',
        (tester) async {
      await pump(tester, lookup: const ProductUnknown(), scanned: '5941234567890');

      await tester.tap(find.byTooltip('Scan a barcode'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('RECORD IT YOURSELF'));
      await tester.pumpAndSettle();

      // Name first, then energy: the sheet's first two TextFormFields in order.
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Salted almonds');
      await tester.enterText(fields.at(2), '600');
      await tester.pumpAndSettle();

      // The sheet is a ListView, so the button is not built until scrolled to.
      //
      // Anchored on the sheet rather than on a heading inside it: a heading
      // scrolls out of the viewport and is unmounted part-way through, and the
      // finder then resolves to nothing mid-scroll. The sheet is there for the
      // whole journey however long the form grows.
      await tester.scrollUntilVisible(
        find.text('INSCRIBE'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ManualFoodSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('INSCRIBE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final stored = await tester.runAsync(
        () => db.foodsDao.findByBarcode('5941234567890'),
      );
      expect(stored, isNotNull);
      expect(stored!.source, FoodSource.manual);
    });
  });

  group('the model, for someone who has not set a key', () {
    // These buttons used to be hidden entirely until a key was saved. Sound
    // reasoning -- a button that always fails is worse than no button -- with
    // the wrong outcome: on a keyless install the app's most useful capability
    // was invisible, and nobody asks for a feature they have never seen.

    testWidgets('the photograph button is there with no key', (tester) async {
      await pump(tester);

      expect(find.byTooltip('Photograph the meal'), findsOneWidget);
      expect(find.byTooltip('Describe the meal'), findsOneWidget);
    });

    testWidgets('and explains itself rather than failing', (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Photograph the meal'));
      await tester.pumpAndSettle();

      expect(find.text('READ THE PLATE'), findsOneWidget);
      expect(find.textContaining('broken into the foods'), findsOneWidget);
      expect(find.text('BIND A KEY'), findsOneWidget);
    });

    testWidgets('the typed-meal button explains its own thing',
        (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Describe the meal'));
      await tester.pumpAndSettle();

      expect(find.text('DESCRIBE THE MEAL'), findsOneWidget);
    });

    testWidgets('it is an offer, not an error', (tester) async {
      // The app is complete without a key and nothing has gone wrong.
      await pump(tester);

      await tester.tap(find.byTooltip('Photograph the meal'));
      await tester.pumpAndSettle();

      expect(find.textContaining('works without'), findsOneWidget);
      // WitcherButton uppercases its own label.
      expect(find.text('NOT NOW'), findsOneWidget);
    });
  });
}
