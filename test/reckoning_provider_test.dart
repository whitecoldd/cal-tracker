import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/energy.dart';
import 'package:cal_tracker/domain/portion.dart';
import 'package:cal_tracker/domain/reckoning.dart';
import 'package:cal_tracker/domain/sealed_value.dart';
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
}
