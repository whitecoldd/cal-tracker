/// A unit a portion can be expressed in.
///
/// Every calculation in the app runs on grams, so each unit carries enough
/// information to get there. The vague ones are kept deliberately — people eat
/// "a handful of almonds", not "28 grams of almonds", and forcing precision at
/// the moment of logging is how food diaries get abandoned. The honesty comes
/// from [PortionUnit.baseConfidence] instead: a vague unit is recorded as
/// vague, and the weekly account can say so.
enum PortionUnit {
  grams('g', 'grams', 1, 1),
  millilitres('ml', 'millilitres', 1, 0.95),

  /// One of whatever the food naturally comes in. Resolved from the food's own
  /// piece weight when it has one.
  piece('pc', 'piece', 100, 0.45),
  slice('sl', 'slice', 30, 0.5),

  handful('handful', 'handful', 30, 0.5),
  bowl('bowl', 'bowl', 250, 0.45),
  plate('plate', 'plate', 350, 0.4),

  cup('cup', 'cup', 240, 0.75),
  tablespoon('tbsp', 'tablespoon', 15, 0.85),
  teaspoon('tsp', 'teaspoon', 5, 0.85);

  const PortionUnit(
    this.short,
    this.label,
    this.defaultGrams,
    this.baseConfidence,
  );

  /// Compact form shown next to a number.
  final String short;

  /// Spoken form, for pickers and for the AI parser's vocabulary.
  final String label;

  /// Grams in one of this unit when the food says nothing more specific.
  final double defaultGrams;

  /// How much to trust that default, 0..1.
  ///
  /// Drives two things: whether the entry is worth spending an AI call to
  /// refine (T8), and whether the weekly account should hedge its numbers.
  final double baseConfidence;

  /// Whether this unit resolves to a food's own piece weight when it has one.
  bool get usesPieceWeight => this == piece || this == slice;

  /// Units that are exact by definition, so no refinement can improve them.
  bool get isExact => this == grams || this == millilitres;
}

/// A portion converted to grams, with how much that conversion can be trusted.
class ResolvedPortion {
  const ResolvedPortion({
    required this.grams,
    required this.confidence,
    required this.usedPieceWeight,
  });

  final double grams;

  /// 0..1.
  final double confidence;

  /// True when the food's own piece weight was used rather than a generic
  /// default — the difference between "1 egg = 50g" and "1 piece = 100g".
  final bool usedPieceWeight;

  /// Whether asking the model for a better estimate could plausibly help.
  bool get worthRefining => confidence < 0.7;
}

/// Converts a quantity and unit into grams.
///
/// Pure: everything it needs about the food is passed in, so it can be tested
/// without a database and reused by the AI parser later.
ResolvedPortion resolvePortion({
  required double quantity,
  required PortionUnit unit,
  double? gramsPerPiece,
}) {
  final safeQuantity = quantity.isFinite && quantity > 0 ? quantity : 0.0;

  // A food that knows what one of it weighs beats any generic default.
  final usePiece = unit.usesPieceWeight &&
      gramsPerPiece != null &&
      gramsPerPiece > 0;

  final perUnit = usePiece ? gramsPerPiece : unit.defaultGrams;
  final confidence = usePiece ? 0.95 : unit.baseConfidence;

  return ResolvedPortion(
    grams: safeQuantity * perUnit,
    confidence: confidence,
    usedPieceWeight: usePiece,
  );
}

/// How a portion should read in the Journal.
///
/// "2 eggs" rather than "100 g", because the Journal is meant to read like a
/// journal — and because seeing your own words back is what makes a wrong
/// entry obvious.
String describePortion({
  required double quantity,
  required PortionUnit unit,
  String? pieceName,
}) {
  final number = _trim(quantity);

  if (unit.isExact) return '$number${unit.short}';

  final noun = unit.usesPieceWeight && pieceName != null && pieceName.isNotEmpty
      ? pieceName
      : unit.label;

  final plural = quantity == 1 ? noun : _pluralise(noun);
  return '$number $plural';
}

String _trim(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

String _pluralise(String noun) {
  if (noun.endsWith('s') || noun.endsWith('x')) return '${noun}es';
  return '${noun}s';
}
