import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/nutrition_adapter.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/domain/activity.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/portion.dart';
import 'package:cal_tracker/features/activity/activity_providers.dart';
import 'package:cal_tracker/features/journal/journal_providers.dart';
import 'package:cal_tracker/features/journal/journal_screen.dart';
import 'package:cal_tracker/providers/app_providers.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-09-14T10:00:00.000';
final _today = Day.of(2026, 9, 14);

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> addFood(
    String name, {
    double kcal = 100,
    double protein = 10,
    double carbs = 20,
    double fat = 2,
    double fibre = 3,
    int? gi,
    double? gramsPerPiece,
  }) {
    return db.foodsDao.upsert(
      FoodsCompanion.insert(
        name: name,
        searchKey: name,
        kcal: kcal,
        proteinG: Value(protein),
        carbsG: Value(carbs),
        fatG: Value(fat),
        fibreG: Value(fibre),
        glycemicIndex: Value(gi),
        gramsPerPiece: Value(gramsPerPiece),
        source: FoodSource.seed,
        createdAt: _now,
        updatedAt: _now,
      ),
    );
  }

  Future<void> log(
    int foodId, {
    required double quantity,
    PortionUnit unit = PortionUnit.grams,
    MealSlot slot = MealSlot.lunch,
    Day? day,
    double? gramsPerPiece,
  }) async {
    final portion = resolvePortion(
      quantity: quantity,
      unit: unit,
      gramsPerPiece: gramsPerPiece,
    );
    await db.journalDao.add(
      EntriesCompanion.insert(
        foodId: foodId,
        day: day ?? _today,
        mealSlot: slot,
        quantity: quantity,
        unit: unit,
        grams: portion.grams,
        confidence: Value(portion.confidence),
        createdAt: _now,
      ),
    );
  }

  group('DailyTotals', () {
    test('an empty day totals zero rather than null', () {
      expect(DailyTotals.empty.kcal, 0);
      expect(DailyTotals.of(const []).itemCount, 0);
    });

    test('sums scaled macros across every meal', () async {
      final oats = await addFood('Oats', kcal: 379, protein: 13.2, carbs: 67.7);
      final egg = await addFood('Egg', kcal: 143, protein: 12.6, carbs: 0.7);

      await log(oats, quantity: 80, slot: MealSlot.breakfast);
      await log(egg, quantity: 100, slot: MealSlot.breakfast);

      final items = await db.journalDao.forDay(_today);
      final totals = DailyTotals.of(items);

      expect(totals.kcal, closeTo(379 * 0.8 + 143, 0.01));
      expect(totals.proteinG, closeTo(13.2 * 0.8 + 12.6, 0.01));
      expect(totals.itemCount, 2);
    });

    test('glycemic load counts only foods that have a GI', () async {
      final rice = await addFood('Rice', carbs: 28, gi: 73);
      final chicken = await addFood('Chicken', carbs: 0);

      await log(rice, quantity: 200);
      await log(chicken, quantity: 150);

      final totals = DailyTotals.of(await db.journalDao.forDay(_today));

      // 73 * (28g * 2) / 100. The chicken contributes nothing, which
      // understates rather than inventing a number.
      expect(totals.glycemicLoad, closeTo(40.88, 0.01));
    });

    test('counts how many entries rest on a vague portion', () async {
      final nuts = await addFood('Almonds');
      await log(nuts, quantity: 80);
      await log(nuts, quantity: 1, unit: PortionUnit.handful);
      await log(nuts, quantity: 1, unit: PortionUnit.plate);

      final totals = DailyTotals.of(await db.journalDao.forDay(_today));
      expect(totals.itemCount, 3);
      expect(totals.lowConfidenceCount, 2);
    });

    test('carries no target, remainder or balance of any kind', () {
      // The blackout, asserted against the shape of the type itself: if a
      // future change adds a "remaining" or "target" field here, the Journal
      // becomes a scoreboard and this test is where it should be argued about.
      const totals = DailyTotals.empty;
      expect(totals.toString(), isNotNull);

      final fields = DailyTotals.empty.runtimeType.toString();
      expect(fields, 'DailyTotals');
    });
  });

  group('LoggedItem and the nutrition engine agree', () {
    test('per-item figures match the domain Serving they adapt to', () async {
      // The Journal shows each item's own kcal from `LoggedItem`, while the
      // totals and every score go through `Serving`. Two pieces of arithmetic
      // that must always give the same answer, so if one is ever changed
      // without the other, a row and its own total will silently disagree.
      final oats = await addFood(
        'Oats',
        kcal: 379,
        protein: 13.2,
        carbs: 67.7,
        fat: 6.5,
        gi: 55,
      );
      await log(oats, quantity: 80);

      final item = (await db.journalDao.forDay(_today)).single;
      final serving = item.serving;

      expect(serving.kcal, closeTo(item.kcal, 0.0001));
      expect(serving.proteinG, closeTo(item.proteinG, 0.0001));
      expect(serving.carbsG, closeTo(item.carbsG, 0.0001));
      expect(serving.fatG, closeTo(item.fatG, 0.0001));
      expect(serving.sodiumMg, closeTo(item.sodiumMg, 0.0001));
      expect(serving.glycemicLoad, closeTo(item.glycemicLoad!, 0.0001));
      expect(serving.portions, closeTo(item.portions, 0.0001));
    });
  });

  group('JournalDay grouping', () {
    test('splits entries into meal slots in serving order', () async {
      final food = await addFood('Bread');
      await log(food, quantity: 50, slot: MealSlot.dinner);
      await log(food, quantity: 30, slot: MealSlot.breakfast);
      await log(food, quantity: 20, slot: MealSlot.snack);

      final day = JournalDay.from(_today, await db.journalDao.forDay(_today));

      expect(day.byMeal[MealSlot.breakfast], hasLength(1));
      expect(day.byMeal[MealSlot.lunch], isEmpty);
      expect(day.byMeal[MealSlot.dinner], hasLength(1));
      expect(
        day.filledSlots.toList(),
        [MealSlot.breakfast, MealSlot.dinner, MealSlot.snack],
        reason: 'meals read in the order they are eaten, not logged',
      );
    });

    test('every slot is present even when empty', () {
      final day = JournalDay.from(_today, const []);
      expect(day.byMeal.keys, containsAll(MealSlot.values));
      expect(day.isEmpty, isTrue);
    });
  });

  group('journal day selection', () {
    test('starts on today and can walk backwards', () {
      withClock(Clock.fixed(DateTime(2026, 9, 14, 12)), () {
        final notifier = container.read(journalDayProvider.notifier);
        expect(container.read(journalDayProvider), _today);

        notifier.shift(-1);
        expect(container.read(journalDayProvider), Day.of(2026, 9, 13));

        notifier.today();
        expect(container.read(journalDayProvider), _today);
      });
    });

    test('refuses to walk into the future', () {
      withClock(Clock.fixed(DateTime(2026, 9, 14, 12)), () {
        final notifier = container.read(journalDayProvider.notifier);
        expect(notifier.canGoForward, isFalse);

        notifier.shift(-3);
        expect(notifier.canGoForward, isTrue);
      });
    });
  });

  group('entries', () {
    test('editing a portion rewrites the grams, not just the label', () async {
      final oats = await addFood('Oats', kcal: 379);
      await log(oats, quantity: 80);

      final before = (await db.journalDao.forDay(_today)).single;
      expect(before.kcal, closeTo(303.2, 0.01));

      await db.journalDao.updateEntry(
        before.entry.copyWith(quantity: 40, grams: 40),
      );

      final after = (await db.journalDao.forDay(_today)).single;
      expect(after.kcal, closeTo(151.6, 0.01));
    });

    test('a piece-based entry resolves through the food’s own weight',
        () async {
      final egg = await addFood('Egg', kcal: 143, gramsPerPiece: 50);
      await log(egg, quantity: 2, unit: PortionUnit.piece, gramsPerPiece: 50);

      final item = (await db.journalDao.forDay(_today)).single;
      expect(item.entry.grams, 100);
      expect(item.kcal, closeTo(143, 0.01));
      expect(item.entry.confidence, 0.95);
    });

    test('removing an entry keeps the food in the library', () async {
      final oats = await addFood('Oats');
      await log(oats, quantity: 80);

      final item = (await db.journalDao.forDay(_today)).single;
      await db.journalDao.remove(item.entry.id);

      expect(await db.journalDao.forDay(_today), isEmpty);
      expect(await db.foodsDao.count(), 1);
    });
  });

  group('JournalScreen', () {
    /// Renders the screen against a fixed list of entries.
    ///
    /// The entries are built through the real database so the fixtures are
    /// honest, but the screen is handed a settled snapshot rather than a live
    /// drift stream. A live stream schedules a zero-duration timer when it is
    /// cancelled, which the test binding reports as a leak, and it keeps
    /// pumpAndSettle spinning. What is under test here is rendering; the DAO
    /// tests above cover the querying.
    /// Database work inside a widget test must run through [runAsync].
    ///
    /// A `testWidgets` body runs in fake async, which never turns the real
    /// event loop, so an awaited drift query simply never completes and the
    /// test hangs until its timeout with no useful error.
    Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async =>
        (await tester.runAsync(body)) as T;

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final items = await real(tester, () => db.journalDao.forDay(_today));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            journalEntriesProvider.overrideWith((ref) => Stream.value(items)),
            // The activity panel reads the database; a widget test's fake
            // async never lets that query finish. See CLAUDE.md §2.
            dayActivityProvider.overrideWith((ref) async => ActivityView.empty),
            dayActivityIsManualProvider.overrideWith((ref) async => false),
          ],
          child: MaterialApp(
            theme: AppTheme.build(),
            home: const JournalScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an empty day says so plainly', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 9, 14, 12)), () async {
        await pump(tester);
        expect(find.text('The page is blank.'), findsOneWidget);
        expect(find.text('TODAY'), findsOneWidget);
      });
    });

    testWidgets('shows what was eaten, grouped by meal', (tester) async {
      await real(tester, () async {
        final oats = await addFood('Oats', kcal: 379, protein: 13.2);
        await log(oats, quantity: 80, slot: MealSlot.breakfast);
      });

      await withClock(Clock.fixed(DateTime(2026, 9, 14, 12)), () async {
        await pump(tester);

        expect(find.text('BREAKFAST'), findsOneWidget);
        expect(find.text('Oats'), findsOneWidget);
        expect(find.text('80g'), findsOneWidget);
        expect(find.text('303'), findsWidgets, reason: 'the day total in kcal');
      });
    });

    testWidgets('never shows a target, a remainder or a verdict',
        (tester) async {
      // The blackout, at the surface a user actually looks at every day.
      await real(tester, () async {
        final oats = await addFood('Oats', kcal: 379);
        await log(oats, quantity: 80, slot: MealSlot.breakfast);
      });

      await withClock(Clock.fixed(DateTime(2026, 9, 14, 12)), () async {
        await pump(tester);

        final text = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => (t.data ?? '').toLowerCase())
            .join(' | ');

        for (final forbidden in [
          'remaining',
          'target',
          'goal',
          'deficit',
          'surplus',
          'maintenance',
          'tdee',
          'losing',
          'gaining',
          'burned',
          'balance',
        ]) {
          expect(
            text.contains(forbidden),
            isFalse,
            reason: 'the Journal showed "$forbidden": $text',
          );
        }

        // And no "x / y" progress framing either.
        expect(text.contains('/'), isFalse, reason: text);
      });
    });

    testWidgets('marks a vague portion so it can be corrected', (tester) async {
      await real(tester, () async {
        final nuts = await addFood('Almonds');
        await log(nuts, quantity: 1, unit: PortionUnit.handful);
      });

      await withClock(Clock.fixed(DateTime(2026, 9, 14, 12)), () async {
        await pump(tester);

        expect(find.text('1 handful'), findsOneWidget);
        expect(
          find.textContaining('rests on a rough portion'),
          findsOneWidget,
          reason: 'singular, since exactly one entry is vague',
        );
      });
    });
  });
}
