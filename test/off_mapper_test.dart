import 'dart:convert';

import 'package:cal_tracker/data/remote/off_mapper.dart';
import 'package:cal_tracker/data/remote/remote_food.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfoodfacts/openfoodfacts.dart' as off;

/// Builds an Open Food Facts product from the raw JSON shape the API returns.
///
/// Going through `fromJson` rather than setting fields directly is the point:
/// it exercises the same parsing the client does, so a change in how the
/// package reads `nutriments` shows up here rather than on a phone.
/// The mapped food, or null if the product was rejected.
///
/// Most tests here are about the mapping itself; which *reason* a rejection
/// carries is asserted in its own group.
RemoteFood? _map(off.Product product) {
  final result = OffMapper.fromProduct(product);
  return result is ProductFound ? result.food : null;
}

/// Why the mapper refused, or null if it did not.
UnusableReason? _reason(off.Product product) {
  final result = OffMapper.fromProduct(product);
  return result is ProductUnusable ? result.reason : null;
}

off.Product _product({
  String? name = 'Rye bread',
  String? brands,
  String? barcode = '7622300336738',
  Map<String, dynamic> nutriments = const {},
  int? novaGroup,
  List<String>? additives,
  String? servingSize,
  num? servingQuantity,
  String? imageSmallUrl,
  Map<String, String> namesByLanguage = const {},
  String? genericName,
}) {
  return off.Product.fromJson({
    'code': barcode,
    'product_name': ?name,
    for (final entry in namesByLanguage.entries)
      'product_name_${entry.key}': entry.value,
    'generic_name': ?genericName,
    'brands': ?brands,
    'nutriments': nutriments,
    'nova_group': ?novaGroup,
    'additives_tags': ?additives,
    'serving_size': ?servingSize,
    'serving_quantity': ?servingQuantity,
    'image_front_small_url': ?imageSmallUrl,
  });
}

/// A complete per-100g panel, as Open Food Facts spells the keys.
const _fullPanel = {
  'energy-kcal_100g': 250.0,
  'proteins_100g': 9.0,
  'carbohydrates_100g': 45.0,
  'sugars_100g': 3.0,
  'fat_100g': 3.3,
  'saturated-fat_100g': 0.6,
  'fiber_100g': 6.0,
  'sodium_100g': 0.5,
};

void main() {
  group('OffMapper.fromProduct', () {
    test('maps a complete product', () {
      final food = _map(
        _product(
          nutriments: _fullPanel,
          novaGroup: 3,
          additives: ['en:e300', 'en:e471'],
          imageSmallUrl: 'https://images.off.org/rye.jpg',
        ),
      )!;

      expect(food.name, 'Rye bread');
      expect(food.barcode, '7622300336738');
      expect(food.kcal, 250);
      expect(food.proteinG, 9);
      expect(food.carbsG, 45);
      expect(food.fatG, 3.3);
      expect(food.satFatG, 0.6);
      expect(food.fibreG, 6);
      expect(food.novaGroup, 3);
      expect(food.additives, ['en:e300', 'en:e471']);
      expect(food.imageUrl, 'https://images.off.org/rye.jpg');
      expect(food.source, FoodSource.openFoodFacts);
    });

    test('sodium is converted from grams to milligrams', () {
      final food = _map(
        _product(nutriments: _fullPanel),
      )!;

      // 0.5 g of sodium is 500 mg, and the column is mg.
      expect(food.sodiumMg, 500);
    });

    test('falls back to salt when sodium is absent', () {
      final food = _map(
        _product(
          nutriments: {
            'energy-kcal_100g': 250.0,
            'salt_100g': 1.25,
          },
        ),
      )!;

      // 1.25 g salt / 2.5 = 0.5 g sodium = 500 mg.
      expect(food.sodiumMg, closeTo(500, 0.001));
    });

    test('derives kcal from kJ when only kJ is reported', () {
      final food = _map(
        _product(nutriments: {'energy-kj_100g': 1046.0}),
      )!;

      expect(food.kcal, closeTo(250, 0.5));
    });

    test('prefers a reported kcal over the kJ conversion', () {
      final food = _map(
        _product(
          nutriments: {'energy-kcal_100g': 240.0, 'energy-kj_100g': 1046.0},
        ),
      )!;

      expect(food.kcal, 240);
    });

    test('converts alcohol from percent by volume to grams', () {
      final food = _map(
        _product(
          name: 'Lager',
          nutriments: {'energy-kcal_100g': 43.0, 'alcohol_100g': 5.0},
        ),
      )!;

      // 5% by volume is not 5 g: ethanol is 0.789 g/ml.
      expect(food.alcoholG, closeTo(3.945, 0.001));
    });

    test('leaves added sugar null when the field is absent', () {
      final food = _map(
        _product(nutriments: _fullPanel),
      )!;

      // Not zero. "No added sugar" and "nobody filled this in" are different
      // claims and the T6 harm model has to tell them apart.
      expect(food.addedSugarG, isNull);
      expect(food.transFatG, isNull);
    });

    test('ignores negative values from bad data entry', () {
      final food = _map(
        _product(
          nutriments: {'energy-kcal_100g': 250.0, 'proteins_100g': -3.0},
        ),
      )!;

      expect(food.proteinG, 0);
    });

    test('keeps only the first brand', () {
      final food = _map(
        _product(nutriments: _fullPanel, brands: 'Hovis,Premier Foods'),
      )!;

      expect(food.brand, 'Hovis');
    });

    test('takes a serving weight as the piece weight', () {
      final food = _map(
        _product(
          nutriments: _fullPanel,
          servingSize: '1 slice (40 g)',
          servingQuantity: 40,
        ),
      )!;

      expect(food.gramsPerPiece, 40);
      expect(food.pieceName, '1 slice (40 g)');
    });

    test('drops a serving label that is only a measurement', () {
      // "2 30 g" would be a nonsense line in the Journal.
      final food = _map(
        _product(
          nutriments: _fullPanel,
          servingSize: '30 g',
          servingQuantity: 30,
        ),
      )!;

      expect(food.gramsPerPiece, 30);
      expect(food.pieceName, isNull);
    });

    test('carries no glycemic index, because Open Food Facts has none', () {
      final food = _map(
        _product(nutriments: _fullPanel),
      )!;

      expect(food.glycemicIndex, isNull);
    });

    group('rejects products that cannot be logged honestly', () {
      test('no energy at all', () {
        // Mapping this to 0 kcal would let someone believe they had logged
        // their lunch while adding nothing to the day.
        expect(
          _map(_product(nutriments: const {})),
          isNull,
        );
      });

      test('no name', () {
        expect(
          _map(
            _product(name: null, nutriments: _fullPanel),
          ),
          isNull,
        );
      });

      test('a blank name', () {
        expect(
          _map(
            _product(name: '   ', nutriments: _fullPanel),
          ),
          isNull,
        );
      });

      test('says which of the two it was', () {
        // The caller has to tell these apart: a nameless product is one the
        // user can name themselves, and one with no energy is not.
        expect(
          _reason(_product(name: null, nutriments: _fullPanel)),
          UnusableReason.noName,
        );
        expect(
          _reason(_product(nutriments: const {})),
          UnusableReason.noEnergy,
        );
      });

      test('a rejection for no energy still carries the name', () {
        final result = OffMapper.fromProduct(
          _product(name: 'Salted almonds', nutriments: const {}),
        );

        // So an offer to record it by hand starts from something.
        expect(result, isA<ProductUnusable>());
        expect((result as ProductUnusable).name, 'Salted almonds');
      });
    });

    group('a name in any language beats no name at all', () {
      // This is the bug behind a scan that resolved to nothing: `product_name`
      // holds only the field for the language that was asked for, so a product
      // named solely in Romanian arrived with it empty and was rejected.

      test('falls back to a name in another language', () {
        final food = _map(
          _product(
            name: null,
            namesByLanguage: const {'ro': 'Migdale sărate'},
            nutriments: _fullPanel,
          ),
        );

        expect(food, isNotNull);
        expect(food!.name, 'Migdale sărate');
      });

      test('prefers English when upstream has it', () {
        final food = _map(
          _product(
            name: null,
            namesByLanguage: const {
              'ro': 'Migdale sărate',
              'en': 'Salted almonds',
            },
            nutriments: _fullPanel,
          ),
        )!;

        expect(food.name, 'Salted almonds');
      });

      test('falls back to the generic name before giving up', () {
        final food = _map(
          _product(
            name: null,
            genericName: 'Roasted nuts',
            nutriments: _fullPanel,
          ),
        )!;

        expect(food.name, 'Roasted nuts');
      });

      test('a blank name in another language is still no name', () {
        expect(
          _map(
            _product(
              name: null,
              namesByLanguage: const {'ro': '   '},
              nutriments: _fullPanel,
            ),
          ),
          isNull,
        );
      });
    });

    group('confidence reflects how complete the panel is', () {
      test('energy only scores lowest', () {
        final food = _map(
          _product(nutriments: {'energy-kcal_100g': 250.0}),
        )!;

        expect(food.confidence, closeTo(0.6, 0.001));
      });

      test('a full panel scores highest', () {
        final food = _map(
          _product(nutriments: _fullPanel),
        )!;

        expect(food.confidence, closeTo(0.95, 0.001));
      });

      test('a partial panel lands in between', () {
        final sparse = _map(
          _product(
            nutriments: {'energy-kcal_100g': 250.0, 'proteins_100g': 9.0},
          ),
        )!;
        final full = _map(
          _product(nutriments: _fullPanel),
        )!;

        expect(sparse.confidence, greaterThan(0.6));
        expect(sparse.confidence, lessThan(full.confidence));
      });
    });
  });

  group('OffMapper.fromProducts', () {
    test('drops the unusable ones instead of failing the whole page', () {
      final foods = OffMapper.fromProducts([
        _product(name: 'Good bread', nutriments: _fullPanel),
        _product(name: 'Barcode and a photo', nutriments: const {}),
        _product(name: null, nutriments: _fullPanel),
        _product(name: 'Also good', nutriments: _fullPanel),
      ]);

      expect(foods.map((f) => f.name), ['Good bread', 'Also good']);
    });

    test('handles a null product list', () {
      expect(OffMapper.fromProducts(null), isEmpty);
    });
  });

  group('RemoteFood.toCompanion', () {
    test('carries the values across and encodes additives as JSON', () {
      final food = _map(
        _product(
          nutriments: _fullPanel,
          novaGroup: 4,
          additives: ['en:e150d'],
        ),
      )!;

      final companion = food.toCompanion(now: DateTime(2026, 9, 15));

      expect(companion.name.value, 'Rye bread');
      expect(companion.kcal.value, 250);
      expect(companion.novaGroup.value, 4);
      expect(companion.source.value, FoodSource.openFoodFacts);
      expect(
        jsonDecode(companion.additivesJson.value!),
        ['en:e150d'],
      );
      expect(companion.createdAt.value, '2026-09-15T00:00:00.000');
    });

    test('writes no additives JSON when there are none', () {
      final food = _map(
        _product(nutriments: _fullPanel),
      )!;

      expect(
        food.toCompanion(now: DateTime(2026, 9, 15)).additivesJson.value,
        isNull,
      );
    });
  });
}
