import 'dart:convert';
import 'dart:typed_data';

import 'package:cal_tracker/data/ai/ai_key_store.dart';
import 'package:cal_tracker/data/ai/image_prep.dart';
import 'package:cal_tracker/data/ai/openrouter_client.dart';
import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/features/ai/ai_providers.dart';
import 'package:cal_tracker/features/journal/manual_food_sheet.dart';
import 'package:cal_tracker/providers/app_providers.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_openrouter.dart';

/// Stands in for the platform channel, which no widget test can run.
class _FakeCompressor implements PhotoCompressor {
  @override
  Future<Uint8List> compress(Uint8List original) async => original;
}

String _reply(Object payload) => jsonEncode({
      'choices': [
        {
          'message': {'role': 'assistant', 'content': jsonEncode(payload)},
        },
      ],
      'usage': {'prompt_tokens': 300, 'completion_tokens': 50},
    });

/// Banzai salted almonds, the product that started this: a Moldovan barcode
/// Open Food Facts has never held, whose panel is printed on the bag.
const _almonds = {
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

Uint8List _photo() => Uint8List.fromList(List.filled(4096, 7));

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  /// Opens the manual sheet with a fake camera and a fake upstream behind it.
  Future<FakeOpenRouterAdapter> pump(
    WidgetTester tester, {
    List<FakeReply> replies = const [],
    bool hasKey = true,
    Uint8List? photo,
    String? barcode = '4840811001867',
  }) async {
    // Tall on purpose. The sheet is a ListView, so a field scrolled out of the
    // viewport is unmounted and simply cannot be found — and the reader panel
    // grows once it has filled the form, which pushes the fields down by
    // exactly enough to lose the first one. A view that holds the whole form
    // keeps these tests about the filling rather than about scrolling.
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final adapter = FakeOpenRouterAdapter(replies);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          aiAvailableProvider.overrideWith((ref) async => hasKey),
          openRouterClientProvider.overrideWithValue(
            OpenRouterClient(
              keys: InMemoryAiKeyStore(key: 'sk-or-v1-testtesttesttesttest'),
              calls: db.aiCallsDao,
              dio: Dio()..httpClientAdapter = adapter,
              timeout: const Duration(seconds: 2),
            ),
          ),
          // No camera and no gallery. Injecting the whole picking step is what
          // makes everything after it testable at all.
          photoPickerProvider.overrideWithValue(
            (source, {int quality = 85}) async => photo,
          ),
          // The real one is a platform channel; the bytes are irrelevant here
          // because the fake upstream never looks at them.
          imagePrepProvider
              .overrideWithValue(ImagePrep(compressor: _FakeCompressor())),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    ManualFoodSheet.show(context, barcode: barcode),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return adapter;
  }

  group('reading the packet', () {
    testWidgets('fills the form from the panel it photographed',
        (tester) async {
      // The whole point of the feature: a product no ledger carries, turned
      // into a row without typing eight figures off small print.
      await pump(
        tester,
        replies: [FakeReply.ok(_reply(_almonds))],
        photo: _photo(),
      );

      await tester.tap(find.text('PHOTOGRAPH'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Salted almonds'), findsOne);
      expect(find.widgetWithText(TextFormField, 'Banzai'), findsOne);
      expect(find.widgetWithText(TextFormField, '607'), findsOne);
      expect(find.widgetWithText(TextFormField, '21.2'), findsOne);
      expect(find.widgetWithText(TextFormField, '380'), findsOne);
    });

    testWidgets('says the figures came off a photograph', (tester) async {
      // A form that silently filled itself would be indistinguishable from one
      // the user had typed, and what is saved here outranks everything.
      await pump(
        tester,
        replies: [FakeReply.ok(_reply(_almonds))],
        photo: _photo(),
      );

      expect(find.textContaining('Check it against'), findsNothing);

      await tester.tap(find.text('PHOTOGRAPH'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Check it against'), findsOne);
    });

    testWidgets('a panel it could not read leaves the form alone',
        (tester) async {
      await pump(
        tester,
        replies: [
          FakeReply.ok(
            _reply({'readable': false, 'food': null, 'serving_g': null}),
          ),
        ],
        photo: _photo(),
      );

      await tester.tap(find.text('PHOTOGRAPH'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No table could be read'), findsOne);
      // Nothing was filled, so nothing has to be un-filled.
      expect(find.widgetWithText(TextFormField, 'Salted almonds'), findsNothing);
    });

    testWidgets('an upstream that fails says so rather than silently doing '
        'nothing', (tester) async {
      await pump(
        tester,
        // Every model in the chain refuses. The user is standing in a kitchen
        // holding a packet; they need to be told to type it.
        replies: const [
          FakeReply.status(500),
          FakeReply.status(500),
          FakeReply.status(500),
        ],
        photo: _photo(),
      );

      await tester.tap(find.text('PHOTOGRAPH'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No model answered'), findsOne);
      // The form is untouched, and the offer to try again is still there.
      expect(find.textContaining('Check it against'), findsNothing);
      expect(find.text('PHOTOGRAPH'), findsOne);
    });

    testWidgets('backing out of the camera spends nothing', (tester) async {
      final adapter = await pump(tester, photo: null);

      await tester.tap(find.text('PHOTOGRAPH'));
      await tester.pumpAndSettle();

      expect(adapter.callCount, 0);
      final calls = await tester.runAsync(
        () => db.aiCallsDao.select(db.aiCalls).get(),
      );
      expect(calls, isEmpty);
    });

    testWidgets('is not offered at all without a key', (tester) async {
      // Unlike the search sheet's model buttons, this one has a complete
      // alternative directly underneath it: the fields.
      await pump(tester, hasKey: false, photo: _photo());

      expect(find.text('PHOTOGRAPH'), findsNothing);
      expect(find.text('Name'.toUpperCase()), findsOne);
    });
  });

  group('what a reading saves', () {
    testWidgets('writes the figures the old form could not hold',
        (tester) async {
      // Sugars, saturates and sodium are on every EU label and all three feed
      // Toxicity and Vitality. Before this they were saved as zero, which is
      // not a missing figure but a wrong one.
      await pump(
        tester,
        replies: [FakeReply.ok(_reply(_almonds))],
        photo: _photo(),
      );

      await tester.tap(find.text('PHOTOGRAPH'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('INSCRIBE'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ManualFoodSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('INSCRIBE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final stored = await tester.runAsync(
        () => db.foodsDao.findByBarcode('4840811001867'),
      );

      expect(stored, isNotNull);
      expect(stored!.name, 'Salted almonds');
      expect(stored.sugarG, 4.4);
      expect(stored.satFatG, 4.1);
      expect(stored.sodiumMg, 380);
      expect(stored.novaGroup, 3);
      expect(stored.glycemicIndex, 15);
      // Still written by hand: the user pressed INSCRIBE on figures they were
      // shown, so this outranks anything upstream says later.
      expect(stored.source, FoodSource.manual);
    });
  });
}
