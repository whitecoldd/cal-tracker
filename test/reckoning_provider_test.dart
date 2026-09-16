import 'package:cal_tracker/data/ai/ai_key_store.dart';
import 'package:cal_tracker/data/ai/openrouter_client.dart';
import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/data/week_archive.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/energy.dart';
import 'package:cal_tracker/domain/harm.dart';
import 'package:cal_tracker/domain/mutagens.dart';
import 'package:cal_tracker/domain/portion.dart';
import 'package:cal_tracker/domain/progression.dart';
import 'package:cal_tracker/domain/reckoning.dart';
import 'package:cal_tracker/domain/sealed_value.dart';
import 'package:cal_tracker/domain/week_findings.dart';
import 'package:cal_tracker/domain/week_pattern.dart';
import 'package:cal_tracker/domain/week_summary.dart';
import 'package:cal_tracker/domain/weekly_tale.dart';
import 'package:cal_tracker/features/journal/journal_providers.dart';
import 'package:cal_tracker/features/reckoning/reckoning_providers.dart';
import 'package:cal_tracker/providers/app_providers.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monday 14 September 2026 .. Sunday 20 September 2026.
const _monday = Day(20260914);
const _sunday = Day(20260920);
const _now = '2026-09-14T08:00:00.000';

/// Deliberately a plain `test`, not `testWidgets`.
///
/// This provider awaits several drift queries, and a widget-test body runs in
/// fake async that never turns the real event loop — the queries would hang
/// until timeout. Off the widget binding the event loop is real, so the
/// provider can be exercised against a real database. The screen is tested
/// separately with a settled snapshot. See CLAUDE.md §2.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> createProfile({int weekEndsOn = DateTime.sunday}) => withClock(
        Clock.fixed(_monday.toDateTime().add(const Duration(hours: 8))),
        () => db.profileDao.create(
          sex: Sex.male,
          birthYear: 1992,
          heightCm: 180,
          weightKg: 82,
          activityLevel: ActivityLevel.villageWalker,
          goal: Goal.loseFat,
          weekEndsOn: weekEndsOn,
        ),
      );

  Future<void> logWeek({double gramsPerDay = 1500, int days = 7}) async {
    final food = await db.foodsDao.upsert(
      FoodsCompanion.insert(
        name: 'Stew',
        searchKey: 'stew',
        kcal: 120,
        proteinG: const Value(9),
        carbsG: const Value(8),
        fatG: const Value(5),
        source: FoodSource.seed,
        createdAt: _now,
        updatedAt: _now,
      ),
    );

    for (var i = 0; i < days; i++) {
      await db.journalDao.add(
        EntriesCompanion.insert(
          foodId: food,
          day: _monday.addDays(i),
          mealSlot: MealSlot.dinner,
          quantity: gramsPerDay,
          unit: PortionUnit.grams,
          grams: gramsPerDay,
          createdAt: _now,
        ),
      );
    }
  }

  /// A week of one salty, additive-bearing food, for the harm surfaces.
  Future<void> logSalt() async {
    final food = await db.foodsDao.upsert(
      FoodsCompanion.insert(
        name: 'Salt pork',
        searchKey: 'salt pork',
        kcal: 400,
        proteinG: const Value(15),
        fatG: const Value(35),
        satFatG: const Value(14),
        sodiumMg: const Value(2000),
        novaGroup: const Value(4),
        additivesJson: const Value('["en:e250","en:e301","en:e330"]'),
        source: FoodSource.openFoodFacts,
        createdAt: _now,
        updatedAt: _now,
      ),
    );

    for (var i = 0; i < 7; i++) {
      await db.journalDao.add(
        EntriesCompanion.insert(
          foodId: food,
          day: _monday.addDays(i),
          mealSlot: MealSlot.dinner,
          quantity: 200,
          unit: PortionUnit.grams,
          grams: 200,
          createdAt: _now,
        ),
      );
    }
  }

  /// Reads the provider with the clock frozen to [today].
  Future<Reckoning> reckoningOn(Day today) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    return withClock(
      Clock.fixed(today.toDateTime().add(const Duration(hours: 12))),
      () async {
        // Let every live stream this provider depends on deliver its first
        // event *before* the reckoning is built. A FutureProvider that is
        // invalidated while its future is still pending re-chains `.future`
        // to the new build, so a dependency that emits mid-flight can keep a
        // read pending indefinitely. In the app this is invisible — the UI
        // simply rebuilds — but a test that awaits `.future` hangs.
        await container.read(profileProvider.future);
        await container.read(journalEntriesProvider.future);
        return container.read(weekReckoningProvider.future);
      },
    );
  }

  test('assembles the live week from the database', () async {
    await createProfile();
    await logWeek();

    final reckoning = await reckoningOn(_sunday);

    expect(reckoning.weekStart, _monday);
    expect(reckoning.weekEnd, _sunday);
    expect(reckoning.loggedDays, 7);
    expect(reckoning.isRevealed, isTrue);
  });

  test('seals the same week on an ordinary weekday', () async {
    await createProfile();
    await logWeek();

    final reckoning = await reckoningOn(_monday.addDays(3));

    expect(reckoning.isRevealed, isFalse);
    expect(reckoning.energyBalanceKcal, isA<Sealed<double>>());
    // The evidence is still readable — it is not a verdict.
    expect(reckoning.loggedDays, 7);
    expect(reckoning.daysUntilReveal, 3);
  });

  test('follows the week-end day configured in the profile', () async {
    // Changing it in Settings must move the reveal everywhere at once, which
    // is the whole reason the gate reads the profile rather than a constant.
    await createProfile(weekEndsOn: DateTime.wednesday);
    await logWeek();

    final onWednesday = await reckoningOn(_monday.addDays(2));
    expect(onWednesday.isRevealed, isTrue);

    final onSunday = await reckoningOn(_sunday);
    expect(onSunday.isRevealed, isFalse);
  });

  test('counts only the days that were actually logged', () async {
    await createProfile();
    await logWeek(days: 3);

    final reckoning = await reckoningOn(_sunday);

    expect(reckoning.loggedDays, 3);
  });

  test('reports the measured weight change across the week', () async {
    await createProfile();
    await logWeek();
    await db.trackingDao.upsertWeight(
      WeightsCompanion.insert(day: _sunday, kg: 81.1, createdAt: _now),
    );

    final reckoning = await reckoningOn(_sunday);

    expect(
      (reckoning.weightDeltaKg as Revealed<double?>).value,
      closeTo(-0.9, 0.0001),
    );
    expect((reckoning.trend as Revealed<WeightTrend?>).value,
        WeightTrend.falling);
  });

  test('a week with no profile still reckons without crashing', () async {
    // Before onboarding there is no BMR to work from. The screen must render
    // something rather than throw.
    await logWeek();

    final reckoning = await reckoningOn(_sunday);

    expect(reckoning.loggedDays, 0, reason: 'no profile means no energy days');
    expect(reckoning.isRevealed, isTrue);
  });

  test('last week reads on an ordinary weekday', () async {
    await createProfile();
    await logWeek();

    // Two days into the following week.
    final reckoning = await reckoningOn(_sunday.addDays(2));

    // The provider defaults to the live week, which is now the next one — so
    // this is the empty current week, sealed.
    expect(reckoning.isRevealed, isFalse);
  });

  test('walking back a week opens a closed one', () async {
    await createProfile();
    await logWeek();

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await withClock(
      Clock.fixed(_sunday.addDays(2).toDateTime().add(const Duration(hours: 12))),
      () async {
        await container.read(profileProvider.future);
        await container.read(journalEntriesProvider.future);
        container.read(reckoningWeekProvider.notifier).shiftWeeks(-1);

        final reckoning = await container.read(weekReckoningProvider.future);

        expect(reckoning.weekStart, _monday);
        expect(reckoning.isRevealed, isTrue, reason: 'a closed week is history');
        expect(reckoning.loggedDays, 7);
      },
    );
  });

  group('a sealed week is paid what its perks are worth', () {
    /// Seals the week containing [today] and hands back its frozen summary.
    ///
    /// The archive is overridden with a **keyless** client. Sealing asks for a
    /// narrative and `WeekArchive` swallows the resulting `AiFailure` on
    /// purpose, so a week still seals with no key, no network and no budget —
    /// which keeps this test on the arithmetic and off the wire entirely.
    Future<WeekSummary> sealWeek(Day today) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          weekArchiveProvider.overrideWithValue(
            WeekArchive(
              weeks: db.weeksDao,
              ai: OpenRouterClient(
                keys: InMemoryAiKeyStore(key: null),
                calls: db.aiCallsDao,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      return withClock(
        Clock.fixed(today.toDateTime().add(const Duration(hours: 12))),
        () async {
          await container.read(profileProvider.future);
          await container.read(journalEntriesProvider.future);
          final archived = await container.read(archivedWeekProvider.future);
          return archived!.summary;
        },
      );
    }

    /// Throws the sealed week away so the next read seals it again.
    ///
    /// The achievements it granted are left in place, which is the point: a
    /// re-seal has to be able to see the perks without being paid by them.
    Future<void> unseal() => db.customStatement('DELETE FROM weeks');

    test('Adrenaline is applied — it was displayed and spent nowhere', () async {
      await createProfile();
      await logWeek();

      final summary = await sealWeek(_sunday);

      // Rebuilt from the frozen summary's own inputs, so this asserts the
      // multiplier without hard-coding what a week of stew happens to score.
      final base = awardXp(
        loggedDays: summary.loggedDays,
        averageVitality: summary.averageVitality,
        goalDays: summary.goalDays,
      ).total;

      expect(base, greaterThan(0));
      expect(
        summary.xp,
        withMultipliers(base, loggedDaysInLastWeek: summary.loggedDays),
      );
      // Seven days logged is the full ceiling, so the award is visibly larger
      // than the sum of its parts. Before T24 these two were equal.
      expect(summary.xp, greaterThan(base));
    });

    test("last week's perk pays this week", () async {
      await createProfile();
      await logWeek();

      final plain = await sealWeek(_sunday);

      await unseal();
      await db.weeksDao.unlock(
        AchievementsCompanion.insert(
          code: Mutagen.greenBlood.code,
          weekStart: Value(_monday.addDays(-7)),
          unlockedAt: _now,
        ),
      );

      final perked = await sealWeek(_sunday);

      expect(perked.xp, greaterThan(plain.xp));
    });

    test('a perk the week earns itself does not pay that same week', () async {
      // The regression an all-time bonus would reintroduce. Sealing a fully
      // logged week grants Green Blood *for that week*; if the bonus were read
      // from the whole achievements table, the second seal would find it and
      // the perk would immediately pay for itself.
      await createProfile();
      await logWeek();

      final first = await sealWeek(_sunday);
      expect(
        await db.weeksDao.mutagensForWeek(_monday),
        contains(Mutagen.greenBlood),
      );

      await unseal();

      expect((await sealWeek(_sunday)).xp, first.xp);
    });
  });

  /// Reads the open half with the clock frozen to [today].
  Future<WeekPattern> patternOn(Day today) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    return withClock(
      Clock.fixed(today.toDateTime().add(const Duration(hours: 12))),
      () async {
        await container.read(profileProvider.future);
        await container.read(journalEntriesProvider.future);
        return container.read(weekPatternProvider.future);
      },
    );
  }

  group('the open half', () {
    test('reads on an ordinary weekday, when the archive reads nothing',
        () async {
      // The whole point of the second provider. archivedWeekProvider returns
      // null six days out of seven; this one must not.
      await createProfile();
      await logWeek();

      final pattern = await patternOn(_monday.addDays(2));

      expect(pattern.weekStart, _monday);
      expect(pattern.isPartial, isTrue);
      expect(pattern.daysInWindow, 3);
      expect(pattern.loggedDays, 3, reason: 'only as far as today');
    });

    test('reads a whole week on the reveal day', () async {
      await createProfile();
      await logWeek();

      final pattern = await patternOn(_sunday);

      expect(pattern.isPartial, isFalse);
      expect(pattern.loggedDays, 7);
      expect(pattern.quality.meanVitality, greaterThan(0));
    });

    test('names the food behind a curse', () async {
      await createProfile();
      await logSalt();

      final pattern = await patternOn(_sunday);
      final salt = pattern[HarmKind.sodium];

      expect(salt, isNotNull);
      expect(salt!.carriers, isNotEmpty);
      expect(salt.carriers.first.food.name, 'Salt pork');
    });

    test('counts each additive once however often the food was eaten',
        () async {
      await createProfile();
      await logSalt();

      final pattern = await patternOn(_sunday);

      // One food, eaten seven times, listing three codes.
      expect(pattern.additiveCount, 3);
      expect(pattern.additives.first.days, 7);
    });

    test('still reads a week that was sealed long ago', () async {
      // A sealed week's stored summary predates every figure here and would
      // decode to zeros. Recomputing from the journal is what makes the report
      // work backwards through the history.
      await createProfile();
      await logWeek();

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final pattern = await withClock(
        Clock.fixed(_sunday.addDays(21).toDateTime()),
        () async {
          await container.read(profileProvider.future);
          await container.read(journalEntriesProvider.future);
          container.read(reckoningWeekProvider.notifier).shiftWeeks(-3);
          return container.read(weekPatternProvider.future);
        },
      );

      expect(pattern.weekStart, _monday);
      expect(pattern.loggedDays, 7);
    });
  });

  group('the seal holds across every weekday', () {
    for (var offset = 0; offset < 7; offset++) {
      final today = _monday.addDays(offset);

      test('nothing readable on day ${offset + 1} states a direction',
          () async {
        await createProfile();
        await logSalt();

        final pattern = await patternOn(today);
        final findings = readFindings(pattern);

        final text = [
          for (final f in findings) '${f.title} ${f.detail} ${f.basis ?? ''}',
          for (final s in tellPattern(pattern, findings)) '${s.title} ${s.body}',
        ].join(' ').toLowerCase();

        // Density units are allowed; amounts are not. See
        // week_findings_test.dart for why those are not the same thing.
        final withoutUnits =
            text.replaceAll(RegExp(r'per (\d[\d,]* )?(kcal|kg)'), '');

        for (final leak in const [
          'kcal',
          'kg',
          'losing',
          'gaining',
          'deficit',
          'surplus',
          'expenditure',
          'burned',
          'tdee',
          'projected',
          'falling',
          'rising',
        ]) {
          expect(
            withoutUnits.contains(leak),
            isFalse,
            reason: 'the open half leaked "$leak" on '
                '${today.toDateTime().weekday}: $text',
          );
        }
      });
    }
  });

}
