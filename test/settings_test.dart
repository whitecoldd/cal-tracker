import 'package:cal_tracker/data/ai/ai_key_store.dart';
import 'package:cal_tracker/data/ai/openrouter_client.dart';
import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/health/step_reader.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/features/activity/activity_providers.dart';
import 'package:cal_tracker/features/ai/ai_providers.dart';
import 'package:cal_tracker/features/backup/backup_providers.dart';
import 'package:cal_tracker/features/settings/settings_screen.dart';
import 'package:cal_tracker/providers/app_providers.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _realLookingKey = 'sk-or-v1-0123456789abcdef0123';

void main() {
  late AppDatabase db;
  late InMemoryAiKeyStore keys;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    keys = InMemoryAiKeyStore();
  });

  tearDown(() async => db.close());

  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async =>
      (await tester.runAsync(body)) as T;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Both async providers hit the database or the key store, and a widget
    // test's fake async never turns the real event loop — so they are resolved
    // here and handed in settled. See CLAUDE.md §2.
    final hasKey = await real(tester, () async => await keys.read() != null);
    final budget = await real(
      tester,
      () => db.aiCallsDao.budget(hasPurchasedCredit: false),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          aiKeyStoreProvider.overrideWithValue(keys),
          aiAvailableProvider.overrideWith((ref) async => hasKey),
          aiBudgetProvider.overrideWith((ref) async => budget),
          // The health section talks to a platform channel that no test can
          // run. Handed in settled. See CLAUDE.md §2 and §3.
          healthAvailabilityProvider
              .overrideWith((ref) async => HealthAvailability.ready),
          healthPermissionProvider.overrideWith((ref) async => false),
          // The backup panel reaches a platform channel and the filesystem;
          // a widget test has neither. See CLAUDE.md §2.
          storageGrantedProvider.overrideWith((ref) async => false),
          existingBackupProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join(' | ');

  group('entering a key', () {
    testWidgets('rejects something that is not a key, without a call',
        (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'hunter2');
      await tester.tap(find.text('BIND THE KEY'));
      await tester.pumpAndSettle();

      expect(find.textContaining('does not look like'), findsOneWidget);
      // A shape check rather than a network check: verifying against
      // OpenRouter would spend one of fifty daily requests.
      expect(await db.aiCallsDao.usedToday(), 0);
      expect(await keys.read(), isNull);
    });

    testWidgets('stores a well-formed key', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), _realLookingKey);
      await tester.tap(find.text('BIND THE KEY'));
      await tester.pumpAndSettle();

      expect(await keys.read(), _realLookingKey);
    });

    testWidgets('the field is obscured while typing', (tester) async {
      await pump(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
      expect(field.autocorrect, isFalse);
    });
  });

  group('a key that is already bound', () {
    testWidgets('is never rendered, not even masked', (tester) async {
      // Every rendering of a credential is a chance to put it in a screenshot,
      // and there is nothing to check by eye.
      keys = InMemoryAiKeyStore(key: _realLookingKey);
      await pump(tester);

      final text = visibleText(tester);
      expect(text, contains('A key is bound.'));
      expect(text, isNot(contains(_realLookingKey)));
      expect(text, isNot(contains('0123')));
      // And no input field to paste it back into.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('can be forgotten', (tester) async {
      keys = InMemoryAiKeyStore(key: _realLookingKey);
      await pump(tester);

      await tester.tap(find.text('FORGET IT'));
      await tester.pumpAndSettle();

      expect(await keys.read(), isNull);
    });
  });

  group('the budget', () {
    testWidgets('shows what is left against the cap', (tester) async {
      await real(tester, () async {
        for (var i = 0; i < 12; i++) {
          await db.aiCallsDao.record(
            model: 'test',
            purpose: AiPurpose.parseText,
            succeeded: true,
          );
        }
      });

      await pump(tester);

      // CLAUDE.md §4: Settings shows today's usage against the cap.
      expect(visibleText(tester), contains('12 of 50'));
      expect(visibleText(tester), contains('38 left today'));
    });

    testWidgets('says the app still works when the day is spent',
        (tester) async {
      final noon = DateTime(2026, 9, 15, 12);
      await real(tester, () async {
        await withClock(Clock.fixed(DateTime(2026, 9, 15, 6)), () async {
          for (var i = 0; i < 50; i++) {
            await db.aiCallsDao.record(
              model: 'test',
              purpose: AiPurpose.parseText,
              succeeded: true,
            );
          }
        });
      });

      await withClock(Clock.fixed(noon), () => pump(tester));

      final text = visibleText(tester);
      expect(text, contains('Spent for today'));
      // The whole point: running out of AI is not running out of app.
      expect(text, contains('works as it always does'));
    });
  });

  group('the key shape check', () {
    test('accepts an OpenRouter key and rejects anything else', () {
      expect(looksLikeOpenRouterKey(_realLookingKey), isTrue);
      expect(looksLikeOpenRouterKey('  $_realLookingKey  '), isTrue);

      expect(looksLikeOpenRouterKey('sk-or-'), isFalse);
      expect(looksLikeOpenRouterKey('sk-ant-0123456789abcdef'), isFalse);
      expect(looksLikeOpenRouterKey(''), isFalse);
    });
  });

  group('the client without a key', () {
    test('reports that it has none rather than failing later', () async {
      final client = OpenRouterClient(
        keys: InMemoryAiKeyStore(),
        calls: db.aiCallsDao,
      );

      expect(await client.hasKey, isFalse);
    });

    test('a blank key counts as none, in both implementations', () async {
      // The fake and the real store must agree: one that treats "   " as a
      // key while the device treats it as none would let a test pass on
      // behaviour the phone does not have.
      final constructed = InMemoryAiKeyStore(key: '   ');
      expect(await constructed.read(), isNull);

      final written = InMemoryAiKeyStore();
      await written.write('   ');
      expect(await written.read(), isNull);

      final client = OpenRouterClient(
        keys: constructed,
        calls: db.aiCallsDao,
      );
      expect(await client.hasKey, isFalse);
    });
  });
}
