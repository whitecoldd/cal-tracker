import 'package:cal_tracker/domain/energy.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('basal metabolic rate (Mifflin-St Jeor)', () {
    test('matches the formula for a male reference case', () {
      // 10(80) + 6.25(180) - 5(30) + 5
      expect(
        EnergyModel.basalMetabolicRate(
          sex: Sex.male,
          weightKg: 80,
          heightCm: 180,
          ageYears: 30,
        ),
        closeTo(1780, 0.01),
      );
    });

    test('matches the formula for a female reference case', () {
      // 10(65) + 6.25(165) - 5(30) - 161
      expect(
        EnergyModel.basalMetabolicRate(
          sex: Sex.female,
          weightKg: 65,
          heightCm: 165,
          ageYears: 30,
        ),
        closeTo(1370.25, 0.01),
      );
    });

    test('unspecified sits exactly between the two constants', () {
      double bmr(Sex sex) => EnergyModel.basalMetabolicRate(
            sex: sex,
            weightKg: 70,
            heightCm: 172,
            ageYears: 35,
          );

      expect(bmr(Sex.unspecified), closeTo((bmr(Sex.male) + bmr(Sex.female)) / 2, 0.01));
    });

    test('never returns a negative rate for extreme inputs', () {
      expect(
        EnergyModel.basalMetabolicRate(
          sex: Sex.female,
          weightKg: 1,
          heightCm: 1,
          ageYears: 120,
        ),
        0,
      );
    });

    test('falls with age and rises with mass, as the formula requires', () {
      double bmr({int age = 30, double kg = 80}) =>
          EnergyModel.basalMetabolicRate(
            sex: Sex.male,
            weightKg: kg,
            heightCm: 180,
            ageYears: age,
          );

      expect(bmr(age: 50), lessThan(bmr(age: 30)));
      expect(bmr(kg: 90), greaterThan(bmr(kg: 80)));
    });
  });

  group('walking energy', () {
    test('counts only the steps the sedentary baseline does not include', () {
      // 10,000 steps at 75cm, 80kg. Billable: 7,000 steps = 5.25 km.
      // 0.5 kcal/kg/km * 80 kg * 5.25 km = 210 kcal.
      expect(
        EnergyModel.walkingEnergy(steps: 10000, strideCm: 75, weightKg: 80),
        closeTo(210, 0.01),
      );
    });

    test('a sedentary day adds nothing on top of the baseline', () {
      // This is the double-count guard: the 1.2 multiplier already contains
      // roughly 3,000 steps, so those steps must not be billed twice.
      expect(
        EnergyModel.walkingEnergy(steps: 3000, strideCm: 75, weightKg: 80),
        0,
      );
      expect(
        EnergyModel.walkingEnergy(steps: 500, strideCm: 75, weightKg: 80),
        0,
      );
    });

    test('scales with body mass and with stride', () {
      final light = EnergyModel.walkingEnergy(
        steps: 10000,
        strideCm: 75,
        weightKg: 60,
      );
      final heavy = EnergyModel.walkingEnergy(
        steps: 10000,
        strideCm: 75,
        weightKg: 90,
      );
      final longLegs = EnergyModel.walkingEnergy(
        steps: 10000,
        strideCm: 85,
        weightKg: 60,
      );

      expect(heavy, greaterThan(light));
      expect(longLegs, greaterThan(light));
    });

    test('distance is steps times stride', () {
      expect(
        EnergyModel.distanceMetres(steps: 10000, strideCm: 75),
        closeTo(7500, 0.01),
      );
    });
  });

  group('activity energy', () {
    test('prefers the platform figure over our estimate, never adds both', () {
      // Health Connect's active energy already includes walking. Summing the
      // two would bill the same steps twice and inflate the weekly verdict.
      final estimated = EnergyModel.activityEnergy(
        steps: 10000,
        strideCm: 75,
        weightKg: 80,
      );
      final reported = EnergyModel.activityEnergy(
        steps: 10000,
        strideCm: 75,
        weightKg: 80,
        reportedActiveKcal: 340,
      );

      expect(estimated, closeTo(210, 0.01));
      expect(reported, 340);
      expect(reported, isNot(closeTo(estimated + 340, 0.01)));
    });

    test('falls back to the estimate when the platform reports nothing', () {
      for (final reported in [null, 0.0]) {
        expect(
          EnergyModel.activityEnergy(
            steps: 10000,
            strideCm: 75,
            weightKg: 80,
            reportedActiveKcal: reported,
          ),
          closeTo(210, 0.01),
        );
      }
    });
  });

  group('total expenditure', () {
    test('is the sedentary baseline plus measured movement', () {
      // BMR 1780 * 1.2 = 2136, plus 210 kcal of walking.
      expect(
        EnergyModel.totalExpenditure(
          bmr: 1780,
          steps: 10000,
          strideCm: 75,
          weightKg: 80,
        ),
        closeTo(2346, 0.01),
      );
    });

    test('a day with no steps still burns the sedentary baseline', () {
      expect(
        EnergyModel.totalExpenditure(
          bmr: 1780,
          steps: 0,
          strideCm: 75,
          weightKg: 80,
        ),
        closeTo(2136, 0.01),
      );
    });

    test('the self-reported estimate is a separate path, not an addition', () {
      // Combining a lifestyle multiplier with measured steps is exactly the
      // double count this model exists to avoid, so the two never mix.
      final estimated = EnergyModel.estimatedExpenditure(
        bmr: 1780,
        level: ActivityLevel.villageWalker,
      );
      expect(estimated, closeTo(1780 * 1.375, 0.01));

      final measured = EnergyModel.totalExpenditure(
        bmr: 1780,
        steps: 10000,
        strideCm: 75,
        weightKg: 80,
      );
      expect(measured, isNot(closeTo(estimated + 210, 0.01)));
    });
  });

  group('daily target', () {
    test('applies the goal adjustment to maintenance', () {
      expect(
        EnergyModel.dailyTarget(maintenance: 2400, goal: Goal.loseFat),
        1900,
      );
      expect(
        EnergyModel.dailyTarget(maintenance: 2400, goal: Goal.maintain),
        2400,
      );
      expect(
        EnergyModel.dailyTarget(maintenance: 2400, goal: Goal.gainMuscle),
        2650,
      );
    });

    test('never recommends below 1200 kcal, however small the person', () {
      // An aggressive deficit on a small maintenance would otherwise send the
      // arithmetic somewhere no app should send anyone.
      expect(
        EnergyModel.dailyTarget(maintenance: 1400, goal: Goal.loseFat),
        1200,
      );
    });

    test('the surplus is smaller than the deficit, deliberately', () {
      expect(
        Goal.gainMuscle.dailyKcalAdjustment.abs(),
        lessThan(Goal.loseFat.dailyKcalAdjustment.abs()),
      );
    });
  });

  group('derived figures', () {
    test('stride is about 0.414 of height', () {
      expect(EnergyModel.strideFromHeight(180), closeTo(74.52, 0.01));
      expect(EnergyModel.strideFromHeight(160), closeTo(66.24, 0.01));
    });

    test('age is read through package:clock', () {
      withClock(Clock.fixed(DateTime(2026, 9, 14)), () {
        expect(EnergyModel.ageFromBirthYear(1995), 31);
      });
      withClock(Clock.fixed(DateTime(2027, 1, 1)), () {
        expect(EnergyModel.ageFromBirthYear(1995), 32);
      });
    });

    test('bmi is mass over height squared, and safe at zero height', () {
      expect(EnergyModel.bmi(weightKg: 80, heightCm: 180), closeTo(24.69, 0.01));
      expect(EnergyModel.bmi(weightKg: 80, heightCm: 0), 0);
    });
  });

  group('activity levels', () {
    test('multipliers increase monotonically', () {
      final values = ActivityLevel.values.map((l) => l.multiplier).toList();
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    });

    test('the lowest level matches the sedentary baseline', () {
      // Otherwise a user on the lowest setting would get a different answer
      // depending on whether their steps happened to sync.
      expect(
        ActivityLevel.hearthbound.multiplier,
        EnergyModel.sedentaryMultiplier,
      );
    });

    test('every level has a plain-language blurb, not just a lore name', () {
      for (final level in ActivityLevel.values) {
        expect(level.blurb.trim(), isNotEmpty, reason: level.name);
        expect(level.title.trim(), isNotEmpty, reason: level.name);
      }
    });
  });
}
