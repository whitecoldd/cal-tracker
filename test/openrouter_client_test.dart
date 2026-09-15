import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cal_tracker/data/ai/ai_key_store.dart';
import 'package:cal_tracker/data/ai/openrouter_client.dart';
import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/domain/portion.dart';
import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// One canned reply.
class _Reply {
  const _Reply.ok(this.body) : status = 200;
  const _Reply.status(this.status) : body = '{}';

  final int status;
  final String body;
}

/// Stands in for the network.
///
/// No test in this file may reach OpenRouter: a real call would need a real
/// key, and a key must never be in the repo (CLAUDE.md §2). It would also cost
/// one of fifty daily requests per run, which is not a budget a test suite can
/// draw on.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.replies);

  /// One reply per request, in order. Runs out deliberately rather than
  /// repeating, so a test that makes an unexpected extra call fails loudly.
  final List<_Reply> replies;

  final List<Map<String, dynamic>> requests = [];
  final List<Map<String, List<String>>> headers = [];

  int get callCount => requests.length;

  /// The models asked, in the order they were asked.
  List<String> get modelsTried =>
      requests.map((r) => r['model'] as String).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // At the adapter layer Dio has not serialised the body yet, so `data` is
    // still the map the client built. Handle both shapes so the fake does not
    // depend on where in the pipeline it is installed.
    final data = options.data;
    requests.add(
      data is String
          ? jsonDecode(data) as Map<String, dynamic>
          : Map<String, dynamic>.from(data as Map),
    );
    headers.add({
      for (final entry in options.headers.entries)
        entry.key: [entry.value.toString()],
    });

    if (requests.length > replies.length) {
      throw StateError('unexpected call ${requests.length}');
    }

    final reply = replies[requests.length - 1];
    return ResponseBody.fromString(
      reply.body,
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A well-formed chat-completions reply carrying [payload] as JSON.
String _reply(Object payload) => jsonEncode({
      'choices': [
        {
          'message': {'role': 'assistant', 'content': jsonEncode(payload)},
        },
      ],
      'usage': {'prompt_tokens': 300, 'completion_tokens': 50},
    });

final _mealPayload = {
  'items': [
    {
      'food': {
        'name': 'Egg, whole',
        'brand': null,
        'kcal': 143,
        'protein_g': 12.6,
        'carbs_g': 0.7,
        'sugar_g': 0.4,
        'fat_g': 9.5,
        'sat_fat_g': 3.1,
        'fibre_g': 0,
        'sodium_mg': 142,
        'nova_group': 1,
        'glycemic_index': null,
        'confidence': 0.9,
      },
      'quantity': 2,
      'unit': 'piece',
      'grams': null,
      'confidence': 0.9,
    },
  ],
  'unrecognised': <String>[],
};

const _portionPayload = {
  'grams': 30,
  'confidence': 0.7,
  'note': 'a cupped handful',
};

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  ({OpenRouterClient client, _FakeAdapter adapter}) build({
    required List<_Reply> replies,
    String? key = 'sk-or-v1-testtesttesttesttest',
    bool purchased = false,
  }) {
    final adapter = _FakeAdapter(replies);
    final dio = Dio()..httpClientAdapter = adapter;

    return (
      client: OpenRouterClient(
        keys: InMemoryAiKeyStore(key: key, purchased: purchased),
        calls: db.aiCallsDao,
        dio: dio,
        timeout: const Duration(seconds: 2),
      ),
      adapter: adapter,
    );
  }

  group('without a key', () {
    test('refuses before touching the network', () async {
      // The app is fully usable with no key. Refusing here rather than failing
      // at the request is what makes that true.
      final built = build(replies: [], key: null);

      await expectLater(
        built.client.parseMeal('two eggs'),
        throwsA(isA<AiNoKey>()),
      );
      expect(built.adapter.callCount, 0);
    });

    test('nothing is recorded against the budget', () async {
      final built = build(replies: [], key: null);

      try {
        await built.client.parseMeal('two eggs');
        fail('expected AiNoKey');
      } on AiNoKey {
        // Expected: nothing was attempted, so nothing was spent.
      }

      expect(await db.aiCallsDao.usedToday(), 0);
    });
  });

  group('the model chain', () {
    test('uses the first model when it answers', () async {
      final built = build(replies: [_Reply.ok(_reply(_mealPayload))]);

      final meal = await built.client.parseMeal('two eggs');

      expect(meal.items.single.food.name, 'Egg, whole');
      expect(built.adapter.modelsTried, [OpenRouterClient.defaultModels.first]);
    });

    test('falls through to the next model on an HTTP error', () async {
      final built = build(replies: [
        const _Reply.status(429),
        _Reply.ok(_reply(_mealPayload)),
      ]);

      final meal = await built.client.parseMeal('two eggs');

      expect(meal.items, hasLength(1));
      expect(built.adapter.modelsTried, [
        OpenRouterClient.defaultModels[0],
        OpenRouterClient.defaultModels[1],
      ]);
    });

    test('falls through when a model returns unusable content', () async {
      // A schema violation is the model's fault, not the network's.
      final built = build(replies: [
        _Reply.ok(jsonEncode({
          'choices': [
            {
              'message': {'content': 'Sorry, I cannot do that.'},
            },
          ],
        })),
        _Reply.ok(_reply(_mealPayload)),
      ]);

      final meal = await built.client.parseMeal('two eggs');

      expect(meal.items, hasLength(1));
      expect(built.adapter.callCount, 2);
    });

    test('gives up once every model has failed', () async {
      final built = build(replies: [
        const _Reply.status(500),
        const _Reply.status(500),
        const _Reply.status(500),
      ]);

      await expectLater(
        built.client.parseMeal('two eggs'),
        throwsA(isA<AiUnreachable>()),
      );
      expect(built.adapter.callCount, 3);
    });

    test('tries the chain in the documented order', () async {
      final built = build(replies: [
        const _Reply.status(500),
        const _Reply.status(500),
        _Reply.ok(_reply(_mealPayload)),
      ]);

      await built.client.parseMeal('two eggs');

      expect(built.adapter.modelsTried, OpenRouterClient.defaultModels);
    });
  });

  /// Records [count] calls earlier today.
  ///
  /// Earlier matters: recording them at the current instant would also trip
  /// the per-minute limit, and the test would pass for the wrong reason.
  Future<void> recordEarlierToday(int count, {required DateTime today}) async {
    await withClock(
      Clock.fixed(DateTime(today.year, today.month, today.day, 6)),
      () async {
        for (var i = 0; i < count; i++) {
          await db.aiCallsDao.record(
            model: 'test',
            purpose: AiPurpose.parseText,
            succeeded: true,
          );
        }
      },
    );
  }

  group('the budget', () {
    test('every attempt is recorded, including the failures', () async {
      // OpenRouter charges the rate limit against the request, not the result,
      // so a failed call is a spent call.
      final built = build(replies: [
        const _Reply.status(500),
        _Reply.ok(_reply(_mealPayload)),
      ]);

      await built.client.parseMeal('two eggs');

      expect(await db.aiCallsDao.usedToday(), 2);
    });

    test('refuses once the day is spent, without calling', () async {
      final noon = DateTime(2026, 9, 15, 12);

      await withClock(Clock.fixed(noon), () async {
        await recordEarlierToday(50, today: noon);

        final built = build(replies: [_Reply.ok(_reply(_mealPayload))]);

        await expectLater(
          built.client.parseMeal('two eggs'),
          throwsA(
            isA<AiBudgetSpent>().having(
              (e) => e.message,
              'message',
              contains('50 requests are spent'),
            ),
          ),
        );
        // The point of checking before the request: the limit is something the
        // app sees coming, not a surprise failure mid-meal.
        expect(built.adapter.callCount, 0);
      });
    });

    test('a purchased balance raises the cap', () async {
      final noon = DateTime(2026, 9, 15, 12);

      await withClock(Clock.fixed(noon), () async {
        await recordEarlierToday(50, today: noon);

        final built = build(
          replies: [_Reply.ok(_reply(_mealPayload))],
          purchased: true,
        );

        final meal = await built.client.parseMeal('two eggs');
        expect(meal.items, hasLength(1));
      });
    });

    test('refuses when the per-minute limit is hit', () async {
      await withClock(Clock.fixed(DateTime(2026, 9, 15, 12)), () async {
        for (var i = 0; i < 20; i++) {
          await db.aiCallsDao.record(
            model: 'test',
            purpose: AiPurpose.parseText,
            succeeded: true,
          );
        }

        final built = build(replies: [_Reply.ok(_reply(_mealPayload))]);

        await expectLater(
          built.client.parseMeal('two eggs'),
          throwsA(isA<AiBudgetSpent>()),
        );
        expect(built.adapter.callCount, 0);
      });
    });

    test('reports what is left', () async {
      await db.aiCallsDao.record(
        model: 'test',
        purpose: AiPurpose.parseText,
        succeeded: true,
      );

      final budget = await build(replies: []).client.budget();

      expect(budget.usedToday, 1);
      expect(budget.dailyLimit, 50);
      expect(budget.remainingToday, 49);
      expect(budget.canCall, isTrue);
    });
  });

  group('the request itself', () {
    test('is constrained to a strict JSON schema', () async {
      // Never parse prose. A malformed reply costs a retry, and a retry is a
      // call. See CLAUDE.md §4.
      final built = build(replies: [_Reply.ok(_reply(_mealPayload))]);
      await built.client.parseMeal('two eggs');

      final format =
          built.adapter.requests.single['response_format'] as Map<String, dynamic>;

      expect(format['type'], 'json_schema');
      final schema = format['json_schema'] as Map<String, dynamic>;
      expect(schema['strict'], isTrue);
      expect(schema['name'], 'parsed_meal');
    });

    test('carries the key as a bearer token', () async {
      final built = build(replies: [_Reply.ok(_reply(_mealPayload))]);
      await built.client.parseMeal('two eggs');

      expect(
        built.adapter.headers.single['Authorization']!.single,
        'Bearer sk-or-v1-testtesttesttesttest',
      );
    });

    test('is deterministic', () async {
      // Extraction, not writing.
      final built = build(replies: [_Reply.ok(_reply(_mealPayload))]);
      await built.client.parseMeal('two eggs');

      expect(built.adapter.requests.single['temperature'], 0);
    });

    test('sends the user text and the system rules', () async {
      final built = build(replies: [_Reply.ok(_reply(_mealPayload))]);
      await built.client.parseMeal('two eggs and a slice of rye');

      final messages =
          built.adapter.requests.single['messages'] as List<dynamic>;
      final system = (messages.first as Map)['content'] as String;
      final user = (messages.last as Map)['content'] as String;

      expect(system, contains('Never diagnose'));
      expect(user, contains('two eggs and a slice of rye'));
    });

    test('no request carries verdict data', () async {
      // The blackout, asserted on the wire rather than only in the prompt
      // builders. See CLAUDE.md §1.
      final built = build(replies: [
        _Reply.ok(_reply(_mealPayload)),
        _Reply.ok(_reply(_portionPayload)),
      ]);

      await built.client.parseMeal('two eggs');
      await built.client.estimatePortion(
        foodName: 'Almonds',
        quantity: 1,
        unit: PortionUnit.handful,
      );

      final wire = jsonEncode(built.adapter.requests).toLowerCase();
      for (final leak in const [
        'tdee',
        'deficit',
        'surplus',
        'maintenance',
        'weight trend',
        'body fat',
        'bmr',
      ]) {
        expect(wire.contains(leak), isFalse, reason: 'leaked "$leak"');
      }
    });
  });

  group('empty input', () {
    test('an empty line costs no call', () async {
      final built = build(replies: []);

      final meal = await built.client.parseMeal('   ');

      expect(meal.isEmpty, isTrue);
      expect(built.adapter.callCount, 0);
      expect(await db.aiCallsDao.usedToday(), 0);
    });
  });

  group('portion estimation', () {
    test('decodes an estimate', () async {
      final built = build(replies: [_Reply.ok(_reply(_portionPayload))]);

      final estimate = await built.client.estimatePortion(
        foodName: 'Almonds',
        quantity: 1,
        unit: PortionUnit.handful,
      );

      expect(estimate.grams, 30);
      expect(estimate.note, 'a cupped handful');
    });

    test('is attributed to its own purpose in the log', () async {
      final built = build(replies: [_Reply.ok(_reply(_portionPayload))]);

      await built.client.estimatePortion(
        foodName: 'Almonds',
        quantity: 1,
        unit: PortionUnit.handful,
      );

      // Every call is attributed so the budget is explainable rather than
      // just a number.
      final calls = await db.aiCallsDao.select(db.aiCalls).get();
      expect(calls.single.purpose, AiPurpose.estimatePortion);
      expect(calls.single.succeeded, isTrue);
      expect(calls.single.promptTokens, 300);
    });
  });
}
