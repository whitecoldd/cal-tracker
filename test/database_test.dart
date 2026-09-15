import 'package:cal_tracker/data/daos/ai_calls_dao.dart';
import 'package:cal_tracker/data/daos/foods_dao.dart';
import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/seed_loader.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/portion.dart';
import 'package:clock/clock.dart';
// drift exports an `isNull` query expression that shadows the matcher.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-09-14T10:00:00.000';

FoodsCompanion _food(
  String name, {
  required FoodSource source,
  double kcal = 100,
  double protein = 10,
  double carbs = 5,
  String? barcode,
  double confidence = 1,
}) {
  return FoodsCompanion.insert(
    name: name,
    // Deliberately NOT normalised: upsert must recompute this itself.
    searchKey: name,
    kcal: kcal,
    proteinG: Value(protein),
    carbsG: Value(carbs),
    barcode: Value(barcode),
    source: source,
    confidence: Value(confidence),
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  group('schema', () {
    test('creates every table and opens cleanly', () async {
      expect(await db.foodsDao.count(), 0);
      expect(await db.aiCallsDao.usedToday(), 0);
      expect(await db.weeksDao.allAchievements(), isEmpty);
    });

    test('enforces the entry -> food foreign key', () async {
      // Drift leaves foreign keys off by default; a dangling entry must fail
      // loudly rather than produce a journal row with no food behind it.
      await expectLater(
        db.journalDao.add(
          EntriesCompanion.insert(
            foodId: 9999,
            day: Day.of(2026, 9, 14),
            mealSlot: MealSlot.lunch,
            quantity: 1,
            unit: PortionUnit.grams,
            grams: 100,
            createdAt: _now,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('FoodsDao.upsert source precedence', () {
    test('a better source overwrites a worse one', () async {
      await db.foodsDao.upsert(_food('Cola', source: FoodSource.ai, kcal: 30));
      await db.foodsDao
          .upsert(_food('Cola', source: FoodSource.openFoodFacts, kcal: 42));

      final all = await db.foodsDao.search('cola');
      expect(all, hasLength(1), reason: 'should update, not duplicate');
      expect(all.single.kcal, 42);
      expect(all.single.source, FoodSource.openFoodFacts);
    });

    test('a worse source never overwrites a better one', () async {
      // The case that matters: a background Open Food Facts refresh must not
      // silently discard a correction the user typed by hand.
      await db.foodsDao
          .upsert(_food('Cola', source: FoodSource.manual, kcal: 42));
      await db.foodsDao
          .upsert(_food('Cola', source: FoodSource.ai, kcal: 999));

      final all = await db.foodsDao.search('cola');
      expect(all.single.kcal, 42);
      expect(all.single.source, FoodSource.manual);
    });

    test('an equal source is allowed to refresh the data', () async {
      await db.foodsDao.upsert(
        _food('Cola', source: FoodSource.openFoodFacts, kcal: 42, barcode: '1'),
      );
      await db.foodsDao.upsert(
        _food('Cola', source: FoodSource.openFoodFacts, kcal: 44, barcode: '1'),
      );

      expect((await db.foodsDao.findByBarcode('1'))!.kcal, 44);
    });

    test('matches an existing food by barcode even under a different name',
        () async {
      await db.foodsDao.upsert(
        _food('Cola', source: FoodSource.ai, barcode: '5449000000996'),
      );
      await db.foodsDao.upsert(
        _food('Coca-Cola Classic',
            source: FoodSource.openFoodFacts, barcode: '5449000000996'),
      );

      expect(await db.foodsDao.count(), 1);
      expect(
        (await db.foodsDao.findByBarcode('5449000000996'))!.name,
        'Coca-Cola Classic',
      );
    });
  });

  group('FoodsDao.search', () {
    test('normalises punctuation and spacing into the search key', () {
      expect(FoodsDao.searchKeyFor('  Coca-Cola   ZERO! '), 'coca cola zero');
      expect(FoodsDao.searchKeyFor('Oats', 'Quaker'), 'oats quaker');
    });

    test('upsert recomputes the search key instead of trusting the caller',
        () async {
      // Two callers spelling the key differently must still hit one row.
      await db.foodsDao.upsert(_food('Oats, rolled, dry', source: FoodSource.seed));
      await db.foodsDao.upsert(
        FoodsCompanion.insert(
          name: 'Oats, rolled, dry',
          searchKey: 'WILDLY-wrong key',
          kcal: 400,
          source: FoodSource.manual,
          createdAt: _now,
          updatedAt: _now,
        ),
      );

      expect(await db.foodsDao.count(), 1);
      expect((await db.foodsDao.search('oats rolled dry')).single.kcal, 400);
    });

    test('puts an exact match above a partial one', () async {
      await db.foodsDao.upsert(_food('Rice pudding', source: FoodSource.seed));
      await db.foodsDao.upsert(_food('Rice', source: FoodSource.seed));

      final results = await db.foodsDao.search('rice');
      expect(results.first.name, 'Rice');
      expect(results, hasLength(2));
    });

    test('an empty query returns nothing rather than everything', () async {
      await db.foodsDao.upsert(_food('Rice', source: FoodSource.seed));
      expect(await db.foodsDao.search('   '), isEmpty);
    });

    group('the searches that came back from first use', () {
      test('words match in any order', () async {
        await db.foodsDao.upsert(
          _food('Monster Energy Ultra White', source: FoodSource.openFoodFacts),
        );

        // The old query was one LIKE over the whole string, so this matched
        // nothing at all while "monster ultra" matched.
        expect(
          (await db.foodsDao.search('white monster')).single.name,
          'Monster Energy Ultra White',
        );
      });

      test('a leading count does not stop a food being found', () async {
        await db.foodsDao.upsert(_food('Egg, whole', source: FoodSource.seed));

        expect(
          (await db.foodsDao.search('5 fried eggs')).map((f) => f.name),
          isEmpty,
          reason: 'no food is named "fried egg" here',
        );
        expect(
          (await db.foodsDao.search('5 eggs')).single.name,
          'Egg, whole',
        );
      });

      test('a plural finds the singular it was stored under', () async {
        await db.foodsDao.upsert(_food('Egg, whole', source: FoodSource.seed));
        await db.foodsDao.upsert(_food('Tomato', source: FoodSource.seed));

        expect((await db.foodsDao.search('eggs')).single.name, 'Egg, whole');
        expect((await db.foodsDao.search('tomatoes')).single.name, 'Tomato');
      });

      test('a stopword does not have to appear in the food name', () async {
        await db.foodsDao.upsert(_food('Rice pudding', source: FoodSource.seed));

        // "with" is nowhere in the stored key. If it were kept as a term,
        // every term having to match would rule the row out.
        expect(
          (await db.foodsDao.search('rice with pudding')).single.name,
          'Rice pudding',
        );
      });
    });

    test('ranks a hand-corrected food above an AI guess', () async {
      // The bug this replaces: the old ORDER BY promised ordering by source
      // quality in its comment and had no ordering term on source at all, so
      // a confident AI row outranked everything.
      await db.foodsDao.upsert(
        _food('Borscht bowl', source: FoodSource.ai, confidence: 0.95),
      );
      await db.foodsDao.upsert(
        _food('Borscht pot', source: FoodSource.manual, confidence: 0.5),
      );

      final results = await db.foodsDao.search('borscht');
      expect(results.map((f) => f.source).toList(),
          [FoodSource.manual, FoodSource.ai]);
    });

    test('falls back to confidence, then to name, within one source', () async {
      await db.foodsDao.upsert(
        _food('Stew, thin', source: FoodSource.seed, confidence: 0.4),
      );
      await db.foodsDao.upsert(
        _food('Stew, thick', source: FoodSource.seed, confidence: 0.9),
      );

      final results = await db.foodsDao.search('stew');
      expect(results.first.name, 'Stew, thick');
    });

    test('a term that is absent excludes the row entirely', () async {
      await db.foodsDao.upsert(_food('Brown rice', source: FoodSource.seed));
      await db.foodsDao.upsert(_food('White bread', source: FoodSource.seed));

      expect(await db.foodsDao.search('brown bread'), isEmpty);
    });
  });

  group('SeedLoader', () {
    const fixture = '''
    {"version":1,"foods":[
      {"name":"Oats, rolled, dry","kcal":379,"protein":13.2,"carbs":67.7,
       "sugar":1.0,"fat":6.5,"satFat":1.2,"fibre":10.1,"sodiumMg":6,
       "gi":55,"nova":1},
      {"name":"Egg, whole","kcal":143,"protein":12.6,"carbs":0.7,"sugar":0.4,
       "fat":9.5,"satFat":3.1,"fibre":0,"sodiumMg":142,"nova":1,
       "gramsPerPiece":50,"pieceName":"egg"}
    ]}''';

    test('loads foods with their GI, NOVA and piece weights', () async {
      final loaded = await SeedLoader(db.foodsDao).loadFromJson(fixture);
      expect(loaded, 2);

      final oats = (await db.foodsDao.search('oats')).single;
      expect(oats.glycemicIndex, 55);
      expect(oats.novaGroup, 1);
      expect(oats.source, FoodSource.seed);

      final egg = (await db.foodsDao.search('egg')).single;
      expect(egg.gramsPerPiece, 50);
      expect(egg.pieceName, 'egg');
      // No GI on a food with essentially no carbohydrate — absent, not zero.
      expect(egg.glycemicIndex, isNull);
    });

    test('loading twice does not duplicate or clobber', () async {
      // The seed foods have no barcode, and SQLite does not treat two NULLs as
      // a unique conflict — so an ignoring insert would silently duplicate the
      // entire table on a second load.
      expect(await SeedLoader(db.foodsDao).loadFromJson(fixture), 2);

      await db.foodsDao.upsert(
        _food('Oats, rolled, dry', source: FoodSource.manual, kcal: 400),
      );

      expect(
        await SeedLoader(db.foodsDao).loadFromJson(fixture),
        0,
        reason: 'nothing new to insert',
      );

      expect(await db.foodsDao.count(), 2);
      final oats = (await db.foodsDao.search('oats')).single;
      expect(oats.kcal, 400, reason: 'a manual correction must survive');
    });

    test('a grown seed file adds only the new foods', () async {
      await SeedLoader(db.foodsDao).loadFromJson(fixture);

      const grown = '''
      {"version":1,"foods":[
        {"name":"Oats, rolled, dry","kcal":379,"protein":13.2,"carbs":67.7,
         "sugar":1.0,"fat":6.5,"satFat":1.2,"fibre":10.1,"sodiumMg":6},
        {"name":"Lentils, cooked","kcal":116,"protein":9,"carbs":20,
         "sugar":1.8,"fat":0.4,"satFat":0.05,"fibre":7.9,"sodiumMg":2,
         "gi":32,"nova":1}
      ]}''';

      expect(await SeedLoader(db.foodsDao).loadFromJson(grown), 1);
      expect(await db.foodsDao.count(), 3);
    });
  });

  group('JournalDao', () {
    late int oatsId;

    setUp(() async {
      oatsId = await db.foodsDao.upsert(
        _food('Oats', source: FoodSource.seed, kcal: 379, protein: 13.2,
            carbs: 67.7),
      );
    });

    Future<void> log(Day day, double grams) => db.journalDao.add(
          EntriesCompanion.insert(
            foodId: oatsId,
            day: day,
            mealSlot: MealSlot.breakfast,
            quantity: grams,
            unit: PortionUnit.grams,
            grams: grams,
            createdAt: _now,
          ),
        );

    test('scales a food per 100g to the portion actually eaten', () async {
      await log(Day.of(2026, 9, 14), 80);

      final item = (await db.journalDao.forDay(Day.of(2026, 9, 14))).single;
      expect(item.portions, closeTo(0.8, 1e-9));
      expect(item.kcal, closeTo(303.2, 0.01));
      expect(item.proteinG, closeTo(10.56, 0.01));
    });

    test('glycemic load weights GI by the carbohydrate actually eaten',
        () async {
      await log(Day.of(2026, 9, 14), 80);
      final item = (await db.journalDao.forDay(Day.of(2026, 9, 14))).single;

      // Oats have no GI yet, so the load is unknown rather than zero.
      expect(item.glycemicLoad, isNull);

      final withGi = await db.foodsDao.upsert(
        FoodsCompanion.insert(
          name: 'Oats',
          searchKey: 'oats',
          kcal: 379,
          carbsG: const Value(67.7),
          glycemicIndex: const Value(55),
          source: FoodSource.manual,
          createdAt: _now,
          updatedAt: _now,
        ),
      );
      expect(withGi, oatsId, reason: 'should update the same row');

      final updated = (await db.journalDao.forDay(Day.of(2026, 9, 14))).single;
      // 55 * (67.7g * 0.8) / 100 = 29.788
      expect(updated.glycemicLoad, closeTo(29.788, 0.001));
    });

    test('reads a day without bleeding in neighbouring days', () async {
      await log(Day.of(2026, 9, 13), 50);
      await log(Day.of(2026, 9, 14), 80);
      await log(Day.of(2026, 9, 15), 60);

      expect(await db.journalDao.forDay(Day.of(2026, 9, 14)), hasLength(1));
      expect(
        (await db.journalDao.forDay(Day.of(2026, 9, 14))).single.entry.grams,
        80,
      );
    });

    test('range reads are inclusive at both ends', () async {
      await log(Day.of(2026, 9, 13), 10);
      await log(Day.of(2026, 9, 14), 20);
      await log(Day.of(2026, 9, 20), 30);
      await log(Day.of(2026, 9, 21), 40);

      final week = await db.journalDao
          .forRange(Day.of(2026, 9, 14), Day.of(2026, 9, 20));
      expect(week.map((i) => i.entry.grams), [20, 30]);
    });

    test('loggedDaysIn reports distinct days, for the streak', () async {
      await log(Day.of(2026, 9, 14), 10);
      await log(Day.of(2026, 9, 14), 20);
      await log(Day.of(2026, 9, 16), 30);

      final days = await db.journalDao
          .loggedDaysIn(Day.of(2026, 9, 14), Day.of(2026, 9, 20));
      expect(days, {Day.of(2026, 9, 14), Day.of(2026, 9, 16)});
    });

    test('deleting an entry leaves the food in the library', () async {
      await log(Day.of(2026, 9, 14), 80);
      final item = (await db.journalDao.forDay(Day.of(2026, 9, 14))).single;

      await db.journalDao.remove(item.entry.id);

      expect(await db.journalDao.forDay(Day.of(2026, 9, 14)), isEmpty);
      expect(await db.foodsDao.count(), 1, reason: 'the Bestiary keeps it');
    });
  });

  group('TrackingDao', () {
    final day = Day.of(2026, 9, 14);

    test('a manual step count is not overwritten by a later sync', () async {
      await db.trackingDao.upsertActivity(
        ActivityDaysCompanion.insert(
          day: day,
          steps: const Value(9000),
          source: ActivitySource.manual,
          updatedAt: _now,
        ),
      );
      await db.trackingDao.upsertActivity(
        ActivityDaysCompanion.insert(
          day: day,
          steps: const Value(120),
          source: ActivitySource.healthConnect,
          updatedAt: _now,
        ),
      );

      expect((await db.trackingDao.activityFor(day))!.steps, 9000);
    });

    test('a sync may replace an earlier sync', () async {
      for (final steps in [120, 8400]) {
        await db.trackingDao.upsertActivity(
          ActivityDaysCompanion.insert(
            day: day,
            steps: Value(steps),
            source: ActivitySource.healthConnect,
            updatedAt: _now,
          ),
        );
      }
      expect((await db.trackingDao.activityFor(day))!.steps, 8400);
    });

    test('finds the most recent weigh-in on or before a day', () async {
      for (final (d, kg) in [(Day.of(2026, 9, 10), 82.0), (Day.of(2026, 9, 13), 81.4)]) {
        await db.trackingDao.upsertWeight(
          WeightsCompanion.insert(day: d, kg: kg, createdAt: _now),
        );
      }

      // No weigh-in on the 14th, so fall back to the 13th rather than nothing.
      expect((await db.trackingDao.latestWeightOnOrBefore(day))!.kg, 81.4);
      expect(
        (await db.trackingDao.latestWeightOnOrBefore(Day.of(2026, 9, 12)))!.kg,
        82.0,
      );
      expect(
        await db.trackingDao.latestWeightOnOrBefore(Day.of(2026, 9, 1)),
        isNull,
      );
    });

    test('re-weighing on the same day replaces rather than appends', () async {
      for (final kg in [81.4, 81.1]) {
        await db.trackingDao.upsertWeight(
          WeightsCompanion.insert(day: day, kg: kg, createdAt: _now),
        );
      }
      final all = await db.trackingDao.weightsInRange(day, day);
      expect(all, hasLength(1));
      expect(all.single.kg, 81.1);
    });
  });

  group('AiCallsDao budget', () {
    test('counts failed calls too, because the limit charges the request',
        () async {
      await withClock(Clock.fixed(DateTime(2026, 9, 14, 12)), () async {
        await db.aiCallsDao.record(
          model: 'nex-agi/nex-n2.5-pro:free',
          purpose: AiPurpose.parseText,
          succeeded: true,
        );
        await db.aiCallsDao.record(
          model: 'nex-agi/nex-n2.5-pro:free',
          purpose: AiPurpose.parseText,
          succeeded: false,
          error: 'timeout',
        );

        expect(await db.aiCallsDao.usedToday(), 2);
      });
    });

    test('reports the free daily cap and what is left', () async {
      await withClock(Clock.fixed(DateTime(2026, 9, 14, 12)), () async {
        for (var i = 0; i < 48; i++) {
          await db.aiCallsDao.record(
            model: 'm',
            purpose: AiPurpose.parseText,
            succeeded: true,
          );
        }

        final budget = await db.aiCallsDao.budget();
        expect(budget.dailyLimit, 50);
        expect(budget.remainingToday, 2);
        expect(budget.dailyExhausted, isFalse);

        final paid = await db.aiCallsDao.budget(hasPurchasedCredit: true);
        expect(paid.dailyLimit, 1000);
        expect(paid.remainingToday, 952);
      });
    });

    test('yesterday does not count against today', () async {
      await withClock(Clock.fixed(DateTime(2026, 9, 13, 23)), () async {
        await db.aiCallsDao.record(
          model: 'm',
          purpose: AiPurpose.parseText,
          succeeded: true,
        );
      });
      await withClock(Clock.fixed(DateTime(2026, 9, 14, 1)), () async {
        expect(await db.aiCallsDao.usedToday(), 0);
      });
    });

    test('the per-minute window only counts the last minute', () async {
      await withClock(Clock.fixed(DateTime(2026, 9, 14, 12, 0)), () async {
        await db.aiCallsDao.record(
          model: 'm',
          purpose: AiPurpose.parseText,
          succeeded: true,
        );
      });

      await withClock(Clock.fixed(DateTime(2026, 9, 14, 12, 0, 30)), () async {
        expect(await db.aiCallsDao.usedLastMinute(), 1);
      });
      await withClock(Clock.fixed(DateTime(2026, 9, 14, 12, 5)), () async {
        expect(await db.aiCallsDao.usedLastMinute(), 0);
      });
    });

    test('canCall is false once either limit is hit', () async {
      const rateLimited = AiBudget(
        usedToday: 1,
        dailyLimit: 50,
        usedLastMinute: 20,
        perMinuteLimit: 20,
      );
      const spent = AiBudget(
        usedToday: 50,
        dailyLimit: 50,
        usedLastMinute: 0,
        perMinuteLimit: 20,
      );

      expect(rateLimited.canCall, isFalse);
      expect(spent.canCall, isFalse);
      expect(spent.remainingToday, 0);
    });
  });

  group('WeeksDao', () {
    final weekStart = Day.of(2026, 9, 14);

    setUp(() async {
      await db.weeksDao.upsert(
        WeeksCompanion.insert(
          weekStart: weekStart,
          weekEnd: Day.of(2026, 9, 20),
          createdAt: _now,
        ),
      );
    });

    test('a week starts unrevealed and is frozen when sealed', () async {
      expect((await db.weeksDao.forWeekStart(weekStart))!.revealed, isFalse);

      await db.weeksDao.seal(
        weekStart,
        summaryJson: '{"deficit":-2340}',
        narrative: 'The Wolf grew lean.',
        xpAwarded: 420,
      );

      final week = (await db.weeksDao.forWeekStart(weekStart))!;
      expect(week.revealed, isTrue);
      expect(week.summaryJson, '{"deficit":-2340}');
      expect(week.xpAwarded, 420);
    });

    test('history only lists revealed weeks', () async {
      expect(await db.weeksDao.watchHistory().first, isEmpty);
      await db.weeksDao.seal(weekStart, summaryJson: '{}');
      expect(await db.weeksDao.watchHistory().first, hasLength(1));
    });

    test('the same achievement cannot be awarded twice for one week', () async {
      for (var i = 0; i < 2; i++) {
        await db.weeksDao.unlock(
          AchievementsCompanion.insert(
            code: 'iron_stomach',
            weekStart: Value(weekStart),
            unlockedAt: _now,
          ),
        );
      }
      expect(await db.weeksDao.allAchievements(), hasLength(1));
    });

    test('but may be earned again in a different week', () async {
      await db.weeksDao.unlock(
        AchievementsCompanion.insert(
          code: 'iron_stomach',
          weekStart: Value(weekStart),
          unlockedAt: _now,
        ),
      );
      await db.weeksDao.unlock(
        AchievementsCompanion.insert(
          code: 'iron_stomach',
          weekStart: Value(Day.of(2026, 9, 21)),
          unlockedAt: _now,
        ),
      );
      expect(await db.weeksDao.allAchievements(), hasLength(2));
    });
  });
}
