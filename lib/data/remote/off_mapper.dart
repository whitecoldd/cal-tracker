import 'package:openfoodfacts/openfoodfacts.dart' as off;

import '../tables.dart';
import 'remote_food.dart';

/// Turns an Open Food Facts product into a [RemoteFood].
///
/// Pure, so the whole of it is testable against captured payloads without a
/// network. That matters more than usual here: Open Food Facts is crowd-sourced
/// and its fields are inconsistent, so the interesting behaviour is all in the
/// fallbacks and the unit conversions, and those are exactly what a live test
/// would not pin down.
///
/// Everything is normalised to per-100g/ml, which is how the `foods` table
/// stores nutrients.
abstract final class OffMapper {
  /// 1 kcal in kilojoules, for products that only report kJ.
  static const _kJPerKcal = 4.184;

  /// Salt to sodium. Sodium chloride is ~39.3% sodium by mass; the food
  /// industry constant is 2.5, and Open Food Facts uses the same one.
  static const _saltToSodium = 2.5;

  /// Density of ethanol in g/ml. Alcohol is reported as % by *volume*, and the
  /// `alcoholG` column is grams, so the two are not interchangeable.
  static const _ethanolDensity = 0.789;

  static const _per = off.PerSize.oneHundredGrams;

  /// Maps a product, or returns null if it cannot be logged honestly.
  ///
  /// Two rejections, both deliberate:
  ///
  /// - **No name.** Nothing to show in the Journal.
  /// - **No energy.** Open Food Facts has many entries that are barely more
  ///   than a barcode and a photo. Mapping one of those to `kcal: 0` would add
  ///   a silent zero to the day's total, which is worse than not offering the
  ///   food at all — the user would believe they had logged their lunch.
  static RemoteFood? fromProduct(off.Product product) {
    final name = (product.productName ?? '').trim();
    if (name.isEmpty) return null;

    final nutriments = product.nutriments;
    if (nutriments == null) return null;

    final kcal = _kcal(nutriments);
    if (kcal == null) return null;

    final brand = _firstBrand(product.brands);

    return RemoteFood(
      name: name,
      brand: brand,
      barcode: product.barcode,
      kcal: kcal,
      proteinG: _grams(nutriments, off.Nutrient.proteins) ?? 0,
      carbsG: _grams(nutriments, off.Nutrient.carbohydrates) ?? 0,
      sugarG: _grams(nutriments, off.Nutrient.sugars) ?? 0,
      // Left null rather than zeroed. "No added sugar" and "nobody filled this
      // field in" are different claims, and the harm model in T6 needs to be
      // able to tell them apart.
      addedSugarG: _grams(nutriments, off.Nutrient.addedSugars),
      fatG: _grams(nutriments, off.Nutrient.fat) ?? 0,
      satFatG: _grams(nutriments, off.Nutrient.saturatedFat) ?? 0,
      transFatG: _grams(nutriments, off.Nutrient.transFat),
      fibreG: _grams(nutriments, off.Nutrient.fiber) ?? 0,
      sodiumMg: _sodiumMg(nutriments) ?? 0,
      alcoholG: _alcoholG(nutriments) ?? 0,
      novaGroup: product.novaGroup,
      additives: product.additives?.ids ?? const [],
      gramsPerPiece: _servingGrams(product),
      pieceName: _pieceName(product),
      imageUrl: product.imageFrontSmallUrl ?? product.imageFrontUrl,
      source: FoodSource.openFoodFacts,
      confidence: _confidence(nutriments),
    );
  }

  /// Maps a page of search results, dropping the ones that cannot be logged.
  static List<RemoteFood> fromProducts(Iterable<off.Product>? products) {
    if (products == null) return const [];
    return [
      for (final p in products) ?fromProduct(p),
    ];
  }

  static double? _grams(off.Nutriments n, off.Nutrient nutrient) {
    final value = n.getValue(nutrient, _per);
    // Negative values exist in the wild from bad data entry.
    if (value == null || value.isNaN || value < 0) return null;
    return value;
  }

  static double? _kcal(off.Nutriments n) {
    final direct = _grams(n, off.Nutrient.energyKCal);
    if (direct != null) return direct;

    final kJ = _grams(n, off.Nutrient.energyKJ);
    if (kJ != null) return kJ / _kJPerKcal;

    return null;
  }

  /// Sodium in **milligrams**. `getValue` returns grams, and many products
  /// carry salt instead of sodium.
  static double? _sodiumMg(off.Nutriments n) {
    final sodiumG = _grams(n, off.Nutrient.sodium);
    if (sodiumG != null) return sodiumG * 1000;

    final saltG = _grams(n, off.Nutrient.salt);
    if (saltG != null) return saltG / _saltToSodium * 1000;

    return null;
  }

  /// Alcohol in **grams per 100ml**, converted from the reported % by volume.
  static double? _alcoholG(off.Nutriments n) {
    final byVolume = _grams(n, off.Nutrient.alcohol);
    if (byVolume == null) return null;
    return byVolume * _ethanolDensity;
  }

  /// Grams in one serving, when the product states a usable one.
  static double? _servingGrams(off.Product product) {
    final quantity = product.servingQuantity;
    if (quantity == null || quantity <= 0) return null;
    return quantity;
  }

  /// What one serving is called, e.g. "1 biscuit (12.5 g)" → "serving".
  ///
  /// Open Food Facts serving sizes are free text and frequently just "30 g",
  /// which would read absurdly in the Journal as "2 30 g". So the label is only
  /// kept when it says something a number does not.
  static String? _pieceName(off.Product product) {
    final raw = product.servingSize?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (_onlyAMeasure.hasMatch(raw)) return null;
    return raw;
  }

  static final _onlyAMeasure = RegExp(
    r'^\s*[\d.,]+\s*(g|kg|ml|cl|l|oz|fl\s*oz)?\s*$',
    caseSensitive: false,
  );

  static String? _firstBrand(String? brands) {
    final first = brands?.split(',').first.trim();
    return (first == null || first.isEmpty) ? null : first;
  }

  /// How much to trust these numbers, from how much of the core panel is there.
  ///
  /// Energy alone scores 0.6; a full panel scores 0.95. This is what decides
  /// whether a later, better source is allowed to overwrite the row, so it has
  /// to reflect completeness rather than just "it came from Open Food Facts".
  static double _confidence(off.Nutriments n) {
    const core = [
      off.Nutrient.proteins,
      off.Nutrient.carbohydrates,
      off.Nutrient.fat,
      off.Nutrient.saturatedFat,
      off.Nutrient.fiber,
      off.Nutrient.sugars,
    ];

    final present = core.where((c) => _grams(n, c) != null).length;
    return 0.6 + 0.35 * (present / core.length);
  }
}
