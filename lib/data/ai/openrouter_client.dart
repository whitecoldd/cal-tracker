import 'dart:async';

import 'package:dio/dio.dart';

import '../../domain/parsed_meal.dart';
import '../../domain/portion.dart';
import '../daos/ai_calls_dao.dart';
import '../tables.dart';
import 'ai_decode.dart';
import 'ai_key_store.dart';
import 'ai_schemas.dart';
import 'prompts.dart';

/// Why a call could not be made, or did not survive.
///
/// A sealed hierarchy because the UI must say something *different* for each:
/// "add a key in Settings" and "you have used today's 50" and "the model is
/// unreachable" are three different situations and only one of them is worth
/// retrying.
sealed class AiFailure implements Exception {
  const AiFailure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// No key has been entered. The app is fully usable in this state.
final class AiNoKey extends AiFailure {
  const AiNoKey() : super('No OpenRouter key has been entered.');
}

/// Today's allowance is gone, or the per-minute limit is hit.
final class AiBudgetSpent extends AiFailure {
  const AiBudgetSpent(super.message, {required this.budget});
  final AiBudget budget;
}

/// Every model in the chain failed, or the network is down.
final class AiUnreachable extends AiFailure {
  const AiUnreachable(super.message);
}

/// A reply arrived but did not match the schema.
final class AiUnreadable extends AiFailure {
  const AiUnreadable(super.message);
}

/// OpenRouter, over its OpenAI-compatible chat completions API.
///
/// Three rules shape this class, all from CLAUDE.md §4:
///
/// - **The budget is checked before the request, not after.** 50 calls a day is
///   low enough that hitting the limit has to be something the app sees coming
///   rather than a surprise failure mid-meal.
/// - **Every attempt is recorded**, successful or not. OpenRouter charges the
///   rate limit against the request, so a failed call is a spent call.
/// - **Every response is schema-constrained.** Nothing here parses prose; a
///   malformed reply is a failure, not something to salvage, because salvaging
///   it would cost a retry and a retry is a call.
class OpenRouterClient {
  OpenRouterClient({
    required AiKeyStore keys,
    required AiCallsDao calls,
    Dio? dio,
    List<String>? models,
    Duration timeout = const Duration(seconds: 45),
  })  : _keys = keys,
        _calls = calls,
        _models = models ?? defaultModels,
        _dio = dio ?? Dio(),
        _timeout = timeout;

  final AiKeyStore _keys;
  final AiCallsDao _calls;
  final List<String> _models;
  final Dio _dio;
  final Duration _timeout;

  /// The fallback chain, best first. All three take images and structured
  /// output, so T9's photo parsing can use the same order.
  static const List<String> defaultModels = [
    'nex-agi/nex-n2.5-pro:free',
    'inclusionai/ling-3.0-flash-vl:free',
    'dots-studio/dots-3-note-preview:free',
  ];

  static const String endpoint =
      'https://openrouter.ai/api/v1/chat/completions';

  /// Whether a key exists at all. Cheap, and drives whether the UI offers AI.
  Future<bool> get hasKey async => await _keys.read() != null;

  Future<AiBudget> budget() async =>
      _calls.budget(hasPurchasedCredit: await _keys.hasPurchasedCredit());

  /// Turns a line of everyday text into items.
  Future<ParsedMeal> parseMeal(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const ParsedMeal(items: []);

    final json = await _structured(
      purpose: AiPurpose.parseText,
      system: Prompts.mealParsingSystem(),
      user: Prompts.mealParsingUser(trimmed),
      schema: AiSchemas.meal,
    );

    return AiDecode.meal(json);
  }

  /// Reads a photograph of a meal into items.
  ///
  /// Shares everything with [parseMeal] but the content type: the same schema,
  /// the same chain, the same budget. A photograph is one request however many
  /// foods are on the plate.
  Future<ParsedMeal> parsePhoto({
    required String imageDataUri,
    String? note,
  }) async {
    final json = await _structured(
      purpose: AiPurpose.parsePhoto,
      system: Prompts.photoSystem(),
      user: [
        {'type': 'text', 'text': Prompts.photoUser(note)},
        {
          'type': 'image_url',
          'image_url': {'url': imageDataUri},
        },
      ],
      schema: AiSchemas.meal,
    );

    return AiDecode.meal(json);
  }

  /// Estimates what a vague portion weighs.
  ///
  /// Given the food and the user's own phrasing and nothing else — the answer
  /// is a property of the words, not of the person eating.
  Future<PortionEstimate> estimatePortion({
    required String foodName,
    required double quantity,
    required PortionUnit unit,
    double? gramsPerPiece,
    String? pieceName,
  }) async {
    final json = await _structured(
      purpose: AiPurpose.estimatePortion,
      system: Prompts.portionSystem(),
      user: Prompts.portionUser(
        foodName: foodName,
        quantity: quantity,
        unit: unit,
        gramsPerPiece: gramsPerPiece,
        pieceName: pieceName,
      ),
      schema: AiSchemas.portion,
    );

    return AiDecode.portion(json);
  }

  /// One request, walking the model chain until one answers.
  ///
  /// [user] is either a plain string or the OpenAI-style list of content
  /// parts that a vision request needs. Both go into the same envelope, so the
  /// chain, the budget and the recording are shared rather than duplicated for
  /// photographs.
  Future<Map<String, dynamic>> _structured({
    required AiPurpose purpose,
    required String system,
    required Object user,
    required Map<String, dynamic> schema,
  }) async {
    final key = await _keys.read();
    if (key == null) throw const AiNoKey();

    final available = await budget();
    if (available.dailyExhausted) {
      throw AiBudgetSpent(
        'Today\'s ${available.dailyLimit} requests are spent.',
        budget: available,
      );
    }
    if (available.rateLimited) {
      throw AiBudgetSpent(
        'More than ${available.perMinuteLimit} requests in the last minute.',
        budget: available,
      );
    }

    Object? lastError;

    for (final model in _models) {
      try {
        final json = await _callOnce(
          key: key,
          model: model,
          system: system,
          user: user,
          schema: schema,
          purpose: purpose,
        );
        return json;
      } on AiUnreadable catch (e) {
        // A schema violation is the model's fault, not the network's — try the
        // next one rather than giving up on the whole chain.
        lastError = e;
      } on DioException catch (e) {
        lastError = e;
      } on TimeoutException catch (e) {
        lastError = e;
      }
    }

    throw AiUnreachable('No model answered. Last error: $lastError');
  }

  /// A single request to one model. Always recorded.
  Future<Map<String, dynamic>> _callOnce({
    required String key,
    required String model,
    required String system,
    required Object user,
    required Map<String, dynamic> schema,
    required AiPurpose purpose,
  }) async {
    try {
      final response = await _dio
          .post<Map<String, dynamic>>(
            endpoint,
            options: Options(
              headers: {
                'Authorization': 'Bearer $key',
                'Content-Type': 'application/json',
                // OpenRouter asks clients to identify themselves.
                'HTTP-Referer': 'https://github.com/whitecoldd/cal-tracker',
                'X-Title': "The Witcher's Diet",
              },
              // Any status is returned rather than thrown, so a 429 can be
              // recorded with its reason instead of surfacing as a bare error.
              validateStatus: (_) => true,
            ),
            data: {
              'model': model,
              'messages': [
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': user},
              ],
              'response_format': {
                'type': 'json_schema',
                'json_schema': schema,
              },
              // Deterministic: this is extraction, not writing.
              'temperature': 0,
            },
          )
          .timeout(_timeout);

      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        await _record(model, purpose, false, error: 'HTTP $status');
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'HTTP $status',
        );
      }

      final body = response.data;
      if (body == null) {
        await _record(model, purpose, false, error: 'empty body');
        throw const AiUnreadable('The model returned an empty body.');
      }

      final usage = body['usage'];
      final content = AiDecode.content(body);
      if (content == null) {
        await _record(model, purpose, false, error: 'no content');
        throw const AiUnreadable('The model returned no content.');
      }

      final Map<String, dynamic> decoded;
      try {
        decoded = AiDecode.json(content);
      } on FormatException catch (e) {
        await _record(model, purpose, false, error: 'bad json: $e');
        throw AiUnreadable('The model did not return JSON: $e');
      }

      await _record(
        model,
        purpose,
        true,
        promptTokens: usage is Map ? usage['prompt_tokens'] as int? : null,
        completionTokens:
            usage is Map ? usage['completion_tokens'] as int? : null,
      );
      return decoded;
    } on TimeoutException {
      await _record(model, purpose, false, error: 'timeout');
      rethrow;
    } on DioException catch (e) {
      // A transport failure that never reached the recording above.
      if (e.response == null) {
        await _record(model, purpose, false, error: 'transport: ${e.type}');
      }
      rethrow;
    }
  }

  Future<void> _record(
    String model,
    AiPurpose purpose,
    bool succeeded, {
    int? promptTokens,
    int? completionTokens,
    String? error,
  }) =>
      _calls.record(
        model: model,
        purpose: purpose,
        succeeded: succeeded,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        error: error,
      );
}
