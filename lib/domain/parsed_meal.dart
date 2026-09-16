/// What the model is allowed to give back. Pure Dart.
///
/// These are the only shapes an AI response can take: everything arrives as a
/// strict JSON schema and is decoded into one of these, so no part of the app
/// ever parses prose. See CLAUDE.md §4.
library;

import 'nutrition.dart';
import 'portion.dart';

/// A food the model described, with nutrients per 100 g.
///
/// Held separately from [ParsedItem] because a parsed item may end up
/// resolving to a food the device already knows — in which case the model's
/// guess at the nutrients is discarded in favour of the better local data, and
/// only its name and portion survive.
class ParsedFood {
  const ParsedFood({
    required this.name,
    required this.panel,
    this.brand,
    this.confidence = 0.6,
  });

  final String name;
  final String? brand;
  final FoodPanel panel;

  /// 0..1. The model's own statement of how sure it is.
  final double confidence;
}

/// What was read off the nutrition table printed on a package.
///
/// One food and nothing else — a packet carries one panel, so there is no list
/// here and no portion. This is deliberately *not* a [ParsedItem]: a label
/// reading is never logged directly. It fills a form the user then checks and
/// saves, because the figures came off a photograph of small print and the
/// person holding the packet is the one who can see whether they are right.
class LabelReading {
  const LabelReading({required this.food, this.servingG});

  final ParsedFood food;

  /// Grams in one serving, where the pack states one.
  ///
  /// Kept apart from the panel because it is a property of the packaging
  /// rather than of the food, and it is the figure most often absent.
  final double? servingG;
}

/// One item the model found in a meal.
class ParsedItem {
  const ParsedItem({
    required this.food,
    required this.quantity,
    required this.unit,
    this.grams,
    this.confidence = 0.6,
  });

  final ParsedFood food;
  final double quantity;
  final PortionUnit unit;

  /// Grams, where the model was willing to commit to a figure.
  ///
  /// Null means "resolve this the ordinary way" — through the food's own piece
  /// weight and the unit table in `portion.dart`, which are better than a
  /// guess for anything the device already knows.
  final double? grams;

  /// 0..1 confidence in the *portion*, distinct from the food's own.
  final double confidence;
}

/// The result of parsing a line of free text.
class ParsedMeal {
  const ParsedMeal({required this.items, this.unrecognised = const []});

  final List<ParsedItem> items;

  /// Fragments the model could not turn into food.
  ///
  /// Surfaced rather than silently dropped: a meal that logs three of four
  /// things and says nothing about the fourth is worse than one that admits
  /// it did not understand "and a bit of the leftovers".
  final List<String> unrecognised;

  bool get isEmpty => items.isEmpty;
}

/// The result of asking the model what a vague portion weighs.
class PortionEstimate {
  const PortionEstimate({
    required this.grams,
    required this.confidence,
    this.note,
  });

  final double grams;

  /// 0..1. Never 1: this is an estimate of something nobody weighed.
  final double confidence;

  /// A short plain-language justification, shown so the number can be
  /// disbelieved rather than merely accepted.
  final String? note;
}
