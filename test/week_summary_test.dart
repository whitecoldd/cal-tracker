import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/energy.dart';
import 'package:cal_tracker/domain/reckoning.dart';
import 'package:cal_tracker/domain/reveal_gate.dart';
import 'package:cal_tracker/domain/week_summary.dart';
import 'package:flutter_test/flutter_test.dart';

const _monday = Day(20260914);
const _sunday = Day(20260920);

Reckoning _reckoningOn(Day today, {double endWeight = 81.1}) => reckon(
      anyDayOfWeek: today,
      today: today,
      gate: const RevealGate(weekEndsOn: DateTime.sunday),
      days: [
        for (var i = 0; i < 7; i++)
          DayEnergy(
            day: _monday.addDays(i),
            intakeKcal: 1800,
            expenditureKcal: 2400,
          ),
      ],
      startWeightKg: 82,
      endWeightKg: endWeight,
      heightCm: 180,
      ageYears: 34,
      sex: Sex.male,
    );

void main() {
  group('XP rewards behaviour, never outcome', () {
    test('nothing in the award reads the direction of the scale', () {
      // The load-bearing property. XP that depended on weight would be a
      // verdict in disguise — it could not be shown daily without leaking the
      // answer, and it would punish an honest week that went sideways on
      // water. See CLAUDE.md §1.
      final xp = awardXp(loggedDays: 7, averageVitality: 70, goalDays: 4);

      // The whole input surface is logging, quality and movement.
      expect(xp.total, greaterThan(0));
      expect(
        awardXp(loggedDays: 7, averageVitality: 70, goalDays: 4).total,
        xp.total,
        reason: 'the same behaviour always earns the same XP',
      );
    });

    test('pays per logged day', () {
      final three = awardXp(loggedDays: 3, averageVitality: 0, goalDays: 0);
      final six = awardXp(loggedDays: 6, averageVitality: 0, goalDays: 0);

      expect(three.forLogging, 30);
      expect(six.forLogging, 60);
    });

    test('pays for diet quality, up to a cap', () {
      expect(
        awardXp(loggedDays: 7, averageVitality: 100, goalDays: 0).forQuality,
        WeekXp.maxQuality,
      );
      expect(
        awardXp(loggedDays: 7, averageVitality: 50, goalDays: 0).forQuality,
        15,
      );
    });

    test('pays for days the step goal was met', () {
      expect(
        awardXp(loggedDays: 7, averageVitality: 0, goalDays: 5).forMovement,
        25,
      );
    });

    test('a complete week earns a bonus', () {
      final six = awardXp(loggedDays: 6, averageVitality: 0, goalDays: 0);
      final seven = awardXp(loggedDays: 7, averageVitality: 0, goalDays: 0);

      expect(six.forCompleteness, 0);
      expect(seven.forCompleteness, WeekXp.completeWeekBonus);
    });

    test('a week with nothing logged earns nothing', () {
      // Not a punishment — simply nothing to pay for.
      expect(
        awardXp(loggedDays: 0, averageVitality: 100, goalDays: 7).total,
        0,
      );
    });

    test('is not thrown by figures outside their range', () {
      final xp = awardXp(loggedDays: 7, averageVitality: 400, goalDays: 99);

      expect(xp.forQuality, WeekXp.maxQuality);
      expect(xp.forMovement, 7 * WeekXp.perGoalDay);
    });
  });

  group('the frozen summary', () {
    const summary = WeekSummary(
      loggedDays: 7,
      energyBalanceKcal: -4200,
      averageDailyBalanceKcal: -600,
      projectedChangeKg: -0.55,
      averageVitality: 68,
      averageToxicity: 31,
      steps: 58000,
      goalDays: 4,
      xp: 145,
      weightDeltaKg: -0.9,
      trend: WeightTrend.falling,
      bodyFatPercent: 21.4,
      dailyBalances: [-600, -500, -700, -650, -550, -600, -600],
      dailyWeights: [82, 81.6, 81.1],
    );

    test('survives a round trip', () {
      final back = WeekSummary.decode(WeekSummary.encode(summary))!;

      expect(back.loggedDays, 7);
      expect(back.energyBalanceKcal, -4200);
      expect(back.weightDeltaKg, -0.9);
      expect(back.trend, WeightTrend.falling);
      expect(back.bodyFatPercent, 21.4);
      expect(back.dailyBalances, hasLength(7));
      expect(back.dailyWeights, [82, 81.6, 81.1]);
      expect(back.xp, 145);
    });

    test('a week with no weigh-ins round-trips its nulls', () {
      const thin = WeekSummary(
        loggedDays: 2,
        energyBalanceKcal: -900,
        averageDailyBalanceKcal: -450,
        projectedChangeKg: -0.12,
        averageVitality: 40,
        averageToxicity: 10,
        steps: 4000,
        goalDays: 0,
        xp: 32,
      );

      final back = WeekSummary.decode(WeekSummary.encode(thin))!;

      expect(back.weightDeltaKg, isNull);
      expect(back.trend, isNull);
      expect(back.bodyFatPercent, isNull);
      expect(back.dailyBalances, isEmpty);
    });

    test('an unreadable summary is null rather than a crash', () {
      // A history that cannot be parsed is worth showing as absent; it is not
      // worth taking the screen down for.
      expect(WeekSummary.decode('not json'), isNull);
      expect(WeekSummary.decode('[1,2,3]'), isNull);
      expect(WeekSummary.decode(''), isNull);
      expect(WeekSummary.decode(null), isNull);
    });

    test('a summary from an older version decodes what it can', () {
      // Fields added later are simply absent; the rest still reads.
      const partial = '{"loggedDays":5,"energyBalanceKcal":-2000}';

      final back = WeekSummary.decode(partial)!;
      expect(back.loggedDays, 5);
      expect(back.energyBalanceKcal, -2000);
      expect(back.xp, 0);
      expect(back.trend, isNull);
    });

    test('an unknown trend name decodes as no trend', () {
      const odd = '{"loggedDays":5,"trend":"plummeting"}';

      expect(WeekSummary.decode(odd)!.trend, isNull);
    });
  });

  group('NarrativeFacts is the guard on the one verdict prompt', () {
    test('cannot be built from a sealed week', () {
      // The narrative is the only call permitted verdict data, and only on the
      // reveal day. Making that unwriteable rather than merely discouraged is
      // the point of this type. See CLAUDE.md §1.
      for (var offset = 0; offset < 6; offset++) {
        final sealed = _reckoningOn(_monday.addDays(offset));

        expect(sealed.isRevealed, isFalse);
        expect(
          NarrativeFacts.from(sealed, averageVitality: 70, steps: 50000),
          isNull,
          reason: 'facts were built for a sealed week',
        );
      }
    });

    test('is built from a revealed week', () {
      final revealed = _reckoningOn(_sunday);

      final facts =
          NarrativeFacts.from(revealed, averageVitality: 68, steps: 58000);

      expect(facts, isNotNull);
      expect(facts!.loggedDays, 7);
      expect(facts.energyBalanceKcal, closeTo(-4200, 0.001));
      expect(facts.trend, WeightTrend.falling);
      expect(facts.steps, 58000);
    });

    test('carries the measured delta when there is one', () {
      final facts = NarrativeFacts.from(
        _reckoningOn(_sunday, endWeight: 80.5),
        averageVitality: 68,
        steps: 58000,
      )!;

      expect(facts.weightDeltaKg, closeTo(-1.5, 0.0001));
    });

    test('a past week can still be described', () {
      // History is readable, so a week the user scrolls back to can have its
      // account written if it never got one.
      final lastWeek = reckon(
        anyDayOfWeek: _monday.addDays(-7),
        today: _monday.addDays(2),
        gate: const RevealGate(weekEndsOn: DateTime.sunday),
        days: [
          DayEnergy(
            day: _monday.addDays(-7),
            intakeKcal: 2000,
            expenditureKcal: 2200,
          ),
        ],
      );

      expect(
        NarrativeFacts.from(lastWeek, averageVitality: 50, steps: 3000),
        isNotNull,
      );
    });
  });
}
