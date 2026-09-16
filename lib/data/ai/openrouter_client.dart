import 'dart:async';

import 'package:dio/dio.dart';

import '../../domain/parsed_meal.dart';
import '../../domain/portion.dart';
import '../../domain/week_summary.dart';
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

/// What OpenRouter says about a key, as opposed to what a model says.
class AiKeyStanding {
  const AiKeyStanding({required this.isFreeTier});

  /// True while the account has never had credit on it.
  ///
  /// The only field read from the reply. It decides the request cap: 50 a day
  /// free, 1,000 once anything has been bought.
  final bool isFreeTier;

  int get dailyLimit =>
      isFreeTier ? AiCallsDao.freeDailyLimit : AiCallsDao.paidDailyLimit;
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

  /// Where OpenRouter describes the key itself rather than answering with a
  /// model. Not an inference endpoint — see [keyStanding].
  static const String keyEndpoint = 'https://openrouter.ai/api/v1/key';

  /// Whether a key exists at all. Cheap, and drives whether the UI offers AI.
  Future<bool> get hasKey async => await _keys.read() != null;

  Future<AiBudget> budget() async =>
      _calls.budget(hasPurchasedCredit: await _keys.hasPurchasedCredit());

  /// Asks OpenRouter what this key is, so the cap does not have to be guessed.
  ///
  /// The daily allowance is 50 requests at a zero balance and 1,000 once any
  /// credit has been bought. The app has known both numbers since T8 and had no
  /// way to tell which applied — `setPurchasedCredit` existed, with a secure
  /// storage slot behind it, and nothing ever called it. So a key with credit
  /// on it was told it had fifty requests a day, and the app would refuse to
  /// read a meal that OpenRouter would happily have answered.
  ///
  /// > **This is not a fifth AI use case.** CLAUDE.md §4 caps *inference* at
  /// > four purposes and this asks no model anything — it reads account
  /// > metadata, the way checking a balance is not a purchase. It is deliberately
  /// > not written to `ai_calls`: that table is the generation budget, and
  /// > recording a metadata read there would make the app spend a request to
  /// > find out how many requests it has.
  ///
  /// Returns null for *unknown*, which is different from free: unreachable, a
  /// rejected key, a body that does not carry the field, or a field of an
  /// unexpected type all mean the caller should leave whatever is stored alone
  /// rather than quietly demoting a paid key to 50 because the network blinked.
  Future<AiKeyStanding?> keyStanding() async {
    final key = await _keys.read();
    if (key == null) return null;

    try {
      final response = await _dio
          .get<Map<String, dynamic>>(
            keyEndpoint,
            options: Options(
              headers: {
                'Authorization': 'Bearer $key',
                'HTTP-Referer': 'https://github.com/whitecoldd/cal-tracker',
                'X-Title': "The Witcher's Diet",
              },
              validateStatus: (_) => true,
            ),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = response.data?['data'];
      if (data is! Map) return null;

      // Only this one field is trusted. `usage` and `limit` describe money and
      // move with spending; the tier is the thing the request cap follows, and
      // reading one number rather than three leaves less to be wrong about
      // somebody else's JSON.
      final free = data['is_free_tier'];
      if (free is! bool) return null;

      return AiKeyStanding(isFreeTier: free);
    } catch (_) {
      // Terminal on purpose, as in T16 and T26: this is somebody else's JSON
      // over somebody else's network, and no failure here is worth surfacing
      // on a settings screen. Unknown is a safe answer.
      return null;
    }
  }

  /// Asks, and writes the answer down if there was one.
  ///
  /// Returns what is stored afterwards, which is the previous value when the
  /// question could not be answered.
  Future<bool> refreshKeyStanding() async {
    final standing = await keyStanding();
    if (standing == null) return _keys.hasPurchasedCredit();

    await _keys.setPurchasedCredit(value: !standing.isFreeTier);
    return !standing.isFreeTier;
  }

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

  /// Reads the nutrition table off a photograph of a package.
  ///
  /// The fifth permitted use, added deliberately against the budget in
  /// CLAUDE.md §4. The case for it: Open Food Facts is thin outside western
  /// Europe, and a barcode it has never heard of used to leave the user typing
  /// eight figures off small print by hand. One call turns a packet into a row
  /// that is then **permanent** — the write-back rule means a product read this
  /// way is never read again, so the steady-state cost is one call per new
  /// product in the user's life rather than one per log.
  ///
  /// Returns null when nothing usable was read, including when the model says
  /// the panel was not legible. The call is spent either way; a retry would
  /// spend a second one on the same blurred photograph, so the sheet asks for
  /// a better picture instead.
  Future<LabelReading?> readLabel({
    required String imageDataUri,
    String? barcode,
  }) async {
    final json = await _structured(
      purpose: AiPurpose.readLabel,
      system: Prompts.labelSystem(),
      user: [
        {'type': 'text', 'text': Prompts.labelUser(barcode: barcode)},
        {
          'type': 'image_url',
          'image_url': {'url': imageDataUri},
        },
      ],
      schema: AiSchemas.label,
    );

    return AiDecode.label(json);
  }

  /// Writes the single weekly account.
  ///
  /// The fourth and last permitted use, and the **only** call given verdict
  /// data. It takes [NarrativeFacts], which cannot be constructed from a week
  /// that is still sealed — so there is no way to write code that asks a model
  /// to describe a week before it closes. See CLAUDE.md §1.
  ///
  /// Returns null if the model answered with nothing usable. The reveal screen
  /// simply shows no narrative rather than spending another call retrying: one
  /// per week is the whole budget for this.
  Future<String?> weeklyNarrative(NarrativeFacts facts) async {
    final json = await _structured(
      purpose: AiPurpose.weeklyNarrative,
      system: Prompts.narrativeSystem(),
      user: Prompts.narrativeUser(facts),
      schema: AiSchemas.narrative,
    );

    return AiDecode.narrative(json);
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
