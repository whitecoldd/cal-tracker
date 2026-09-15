import 'dart:convert';

import 'package:drift/drift.dart';

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

  /// A remote image URL, not a file on disk. Stored in `imagePath` because a
  /// food has exactly one picture and its origin does not change how it is
  /// shown; T9 writes local capture paths into the same column.
  final String? imageUrl;

  final FoodSource source;
  final double confidence;

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
