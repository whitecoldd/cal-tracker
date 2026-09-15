import 'dart:convert';

import '../../domain/nutrition.dart';
import '../../domain/parsed_meal.dart';
import '../../domain/portion.dart';

/// Turns an OpenRouter reply into the app's own types.
///
/// Separated from the client so every decoding rule is testable against a
/// captured payload with no network in the room — which matters here more than
/// usual, because a decode failure costs a call against a 50-a-day budget and
/// is therefore expensive to discover on a phone.
///
/// The posture throughout is **distrustful**. The schema is strict, but a model
/// can still return a number where the schema says number and have it be
/// nonsense; so every figure is clamped to something physically possible
/// rather than taken on faith.
abstract final class AiDecode {
  /// Pulls the assistant's message out of a chat-completions body.
  static String? content(Map<String, dynamic> body) {
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) return null;

    final first = choices.first;
    if (first is! Map) return null;

    final message = first['message'];
    if (message is! Map) return null;

    final text = message['content'];
    if (text is! String || text.trim().isEmpty) return null;
    return text;
  }

  /// Decodes the message body as a JSON object.
  ///
  /// Tolerates a fenced block, because a model occasionally wraps JSON in
  /// ```` ```json ```` despite being told not to. That is the *only* leniency
  /// here — anything past it is a failure, not something to salvage.
  static Map<String, dynamic> json(String content) {
    var text = content.trim();

    if (text.startsWith('```')) {
      final firstBreak = text.indexOf('\n');
      final lastFence = text.lastIndexOf('```');
      if (firstBreak != -1 && lastFence > firstBreak) {
        text = text.substring(firstBreak + 1, lastFence).trim();
      }
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }
    return decoded;
  }

  /// Decodes a parsed meal.
  static ParsedMeal meal(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <ParsedItem>[];

    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final item = _item(raw.cast<String, dynamic>());
        if (item != null) items.add(item);
      }
    }

    final rawUnrecognised = json['unrecognised'];
    final unrecognised = <String>[
      if (rawUnrecognised is List)
        for (final fragment in rawUnrecognised)
          if (fragment is String && fragment.trim().isNotEmpty) fragment.trim(),
    ];

    return ParsedMeal(items: items, unrecognised: unrecognised);
  }

  static ParsedItem? _item(Map<String, dynamic> json) {
    final rawFood = json['food'];
    if (rawFood is! Map) return null;

    final food = _food(rawFood.cast<String, dynamic>());
    if (food == null) return null;

    final quantity = _positive(json['quantity']) ?? 1;
    final unit = _unit(json['unit']);

    return ParsedItem(
      food: food,
      quantity: quantity,
      unit: unit,
      grams: _positive(json['grams']),
      confidence: _confidence(json['confidence']),
    );
  }

  static ParsedFood? _food(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    final brand = (json['brand'] as String?)?.trim();

    return ParsedFood(
      name: name,
      brand: (brand == null || brand.isEmpty) ? null : brand,
      confidence: _confidence(json['confidence']),
      panel: FoodPanel(
        // Energy above about 900 kcal/100 g is impossible — pure fat is 900.
        kcal: _clamp(json['kcal'], 0, 900),
        proteinG: _clamp(json['protein_g'], 0, 100),
        carbsG: _clamp(json['carbs_g'], 0, 100),
        sugarG: _clamp(json['sugar_g'], 0, 100),
        fatG: _clamp(json['fat_g'], 0, 100),
        satFatG: _clamp(json['sat_fat_g'], 0, 100),
        fibreG: _clamp(json['fibre_g'], 0, 100),
        sodiumMg: _clamp(json['sodium_mg'], 0, 40000),
        novaGroup: _range(json['nova_group'], 1, 4),
        glycemicIndex: _range(json['glycemic_index'], 0, 150),
      ),
    );
  }

  /// Decodes a portion estimate.
  static PortionEstimate portion(Map<String, dynamic> json) {
    final note = (json['note'] as String?)?.trim();

    return PortionEstimate(
      // Five kilograms of one food in one sitting is not a portion.
      grams: _clamp(json['grams'], 0, 5000),
      // Capped below certainty whatever the model claims: nobody weighed this,
      // and an estimate that presents itself as exact invites the user to stop
      // correcting it.
      confidence: _confidence(json['confidence']).clamp(0.0, 0.85),
      note: (note == null || note.isEmpty) ? null : note,
    );
  }

  /// Decodes the weekly narrative.
  static String? narrative(Map<String, dynamic> json) {
    final text = (json['text'] as String?)?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  // --- coercion helpers ---

  static double _clamp(Object? value, double low, double high) {
    final number = _number(value);
    if (number == null || number.isNaN) return low;
    return number.clamp(low, high);
  }

  static int? _range(Object? value, int low, int high) {
    final number = _number(value);
    if (number == null || number.isNaN) return null;
    final rounded = number.round();
    return (rounded < low || rounded > high) ? null : rounded;
  }

  static double? _positive(Object? value) {
    final number = _number(value);
    if (number == null || number.isNaN || number <= 0) return null;
    return number;
  }

  static double _confidence(Object? value) {
    final number = _number(value);
    // A model that omits confidence is not confident.
    if (number == null || number.isNaN) return 0.5;
    return number.clamp(0.0, 1.0);
  }

  /// Accepts a number or a numeric string.
  ///
  /// Models occasionally answer `"12"` for a number field even under a strict
  /// schema, and losing a whole meal to a pair of quotes would cost a call.
  static double? _number(Object? value) => switch (value) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s.trim()),
        _ => null,
      };

  /// Maps a unit name back onto the enum, falling back to grams.
  ///
  /// The schema constrains this to the enum's own names, so a miss means the
  /// model ignored the schema — in which case grams plus the model's own
  /// `grams` figure is the least-wrong reading.
  static PortionUnit _unit(Object? value) {
    if (value is! String) return PortionUnit.grams;
    final name = value.trim().toLowerCase();

    for (final unit in PortionUnit.values) {
      if (unit.name.toLowerCase() == name) return unit;
      if (unit.label.toLowerCase() == name) return unit;
      if (unit.short.toLowerCase() == name) return unit;
    }
    return PortionUnit.grams;
  }
}
