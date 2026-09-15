@Tags(['golden'])
library;

import 'package:cal_tracker/data/daos/journal_dao.dart';
import 'package:cal_tracker/data/database.dart';
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

import 'font_loader.dart';

/// Renders a day of the Journal at phone width.
///
/// The picture is the check that matters here: it should be obvious at a glance
/// that nothing on this screen tells you whether the day was good or bad.
const _now = '2026-09-14T08:00:00.000';
final _today = Day.of(2026, 9, 14);

void main() {
  setUpAll(loadAppFonts);

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  testWidgets('journal golden: a logged day', (tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final items = await tester.runAsync(() async {
      Future<int> food(
        String name,
        double kcal,
        double p,
        double c,
        double f,
        double fibre, {
        double? piece,
        String? pieceName,
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
              gramsPerPiece: Value(piece),
              pieceName: Value(pieceName),
              source: FoodSource.seed,
              createdAt: _now,
              updatedAt: _now,
            ),
          );

      Future<void> log(
        int id,
        double qty,
        PortionUnit unit,
        MealSlot slot, {
        double? piece,
      }) async {
        final portion =
            resolvePortion(quantity: qty, unit: unit, gramsPerPiece: piece);
        await db.journalDao.add(
          EntriesCompanion.insert(
            foodId: id,
            day: _today,
            mealSlot: slot,
            quantity: qty,
            unit: unit,
            grams: portion.grams,
            confidence: Value(portion.confidence),
            createdAt: _now,
          ),
        );
      }

      final oats = await food('Oats, rolled, dry', 379, 13.2, 67.7, 6.5, 10.1);
      final egg = await food('Egg, whole', 143, 12.6, 0.7, 9.5, 0,
          piece: 50, pieceName: 'egg');
      final chicken = await food('Chicken breast, cooked', 165, 31, 0, 3.6, 0);
      final rice = await food('White rice, cooked', 130, 2.7, 28, 0.3, 0.4);
      final almonds = await food('Almonds', 579, 21.2, 21.6, 49.9, 12.5);

      await log(oats, 80, PortionUnit.grams, MealSlot.breakfast);
      await log(egg, 2, PortionUnit.piece, MealSlot.breakfast, piece: 50);
      await log(chicken, 200, PortionUnit.grams, MealSlot.lunch);
      await log(rice, 250, PortionUnit.grams, MealSlot.lunch);
      await log(almonds, 1, PortionUnit.handful, MealSlot.snack);

      return db.journalDao.forDay(_today);
    });

    await withClock(Clock.fixed(DateTime(2026, 9, 14, 12)), () async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            journalEntriesProvider
                .overrideWith((ref) => Stream.value(items as List<LoggedItem>)),
            // A settled day of movement, so the golden shows the panel with
            // real figures rather than its loading box.
            dayActivityProvider.overrideWith(
              (ref) async => const ActivityView(
                steps: 8240,
                distanceM: 6100,
                stepGoal: 10000,
                stamina: 82.4,
              ),
            ),
            dayActivityIsManualProvider.overrideWith((ref) async => false),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            home: const JournalScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(JournalScreen),
        matchesGoldenFile('journal_day.png'),
      );
    });
  });
}
