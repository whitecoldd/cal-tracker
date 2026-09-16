import 'package:cal_tracker/data/ai/prompts.dart';
import 'package:cal_tracker/domain/nutrition.dart';
import 'package:cal_tracker/domain/portion.dart';
import 'package:cal_tracker/domain/reckoning.dart';
import 'package:cal_tracker/domain/reveal_gate.dart';
import 'package:cal_tracker/domain/week_findings.dart';
import 'package:cal_tracker/domain/week_pattern.dart';
import 'package:cal_tracker/domain/week_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/week_fixtures.dart';

/// Every prompt a daily interaction can send.
///
/// The weekly narrative is deliberately absent: it is the one call permitted
/// verdict data, and it runs only on the reveal day.
List<String> _dailyPrompts() => [
      Prompts.mealParsingSystem(),
      Prompts.mealParsingUser('two eggs and a slice of rye'),
      Prompts.portionSystem(),
      Prompts.portionUser(
        foodName: 'Almonds',
        quantity: 1,
        unit: PortionUnit.handful,
        gramsPerPiece: 1.2,
        pieceName: 'almond',
      ),
      Prompts.photoSystem(),
      Prompts.photoUser(null),
      Prompts.photoUser('the sauce is tahini'),
      Prompts.labelSystem(),
      Prompts.labelUser(),
      Prompts.labelUser(barcode: '4840811001867'),
    ];

void main() {
  group('reading a label', () {
    test('is told to transcribe rather than to recall', () {
      // The failure that matters here is not a refusal but a plausible
      // invention: a model that half-reads a blurred panel and fills the rest
      // in from what that product usually contains produces a row the user
      // will never think to doubt.
      final system = Prompts.labelSystem().toLowerCase();

      expect(system, contains('transcribe'));
      expect(system, contains('do not recall'));
      expect(system, contains('readable to false'));
    });

    test('carries the house rules like every other prompt', () {
      // The "never diagnose" clause lives in the shared preamble precisely so
      // a fifth use cannot be added without it. This is the test that says so.
      expect(Prompts.labelSystem(), contains('Never diagnose'));
    });

    test('passes a barcode as identification, never as a question', () {
      final user = Prompts.labelUser(barcode: '4840811001867');

      expect(user, contains('4840811001867'));
      // Asking the model what the code is would invite exactly the recall the
      // system prompt spends its length forbidding.
      expect(user.toLowerCase(), contains('read the printed table'));
    });

    test('says nothing about a barcode when there is none', () {
      expect(Prompts.labelUser(), isNot(contains('scans as')));
      expect(Prompts.labelUser(barcode: '  '), isNot(contains('scans as')));
    });
  });

  group('the blackout reaches the prompts', () {
    test('no daily prompt contains verdict data', () {
      // A model cannot leak a figure it was never told. This is the cheapest
      // and most complete enforcement available: the words are simply not in
      // the request. See CLAUDE.md §1.
      const forbidden = [
        'tdee',
        'deficit',
        'surplus',
        'maintenance',
        'weight trend',
        'losing',
        'gaining',
        'energy balance',
        'body fat',
        'bmr',
        'kg',
      ];

      for (final prompt in _dailyPrompts()) {
        final text = prompt.toLowerCase();
        for (final word in forbidden) {
          expect(
            text.contains(word),
            isFalse,
            reason: 'a daily prompt mentioned "$word":\n$prompt',
          );
        }
      }
    });

    test('daily prompts tell the model it knows nothing about the body', () {
      // Belt and braces: the data is absent, and the model is told not to
      // speculate about what is absent.
      for (final prompt in [
        Prompts.mealParsingSystem(),
        Prompts.portionSystem(),
      ]) {
        expect(prompt.toLowerCase(), contains('never told anything about'));
      }
    });

    test('the portion question carries only the food and the phrasing', () {
      final prompt = Prompts.portionUser(
        foodName: 'Almonds',
        quantity: 1,
        unit: PortionUnit.handful,
      );

      expect(prompt, contains('Almonds'));
      expect(prompt, contains('handful'));
      // The answer is a property of the words, not of the person.
      expect(prompt.toLowerCase(), isNot(contains('goal')));
      expect(prompt.toLowerCase(), isNot(contains('daily')));
    });

    test('the narrative is the only prompt that admits verdict data', () {
      // And it says so explicitly, so the exception is visible in the prompt
      // itself rather than only in the calling code.
      final narrative = Prompts.narrativeSystem().toLowerCase();

      expect(narrative, contains('the week has closed'));
      expect(narrative, contains('exception'));
    });
  });

  group('no prompt invites a diagnosis', () {
    test('every prompt forbids judging the person', () {
      // Required by CLAUDE.md §7: harm is lore drawn from public data, never a
      // claim about this person's body.
      for (final prompt in [
        ..._dailyPrompts(),
        Prompts.narrativeSystem(),
      ]) {
        if (!prompt.contains('Rules you must follow')) continue;
        final text = prompt.toLowerCase();
        expect(text, contains('never diagnose'));
        expect(text, contains('not judging a person'));
      }
    });

    test('the house rules reach every system prompt', () {
      // The clause lives in one shared preamble so a new use cannot be added
      // without it.
      for (final system in [
        Prompts.mealParsingSystem(),
        Prompts.portionSystem(),
        Prompts.narrativeSystem(),
      ]) {
        expect(system, contains('Rules you must follow exactly'));
        expect(system.toLowerCase(), contains('never add prose'));
      }
    });

    test('the narrative may describe food but never call it healthy', () {
      final narrative = Prompts.narrativeSystem().toLowerCase();

      expect(narrative, contains('never call a food healthy or'));
      expect(narrative, contains('never advise a change'));
    });

    test('the narrative may not invent a food, an additive or a day', () {
      // It is now given actual food names and E-numbers, which is exactly the
      // material a model embellishes if it is not told not to.
      final narrative = Prompts.narrativeSystem().toLowerCase();

      expect(narrative, contains('use only the figures given'));
      expect(narrative, contains('never name an additive, a food or a day'));
    });

    test('the narrative is told not to congratulate or scold', () {
      final narrative = Prompts.narrativeSystem().toLowerCase();

      expect(narrative, contains('do not congratulate or scold'));
      expect(narrative, contains('do not give medical advice'));
      // A target for next week would be the app setting a goal from a verdict,
      // which is the daily screens' problem arriving a week later.
      expect(narrative, contains('do not suggest a target'));
    });
  });

  group('the narrative prompt carries what was eaten', () {
    NarrativeFacts factsFor(WeekPattern pattern) => NarrativeFacts.from(
          reckon(
            anyDayOfWeek: fixtureSunday,
            today: fixtureSunday,
            gate: const RevealGate(weekEndsOn: DateTime.sunday),
            days: [
              for (var i = 0; i < 7; i++)
                DayEnergy(
                  day: fixtureMonday.addDays(i),
                  intakeKcal: 1800,
                  expenditureKcal: 2400,
                ),
            ],
            startWeightKg: 82,
            endWeightKg: 81.1,
          ),
          averageVitality: 61,
          steps: 54000,
          pattern: pattern,
          findings: readFindings(pattern),
        )!;

    test('names the additives and the food that carried a curse', () {
      final prompt = Prompts.narrativeUser(factsFor(fixturePattern()));

      expect(prompt, contains('what was eaten'));
      expect(prompt, contains('Additives:'));
      expect(prompt, contains('E330'));
      expect(prompt, contains('Composition:'));
    });

    test('still carries the verdict block it always did', () {
      final prompt = Prompts.narrativeUser(factsFor(fixturePattern()));

      expect(prompt, contains('Energy balance:'));
      expect(prompt, contains('Measured weight change:'));
    });

    test('stays bounded however much was logged', () {
      // The caps are the point: this block must not grow with the size of the
      // food library, or a heavy week would send a prompt several times the
      // size of a light one for no extra insight.
      final huge = readWeek(
        weekStart: fixtureMonday,
        weekEnd: fixtureSunday,
        throughDay: fixtureSunday,
        portions: [
          for (var day = 0; day < 7; day++)
            for (var i = 0; i < 40; i++)
              LoggedPortion(
                day: fixtureMonday.addDays(day),
                food: FoodIdentity(id: i, name: 'Food $i'),
                serving: Serving(
                  food: FoodPanel(
                    kcal: 300,
                    sodiumMg: 400,
                    novaGroup: 4,
                    additives: ['E${100 + i}'],
                  ),
                  grams: 100,
                ),
              ),
        ],
      );

      final prompt = Prompts.narrativeUser(factsFor(huge));

      expect(
        prompt.split('\n'),
        hasLength(lessThan(40)),
        reason: 'the descriptive block grew with the journal: $prompt',
      );
    });
  });

  group('the photograph prompt', () {
    test('tells the model to name only what it can see', () {
      // The failure mode that matters: a model that infers a side dish out of
      // frame adds food nobody ate to the day's total.
      final system = Prompts.photoSystem().toLowerCase();

      expect(system, contains('only what you can actually see'));
      // Line breaks in the prompt are incidental, so match on words rather
      // than on how the source happens to wrap.
      expect(system.replaceAll(RegExp(r'\s+'), ' '), contains('out of frame'));
    });

    test('asks for the unidentifiable rather than a guess', () {
      expect(
        Prompts.photoSystem(),
        contains('cannot identify into "unrecognised"'),
      );
    });

    test('handles a picture that is not food', () {
      expect(Prompts.photoSystem(), contains('not of food, return no items'));
    });

    test('passes the user note through when there is one', () {
      expect(
        Prompts.photoUser('the sauce is tahini'),
        contains('the sauce is tahini'),
      );
      expect(Prompts.photoUser(null), isNot(contains('adds:')));
      expect(Prompts.photoUser('  '), isNot(contains('adds:')));
    });

    test('breaks a cooked dish into its components', () {
      // "Only what you can see" is right for a plate and wrong for a stew,
      // where the components are by definition not individually visible. A
      // model held to the stricter reading returns one opaque item, or none.
      final system = Prompts.photoSystem().replaceAll(RegExp(r'\s+'), ' ');

      expect(system, contains('single cooked dish'));
      expect(system, contains('components it is ordinarily made of'));
    });

    test('an inferred component must be marked as one', () {
      // What keeps the composite clause honest. The app already surfaces a
      // low-confidence portion as one worth correcting.
      final system = Prompts.photoSystem().replaceAll(RegExp(r'\s+'), ' ');

      expect(system, contains('did not see directly a confidence of 0.5'));
      expect(system, contains('prefer fewer, larger components'));
    });

    test('still refuses to invent what is out of frame', () {
      // The composite clause must not have loosened this.
      final system = Prompts.photoSystem().toLowerCase();
      expect(system, contains('only what you can actually see'));
      expect(
        system.replaceAll(RegExp(r'\s+'), ' '),
        contains('out of frame'),
      );
    });
  });

  group('the prompts say what the schema needs', () {
    test('units are stated in the terms the app stores', () {
      final system = Prompts.mealParsingSystem();

      expect(system, contains('per-100g'));
      expect(system, contains('kcal'));
      expect(system, contains('milligrams'));
    });

    test('the portion prompt refuses false certainty', () {
      expect(Prompts.portionSystem(), contains('confidence must be below 0.9'));
    });

    test('a known piece weight is offered when there is one', () {
      final withPiece = Prompts.portionUser(
        foodName: 'Egg',
        quantity: 2,
        unit: PortionUnit.piece,
        gramsPerPiece: 50,
        pieceName: 'egg',
      );
      final without = Prompts.portionUser(
        foodName: 'Egg',
        quantity: 2,
        unit: PortionUnit.piece,
      );

      expect(withPiece, contains('One egg of this food weighs about 50'));
      expect(without, isNot(contains('weighs about')));
    });
  });
}
