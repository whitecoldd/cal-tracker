import 'package:cal_tracker/data/ai/prompts.dart';
import 'package:cal_tracker/domain/portion.dart';
import 'package:flutter_test/flutter_test.dart';

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
    ];

void main() {
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

    test('the narrative is told not to congratulate or scold', () {
      final narrative = Prompts.narrativeSystem().toLowerCase();

      expect(narrative, contains('do not congratulate or scold'));
      expect(narrative, contains('do not give medical advice'));
      // A target for next week would be the app setting a goal from a verdict,
      // which is the daily screens' problem arriving a week later.
      expect(narrative, contains('do not suggest a target'));
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
