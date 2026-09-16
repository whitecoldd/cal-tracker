import 'dart:convert';

import 'package:cal_tracker/data/ai/ai_decode.dart';
import 'package:cal_tracker/domain/portion.dart';
import 'package:flutter_test/flutter_test.dart';

/// A chat-completions body with [content] as the assistant's message.
Map<String, dynamic> _body(String content) => {
      'choices': [
        {
          'message': {'role': 'assistant', 'content': content},
          'finish_reason': 'stop',
        },
      ],
      'usage': {'prompt_tokens': 412, 'completion_tokens': 88},
    };

Map<String, dynamic> _foodJson({
  String name = 'Egg, whole',
  Object? brand,
  Object? kcal = 143,
  Object? protein = 12.6,
  Object? nova = 1,
  Object? gi,
  Object? confidence = 0.8,
}) =>
    {
      'name': name,
      'brand': brand,
      'kcal': kcal,
      'protein_g': protein,
      'carbs_g': 0.7,
      'sugar_g': 0.4,
      'fat_g': 9.5,
      'sat_fat_g': 3.1,
      'fibre_g': 0,
      'sodium_mg': 142,
      'nova_group': nova,
      'glycemic_index': gi,
      'confidence': confidence,
    };

void main() {
  group('content extraction', () {
    test('pulls the assistant message out of a reply', () {
      expect(AiDecode.content(_body('{"a":1}')), '{"a":1}');
    });

    test('returns null for a reply with no usable message', () {
      expect(AiDecode.content({}), isNull);
      expect(AiDecode.content({'choices': <Object>[]}), isNull);
      expect(
        AiDecode.content({
          'choices': [
            {'message': <String, Object?>{'content': '   '}},
          ],
        }),
        isNull,
      );
    });
  });

  group('json decoding', () {
    test('reads a plain object', () {
      expect(AiDecode.json('{"grams": 30}'), {'grams': 30});
    });

    test('tolerates a fenced block', () {
      // Models occasionally wrap JSON in a code fence despite being told not
      // to, and losing a whole meal to three backticks would cost a call.
      const fenced = '```json\n{"grams": 30}\n```';
      expect(AiDecode.json(fenced), {'grams': 30});
    });

    test('rejects prose', () {
      // The leniency stops at the fence. Anything past it is a failure, not
      // something to salvage.
      expect(
        () => AiDecode.json('About thirty grams, I think.'),
        throwsFormatException,
      );
    });

    test('rejects a bare array', () {
      expect(() => AiDecode.json('[1, 2]'), throwsFormatException);
    });
  });

  group('meal decoding', () {
    Map<String, dynamic> mealJson(List<Map<String, dynamic>> items) => {
          'items': items,
          'unrecognised': <String>[],
        };

    test('decodes items with their portions', () {
      final meal = AiDecode.meal(mealJson([
        {
          'food': _foodJson(),
          'quantity': 2,
          'unit': 'piece',
          'grams': null,
          'confidence': 0.9,
        },
      ]));

      final item = meal.items.single;
      expect(item.food.name, 'Egg, whole');
      expect(item.quantity, 2);
      expect(item.unit, PortionUnit.piece);
      expect(item.grams, isNull);
      expect(item.confidence, 0.9);
      expect(item.food.panel.kcal, 143);
    });

    test('keeps fragments it could not turn into food', () {
      // Surfaced rather than dropped: a meal that logs three of four things
      // and says nothing about the fourth is worse than one that admits it.
      final meal = AiDecode.meal({
        'items': <Object>[],
        'unrecognised': ['and a bit of the leftovers', '  ', ''],
      });

      expect(meal.unrecognised, ['and a bit of the leftovers']);
      expect(meal.isEmpty, isTrue);
    });

    test('drops an item with no usable food rather than failing the meal', () {
      final meal = AiDecode.meal(mealJson([
        {'food': <String, Object?>{'name': '  '}, 'quantity': 1, 'unit': 'g'},
        {
          'food': _foodJson(name: 'Rye bread'),
          'quantity': 1,
          'unit': 'slice',
        },
      ]));

      expect(meal.items.single.food.name, 'Rye bread');
    });

    test('an absent quantity falls back to one', () {
      final meal = AiDecode.meal(mealJson([
        {'food': _foodJson(), 'quantity': null, 'unit': 'piece'},
      ]));

      expect(meal.items.single.quantity, 1);
    });

    group('unit mapping', () {
      test('accepts the enum name, the label and the short form', () {
        for (final spelling in ['handful', 'Handful', 'HANDFUL']) {
          final meal = AiDecode.meal(mealJson([
            {'food': _foodJson(), 'quantity': 1, 'unit': spelling},
          ]));
          expect(meal.items.single.unit, PortionUnit.handful);
        }

        final short = AiDecode.meal(mealJson([
          {'food': _foodJson(), 'quantity': 1, 'unit': 'tbsp'},
        ]));
        expect(short.items.single.unit, PortionUnit.tablespoon);
      });

      test('falls back to grams for a unit the app does not have', () {
        // The schema constrains this, so a miss means the model ignored it —
        // grams plus its own gram figure is the least-wrong reading.
        final meal = AiDecode.meal(mealJson([
          {'food': _foodJson(), 'quantity': 1, 'unit': 'fistful'},
        ]));

        expect(meal.items.single.unit, PortionUnit.grams);
      });
    });

    group('distrust of the numbers', () {
      test('clamps energy to something physically possible', () {
        // Pure fat is 900 kcal per 100 g. Anything above it is a model error,
        // and logging it would silently wreck the day's total.
        final meal = AiDecode.meal(mealJson([
          {'food': _foodJson(kcal: 90000), 'quantity': 1, 'unit': 'g'},
        ]));

        expect(meal.items.single.food.panel.kcal, 900);
      });

      test('a negative figure becomes zero', () {
        final meal = AiDecode.meal(mealJson([
          {'food': _foodJson(protein: -5), 'quantity': 1, 'unit': 'g'},
        ]));

        expect(meal.items.single.food.panel.proteinG, 0);
      });

      test('a NOVA group outside 1..4 is dropped, not clamped', () {
        // Clamping would assert a processing level the model did not claim.
        final meal = AiDecode.meal(mealJson([
          {'food': _foodJson(nova: 9), 'quantity': 1, 'unit': 'g'},
        ]));

        expect(meal.items.single.food.panel.novaGroup, isNull);
      });

      test('a numeric string is accepted', () {
        // Models answer "12" for a number field often enough that losing a
        // meal to a pair of quotes would be an expensive purity.
        final meal = AiDecode.meal(mealJson([
          {'food': _foodJson(kcal: '143'), 'quantity': '2', 'unit': 'piece'},
        ]));

        expect(meal.items.single.food.panel.kcal, 143);
        expect(meal.items.single.quantity, 2);
      });

      test('a missing confidence is read as uncertain, not as certain', () {
        final meal = AiDecode.meal(mealJson([
          {'food': _foodJson(confidence: null), 'quantity': 1, 'unit': 'g'},
        ]));

        expect(meal.items.single.food.confidence, 0.5);
      });

      test('an empty brand becomes null', () {
        final meal = AiDecode.meal(mealJson([
          {'food': _foodJson(brand: '  '), 'quantity': 1, 'unit': 'g'},
        ]));

        expect(meal.items.single.food.brand, isNull);
      });
    });

    test('survives a completely malformed items array', () {
      final meal = AiDecode.meal({'items': 'nonsense', 'unrecognised': null});

      expect(meal.isEmpty, isTrue);
      expect(meal.unrecognised, isEmpty);
    });
  });

  group('label decoding', () {
    Map<String, dynamic> reading({
      Object? readable = true,
      Object? food = const {
        'name': 'Salted almonds',
        'brand': 'Banzai',
        'kcal': 607,
        'protein_g': 21.2,
        'carbs_g': 6.9,
        'sugar_g': 4.4,
        'fat_g': 52.5,
        'sat_fat_g': 4.1,
        'fibre_g': 12.5,
        'sodium_mg': 380,
        'nova_group': 3,
        'glycemic_index': 15,
        'confidence': 0.8,
      },
      Object? servingG = 30,
    }) =>
        {'readable': readable, 'food': food, 'serving_g': servingG};

    test('reads the panel and the serving', () {
      final result = AiDecode.label(reading())!;

      expect(result.food.name, 'Salted almonds');
      expect(result.food.brand, 'Banzai');
      expect(result.food.panel.kcal, 607);
      expect(result.food.panel.sodiumMg, 380);
      expect(result.servingG, 30);
    });

    test('a panel the model could not see is nothing, not zeroes', () {
      // The one answer that would cost a call *and* poison the library is an
      // invented panel, so "not legible" has to be sayable and has to be
      // believed when it is said.
      expect(AiDecode.label(reading(readable: false)), isNull);
      expect(AiDecode.label(reading(food: null)), isNull);
    });

    test('a nameless food is not a reading', () {
      expect(
        AiDecode.label(reading(food: {'name': '   ', 'kcal': 100})),
        isNull,
      );
    });

    test('is as distrustful of a label as of a plate', () {
      // Same clamps, same helper. A figure read off small print gets no more
      // credit than one guessed from a photograph of a dinner.
      final result = AiDecode.label(
        reading(food: {'name': 'Suet', 'kcal': 4000, 'sat_fat_g': -3}),
      )!;

      expect(result.food.panel.kcal, 900);
      expect(result.food.panel.satFatG, 0);
    });

    test('an impossible serving is dropped rather than pulled to the edge', () {
      // Unlike a nutrient, this one is optional: a wrong figure would be typed
      // into a form as though the pack had stated it, and no figure is better.
      expect(AiDecode.label(reading(servingG: 9000))?.servingG, isNull);
      expect(AiDecode.label(reading(servingG: 0))?.servingG, isNull);
      expect(AiDecode.label(reading(servingG: null))?.servingG, isNull);
    });
  });

  group('portion decoding', () {
    test('reads the estimate and its note', () {
      final estimate = AiDecode.portion({
        'grams': 30,
        'confidence': 0.7,
        'note': 'a cupped handful, about 30 g',
      });

      expect(estimate.grams, 30);
      expect(estimate.confidence, 0.7);
      expect(estimate.note, 'a cupped handful, about 30 g');
    });

    test('never reports certainty, whatever the model claims', () {
      // Nobody weighed this. An estimate that presents itself as exact invites
      // the user to stop correcting it.
      final estimate = AiDecode.portion({
        'grams': 30,
        'confidence': 1.0,
        'note': null,
      });

      expect(estimate.confidence, lessThanOrEqualTo(0.85));
    });

    test('clamps an absurd weight', () {
      final estimate = AiDecode.portion({
        'grams': 900000,
        'confidence': 0.5,
        'note': null,
      });

      expect(estimate.grams, 5000);
    });

    test('an empty note becomes null', () {
      final estimate = AiDecode.portion({
        'grams': 30,
        'confidence': 0.5,
        'note': '   ',
      });

      expect(estimate.note, isNull);
    });
  });

  group('narrative decoding', () {
    test('reads the text', () {
      expect(AiDecode.narrative({'text': 'The week was long.'}),
          'The week was long.');
    });

    test('an empty narrative is null rather than an empty panel', () {
      expect(AiDecode.narrative({'text': '  '}), isNull);
      expect(AiDecode.narrative(<String, Object?>{}), isNull);
    });
  });

  group('a realistic end-to-end payload', () {
    test('decodes a full reply as it would arrive', () {
      final content = jsonEncode({
        'items': [
          {
            'food': _foodJson(),
            'quantity': 2,
            'unit': 'piece',
            'grams': 100,
            'confidence': 0.92,
          },
          {
            'food': _foodJson(name: 'Rye bread', kcal: 259, nova: 3),
            'quantity': 1,
            'unit': 'slice',
            'grams': null,
            'confidence': 0.75,
          },
        ],
        'unrecognised': <String>[],
      });

      final meal = AiDecode.meal(AiDecode.json(AiDecode.content(_body(content))!));

      expect(meal.items, hasLength(2));
      expect(meal.items.first.grams, 100);
      expect(meal.items.last.food.panel.novaGroup, 3);
      expect(meal.unrecognised, isEmpty);
    });
  });
}
