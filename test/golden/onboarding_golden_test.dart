@Tags(['golden'])
library;

import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/domain/energy.dart';
import 'package:cal_tracker/features/onboarding/onboarding_controller.dart';
import 'package:cal_tracker/features/onboarding/onboarding_screen.dart';
import 'package:cal_tracker/providers/app_providers.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:cal_tracker/widgets/witcher_button.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_loader.dart';

/// Renders each page of character creation at real phone width, so the flow can
/// be judged without a device.
///
/// Phone width matters here specifically: both layout bugs found in this screen
/// were labels with wide letter spacing overflowing a narrow row, and neither
/// would show on a tablet-sized surface.
void main() {
  setUpAll(loadAppFonts);

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> pumpAt(WidgetTester tester, int page) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Pre-fill so the later pages have something to show.
    ProviderScope.containerOf(tester.element(find.byType(OnboardingScreen)))
        .read(onboardingDraftProvider.notifier)
        .update(
          (_) => const OnboardingDraft(
            sex: Sex.male,
            birthYear: 1995,
            heightCm: 180,
            weightKg: 80,
            goal: Goal.loseFat,
            activityLevel: ActivityLevel.villageWalker,
            targetWeightKg: 74,
          ),
        );
    await tester.pumpAndSettle();

    for (var i = 0; i < page; i++) {
      await tester.tap(find.widgetWithText(WitcherButton, 'CONTINUE'));
      await tester.pumpAndSettle();
    }
  }

  const names = ['terms', 'identity', 'body', 'road', 'reckoning'];

  for (var page = 0; page < names.length; page++) {
    testWidgets('onboarding golden: ${names[page]}', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 9, 14)), () async {
        await pumpAt(tester, page);
        await expectLater(
          find.byType(OnboardingScreen),
          matchesGoldenFile('onboarding_${names[page]}.png'),
        );
      });
    });
  }
}
