import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/portion.dart';
import 'package:cal_tracker/features/alchemy/alchemy_providers.dart';
import 'package:cal_tracker/features/alchemy/alchemy_screen.dart';
import 'package:cal_tracker/features/journal/journal_providers.dart';
import 'package:cal_tracker/providers/app_providers.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-09-15T10:00:00.000';
final _today = Day.of(2026, 9, 15);

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> addFood(
    String name, {
    double kcal = 400,
    double protein = 20,
    double carbs = 50,
    double fat = 12,
    double fibre = 8,
    double sugar = 4,
    double? addedSugar,
    double satFat = 3,
    double sodium = 300,
    int? nova = 1,
    int? gi,
  }) {
    return db.foodsDao.upsert(
      FoodsCompanion.insert(
        name: name,
        searchKey: name,
        kcal: kcal,
        proteinG: Value(protein),
        carbsG: Value(carbs),
        sugarG: Value(sugar),
        addedSugarG: Value(addedSugar),
        fatG: Value(fat),
        satFatG: Value(satFat),
        fibreG: Value(fibre),
        sodiumMg: Value(sodium),
        glycemicIndex: Value(gi),
        novaGroup: Value(nova),
        source: FoodSource.seed,
        createdAt: _now,
        updatedAt: _now,
      ),
    );
  }

  Future<void> log(int foodId, {double grams = 100}) {
    return db.journalDao.add(
      EntriesCompanion.insert(
        foodId: foodId,
        day: _today,
        mealSlot: MealSlot.lunch,
        quantity: grams,
        unit: PortionUnit.grams,
        grams: grams,
        createdAt: _now,
      ),
    );
  }

  /// Database work has to run on the real event loop; a widget-test body runs
  /// in fake async, which never turns it. See CLAUDE.md §2.
  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async =>
      (await tester.runAsync(body)) as T;

  Future<void> pump(WidgetTester tester, {double toxicity = 0}) async {
    // Deliberately far taller than a phone. The screen is a lazy ListView, so
    // on a real-sized viewport the lower panels are never built — and the
    // blackout check below scrapes only built widgets, which would make it
    // pass by simply not looking at the half of the screen most likely to
    // leak. A tall viewport forces the whole page into the tree.
    tester.view.physicalSize = const Size(1080, 7200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final items = await real(tester, () => db.journalDao.forDay(_today));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // A settled snapshot rather than a live drift stream: a live one
          // schedules a zero-duration timer on cancel that the binding
          // reports as a leak.
          journalEntriesProvider.overrideWith((ref) => Stream.value(items)),
          // Both of these await a drift query of their own. A widget-test body
          // runs in fake async, which never turns the real event loop, so the
          // query would never complete and `pumpAndSettle` would spin until the
          // timeout with no useful error — CLAUDE.md §2. Their own logic is
          // covered by scoring_test.dart; what is under test here is the text
          // the screen puts on the glass.
          toxicityProvider.overrideWith((ref) async => toxicity),
          latestWeightProvider.overrideWith((ref) async => 80.0),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(body: AlchemyScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => (t.data ?? '').toLowerCase())
      .join(' | ');

  testWidgets('an empty day says so rather than showing zeroed meters',
      (tester) async {
    await withClock(Clock.fixed(DateTime(2026, 9, 15, 12)), () async {
      await pump(tester);

      // A Vitality of zero on an unlogged day would read as a verdict on the
      // day rather than an absence of data.
      expect(find.text('NO DECOCTION BREWED'), findsOneWidget);
      expect(visibleText(tester), isNot(contains('0 / 100')));
    });
  });

  testWidgets('shows the day composition and its harm readings',
      (tester) async {
    await real(tester, () async {
      final oats = await addFood('Oats', gi: 55);
      await log(oats, grams: 100);
    });

    await withClock(Clock.fixed(DateTime(2026, 9, 15, 12)), () async {
      await pump(tester);

      expect(find.text('DECOCTIONS'), findsOneWidget);
      expect(find.text('CONDITION'), findsOneWidget);
      expect(find.text('HUMOURS'), findsOneWidget);
      expect(find.text('CURSES'), findsOneWidget);

      final text = visibleText(tester);
      expect(text, contains('of energy'));
      expect(text, contains('usual range'));
    });
  });

  testWidgets('carries the harm disclaimer wherever harm is shown',
      (tester) async {
    // Required by CLAUDE.md §7 on every harm surface.
    await real(tester, () async {
      final junk = await addFood('Cola', nova: 4, addedSugar: 40);
      await log(junk, grams: 300);
    });

    await withClock(Clock.fixed(DateTime(2026, 9, 15, 12)), () async {
      await pump(tester);

      final text = visibleText(tester);
      expect(text, contains('not medical advice'));
      expect(text, contains('physician'));
    });
  });

  testWidgets('never answers whether the user is losing or gaining',
      (tester) async {
    // The blackout, at the screen that comes closest to breaking it: Alchemy
    // is the one daily surface that talks about quality, and a macro target
    // derived from TDEE here could be subtracted back into a deficit.
    await real(tester, () async {
      final oats = await addFood('Oats', gi: 55);
      final junk = await addFood('Cola', nova: 4, addedSugar: 40);
      await log(oats, grams: 200);
      await log(junk, grams: 330);
    });

    await withClock(Clock.fixed(DateTime(2026, 9, 15, 12)), () async {
      await pump(tester);

      final text = visibleText(tester);

      for (final forbidden in [
        'remaining',
        'deficit',
        'surplus',
        'maintenance',
        'tdee',
        'losing',
        'gaining',
        'burned',
        'expenditure',
        'calories left',
        'over budget',
        'under budget',
      ]) {
        expect(
          text.contains(forbidden),
          isFalse,
          reason: 'Alchemy showed "$forbidden": $text',
        );
      }
    });
  });

  testWidgets('says plainly that the bands are not a goal set for the user',
      (tester) async {
    await real(tester, () async {
      final oats = await addFood('Oats');
      await log(oats, grams: 150);
    });

    await withClock(Clock.fixed(DateTime(2026, 9, 15, 12)), () async {
      await pump(tester);

      final text = visibleText(tester);
      // The one place the word "target" is allowed on a daily screen is a
      // sentence denying that there is one.
      expect(text, contains('not a target set for you'));
      expect(text, contains('how the day was composed'));
    });
  });
}
