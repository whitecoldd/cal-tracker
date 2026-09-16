/// Every prompt the app sends, as pure functions.
///
/// Pure so the two rules that matter most can be *tested* rather than merely
/// intended:
///
/// - **No daily prompt is given verdict data.** A model cannot leak a figure it
///   was never told, so TDEE, weight, weight trend and energy balance never
///   appear in a prompt except the weekly narrative, which runs only on the
///   reveal day. See CLAUDE.md §1.
/// - **No prompt invites a diagnosis.** Harm is lore drawn from public data,
///   never a claim about this person's body. See CLAUDE.md §7.
library;

import '../../domain/portion.dart';
import '../../domain/week_summary.dart';

abstract final class Prompts {
  /// Shared preamble. Every call carries it.
  ///
  /// The "never diagnose" clause lives here rather than in each prompt so a new
  /// use cannot be added without it.
  static const String _house = '''
You are a nutrition data extractor inside an offline-first food tracker.

Rules you must follow exactly:
- Reply only with JSON matching the provided schema. Never add prose.
- Use per-100g figures for nutrients, in grams, except energy in kcal and
  sodium in milligrams.
- If you are unsure of a value, give your best estimate and lower the
  confidence. Never invent precision.
- Never diagnose, warn about, or comment on the health of the person eating.
  Do not describe food as healthy, unhealthy, good or bad. You are describing
  food, not judging a person.
- You are never told anything about the user's weight, body or energy needs,
  and must not ask for them or speculate about them.''';

  /// System prompt for turning a typed line into items.
  static String mealParsingSystem() => '''
$_house

Task: split a line of everyday text into the foods it names.
- Keep the user's own phrasing for each food name where it is a real food.
- Prefer generic foods over brands unless a brand is named.
- quantity/unit should mirror how the user said it: "two eggs" is
  quantity 2, unit "piece". Only give grams when you are confident.
- Put any fragment you cannot turn into a food into "unrecognised".''';

  /// The user's line, as the model sees it.
  static String mealParsingUser(String text) => 'Meal: $text';

  /// System prompt for reading a photograph of a meal.
  ///
  /// The composite-dish clause is not a loosening of the "only what you can
  /// see" rule, it is the rule applied honestly. A stew, a bake or a curry is
  /// a thing you *can* see; its components are by definition not individually
  /// visible, and a model told to name only what is visible will either return
  /// one opaque item or nothing at all. What keeps it truthful is that an
  /// inferred component must carry a lower confidence, which the app already
  /// surfaces as a portion worth correcting.
  static String photoSystem() => '''
$_house

Task: list the foods in a photograph of a meal.
- Name only what you can actually see. Do not infer a side dish that is out
  of frame or guess at a sauce you cannot identify.
- If the photograph shows a single cooked dish rather than separate foods on
  a plate, name the dish and break it into the components it is ordinarily
  made of. Give every component you did not see directly a confidence of 0.5
  or below, and prefer fewer, larger components over a long invented recipe.
- Estimate portions from the plate and the usual size of what is on it.
  Lower the confidence when the angle hides depth.
- Put anything you can see but cannot identify into "unrecognised",
  described in plain words such as "a brown sauce".
- If the picture is not of food, return no items.''';

  /// The instruction sent alongside the image.
  static String photoUser(String? note) {
    if (note == null || note.trim().isEmpty) {
      return 'List the foods in this photograph.';
    }
    // The cook's own description, which outweighs anything the model can infer
    // from pixels — it is the only source in the whole exchange that was
    // actually present when the food was made.
    return 'List the foods in this photograph. '
        'The person who cooked and ate it adds: ${note.trim()}';
  }

  /// System prompt for estimating what a vague portion weighs.
  static String portionSystem() => '''
$_house

Task: estimate the weight in grams of a described portion of one food.
- Answer for a typical adult serving as the phrase is ordinarily used.
- confidence must be below 0.9: nobody weighed this.
- note: one short clause saying what you assumed, for example
  "a cupped handful, about 30 g".''';

  /// The portion question, as the model sees it.
  ///
  /// Carries the food and the phrasing and **nothing else**. There is
  /// deliberately no body mass, no goal and no daily total here: the answer is
  /// a property of the food and the words, not of the person.
  static String portionUser({
    required String foodName,
    required double quantity,
    required PortionUnit unit,
    double? gramsPerPiece,
    String? pieceName,
  }) {
    final buffer = StringBuffer()
      ..writeln('Food: $foodName')
      ..writeln('Portion as described: $quantity ${unit.label}');

    if (gramsPerPiece != null) {
      final name = pieceName ?? 'piece';
      buffer.writeln('One $name of this food weighs about ${gramsPerPiece}g.');
    }

    return buffer.toString().trim();
  }

  /// The week's figures, as the model sees them.
  ///
  /// Takes [NarrativeFacts] rather than loose numbers because that type cannot
  /// be built from a sealed week — so this function physically cannot be
  /// called about a week still in progress.
  static String narrativeUser(NarrativeFacts facts) {
    final buffer = StringBuffer()
      ..writeln('Days logged: ${facts.loggedDays} of 7')
      ..writeln(
        'Energy balance: ${facts.energyBalanceKcal.round()} kcal across the '
        'week (${facts.averageDailyBalanceKcal.round()} a day)',
      )
      ..writeln(
        'Projected change from that balance: '
        '${facts.projectedChangeKg.toStringAsFixed(2)} kg',
      )
      ..writeln('Average diet quality: ${facts.averageVitality.round()} of 100')
      ..writeln('Steps: ${facts.steps}');

    final delta = facts.weightDeltaKg;
    if (delta != null) {
      buffer.writeln('Measured weight change: ${delta.toStringAsFixed(2)} kg');
    } else {
      buffer.writeln('Measured weight change: not enough weigh-ins');
    }

    final trend = facts.trend;
    if (trend != null) buffer.writeln('Direction: ${trend.label}');

    return buffer.toString().trim();
  }

  /// System prompt for the single weekly narrative.
  ///
  /// The **only** prompt permitted to receive verdict data, and only on the
  /// reveal day. Everything else in this class is written so that a model
  /// could not leak a trend if it wanted to, because it was never told one.
  static String narrativeSystem() => '''
$_house

Exception to the rules above, for this task only: you are given the week's
figures because the week has closed and the user is reading them now.

Task: write a short account of the week in the voice of a witcher's journal.
- Three to five sentences. No lists, no headings.
- State what happened plainly. Do not congratulate or scold.
- Do not give medical advice or predict health outcomes.
- Do not suggest a target for next week.''';
}
