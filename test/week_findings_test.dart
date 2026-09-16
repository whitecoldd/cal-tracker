import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/nutrition.dart';
import 'package:cal_tracker/domain/week_findings.dart';
import 'package:cal_tracker/domain/week_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

const _monday = Day(20260914);
const _sunday = Day(20260920);

const _crisps = FoodIdentity(id: 1, name: 'Crisps');
const _porridge = FoodIdentity(id: 2, name: 'Porridge');
const _noodles = FoodIdentity(id: 3, name: 'Instant noodles');
const _lager = FoodIdentity(id: 4, name: 'Lager');

const _saltyPanel = FoodPanel(
  kcal: 500,
  proteinG: 6,
  carbsG: 50,
  fatG: 30,
  satFatG: 18,
  fibreG: 1,
  sodiumMg: 2600,
  sugarG: 20,
  addedSugarG: 20,
  novaGroup: 4,
  additives: ['E621', 'E330', 'E102'],
);

const _wholePanel = FoodPanel(
  kcal: 360,
  proteinG: 25,
  carbsG: 50,
  fatG: 7,
  satFatG: 1.5,
  fibreG: 12,
  sodiumMg: 10,
  addedSugarG: 0,
  novaGroup: 1,
);

const _beerPanel = FoodPanel(
  kcal: 43,
  carbsG: 3.6,
  alcoholG: 3.9,
  novaGroup: 3,
);

LoggedPortion _eat(
  Day day,
  FoodIdentity food,
  FoodPanel panel, {
  double grams = 100,
}) =>
    LoggedPortion(
      day: day,
      food: food,
      serving: Serving(food: panel, grams: grams),
    );

WeekPattern _week(
  List<LoggedPortion> portions, {
  List<DayMovement> movement = const [],
  double? bodyMassKg,
}) =>
    readWeek(
      weekStart: _monday,
      weekEnd: _sunday,
      throughDay: _sunday,
      portions: portions,
      movement: movement,
      bodyMassKg: bodyMassKg,
    );

/// A week of nothing but salty ultra-processed food.
WeekPattern _badWeek() => _week([
      for (var i = 0; i < 7; i++)
        _eat(_monday.addDays(i), _crisps, _saltyPanel, grams: 200),
    ]);

/// A week of nothing but whole food.
WeekPattern _goodWeek() => _week(
      [
        for (var i = 0; i < 7; i++)
          _eat(_monday.addDays(i), _porridge, _wholePanel, grams: 500),
      ],
      bodyMassKg: 75,
      movement: [
        for (var i = 0; i < 7; i++)
          DayMovement(day: _monday.addDays(i), steps: 12000, waterMl: 2200),
      ],
    );

Set<FindingCode> _codes(List<Finding> findings) =>
    findings.map((f) => f.code).toSet();

void main() {
  group('an empty week says nothing', () {
    test('rather than inventing statements about an absence', () {
      expect(readFindings(_week(const [])), isEmpty);
    });
  });

  group('warnings', () {
    test('a salty week is noticed, with the guideline attached', () {
      final findings = readFindings(_badWeek());
      final salt = findings.firstWhere(
        (f) => f.code == FindingCode.saltOnMostDays,
      );

      expect(salt.tone, Tone.warning);
      expect(salt.detail, contains('of 7 logged past the guideline'));
      expect(salt.basis, isNotNull);
      expect(salt.basis, contains('2,000 mg'));
    });

    test('names what the week carried', () {
      final codes = _codes(readFindings(_badWeek()));

      expect(codes, contains(FindingCode.saltOnMostDays));
      expect(codes, contains(FindingCode.sweetRot));
      expect(codes, contains(FindingCode.thickBlood));
      expect(codes, contains(FindingCode.refinedMatter));
      expect(codes, contains(FindingCode.thinFibre));
    });

    test('alcohol is counted in units, never excused', () {
      final findings = readFindings(
        _week([
          for (var i = 0; i < 3; i++)
            _eat(_monday.addDays(i), _lager, _beerPanel, grams: 500),
        ]),
      );

      final drink = findings.firstWhere(
        (f) => f.code == FindingCode.strongDrink,
      );

      expect(drink.detail, contains('units'));
      expect(drink.basis, contains('No amount is described as beneficial'));
    });

    test('a thin week says so, because everything else rests on it', () {
      final findings = readFindings(
        _week([_eat(_monday, _porridge, _wholePanel)]),
      );

      final gaps = findings.firstWhere((f) => f.code == FindingCode.theGaps);
      expect(gaps.detail, contains('1 of 7'));
    });

    test('a week with nothing wrong produces no warnings at all', () {
      final warnings = topFindings(readFindings(_goodWeek()), Tone.warning);

      // Rather than fabricating one to fill the block.
      expect(
        warnings.where((f) => f.code != FindingCode.compositionDrift),
        isEmpty,
      );
    });
  });

  group('boons', () {
    test('a whole-food week is credited for what it held', () {
      final codes = _codes(readFindings(_goodWeek()));

      expect(codes, contains(FindingCode.cleanDays));
      expect(codes, contains(FindingCode.fibreHeld));
      expect(codes, contains(FindingCode.wholeFood));
      expect(codes, contains(FindingCode.saltRestraint));
      expect(codes, contains(FindingCode.noStrongDrink));
      expect(codes, contains(FindingCode.everyDayWritten));
      expect(codes, contains(FindingCode.groundCovered));
    });

    test('protein needs a weigh-in before it can be credited', () {
      final weighed = _codes(readFindings(_goodWeek()));
      final unweighed = _codes(
        readFindings(
          _week([
            for (var i = 0; i < 7; i++)
              _eat(_monday.addDays(i), _porridge, _wholePanel, grams: 500),
          ]),
        ),
      );

      expect(weighed, contains(FindingCode.proteinHeld));
      expect(unweighed, isNot(contains(FindingCode.proteinHeld)));
    });

    test('even a bad week is credited where it held', () {
      // The point of the per-tone cap: a week of crisps still gets its boons
      // read out, because a report that only accuses is not a report.
      final boons = topFindings(readFindings(_badWeek()), Tone.boon);

      expect(boons, isNotEmpty);
    });

    test('names the best day of the week', () {
      final findings = readFindings(
        _week([
          _eat(_monday, _porridge, _wholePanel),
          _eat(_monday.addDays(1), _crisps, _saltyPanel),
        ]),
      );

      final best = findings.firstWhere((f) => f.code == FindingCode.bestDay);
      expect(best.detail, contains('Monday'));
    });
  });

  group('ordering and the cap', () {
    test('caps each tone independently', () {
      final all = readFindings(_badWeek());

      expect(
        topFindings(all, Tone.warning),
        hasLength(lessThanOrEqualTo(maxFindingsPerTone)),
      );
      expect(
        topFindings(all, Tone.boon),
        hasLength(lessThanOrEqualTo(maxFindingsPerTone)),
      );
    });

    test('so one tone can never take every slot', () {
      final all = readFindings(_badWeek());
      final shown = [
        ...topFindings(all, Tone.warning),
        ...topFindings(all, Tone.boon),
      ];

      expect(shown.where((f) => f.tone == Tone.warning), isNotEmpty);
      expect(shown.where((f) => f.tone == Tone.boon), isNotEmpty);
      expect(shown, hasLength(lessThanOrEqualTo(maxFindingsPerTone * 2)));
    });

    test('is ordered by weight, heaviest first', () {
      final warnings = topFindings(readFindings(_badWeek()), Tone.warning);

      for (var i = 1; i < warnings.length; i++) {
        expect(
          warnings[i - 1].weight,
          greaterThanOrEqualTo(warnings[i].weight),
        );
      }
    });

    test('is stable across runs', () {
      final a = topFindings(readFindings(_badWeek()), Tone.warning)
          .map((f) => f.code)
          .toList();
      final b = topFindings(readFindings(_badWeek()), Tone.warning)
          .map((f) => f.code)
          .toList();

      expect(a, b);
    });
  });

  group('the wording rules, which are the point of §7', () {
    /// Every finding either week can produce.
    List<Finding> everything() => [
          ...readFindings(_badWeek()),
          ...readFindings(_goodWeek()),
          ...readFindings(
            _week([
              for (var i = 0; i < 3; i++)
                _eat(_monday.addDays(i), _lager, _beerPanel, grams: 500),
              _eat(_monday, _noodles, _saltyPanel),
            ]),
          ),
        ];

    test('never advises, never sets a target, never diagnoses', () {
      for (final finding in everything()) {
        final text = '${finding.title} ${finding.detail} ${finding.basis ?? ''}'
            .toLowerCase();

        for (final forbidden in const [
          'should',
          'must eat',
          'try to',
          'aim for',
          'next week',
          'healthy',
          'unhealthy',
          'good for you',
          'bad for you',
          'risk of',
          'disease',
          'diagnos',
          'you need',
        ]) {
          expect(
            text.contains(forbidden),
            isFalse,
            reason: '${finding.code.name} said "$forbidden": $text',
          );
        }
      }
    });

    test('never states a direction, which is the seal', () {
      for (final finding in everything()) {
        final text = '${finding.title} ${finding.detail}'.toLowerCase();

        for (final leak in const [
          'losing',
          'gaining',
          'deficit',
          'surplus',
          'burned',
          'expenditure',
          'tdee',
          'balance',
          'projected',
        ]) {
          expect(
            text.contains(leak),
            isFalse,
            reason: '${finding.code.name} leaked "$leak": $text',
          );
        }
      }
    });

    test('states no quantity of energy or weight, only densities', () {
      // The distinction this whole feature turns on. "14 g per 1000 kcal" and
      // "1.6 g per kg" are *densities*: they say how the food was composed and
      // contain no amount of anything. "1,850 kcal a day" is a quantity, and a
      // reader who knows their own expenditure can subtract it into a verdict
      // in their head. "81.4 kg" is the verdict outright.
      //
      // So the unit is allowed and the amount is not, and the rule is written
      // down here rather than left to whoever words the next finding.
      // The two density units the nutrition engine actually uses.
      final units = RegExp(r'per (\d[\d,]* )?(kcal|kg)');

      for (final finding in everything()) {
        final text = '${finding.title} ${finding.detail}'.toLowerCase();
        final withoutUnits = text.replaceAll(units, '');

        expect(
          withoutUnits,
          isNot(contains('kcal')),
          reason: '${finding.code.name} stated an amount of energy rather '
              'than a density: $text',
        );
        expect(
          withoutUnits,
          isNot(contains('kg')),
          reason: '${finding.code.name} stated a weight rather than a '
              'density: $text',
        );
      }
    });

    test('every warning resting on a guideline carries it', () {
      const restsOnAGuideline = {
        FindingCode.saltOnMostDays,
        FindingCode.sweetRot,
        FindingCode.thickBlood,
        FindingCode.rancidOil,
        FindingCode.strongDrink,
        FindingCode.refinedMatter,
        FindingCode.residue,
      };

      for (final finding in everything()) {
        if (!restsOnAGuideline.contains(finding.code)) continue;

        expect(
          finding.basis,
          isNotNull,
          reason: '${finding.code.name} accused without stating the figure '
              'it was measured against',
        );
        expect(finding.basis, isNotEmpty);
      }
    });

    test('no finding is empty or unlabelled', () {
      for (final finding in everything()) {
        expect(finding.title.trim(), isNotEmpty);
        expect(finding.detail.trim(), isNotEmpty);
        expect(finding.weight, inInclusiveRange(0, 1));
      }
    });
  });
}
