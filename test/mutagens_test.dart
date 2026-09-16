import 'package:cal_tracker/domain/mutagens.dart';
import 'package:cal_tracker/domain/reckoning.dart';
import 'package:cal_tracker/domain/week_summary.dart';
import 'package:flutter_test/flutter_test.dart';

WeekSummary _week({
  int loggedDays = 7,
  double vitality = 75,
  double toxicity = 20,
  int goalDays = 5,
  double? weightDelta,
  WeightTrend? trend,
  double balance = -4200,
}) {
  return WeekSummary(
    loggedDays: loggedDays,
    energyBalanceKcal: balance,
    averageDailyBalanceKcal: balance / 7,
    projectedChangeKg: balance / 7700,
    averageVitality: vitality,
    averageToxicity: toxicity,
    steps: 58000,
    goalDays: goalDays,
    xp: 145,
    weightDeltaKg: weightDelta,
    trend: trend,
  );
}

void main() {
  group('a perk is never paid for the scale', () {
    test('the same behaviour earns the same mutagens whatever the weight did',
        () {
      // The rule this whole file is arranged around. A perk that depended on
      // the verdict would *be* the verdict — it would appear on the character
      // sheet the following Monday and answer the question the app exists to
      // defer. See CLAUDE.md §1.
      final lost = _week(weightDelta: -1.4, trend: WeightTrend.falling);
      final held = _week(weightDelta: 0.0, trend: WeightTrend.holding);
      final gained = _week(weightDelta: 1.4, trend: WeightTrend.rising);

      expect(earnedBy(lost), earnedBy(held));
      expect(earnedBy(held), earnedBy(gained));
    });

    test('an enormous surplus earns the same as an enormous deficit', () {
      final deficit = _week(balance: -9000);
      final surplus = _week(balance: 9000);

      expect(earnedBy(deficit), earnedBy(surplus));
    });
  });

  group('what each mutagen asks for', () {
    test('Green Blood wants the whole week written down', () {
      expect(earnedBy(_week(loggedDays: 7)), contains(Mutagen.greenBlood));
      expect(
        earnedBy(_week(loggedDays: 6)),
        isNot(contains(Mutagen.greenBlood)),
      );
    });

    test('Red Vitriol wants the week eaten well', () {
      expect(earnedBy(_week(vitality: 70)), contains(Mutagen.redVitriol));
      expect(
        earnedBy(_week(vitality: 69)),
        isNot(contains(Mutagen.redVitriol)),
      );
    });

    test('Blue Essence wants miles under the boots', () {
      expect(earnedBy(_week(goalDays: 5)), contains(Mutagen.blueEssence));
      expect(
        earnedBy(_week(goalDays: 4)),
        isNot(contains(Mutagen.blueEssence)),
      );
    });

    test('White Honey wants a week out of the packet', () {
      expect(earnedBy(_week(toxicity: 25)), contains(Mutagen.whiteHoney));
      expect(
        earnedBy(_week(toxicity: 26)),
        isNot(contains(Mutagen.whiteHoney)),
      );
    });

    test('a perfect week earns all four', () {
      final all = earnedBy(
        _week(loggedDays: 7, vitality: 90, goalDays: 7, toxicity: 5),
      );

      expect(all, hasLength(Mutagen.values.length));
    });
  });

  group('an empty week', () {
    test('earns nothing, rather than passing every restraint test', () {
      // The trap. A week with nothing logged has no toxicity at all, so
      // White Honey would pass on an absence of evidence — the same shape as
      // the Vitality trap in T6.
      final nothing = _week(
        loggedDays: 0,
        vitality: 0,
        goalDays: 0,
        toxicity: 0,
      );

      expect(earnedBy(nothing), isEmpty);
    });
  });

  group('the bonus they add up to', () {
    test('nothing earned is no bonus at all', () {
      expect(bonusOf(const []).isEmpty, isTrue);
      expect(MutagenBonus.none.experience, 0);
    });

    test('experience mutagens stack', () {
      final bonus = bonusOf([Mutagen.greenBlood, Mutagen.redVitriol]);

      expect(bonus.experience, closeTo(0.20, 0.0001));
    });

    test('each effect accumulates on its own track', () {
      final bonus = bonusOf(Mutagen.values);

      expect(bonus.experience, greaterThan(0));
      expect(bonus.adrenaline, greaterThan(0));
      expect(bonus.purge, greaterThan(0));
    });

    test('stacking is capped', () {
      // A long run of good weeks must not compound into a figure that makes
      // the earlier ones look worthless.
      final many = bonusOf([
        for (var i = 0; i < 20; i++) Mutagen.greenBlood,
      ]);

      expect(many.experience, maxStackedBonus);
    });
  });

  group('identity', () {
    test('every mutagen has a stable code and readable strings', () {
      final codes = <String>{};

      for (final mutagen in Mutagen.values) {
        expect(mutagen.code, isNotEmpty);
        expect(mutagen.title, isNotEmpty);
        expect(mutagen.lore, isNotEmpty);
        expect(mutagen.magnitude, greaterThan(0));
        expect(codes.add(mutagen.code), isTrue, reason: 'duplicate code');
      }
    });

    test('a code round-trips', () {
      for (final mutagen in Mutagen.values) {
        expect(Mutagen.byCode(mutagen.code), mutagen);
      }
      expect(Mutagen.byCode('not_a_mutagen'), isNull);
    });
  });

  group('re-running on an archived week', () {
    test('always gives the same answer', () {
      // Decided from the frozen summary, so a perk cannot change its mind
      // about a week the user has already been shown.
      final summary = _week();
      final stored = WeekSummary.decode(WeekSummary.encode(summary))!;

      expect(earnedBy(stored), earnedBy(summary));
    });
  });
}
