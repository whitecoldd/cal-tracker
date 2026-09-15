import 'package:cal_tracker/domain/activity.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:flutter_test/flutter_test.dart';

const _today = Day(20260915);

void main() {
  group('Stamina', () {
    test('is the share of the step goal reached', () {
      expect(staminaFor(steps: 5000, stepGoal: 10000), 50);
      expect(staminaFor(steps: 10000, stepGoal: 10000), 100);
    });

    test('does not exceed 100 on a long walk', () {
      expect(staminaFor(steps: 40000, stepGoal: 10000), 100);
    });

    test('a day with no steps is zero, not an error', () {
      expect(staminaFor(steps: 0, stepGoal: 10000), 0);
    });

    test('a nonsensical goal does not divide by zero', () {
      expect(staminaFor(steps: 5000, stepGoal: 0), 0);
      expect(staminaFor(steps: 5000, stepGoal: -1), 0);
    });

    test('compares steps against the user own goal, not expenditure', () {
      // The reason Stamina is on the always-visible side of CLAUDE.md §1: a
      // step goal is set in character creation and has nothing to do with
      // energy balance, so no arrangement of this can be solved into a
      // deficit.
      final same = staminaFor(steps: 8000, stepGoal: 10000);
      expect(same, 80);
      // Changing nothing but the goal changes the figure, which is exactly
      // what an expenditure-derived number would *not* do.
      expect(staminaFor(steps: 8000, stepGoal: 8000), 100);
    });
  });

  group('the Aard charge', () {
    test('rises with movement', () {
      final still = aardCharge(steps: 0, distanceM: 0, stepGoal: 10000);
      final walked = aardCharge(steps: 6000, distanceM: 4200, stepGoal: 10000);
      final marched =
          aardCharge(steps: 14000, distanceM: 10000, stepGoal: 10000);

      expect(still, 0);
      expect(walked, greaterThan(still));
      expect(marched, greaterThan(walked));
    });

    test('is bounded at one', () {
      expect(
        aardCharge(steps: 99000, distanceM: 90000, stepGoal: 10000),
        1.0,
      );
    });

    test('leans on steps rather than distance', () {
      // Distance is derived from stride on most days, so weighting the two
      // equally would count the same number twice.
      final stepsOnly =
          aardCharge(steps: 10000, distanceM: 0, stepGoal: 10000);
      final distanceOnly =
          aardCharge(steps: 0, distanceM: 7000, stepGoal: 10000);

      expect(stepsOnly, greaterThan(distanceOnly));
    });

    test('a nonsensical goal does not divide by zero', () {
      expect(aardCharge(steps: 5000, distanceM: 3000, stepGoal: 0), 0);
    });
  });

  group('ActivityView', () {
    test('carries no energy figure at all', () {
      // The enforcement, stated as a test: expenditure is a term of the
      // verdict, and a widget cannot render what it was never handed. If a
      // kcal field is ever added to ActivityView, this is where it should be
      // argued about. See CLAUDE.md §1.
      const view = ActivityView(
        steps: 8000,
        distanceM: 5600,
        stepGoal: 10000,
        stamina: 80,
      );

      final surface = view.toString().toLowerCase();
      for (final banned in const ['kcal', 'energy', 'burn', 'calorie']) {
        expect(surface.contains(banned), isFalse, reason: 'leaked "$banned"');
      }
    });

    test('drops the energy figure when built from a stored day', () {
      const stored = DayActivity(
        day: _today,
        steps: 8000,
        distanceM: 5600,
        activeKcal: 420,
      );

      final view = ActivityView.of(stored, stepGoal: 10000);

      expect(view.steps, 8000);
      expect(view.stamina, 80);
      // The kcal simply has nowhere to go.
      expect(view.toString(), isNot(contains('420')));
    });

    test('goal progress never overflows its bar', () {
      const over = ActivityView(
        steps: 25000,
        distanceM: 0,
        stepGoal: 10000,
        stamina: 100,
      );

      expect(over.goalFraction, 1.0);
      expect(over.metGoal, isTrue);
    });

    test('reports distance in kilometres for display', () {
      const view = ActivityView(
        steps: 8000,
        distanceM: 5600,
        stepGoal: 10000,
        stamina: 80,
      );

      expect(view.distanceKm, closeTo(5.6, 0.001));
    });
  });

  group('mergeActivity', () {
    const measured = DayActivity(day: _today, steps: 9000, distanceM: 6300);

    test('takes the measured day when nothing is stored', () {
      expect(
        mergeActivity(existing: null, measured: measured).steps,
        9000,
      );
    });

    test('overwrites an earlier measured day', () {
      // Health Connect back-fills, so a later read of the same day is usually
      // more complete rather than in conflict.
      const earlier = DayActivity(day: _today, steps: 4000);

      expect(
        mergeActivity(existing: earlier, measured: measured).steps,
        9000,
      );
    });

    test('never overwrites what the user typed', () {
      // They typed it precisely because the device was wrong. A sync that
      // replaced it would make the override pointless.
      const typed = DayActivity(day: _today, steps: 12000, isManual: true);

      final merged = mergeActivity(existing: typed, measured: measured);

      expect(merged.steps, 12000);
      expect(merged.isManual, isTrue);
    });
  });

  group('distanceForSteps', () {
    test('derives metres from stride', () {
      // 10,000 steps at a 74 cm stride is 7.4 km.
      expect(
        distanceForSteps(steps: 10000, strideCm: 74),
        closeTo(7400, 0.001),
      );
    });
  });

  group('activeDaysIn', () {
    test('counts only days with movement recorded', () {
      final days = [
        const DayActivity(day: Day(20260914), steps: 8000),
        const DayActivity(day: Day(20260915)),
        const DayActivity(day: Day(20260916), distanceM: 2000),
      ];

      expect(activeDaysIn(days), 2);
    });

    test('is capped by the window', () {
      final days = [
        for (var i = 0; i < 30; i++)
          DayActivity(day: const Day(20260901).addDays(i), steps: 5000),
      ];

      expect(activeDaysIn(days, window: 7), 7);
    });
  });

  group('DayActivity', () {
    test('knows whether anything was recorded', () {
      expect(const DayActivity(day: _today).hasMovement, isFalse);
      expect(const DayActivity(day: _today, steps: 1).hasMovement, isTrue);
      expect(
        const DayActivity(day: _today, distanceM: 10).hasMovement,
        isTrue,
      );
    });
  });
}
