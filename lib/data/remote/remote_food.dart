import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/nutrition.dart';
import '../database.dart';
import '../tables.dart';

/// A food found upstream that is **not yet in the library**.
///
/// Deliberately a different type from [Food]. A [Food] carries a real row id
/// and can be logged; a [RemoteFood] cannot, because an entry referencing it
/// would point at a row that does not exist. The only way across is
/// [toCompanion] plus a write to `foods`, which is exactly the write-back the
/// budget rule in CLAUDE.md §4 demands — so the type system makes "show it,
/// then forget it" impossible to write by accident.
class RemoteFood {
  const RemoteFood({
    required this.name,
    required this.kcal,
    required this.source,
    required this.confidence,
    this.brand,
    this.barcode,
    this.proteinG = 0,
    this.carbsG = 0,
    this.sugarG = 0,
    this.addedSugarG,
    this.fatG = 0,
    this.satFatG = 0,
    this.transFatG,
    this.fibreG = 0,
    this.sodiumMg = 0,
    this.alcoholG = 0,
    this.glycemicIndex,
    this.novaGroup,
    this.additives = const [],
    this.gramsPerPiece,
    this.pieceName,
    this.imageUrl,
  });

  final String name;
  final String? brand;
  final String? barcode;

  // --- per 100 g / 100 ml ---
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double sugarG;
  final double? addedSugarG;
  final double fatG;
  final double satFatG;
  final double? transFatG;
  final double fibreG;
  final double sodiumMg;
  final double alcoholG;

  /// Open Food Facts does not carry glycemic index, so this is null for
  /// anything from there. The seed table and the model are the GI sources.
  final int? glycemicIndex;

  final int? novaGroup;

  /// Additive tags as Open Food Facts spells them, e.g. `en:e150d`.
  final List<String> additives;

  final double? gramsPerPiece;
  final String? pieceName;

  /// A remote image URL, not a file on disk.
  ///
  /// `Foods.imagePath` holds exactly this and nothing else — an earlier version
  /// of this comment claimed T9 wrote local capture paths into the same column,
  /// which was never true and would have made the column ambiguous. The local
  /// copy `CreatureImageStore` fetches lives in the cache directory, keyed by
  /// food id, so a path and a URL are never confused for one another.
  final String? imageUrl;

  final FoodSource source;
  final double confidence;

  /// The nutrient panel, for the scoring engine.
  ///
  /// An upstream result is ranked and read for harm by exactly the same code
  /// as a stored one, so a food does not change rarity at the moment it is
  /// saved.
  FoodPanel get panel => FoodPanel(
        kcal: kcal,
        proteinG: proteinG,
        carbsG: carbsG,
        sugarG: sugarG,
        addedSugarG: addedSugarG,
        fatG: fatG,
        satFatG: satFatG,
        transFatG: transFatG,
        fibreG: fibreG,
        sodiumMg: sodiumMg,
        alcoholG: alcoholG,
        glycemicIndex: glycemicIndex,
        novaGroup: novaGroup,
        additiveCount: additives.length,
      );

  FoodsCompanion toCompanion({required DateTime now}) {
    final stamp = now.toIso8601String();
    return FoodsCompanion.insert(
      name: name,
      brand: Value(brand),
      barcode: Value(barcode),
      // Recomputed by FoodsDao.upsert; a placeholder here keeps the companion
      // constructible without duplicating the normalisation rule.
      searchKey: '',
      kcal: kcal,
      proteinG: Value(proteinG),
      carbsG: Value(carbsG),
      sugarG: Value(sugarG),
      addedSugarG: Value(addedSugarG),
      fatG: Value(fatG),
      satFatG: Value(satFatG),
      transFatG: Value(transFatG),
      fibreG: Value(fibreG),
      sodiumMg: Value(sodiumMg),
      alcoholG: Value(alcoholG),
      glycemicIndex: Value(glycemicIndex),
      novaGroup: Value(novaGroup),
      additivesJson:
          Value(additives.isEmpty ? null : jsonEncode(additives)),
      gramsPerPiece: Value(gramsPerPiece),
      pieceName: Value(pieceName),
      source: source,
      confidence: Value(confidence),
      imagePath: Value(imageUrl),
      createdAt: stamp,
      updatedAt: stamp,
    );
  }
}

/// Why a product that exists upstream still cannot be logged.
///
/// Both are common in a crowd-sourced database, and they are different
/// problems: a nameless product is one the user can name themselves, while a
/// product with no energy figure is one nobody can rescue without weighing it.
enum UnusableReason {
  /// Upstream carries no product name in any language we asked for.
  noName,

  /// Upstream carries no energy value, in kcal or kJ.
  noEnergy,
}

/// What a barcode lookup found upstream.
///
/// Sealed because "we have never heard of this code" and "we have it but it is
/// unusable" are different answers that the old nullable return collapsed into
/// one silent `null` — which is how a scan came to fail with nothing on screen.
/// The analyzer treats a non-exhaustive switch as an error, so a caller cannot
/// forget one of these the way the old `null` was forgotten.
sealed class ProductLookup {
  const ProductLookup();
}

/// A product that can be logged as it stands.
final class ProductFound extends ProductLookup {
  const ProductFound(this.food);

  final RemoteFood food;
}

/// A product upstream holds but the app cannot honestly use.
///
/// [name] is whatever upstream did give, when it gave one — worth carrying,
/// because it is what a hand-written entry can be prefilled with.
final class ProductUnusable extends ProductLookup {
  const ProductUnusable(this.reason, {this.name});

  final UnusableReason reason;
  final String? name;
}

/// Upstream has no record of this barcode at all.
final class ProductUnknown extends ProductLookup {
  const ProductUnknown();
}
