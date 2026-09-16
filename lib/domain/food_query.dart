import 'portion.dart';

/// Words that carry no meaning in a food name.
///
/// Dropped from a query rather than matched. Because every term must match,
/// keeping "of" would make "2 slices of bread" findable only against a food
/// whose own name happens to contain the word.
const Set<String> searchStopwords = {
  'a',
  'an',
  'the',
  'of',
  'with',
  'and',
  'some',
};

/// Number words a portion can plausibly be counted in.
///
/// Small and fixed on purpose. This is not an attempt at a number parser — it
/// exists because every term must match, so an unrecognised leading "dozen"
/// would block the whole query and return nothing at all, which is strictly
/// worse than the behaviour it replaces. Anything richer belongs in the
/// free-text path, which already has a model behind it.
const Map<String, double> searchNumberWords = {
  'a': 1,
  'an': 1,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'half': 0.5,
  'dozen': 12,
};

/// Unit words beyond what [PortionUnit] spells for itself.
const Map<String, PortionUnit> _unitAliases = {
  'gram': PortionUnit.grams,
  'grams': PortionUnit.grams,
  'millilitre': PortionUnit.millilitres,
  'milliliter': PortionUnit.millilitres,
  'mls': PortionUnit.millilitres,
  'pcs': PortionUnit.piece,
  'pieces': PortionUnit.piece,
  'spoon': PortionUnit.tablespoon,
  'glass': PortionUnit.cup,
};

/// The one normalisation rule: lowercase, alphanumerics, single spaces.
///
/// `FoodsDao.searchKeyFor` delegates here so a stored key and a typed query can
/// never be normalised two different ways. **Changing this is a migration:**
/// every `search_key` already on a device was written by it.
String normaliseSearchText(String name, [String? brand]) {
  final joined = brand == null || brand.isEmpty ? name : '$name $brand';
  return joined
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// A singular stem, by truncation only.
///
/// Truncating is what makes the whole scheme work without touching stored data.
/// Because matching is *containment* rather than equality, a stem that is a
/// prefix of both forms matches both: `eggs` becomes `egg`, which finds a
/// stored `egg whole` and a stored `scrambled eggs` alike. So only the query is
/// ever stemmed, `search_key` keeps its exact contract, and there is no re-key
/// pass and no schema bump.
///
/// The length floors protect the short words this would otherwise destroy:
/// `is` survives, `glass` does not become `gla`, `fries` does not become `fr`.
/// Over-stripping a long word (`hummus` to `hummu`) only widens recall, which
/// the match tiers then push back down the list.
String stemWord(String word) {
  if (word.endsWith('ies') && word.length >= 6) {
    return word.substring(0, word.length - 3);
  }
  if (word.endsWith('es') && word.length >= 5) {
    return word.substring(0, word.length - 2);
  }
  if (word.endsWith('s') && !word.endsWith('ss') && word.length >= 4) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

/// What the user typed, understood.
class FoodQuery {
  const FoodQuery({
    required this.key,
    required this.words,
    required this.terms,
    this.quantity,
    this.unit,
  });

  static const empty = FoodQuery(key: '', words: [], terms: []);

  /// The whole query, normalised. Used only for the exact-match tier.
  final String key;

  /// The meaningful words: stopwords and any leading quantity removed, but
  /// **not** stemmed. This is what goes upstream — Open Food Facts should never
  /// be shown a stem, which is not a word anybody wrote.
  final List<String> words;

  /// [words] reduced to stems. What local matching is built from.
  final List<String> terms;

  /// A quantity read off the front of the query, if there was one.
  final double? quantity;

  /// The unit that quantity was expressed in, if the query named one.
  final PortionUnit? unit;

  bool get isEmpty => terms.isEmpty;

  /// The text to send upstream.
  String get remoteText => words.join(' ');

  @override
  String toString() => 'FoodQuery($terms, quantity: $quantity, unit: $unit)';
}

/// Reads a search box.
FoodQuery parseFoodQuery(String raw) {
  final key = normaliseSearchText(raw);
  if (key.isEmpty) return FoodQuery.empty;

  // The quantity is read before normalisation, not after. `normaliseSearchText`
  // strips the decimal point along with every other punctuation mark, so by the
  // time a query is a search key "1.5 cup rice" has already become "1 5 cup
  // rice" and the half is gone.
  final taken = _takeLeadingQuantity(raw);
  final restKey = normaliseSearchText(taken.rest);
  final restTokens = restKey.isEmpty ? const <String>[] : restKey.split(' ');

  double? quantity;
  PortionUnit? unit;
  List<String> tokens;

  // Taken only if a real word survives it. Someone searching for "500" means
  // the number: there is no food left once it is removed.
  if (taken.quantity != null &&
      restTokens.any((t) => !searchStopwords.contains(t))) {
    quantity = taken.quantity;
    unit = taken.unit;
    tokens = restTokens;
  } else {
    tokens = key.split(' ');
  }

  final words = tokens.where((t) => !searchStopwords.contains(t)).toList();
  if (words.isEmpty) {
    // Every token was a stopword. Search for them literally rather than for
    // nothing — "the" is somebody's brand.
    return FoodQuery(
      key: key,
      words: tokens,
      terms: tokens.map(stemWord).toList(),
    );
  }

  return FoodQuery(
    key: key,
    words: words,
    terms: words.map(stemWord).toList(),
    quantity: quantity,
    unit: unit,
  );
}

/// A leading quantity split off the front of a query.
class _LeadingQuantity {
  const _LeadingQuantity(this.quantity, this.unit, this.rest);

  final double? quantity;
  final PortionUnit? unit;

  /// Everything after the quantity, still unnormalised.
  final String rest;
}

_LeadingQuantity _takeLeadingQuantity(String raw) {
  // Keeps the decimal point that normalisation would remove, and nothing else.
  final soft = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9.\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (soft.isEmpty) return _LeadingQuantity(null, null, raw);

  final tokens = soft.split(' ');
  var index = 0;
  double? value;
  PortionUnit? unit;

  // "500ml", "2tbsp" — a number with its unit glued on.
  final glued = RegExp(r'^(\d+(?:\.\d+)?)([a-z]+)$').firstMatch(tokens.first);
  if (glued != null) {
    final gluedValue = double.tryParse(glued.group(1)!);
    final gluedUnit = _unitFor(glued.group(2)!);
    if (gluedValue != null && gluedUnit != null) {
      return _LeadingQuantity(
        gluedValue,
        gluedUnit,
        tokens.sublist(1).join(' '),
      );
    }
  }

  value = double.tryParse(tokens.first) ?? searchNumberWords[tokens.first];
  if (value == null) return _LeadingQuantity(null, null, raw);
  index = 1;

  // "a dozen eggs": the article is a number word in its own right, so without
  // this the quantity would come out as one.
  if ((tokens.first == 'a' || tokens.first == 'an') && tokens.length > 1) {
    final second = searchNumberWords[tokens[1]];
    if (second != null) {
      value = second;
      index = 2;
    }
  }

  // A unit word immediately after the number: "2 slices of bread".
  if (index < tokens.length) {
    unit = _unitFor(tokens[index]);
    if (unit != null) index++;
  }

  return _LeadingQuantity(value, unit, tokens.sublist(index).join(' '));
}

PortionUnit? _unitFor(String word) {
  for (final unit in PortionUnit.values) {
    if (word == unit.short || word == unit.label) return unit;
    if (word == '${unit.label}s' || word == '${unit.label}es') return unit;
  }
  return _unitAliases[word];
}

/// How well a stored key answers a query. Lower is better.
///
/// * 0 — the key is exactly what was typed.
/// * 1 — every term begins a word in the key.
/// * 2 — every term appears somewhere in the key.
/// * null — it does not answer it at all.
///
/// Tier 1 means "begins a word *inside* the key", not "the key begins with the
/// term". A key that had to start with the first term could never rank
/// `monster energy ultra white` for `white monster`, which is one of the two
/// searches this was written to fix.
int? matchTier(String searchKey, FoodQuery query) {
  if (query.isEmpty) return null;
  if (searchKey == query.key) return 0;

  var everyTermStartsAWord = true;
  for (final term in query.terms) {
    if (!searchKey.contains(term)) return null;
    everyTermStartsAWord = everyTermStartsAWord &&
        (searchKey.startsWith(term) || searchKey.contains(' $term'));
  }

  return everyTermStartsAWord ? 1 : 2;
}
