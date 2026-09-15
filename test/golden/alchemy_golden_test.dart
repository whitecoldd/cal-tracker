@Tags(['golden'])
library;

import 'package:cal_tracker/data/daos/journal_dao.dart';
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

import 'font_loader.dart';

/// Renders a mixed day of Alchemy at phone width.
///
/// The picture is the check that matters: the vials must read as *composition*
/// and the Curses panel must carry its disclaimer, while nothing anywhere on
/// the page suggests whether the day was a deficit or a surplus.
const _now = '2026-09-15T08:00:00.000';
final _today = Day.of(2026, 9, 15);

void main() {
  setUpAll(loadAppFonts);

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  testWidgets('alchemy golden: a mixed day', (tester) async {
    // Taller than a phone so the whole page is in one image; width is a real
    // phone's 360 logical pixels, which is where the layout actually strains.
    tester.view.physicalSize = const Size(1080, 5400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final items = await tester.runAsync(() async {
      Future<int> food(
        String name, {
        required double kcal,
        double p = 0,
        double c = 0,
        double f = 0,
        double fibre = 0,
        double sugar = 0,
        double? addedSugar,
        double satFat = 0,
        double sodium = 0,
        int? nova,
        int? gi,
        int additives = 0,
      }) =>
          db.foodsDao.upsert(
            FoodsCompanion.insert(
              name: name,
              searchKey: name,
              kcal: kcal,
              proteinG: Value(p),
              carbsG: Value(c),
              fatG: Value(f),
              fibreG: Value(fibre),
              sugarG: Value(sugar),
              addedSugarG: Value(addedSugar),
              satFatG: Value(satFat),
              sodiumMg: Value(sodium),
              glycemicIndex: Value(gi),
              novaGroup: Value(nova),
              additivesJson: Value(
                additives == 0
                    ? null
                    : '[${List.generate(additives, (i) => '"en:e${100 + i}"').join(',')}]',
              ),
              source: FoodSource.seed,
              createdAt: _now,
              updatedAt: _now,
            ),
          );

      Future<void> log(int id, double grams) => db.journalDao.add(
            EntriesCompanion.insert(
              foodId: id,
              day: _today,
              mealSlot: MealSlot.lunch,
              quantity: grams,
              unit: PortionUnit.grams,
              grams: grams,
              createdAt: _now,
            ),
          );

      final oats = await food(
        'Oats, rolled, dry',
        kcal: 379,
        p: 13.2,
        c: 67.7,
        f: 6.5,
        fibre: 10.1,
        sugar: 1,
        satFat: 1.1,
        sodium: 6,
        nova: 1,
        gi: 55,
      );
      final chicken = await food(
        'Chicken breast, cooked',
        kcal: 165,
        p: 31,
        f: 3.6,
        satFat: 1,
        sodium: 74,
        nova: 1,
      );
      final crisps = await food(
        'Salted crisps',
        kcal: 536,
        p: 6,
        c: 53,
        f: 34,
        fibre: 4,
        sugar: 1,
        addedSugar: 1,
        satFat: 3,
        sodium: 600,
        nova: 4,
        gi: 70,
        additives: 4,
      );

      await log(oats, 80);
      await log(chicken, 200);
      await log(crisps, 100);

      return db.journalDao.forDay(_today);
    });

    await withClock(Clock.fixed(DateTime(2026, 9, 15, 12)), () async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            journalEntriesProvider
                .overrideWith((ref) => Stream.value(items as List<LoggedItem>)),
            // Settled values: both await a drift query, which a widget test's
            // fake async never lets complete. See CLAUDE.md §2.
            toxicityProvider.overrideWith((ref) async => 34.0),
            latestWeightProvider.overrideWith((ref) async => 82.0),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            home: const Scaffold(body: AlchemyScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AlchemyScreen),
        matchesGoldenFile('alchemy_day.png'),
      );
    });
  });
}
