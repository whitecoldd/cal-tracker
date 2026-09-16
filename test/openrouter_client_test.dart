import 'dart:convert';

import 'package:cal_tracker/data/ai/ai_key_store.dart';
import 'package:cal_tracker/data/ai/openrouter_client.dart';
import 'package:cal_tracker/data/daos/ai_calls_dao.dart';
import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/domain/portion.dart';
import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_openrouter.dart';

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

const _labelPayload = {
  'readable': true,
  'food': {
    'name': 'Salted almonds',
    'brand': 'Banzai',
    'kcal': 607,
    'protein_g': 21.2,
    'carbs_g': 6.9,
    'sugar_g': 4.4,
    'fat_g': 52.5,
    'sat_fat_g': 4.1,
    'fibre_g': 12.5,
    'sodium_mg': 380,
    'nova_group': 3,
    'glycemic_index': 15,
    'confidence': 0.8,
  },
  'serving_g': 30,
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

  ({OpenRouterClient client, FakeOpenRouterAdapter adapter}) build({
    required List<FakeReply> replies,
    String? key = 'sk-or-v1-testtesttesttesttest',
    bool purchased = false,
  }) {
    final adapter = FakeOpenRouterAdapter(replies);
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

  String standingReply({required bool free}) =>
      jsonEncode({'data': {'label': 'test', 'is_free_tier': free}});

  group('what the key is worth', () {
    test('a key with credit raises the cap to a thousand', () async {
      // The gap this closed: paidDailyLimit and the storage slot behind
      // setPurchasedCredit both existed from T8, and nothing ever called it, so
      // a key with credit on it was told it had fifty requests a day.
      final built = build(replies: [FakeReply.ok(standingReply(free: false))]);

      expect(await built.client.refreshKeyStanding(), isTrue);
      expect((await built.client.budget()).dailyLimit,
          AiCallsDao.paidDailyLimit);
    });

    test('a free key keeps the free cap', () async {
      final built = build(replies: [FakeReply.ok(standingReply(free: true))]);

      expect(await built.client.refreshKeyStanding(), isFalse);
      expect((await built.client.budget()).dailyLimit,
          AiCallsDao.freeDailyLimit);
    });

    test('it does not spend a request to ask', () async {
      // CLAUDE.md §4 caps *inference* at four purposes, and this asks no model
      // anything. Recording it would make the app spend a request to find out
      // how many requests it has.
      final built = build(replies: [FakeReply.ok(standingReply(free: false))]);

      await built.client.refreshKeyStanding();

      expect((await built.client.budget()).usedToday, 0);
    });

    test('with no key it does not even ask', () async {
      final built = build(replies: [], key: null);

      expect(await built.client.keyStanding(), isNull);
      expect(built.adapter.callCount, 0);
    });
  });

  group('an unanswerable question never demotes a paid key', () {
    // Every one of these must leave the stored value alone. Returning "free"
    // on a failure would drop a paying user to fifty requests because their
    // train went into a tunnel.
    Future<void> expectKept(FakeReply reply) async {
      final built = build(replies: [reply], purchased: true);

      expect(await built.client.keyStanding(), isNull);
      expect(await built.client.refreshKeyStanding(), isTrue);
      expect((await built.client.budget()).dailyLimit,
          AiCallsDao.paidDailyLimit);
    }

    test('a rejected key', () => expectKept(const FakeReply.status(401)));
    test('a server error', () => expectKept(const FakeReply.status(500)));

    test('a body with no tier in it', () async {
      await expectKept(FakeReply.ok(jsonEncode({'data': {'label': 'x'}})));
    });

    test('a tier of the wrong type', () async {
      await expectKept(
        FakeReply.ok(jsonEncode({'data': {'is_free_tier': 'yes'}})),
      );
    });

    test('a reply that is not the shape at all', () async {
      await expectKept(FakeReply.ok(jsonEncode({'data': 'nothing useful'})));
    });
  });

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
      final built = build(replies: [FakeReply.ok(_reply(_mealPayload))]);

      final meal = await built.client.parseMeal('two eggs');

      expect(meal.items.single.food.name, 'Egg, whole');
      expect(built.adapter.modelsTried, [OpenRouterClient.defaultModels.first]);
    });

    test('falls through to the next model on an HTTP error', () async {
      final built = build(replies: [
        const FakeReply.status(429),
        FakeReply.ok(_reply(_mealPayload)),
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
        FakeReply.ok(jsonEncode({
          'choices': [
            {
              'message': {'content': 'Sorry, I cannot do that.'},
            },
          ],
        })),
        FakeReply.ok(_reply(_mealPayload)),
      ]);

      final meal = await built.client.parseMeal('two eggs');

      expect(meal.items, hasLength(1));
      expect(built.adapter.callCount, 2);
    });

    test('gives up once every model has failed', () async {
      final built = build(replies: [
        const FakeReply.status(500),
        const FakeReply.status(500),
        const FakeReply.status(500),
      ]);

      await expectLater(
        built.client.parseMeal('two eggs'),
        throwsA(isA<AiUnreachable>()),
      );
      expect(built.adapter.callCount, 3);
    });

    test('tries the chain in the documented order', () async {
      final built = build(replies: [
        const FakeReply.status(500),
        const FakeReply.status(500),
        FakeReply.ok(_reply(_mealPayload)),
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
        const FakeReply.status(500),
        FakeReply.ok(_reply(_mealPayload)),
      ]);

      await built.client.parseMeal('two eggs');

      expect(await db.aiCallsDao.usedToday(), 2);
    });

    test('refuses once the day is spent, without calling', () async {
      final noon = DateTime(2026, 9, 15, 12);

      await withClock(Clock.fixed(noon), () async {
        await recordEarlierToday(50, today: noon);

        final built = build(replies: [FakeReply.ok(_reply(_mealPayload))]);

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
          replies: [FakeReply.ok(_reply(_mealPayload))],
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

        final built = build(replies: [FakeReply.ok(_reply(_mealPayload))]);

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
      final built = build(replies: [FakeReply.ok(_reply(_mealPayload))]);
      await built.client.parseMeal('two eggs');

      final format =
          built.adapter.requests.single['response_format'] as Map<String, dynamic>;

      expect(format['type'], 'json_schema');
      final schema = format['json_schema'] as Map<String, dynamic>;
      expect(schema['strict'], isTrue);
      expect(schema['name'], 'parsed_meal');
    });

    test('carries the key as a bearer token', () async {
      final built = build(replies: [FakeReply.ok(_reply(_mealPayload))]);
      await built.client.parseMeal('two eggs');

      expect(
        built.adapter.headers.single['Authorization']!.single,
        'Bearer sk-or-v1-testtesttesttesttest',
      );
    });

    test('is deterministic', () async {
      // Extraction, not writing.
      final built = build(replies: [FakeReply.ok(_reply(_mealPayload))]);
      await built.client.parseMeal('two eggs');

      expect(built.adapter.requests.single['temperature'], 0);
    });

    test('sends the user text and the system rules', () async {
      final built = build(replies: [FakeReply.ok(_reply(_mealPayload))]);
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
        FakeReply.ok(_reply(_mealPayload)),
        FakeReply.ok(_reply(_portionPayload)),
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

  group('reading a photograph', () {
    const dataUri = 'data:image/jpeg;base64,AAAA';

    test('sends the image beside the instruction', () async {
      final built = build(replies: [FakeReply.ok(_reply(_mealPayload))]);

      final meal = await built.client.parsePhoto(imageDataUri: dataUri);

      expect(meal.items.single.food.name, 'Egg, whole');

      final messages =
          built.adapter.requests.single['messages'] as List<dynamic>;
      final parts = (messages.last as Map)['content'] as List<dynamic>;

      expect(parts, hasLength(2));
      expect((parts.first as Map)['type'], 'text');
      expect((parts.last as Map)['type'], 'image_url');
      expect(
        ((parts.last as Map)['image_url'] as Map)['url'],
        dataUri,
      );
    });

    test('is one request, however many foods are on the plate', () async {
      final built = build(replies: [FakeReply.ok(_reply(_mealPayload))]);

      await built.client.parsePhoto(imageDataUri: dataUri);

      expect(built.adapter.callCount, 1);
      expect(await db.aiCallsDao.usedToday(), 1);
    });

    test('carries the user note when there is one', () async {
      final built = build(replies: [FakeReply.ok(_reply(_mealPayload))]);

      await built.client.parsePhoto(
        imageDataUri: dataUri,
        note: 'the sauce is tahini',
      );

      final messages =
          built.adapter.requests.single['messages'] as List<dynamic>;
      final parts = (messages.last as Map)['content'] as List<dynamic>;

      // The user's own hint is usually worth more than anything the model can
      // infer from the pixels.
      expect((parts.first as Map)['text'], contains('tahini'));
    });

    test('omits the note when it is blank', () async {
      final built = build(replies: [FakeReply.ok(_reply(_mealPayload))]);

      await built.client.parsePhoto(imageDataUri: dataUri, note: '   ');

      final messages =
          built.adapter.requests.single['messages'] as List<dynamic>;
      final parts = (messages.last as Map)['content'] as List<dynamic>;

      expect((parts.first as Map)['text'], isNot(contains('adds:')));
    });

    test('shares the schema and the chain with the typed path', () async {
      final built = build(replies: [
        const FakeReply.status(500),
        FakeReply.ok(_reply(_mealPayload)),
      ]);

      await built.client.parsePhoto(imageDataUri: dataUri);

      final format = built.adapter.requests.first['response_format']
          as Map<String, dynamic>;
      expect(
        (format['json_schema'] as Map<String, dynamic>)['name'],
        'parsed_meal',
      );
      expect(built.adapter.modelsTried, [
        OpenRouterClient.defaultModels[0],
        OpenRouterClient.defaultModels[1],
      ]);
    });

    test('is attributed to the photo purpose', () async {
      final built = build(replies: [FakeReply.ok(_reply(_mealPayload))]);

      await built.client.parsePhoto(imageDataUri: dataUri);

      final calls = await db.aiCallsDao.select(db.aiCalls).get();
      expect(calls.single.purpose, AiPurpose.parsePhoto);
    });

    test('refuses without a key, before the image is sent anywhere', () async {
      final built = build(replies: [], key: null);

      await expectLater(
        built.client.parsePhoto(imageDataUri: dataUri),
        throwsA(isA<AiNoKey>()),
      );
      expect(built.adapter.callCount, 0);
    });

    test('carries no verdict data', () async {
      final built = build(replies: [FakeReply.ok(_reply(_mealPayload))]);

      await built.client.parsePhoto(
        imageDataUri: dataUri,
        note: 'leftovers',
      );

      final wire = jsonEncode(built.adapter.requests).toLowerCase();
      for (final leak in const ['tdee', 'deficit', 'surplus', 'bmr']) {
        expect(wire.contains(leak), isFalse, reason: 'leaked "$leak"');
      }
    });
  });

  group('portion estimation', () {
    test('decodes an estimate', () async {
      final built = build(replies: [FakeReply.ok(_reply(_portionPayload))]);

      final estimate = await built.client.estimatePortion(
        foodName: 'Almonds',
        quantity: 1,
        unit: PortionUnit.handful,
      );

      expect(estimate.grams, 30);
      expect(estimate.note, 'a cupped handful');
    });

    test('is attributed to its own purpose in the log', () async {
      final built = build(replies: [FakeReply.ok(_reply(_portionPayload))]);

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

  group('reading a label', () {
    const dataUri = 'data:image/jpeg;base64,AAAA';

    test('returns the panel the pack states', () async {
      final built = build(replies: [FakeReply.ok(_reply(_labelPayload))]);

      final reading = await built.client.readLabel(imageDataUri: dataUri);

      expect(reading!.food.name, 'Salted almonds');
      expect(reading.food.panel.kcal, 607);
      expect(reading.servingG, 30);
    });

    test('sends the image and asks for the label schema', () async {
      final built = build(replies: [FakeReply.ok(_reply(_labelPayload))]);

      await built.client.readLabel(imageDataUri: dataUri);

      final request = built.adapter.requests.single;
      final messages = request['messages'] as List<dynamic>;
      final parts = (messages.last as Map)['content'] as List<dynamic>;

      expect((parts.last as Map)['image_url'], {'url': dataUri});

      final format = request['response_format'] as Map<String, dynamic>;
      expect(
        (format['json_schema'] as Map<String, dynamic>)['name'],
        'label_reading',
      );
    });

    test('passes the barcode when the scan that failed gave one', () async {
      final built = build(replies: [FakeReply.ok(_reply(_labelPayload))]);

      await built.client.readLabel(
        imageDataUri: dataUri,
        barcode: '4840811001867',
      );

      final messages =
          built.adapter.requests.single['messages'] as List<dynamic>;
      final parts = (messages.last as Map)['content'] as List<dynamic>;

      expect((parts.first as Map)['text'], contains('4840811001867'));
    });

    test('a panel it could not read is null, not an empty food', () async {
      final built = build(
        replies: [
          FakeReply.ok(
            _reply({'readable': false, 'food': null, 'serving_g': null}),
          ),
        ],
      );

      // The call is spent either way. What must not happen is a row of zeroes
      // reaching the library under the name of a real product.
      expect(await built.client.readLabel(imageDataUri: dataUri), isNull);
    });

    test('is attributed to its own purpose in the log', () async {
      final built = build(replies: [FakeReply.ok(_reply(_labelPayload))]);

      await built.client.readLabel(imageDataUri: dataUri);

      // The fifth permitted use in CLAUDE.md §4, and countable as such: the
      // budget in Settings is only explainable if each use is separable.
      final calls = await db.aiCallsDao.select(db.aiCalls).get();
      expect(calls.single.purpose, AiPurpose.readLabel);
      expect(calls.single.succeeded, isTrue);
    });

    test('refuses without a key, before the image is sent anywhere', () async {
      final built = build(replies: [], key: null);

      await expectLater(
        built.client.readLabel(imageDataUri: dataUri),
        throwsA(isA<AiNoKey>()),
      );
      expect(built.adapter.callCount, 0);
    });

    test('carries no verdict data', () async {
      final built = build(replies: [FakeReply.ok(_reply(_labelPayload))]);

      await built.client.readLabel(
        imageDataUri: dataUri,
        barcode: '4840811001867',
      );

      // A packet knows nothing about the person holding it, and this request
      // must not either. See CLAUDE.md §1.
      //
      // The same words the photo path is held to. Bare "weight" is not among
      // them on purpose: it appears in the house preamble, in the clause that
      // tells the model it is never told the user's — which is the blackout
      // being stated, not broken.
      final wire = jsonEncode(built.adapter.requests).toLowerCase();
      for (final leak in const ['tdee', 'deficit', 'surplus', 'bmr']) {
        expect(wire.contains(leak), isFalse, reason: 'leaked "$leak"');
      }
    });
  });
}
