import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/energy.dart';
import 'package:cal_tracker/domain/nutrition.dart';
import 'package:cal_tracker/domain/reckoning.dart';
import 'package:cal_tracker/domain/reveal_gate.dart';
import 'package:cal_tracker/domain/week_findings.dart';
import 'package:cal_tracker/domain/week_pattern.dart';
import 'package:cal_tracker/domain/week_summary.dart';
import 'package:cal_tracker/domain/weekly_tale.dart';
import 'package:flutter_test/flutter_test.dart';

const _monday = Day(20260914);
const _sunday = Day(20260920);

const _crisps = FoodIdentity(id: 1, name: 'Crisps');
const _porridge = FoodIdentity(id: 2, name: 'Porridge');

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

LoggedPortion _eat(Day day, FoodIdentity food, FoodPanel panel) =>
    LoggedPortion(
      day: day,
      food: food,
      serving: Serving(food: panel, grams: 200),
    );

WeekPattern _week(List<LoggedPortion> portions) => readWeek(
      weekStart: _monday,
      weekEnd: _sunday,
      throughDay: _sunday,
      portions: portions,
    );

WeekPattern _fullWeek() => _week([
      for (var i = 0; i < 4; i++) _eat(_monday.addDays(i), _crisps, _saltyPanel),
      for (var i = 4; i < 7; i++)
        _eat(_monday.addDays(i), _porridge, _wholePanel),
    ]);

/// A revealed reckoning, so [NarrativeFacts] can actually be built.
Reckoning _revealed() => reckon(
      anyDayOfWeek: _sunday,
      today: _sunday,
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
      endWeightKg: 81.1,
      heightCm: 180,
      ageYears: 34,
      sex: Sex.male,
    );

NarrativeFacts _facts() => NarrativeFacts.from(
      _revealed(),
      averageVitality: 61,
      steps: 54000,
      pattern: _fullWeek(),
      findings: readFindings(_fullWeek()),
    )!;

String _body(List<TaleSection> sections) =>
    sections.map((s) => '${s.title} ${s.body}').join(' ').toLowerCase();

void main() {
  group('tellPattern', () {
    test('gives an account with no verdict in it', () {
      final pattern = _fullWeek();
      final sections = tellPattern(pattern, readFindings(pattern));

      expect(sections, isNotEmpty);
      expect(sections.first.title, TaleTitles.opening);
      expect(
        sections.map((s) => s.title),
        containsAll([TaleTitles.opening, TaleTitles.table]),
      );
    });

    test('names the additives it found', () {
      final pattern = _fullWeek();
      final text = _body(tellPattern(pattern, readFindings(pattern)));

      expect(text, contains('distinct additives'));
      expect(text, anyOf(contains('e621'), contains('e330'), contains('e102')));
    });

    test('says both what the week carried and what it held', () {
      final pattern = _fullWeek();
      final titles =
          tellPattern(pattern, readFindings(pattern)).map((s) => s.title);

      expect(titles, contains(TaleTitles.curses));
      expect(titles, contains(TaleTitles.boons));
    });

    test('a week with nothing written down says so, and stops', () {
      final sections = tellPattern(_week(const []), const []);

      expect(sections, hasLength(1));
      expect(sections.single.body, contains('Nothing was written down'));
    });

    test('never states a quantity of energy, a weight or a direction', () {
      // The Tale is rendered mid-week, so this is the same rule the screen is
      // held to. A density unit is allowed; an amount is not — see
      // week_findings_test.dart for why the two are not the same thing.
      final pattern = _fullWeek();
      final text = _body(tellPattern(pattern, readFindings(pattern)));
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
        'balance',
        'projected',
        'falling',
        'rising',
      ]) {
        expect(
          withoutUnits.contains(leak),
          isFalse,
          reason: 'the pattern half of The Tale leaked "$leak": $text',
        );
      }
    });
  });

  group('tellVerdict', () {
    test('is the one passage allowed to say which way it went', () {
      final section = tellVerdict(_facts());

      expect(section.title, TaleTitles.reckoning);
      expect(section.body, contains('kcal'));
      expect(section.body.toLowerCase(), contains('falling'));
    });

    test('says plainly when there were not enough weigh-ins', () {
      final thin = NarrativeFacts.from(
        reckon(
          anyDayOfWeek: _sunday,
          today: _sunday,
          gate: const RevealGate(weekEndsOn: DateTime.sunday),
          days: const [
            DayEnergy(day: _monday, intakeKcal: 1800, expenditureKcal: 2400),
          ],
        ),
        averageVitality: 50,
        steps: 1000,
        pattern: _fullWeek(),
        findings: const [],
      )!;

      expect(tellVerdict(thin).body, contains('not enough weigh-ins'));
    });

    test('cannot be reached for a week that has not closed', () {
      // The guard is NarrativeFacts itself, and this is what enforces it: on
      // any day but the reveal there is no value to pass to tellVerdict.
      for (var offset = 0; offset < 6; offset++) {
        final today = _monday.addDays(offset);
        final facts = NarrativeFacts.from(
          reckon(
            anyDayOfWeek: today,
            today: today,
            gate: const RevealGate(weekEndsOn: DateTime.sunday),
            days: const [],
          ),
          averageVitality: 50,
          steps: 0,
          pattern: _week(const []),
          findings: const [],
        );

        expect(
          facts,
          isNull,
          reason: 'a verdict passage was constructible on a sealed day',
        );
      }
    });
  });

  group('tellWeek', () {
    test('is marked as the app\'s own account, not as written prose', () {
      final pattern = _fullWeek();
      final tale = tellWeek(pattern, readFindings(pattern));

      expect(tale.source, TaleSource.told);
      expect(tale.source.provenance, contains('No model was asked'));
    });

    test('adds the verdict passage only when the facts exist', () {
      final pattern = _fullWeek();
      final findings = readFindings(pattern);

      final sealed = tellWeek(pattern, findings);
      final open = tellWeek(pattern, findings, facts: _facts());

      expect(
        sealed.sections.map((s) => s.title),
        isNot(contains(TaleTitles.reckoning)),
      );
      expect(
        open.sections.map((s) => s.title),
        contains(TaleTitles.reckoning),
      );
    });
  });

  group('decode', () {
    test('reads the structured account this version writes', () {
      const tale = WeeklyTale(
        sections: [
          TaleSection(title: 'The opening', body: 'A hard week.'),
          TaleSection(title: 'The table', body: 'Bread and salt.'),
        ],
        source: TaleSource.told,
      );

      final read = WeeklyTale.decode(WeeklyTale.encode(tale))!;

      expect(read.sections, hasLength(2));
      expect(read.sections.first.body, 'A hard week.');
      // Anything that was stored was written at the seal.
      expect(read.source, TaleSource.written);
    });

    test('reads a 1.0.x plain paragraph as one section', () {
      // Every week sealed before this version holds a bare string. It must
      // still render, which is why the richer account needs no migration.
      final read = WeeklyTale.decode(
        'The week passed as weeks do, without much to mark it.',
      )!;

      expect(read.sections, hasLength(1));
      expect(read.sections.single.body, startsWith('The week passed'));
      expect(read.source, TaleSource.written);
    });

    test('an unreadable account is worth nothing, not a crash', () {
      expect(WeeklyTale.decode(null), isNull);
      expect(WeeklyTale.decode(''), isNull);
      expect(WeeklyTale.decode('   '), isNull);
    });

    test('malformed JSON falls back to showing it as prose', () {
      // A stored account is worth showing imperfectly rather than discarding.
      final read = WeeklyTale.decode('{not really json');

      expect(read, isNotNull);
      expect(read!.sections, hasLength(1));
    });

    test('drops empty sections rather than rendering blank panels', () {
      final read = WeeklyTale.decode(
        '{"sections":[{"title":"A","body":"kept"},{"title":"B","body":"  "}]}',
      )!;

      expect(read.sections, hasLength(1));
      expect(read.sections.single.body, 'kept');
    });
  });
}
