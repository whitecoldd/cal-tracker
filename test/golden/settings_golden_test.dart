@Tags(['golden'])
library;

import 'package:cal_tracker/data/ai/ai_key_store.dart';
import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/health/step_reader.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/features/activity/activity_providers.dart';
import 'package:cal_tracker/features/ai/ai_providers.dart';
import 'package:cal_tracker/features/settings/settings_screen.dart';
import 'package:cal_tracker/providers/app_providers.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_loader.dart';

/// Settings in both states.
///
/// The bound-key picture is the one that matters: it must show that a key is
/// present without showing any part of it. A credential rendered on screen is
/// a credential that can end up in a screenshot.
void main() {
  setUpAll(loadAppFonts);

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> pump(
    WidgetTester tester, {
    required bool hasKey,
    required int used,
  }) async {
    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final budget = await tester.runAsync(() async {
      for (var i = 0; i < used; i++) {
        await db.aiCallsDao.record(
          model: 'nex-agi/nex-n2.5-pro:free',
          purpose: AiPurpose.parseText,
          succeeded: true,
        );
      }
      return db.aiCallsDao.budget();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          aiKeyStoreProvider.overrideWithValue(
            InMemoryAiKeyStore(key: hasKey ? 'sk-or-v1-0123456789abcdef' : null),
          ),
          aiAvailableProvider.overrideWith((ref) async => hasKey),
          aiBudgetProvider.overrideWith((ref) async => budget!),
          // The health section talks to a platform channel that no test can
          // run. Handed in settled. See CLAUDE.md §2 and §3.
          healthAvailabilityProvider
              .overrideWith((ref) async => HealthAvailability.ready),
          healthPermissionProvider.overrideWith((ref) async => false),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: const SafeArea(child: SettingsScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('settings golden: no key yet', (tester) async {
    await pump(tester, hasKey: false, used: 0);

    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('settings_no_key.png'),
    );
  });

  testWidgets('settings golden: a key bound, budget part spent',
      (tester) async {
    await pump(tester, hasKey: true, used: 12);

    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('settings_bound.png'),
    );
  });
}
