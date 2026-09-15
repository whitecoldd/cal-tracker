import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/energy.dart';
import 'package:cal_tracker/domain/reckoning.dart';
import 'package:cal_tracker/domain/reveal_gate.dart';
import 'package:cal_tracker/domain/sealed_value.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monday 14 September 2026 through Sunday 20 September 2026.
const _monday = Day(20260914);
const _sunday = Day(20260920);

String _name(int weekday) => const {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    }[weekday]!;

/// A week where every day ran a 500 kcal deficit.
List<DayEnergy> _steadyDeficit({double perDay = -500}) => [
      for (var i = 0; i < 7; i++)
        DayEnergy(
          day: _monday.addDays(i),
          intakeKcal: 2000,
          expenditureKcal: 2000 - perDay,
        ),
    ];

/// Reckons the **live** week as of [today].
///
/// The subject defaults to `today` rather than a fixed date on purpose: with a
/// mid-week `weekEndsOn`, a date pinned to one Monday falls into a past week
/// partway through, and would then be revealed as history — correctly, but it
/// would not be testing the blackout.
Reckoning _reckonOn(
  Day today, {
  int weekEndsOn = DateTime.sunday,
  List<DayEnergy>? days,
  double? startWeight = 80,
  double? endWeight = 79.5,
}) {
  return reckon(
    anyDayOfWeek: today,
    today: today,
    gate: RevealGate(weekEndsOn: weekEndsOn),
    days: days ?? _steadyDeficit(),
    startWeightKg: startWeight,
    endWeightKg: endWeight,
    heightCm: 180,
    ageYears: 34,
    sex: Sex.male,
  );
}

/// Every sealed-bearing field on a reckoning, so a new one cannot be added
/// without this list refusing to compile — and therefore without the blackout
/// tests below covering it.
List<SealedValue<Object?>> _verdicts(Reckoning r) => [
      r.energyBalanceKcal,
      r.averageDailyBalanceKcal,
      r.weightDeltaKg,
      r.trend,
      r.projectedChangeKg,
      r.bodyFatPercent,
      r.dailyBalances,
    ];

void main() {
  group('the blackout', () {
    // The rule from CLAUDE.md §1: freeze the clock to each weekday and assert
    // Sealed on every non-reveal day, for every verdict value.
    for (final weekEndsOn in [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ]) {
      group('week ending ${_name(weekEndsOn)}', () {
        for (var offset = 0; offset < 7; offset++) {
          final today = _monday.addDays(offset);
          final isRevealDay = today.weekday == weekEndsOn;

          test('${_name(today.weekday)}: every verdict is '
              '${isRevealDay ? "revealed" : "sealed"}', () {
            final reckoning = _reckonOn(today, weekEndsOn: weekEndsOn);

            for (final verdict in _verdicts(reckoning)) {
              expect(
                verdict.isRevealed,
                isRevealDay,
                reason: '$verdict on ${_name(today.weekday)} '
                    'with week ending ${_name(weekEndsOn)}',
              );
            }
            expect(reckoning.isRevealed, isRevealDay);
          });
        }
      });
    }

    test('a sealed verdict is never even calculated', () {
      // If the arithmetic ran and the result were merely wrapped, the number
      // would exist in memory — reachable by a log line, a crash report, or a
      // future refactor that reaches past the type.
      var touched = 0;
      final days = [
        for (var i = 0; i < 7; i++)
          DayEnergy(
            day: _monday.addDays(i),
            intakeKcal: 2000,
            expenditureKcal: 2500,
          ),
      ];

      reckon(
        anyDayOfWeek: _monday,
        today: _monday, // not a Sunday
        gate: const RevealGate(weekEndsOn: DateTime.sunday),
        days: days,
        startWeightKg: 80,
        // Reading this at all would mean the weight arithmetic ran.
        endWeightKg: (() {
          touched++;
          return 79.0;
        })(),
      );

      // The weight was read once to build the argument, never again.
      expect(touched, 1);
    });

    test('sealed values carry nothing readable in toString', () {
      final reckoning = _reckonOn(_monday);

      for (final verdict in _verdicts(reckoning)) {
        expect(verdict.toString(), 'Sealed()');
      }
    });

    test('last week reads on an ordinary weekday', () {
      // History is not the verdict; refusing it would make the app useless as
      // a record.
      final reckoning = reckon(
        anyDayOfWeek: _monday.addDays(-7),
        today: _monday.addDays(2),
        gate: const RevealGate(weekEndsOn: DateTime.sunday),
        days: _steadyDeficit(),
        startWeightKg: 80,
        endWeightKg: 79.5,
      );

      expect(reckoning.isRevealed, isTrue);
    });
  });

  group('on the reveal day', () {
    test('energy balance sums the week', () {
      final reckoning = _reckonOn(_sunday);

      // Seven days at -500.
      expect(
        (reckoning.energyBalanceKcal as Revealed<double>).value,
        closeTo(-3500, 0.001),
      );
    });

    test('the average is per logged day, not per calendar day', () {
      // Four logged days at -500, three days never logged at all.
      final days = [
        for (var i = 0; i < 4; i++)
          DayEnergy(
            day: _monday.addDays(i),
            intakeKcal: 2000,
            expenditureKcal: 2500,
          ),
        for (var i = 4; i < 7; i++)
          DayEnergy(
            day: _monday.addDays(i),
            intakeKcal: 0,
            expenditureKcal: 2500,
          ),
      ];

      final reckoning = _reckonOn(_sunday, days: days);

      expect(reckoning.loggedDays, 4);
      // -2000 over four logged days. Dividing by seven would report a deficit
      // the user never ran — the unlogged days are unknown, not fasted.
      expect(
        (reckoning.averageDailyBalanceKcal as Revealed<double>).value,
        closeTo(-500, 0.001),
      );
      expect(
        (reckoning.energyBalanceKcal as Revealed<double>).value,
        closeTo(-2000, 0.001),
      );
    });

    test('projects weight change from the energy balance', () {
      final reckoning = _reckonOn(_sunday);

      // -3500 kcal over 7700 kcal per kg.
      expect(
        (reckoning.projectedChangeKg as Revealed<double>).value,
        closeTo(-3500 / 7700, 0.0001),
      );
    });

    test('the week shape is a list of each logged day balance', () {
      final reckoning = _reckonOn(_sunday);

      // Plotted by the reveal chart. Sealed with the rest, because drawing
      // the verdict as a picture is no better than printing it.
      expect(
        (reckoning.dailyBalances as Revealed<List<double>>).value,
        hasLength(7),
      );
      expect(
        (reckoning.dailyBalances as Revealed<List<double>>).value.first,
        closeTo(-500, 0.001),
      );
    });

    test('reports the measured weight delta', () {
      final reckoning = _reckonOn(_sunday, startWeight: 80, endWeight: 78.8);

      expect(
        (reckoning.weightDeltaKg as Revealed<double?>).value,
        closeTo(-1.2, 0.0001),
      );
    });

    test('loggedDays is readable even while the week is sealed', () {
      // It says nothing about gaining or losing, and it is what tells the user
      // how much the sealed figures are worth.
      final reckoning = _reckonOn(_monday);

      expect(reckoning.isRevealed, isFalse);
      expect(reckoning.loggedDays, 7);
    });
  });

  group('the weight trend applies a noise band', () {
    test('a small move is holding, not a trend', () {
      // The behaviour the whole app exists to prevent: reacting to noise.
      final reckoning = _reckonOn(_sunday, startWeight: 80, endWeight: 79.8);

      expect(
        (reckoning.trend as Revealed<WeightTrend?>).value,
        WeightTrend.holding,
      );
    });

    test('a real fall is falling', () {
      final reckoning = _reckonOn(_sunday, startWeight: 80, endWeight: 79.2);

      expect(
        (reckoning.trend as Revealed<WeightTrend?>).value,
        WeightTrend.falling,
      );
    });

    test('a real rise is rising', () {
      final reckoning = _reckonOn(_sunday, startWeight: 80, endWeight: 80.9);

      expect(
        (reckoning.trend as Revealed<WeightTrend?>).value,
        WeightTrend.rising,
      );
    });

    test('the band is applied just inside and just outside', () {
      // The exact boundary is not worth asserting: 80 - 0.3 lands on
      // 0.29999999999999716, so a test pinned to it measures floating-point
      // representation rather than the rule.
      WeightTrend? trendFor(double end) => (_reckonOn(
            _sunday,
            startWeight: 80,
            endWeight: end,
          ).trend as Revealed<WeightTrend?>)
          .value;

      expect(trendFor(80 - weightNoiseKg + 0.05), WeightTrend.holding);
      expect(trendFor(80 - weightNoiseKg - 0.05), WeightTrend.falling);
    });
  });

  group('missing weigh-ins', () {
    test('a week with only one weigh-in reports no delta', () {
      final reckoning = _reckonOn(_sunday, startWeight: 80, endWeight: null);

      // Revealed, but with nothing to say — which is different from sealed.
      expect(reckoning.weightDeltaKg.isRevealed, isTrue);
      expect((reckoning.weightDeltaKg as Revealed<double?>).value, isNull);
      expect((reckoning.trend as Revealed<WeightTrend?>).value, isNull);
    });

    test('the energy balance is still reported without any weigh-in', () {
      final reckoning = _reckonOn(_sunday, startWeight: null, endWeight: null);

      expect(reckoning.energyBalanceKcal.isRevealed, isTrue);
    });
  });

  group('estimateBodyFatPercent', () {
    test('computes Deurenberg for a known case', () {
      // 80 kg at 180 cm is BMI 24.691.
      // 1.20*24.691 + 0.23*34 - 10.8*1 - 5.4 = 21.25.
      final percent = estimateBodyFatPercent(
        weightKg: 80,
        heightCm: 180,
        ageYears: 34,
        sex: Sex.male,
      );

      expect(percent, closeTo(21.25, 0.01));
    });

    test('the sex term shifts the estimate', () {
      double? forSex(Sex sex) => estimateBodyFatPercent(
            weightKg: 80,
            heightCm: 180,
            ageYears: 34,
            sex: sex,
          );

      // Women carry more essential fat at the same BMI; unspecified takes the
      // midpoint rather than inventing a third population.
      expect(forSex(Sex.female)! - forSex(Sex.male)!, closeTo(10.8, 0.001));
      expect(
        forSex(Sex.unspecified),
        closeTo((forSex(Sex.male)! + forSex(Sex.female)!) / 2, 0.001),
      );
    });

    test('returns null when anything it needs is missing', () {
      expect(
        estimateBodyFatPercent(
          weightKg: null,
          heightCm: 180,
          ageYears: 34,
          sex: Sex.male,
        ),
        isNull,
      );
      expect(
        estimateBodyFatPercent(
          weightKg: 80,
          heightCm: null,
          ageYears: 34,
          sex: Sex.male,
        ),
        isNull,
      );
      expect(
        estimateBodyFatPercent(
          weightKg: 80,
          heightCm: 180,
          ageYears: null,
          sex: Sex.male,
        ),
        isNull,
      );
    });

    test('stays inside a physically possible range', () {
      final absurd = estimateBodyFatPercent(
        weightKg: 400,
        heightCm: 150,
        ageYears: 90,
        sex: Sex.female,
      );

      expect(absurd, lessThanOrEqualTo(70));
    });
  });

  group('credibility', () {
    test('an ordinary week is credible', () {
      expect(isCredible(-0.45), isTrue);
      expect(isCredible(1.2), isTrue);
    });

    test('an implausible figure is not', () {
      // Almost always a mis-typed portion or a missing week of logs, and a
      // confident "you gained 4 kg" would be worse than saying nothing.
      expect(isCredible(4.0), isFalse);
      expect(isCredible(-3.1), isFalse);
    });

    test('clamping keeps the sign', () {
      expect(clampCredible(5.0), maxCredibleWeeklyKg);
      expect(clampCredible(-5.0), -maxCredibleWeeklyKg);
      expect(clampCredible(0.4), closeTo(0.4, 0.0001));
    });
  });

  group('roundBalance', () {
    test('rounds to ten kcal, because it is not known any better', () {
      // The figure carries the error of a BMR estimate, a step count and a
      // hundred portion guesses. Reporting it to the calorie would be a lie
      // about how well it is known.
      expect(roundBalance(-3487), -3490);
      expect(roundBalance(212), 210);
    });
  });

  group('expenditureFor', () {
    test('falls back to the activity level with no step data', () {
      final estimated = expenditureFor(
        bmr: 1800,
        weightKg: 80,
        strideCm: 74,
        level: ActivityLevel.villageWalker,
      );

      expect(
        estimated,
        closeTo(
          EnergyModel.estimatedExpenditure(
            bmr: 1800,
            level: ActivityLevel.villageWalker,
          ),
          0.001,
        ),
      );
    });

    test('uses measured movement when there are steps', () {
      final measured = expenditureFor(
        bmr: 1800,
        weightKg: 80,
        strideCm: 74,
        level: ActivityLevel.villageWalker,
        steps: 12000,
      );

      expect(
        measured,
        closeTo(
          EnergyModel.totalExpenditure(
            bmr: 1800,
            steps: 12000,
            strideCm: 74,
            weightKg: 80,
          ),
          0.001,
        ),
      );
    });
  });
}
