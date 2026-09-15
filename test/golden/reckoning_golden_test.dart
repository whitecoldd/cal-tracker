@Tags(['golden'])
library;

import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/energy.dart';
import 'package:cal_tracker/domain/reckoning.dart';
import 'package:cal_tracker/domain/reveal_gate.dart';
import 'package:cal_tracker/features/reckoning/reckoning_providers.dart';
import 'package:cal_tracker/features/reckoning/reckoning_screen.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_loader.dart';

/// The two states of the product's spine, rendered side by side in the repo.
///
/// The sealed one is the picture that matters: it should read as something
/// deliberately locked and waiting to open, not as a screen that failed to
/// load. That distinction is the difference between the blackout feeling like
/// the point and feeling like a bug.
const _monday = Day(20260914);

Reckoning _on(Day today) => reckon(
      anyDayOfWeek: today,
      today: today,
      gate: const RevealGate(weekEndsOn: DateTime.sunday),
      days: [
        for (var i = 0; i < 7; i++)
          DayEnergy(
            day: _monday.addDays(i),
            intakeKcal: 1840,
            expenditureKcal: 2390,
          ),
      ],
      startWeightKg: 82,
      endWeightKg: 81.1,
      heightCm: 180,
      ageYears: 34,
      sex: Sex.male,
    );

void main() {
  setUpAll(loadAppFonts);

  Future<void> pump(WidgetTester tester, Reckoning reckoning) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          revealGateProvider.overrideWithValue(
            const RevealGate(weekEndsOn: DateTime.sunday),
          ),
          weekReckoningProvider.overrideWith((ref) async => reckoning),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            appBar: AppBar(title: const Text('Week')),
            body: const SafeArea(child: ReckoningScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reckoning golden: sealed mid-week', (tester) async {
    await pump(tester, _on(_monday.addDays(2)));

    await expectLater(
      find.byType(ReckoningScreen),
      matchesGoldenFile('reckoning_sealed.png'),
    );
  });

  testWidgets('reckoning golden: the week told', (tester) async {
    await pump(tester, _on(_monday.addDays(6)));

    await expectLater(
      find.byType(ReckoningScreen),
      matchesGoldenFile('reckoning_revealed.png'),
    );
  });
}
