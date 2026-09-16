import '../../domain/portion.dart';

/// The JSON schemas every AI call is constrained to.
///
/// `response_format: {type: "json_schema"}` with `strict: true`, so the model
/// cannot answer with prose and the app never has to guess at a reply. This is
/// the rule in CLAUDE.md §4 that makes a 50-call budget survivable: a malformed
/// answer would otherwise cost a retry, and a retry is a call.
abstract final class AiSchemas {
  /// The unit vocabulary, taken from the enum rather than written out twice.
  ///
  /// A model that answers with a unit the app does not have would be a decode
  /// failure, and a decode failure costs a call.
  static List<String> get unitNames =>
      PortionUnit.values.map((u) => u.name).toList();

  static Map<String, dynamic> get _food => {
        'type': 'object',
        'additionalProperties': false,
        'required': [
          'name',
          'brand',
          'kcal',
          'protein_g',
          'carbs_g',
          'sugar_g',
          'fat_g',
          'sat_fat_g',
          'fibre_g',
          'sodium_mg',
          'nova_group',
          'glycemic_index',
          'confidence',
        ],
        'properties': {
          'name': {'type': 'string'},
          // Nullable rather than optional: `strict` mode requires every
          // property to be present, so "unknown" has to be expressible as a
          // value rather than as an absence.
          'brand': {
            'type': ['string', 'null'],
          },
          'kcal': {'type': 'number', 'description': 'per 100 g'},
          'protein_g': {'type': 'number'},
          'carbs_g': {'type': 'number'},
          'sugar_g': {'type': 'number'},
          'fat_g': {'type': 'number'},
          'sat_fat_g': {'type': 'number'},
          'fibre_g': {'type': 'number'},
          'sodium_mg': {'type': 'number'},
          'nova_group': {
            'type': ['integer', 'null'],
            'description': '1 to 4, or null if unsure',
          },
          'glycemic_index': {
            'type': ['integer', 'null'],
            'description': 'null for foods with little carbohydrate',
          },
          'confidence': {'type': 'number', 'minimum': 0, 'maximum': 1},
        },
      };

  /// Free-text meal parsing.
  static Map<String, dynamic> get meal => {
        'name': 'parsed_meal',
        'strict': true,
        'schema': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['items', 'unrecognised'],
          'properties': {
            'items': {
              'type': 'array',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'required': [
                  'food',
                  'quantity',
                  'unit',
                  'grams',
                  'confidence',
                ],
                'properties': {
                  'food': _food,
                  'quantity': {'type': 'number', 'minimum': 0},
                  'unit': {'type': 'string', 'enum': unitNames},
                  'grams': {
                    'type': ['number', 'null'],
                    'description': 'only when confident',
                  },
                  'confidence': {
                    'type': 'number',
                    'minimum': 0,
                    'maximum': 1,
                  },
                },
              },
            },
            'unrecognised': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
        },
      };

  /// Vague-portion estimation.
  static Map<String, dynamic> get portion => {
        'name': 'portion_estimate',
        'strict': true,
        'schema': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['grams', 'confidence', 'note'],
          'properties': {
            'grams': {'type': 'number', 'minimum': 0},
            'confidence': {'type': 'number', 'minimum': 0, 'maximum': 1},
            'note': {
              'type': ['string', 'null'],
            },
          },
        },
      };

  /// Reading the nutrition table off a package.
  ///
  /// One food, not a list: a packet carries one panel. [_food] is reused
  /// wholesale so a figure read off a label is clamped by exactly the same
  /// rules as one the model guessed at from a plate — the source differs, the
  /// distrust does not.
  ///
  /// `readable` exists because "I photographed the wrong side of the packet" is
  /// an ordinary outcome and has to be sayable. Without it the model's only way
  /// to report failure would be to invent a panel, which is the one answer that
  /// costs a call *and* poisons the library.
  static Map<String, dynamic> get label => {
        'name': 'label_reading',
        'strict': true,
        'schema': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['readable', 'food', 'serving_g'],
          'properties': {
            'readable': {
              'type': 'boolean',
              'description':
                  'false if no nutrition table is legible in the image',
            },
            'food': {
              ..._food,
              'type': ['object', 'null'],
            },
            'serving_g': {
              'type': ['number', 'null'],
              'description':
                  'grams in one stated serving, if the pack names one',
            },
          },
        },
      };

  /// The single weekly narrative, in four named sections.
  ///
  /// Four rather than one because The Tale lays them out as separate panels,
  /// and four rather than five because a *closing* field is exactly where a
  /// model reaches for "next week, try…" — which CLAUDE.md §7 forbids. The app
  /// supplies its own closing: the disclaimer.
  ///
  /// Each extra required string is another chance a free model trips `strict`,
  /// and `_structured` records every attempt against the daily budget. If
  /// these start failing in practice, collapse to two rather than retrying.
  static Map<String, dynamic> get narrative => {
        'name': 'weekly_narrative',
        'strict': true,
        'schema': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['opening', 'the_table', 'the_curses', 'the_boons'],
          'properties': {
            'opening': {
              'type': 'string',
              'description': 'the week in one breath',
            },
            'the_table': {
              'type': 'string',
              'description': 'what was eaten and how it was composed',
            },
            'the_curses': {
              'type': 'string',
              'description': 'what the week carried, as figures against '
                  'published guidelines',
            },
            'the_boons': {
              'type': 'string',
              'description': 'what the week held well',
            },
          },
        },
      };
}
