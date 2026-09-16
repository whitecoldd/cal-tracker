@Tags(['golden'])
library;

import 'package:cal_tracker/data/week_archive.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/energy.dart';
import 'package:cal_tracker/domain/nutrition.dart';
import 'package:cal_tracker/domain/progression.dart';
import 'package:cal_tracker/domain/reckoning.dart';
import 'package:cal_tracker/domain/reveal_gate.dart';
import 'package:cal_tracker/domain/week_pattern.dart';
import 'package:cal_tracker/domain/week_summary.dart';
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

  Future<void> pump(
    WidgetTester tester,
    Reckoning reckoning, {
    ReckoningMode mode = ReckoningMode.tally,
  }) async {
    // Taller since T41: The Tally is a report now, not four panels.
    tester.view.physicalSize = const Size(1080, 9600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          revealGateProvider.overrideWithValue(
            const RevealGate(weekEndsOn: DateTime.sunday),
          ),
          weekReckoningProvider.overrideWith((ref) async => reckoning),
          archivedWeekProvider.overrideWith(
            (ref) async => reckoning.isRevealed
                ? const ArchivedWeek(
                    weekStart: _monday,
                    narrative:
                        'Seven days on the road, and the ledger closed light. '
                        'The scale gave back nine hundred grams; the ledger '
                        'expected half a kilo, and the difference is water, as '
                        'it always is. Nothing was skipped.',
                    summary: WeekSummary(
                      loggedDays: 7,
                      energyBalanceKcal: -3850,
                      averageDailyBalanceKcal: -550,
                      projectedChangeKg: -0.5,
                      averageVitality: 68,
                      averageToxicity: 31,
                      steps: 58000,
                      goalDays: 4,
                      xp: 145,
                      weightDeltaKg: -0.9,
                      trend: WeightTrend.falling,
                      dailyBalances: [-610, -480, -720, -540, -390, -650, -460],
                      dailyWeights: [82, 81.8, 81.5, 81.4, 81.1],
                    ),
                  )
                : null,
          ),
          // The revealed golden carries a level-up so the mark is actually
          // reviewable without a device — CLAUDE.md §5. Without this override
          // the provider would reach a real database the golden has not got.
          levelUpProvider.overrideWith(
            (ref) async => reckoning.isRevealed
                ? levelUpFrom(xpBefore: 420, xpGained: 145)
                : null,
          ),
          weekPatternProvider.overrideWith((ref) async => _pattern()),
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

    if (mode != ReckoningMode.tally) {
      await tester.tap(find.text(mode.label.toUpperCase()));
      await tester.pumpAndSettle();
    }
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

  testWidgets('reckoning golden: the tale, told', (tester) async {
    await pump(tester, _on(_monday.addDays(6)), mode: ReckoningMode.tale);

    await expectLater(
      find.byType(ReckoningScreen),
      matchesGoldenFile('reckoning_tale.png'),
    );
  });

  testWidgets('reckoning golden: the tale, still sealed', (tester) async {
    // The state nobody will look at on a device, and the one most likely to
    // read as broken rather than as deliberately locked.
    await pump(tester, _on(_monday.addDays(2)), mode: ReckoningMode.tale);

    await expectLater(
      find.byType(ReckoningScreen),
      matchesGoldenFile('reckoning_tale_sealed.png'),
    );
  });
}

/// A week with something in it to report, so the goldens show a real Tally.
WeekPattern _pattern() => readWeek(
      weekStart: _monday,
      weekEnd: _monday.addDays(6),
      throughDay: _monday.addDays(6),
      bodyMassKg: 81,
      movement: [
        for (var i = 0; i < 7; i++)
          DayMovement(
            day: _monday.addDays(i),
            steps: 7000 + i * 900,
            waterMl: 1500 + i * 150,
            mealSlotsUsed: 3,
          ),
      ],
      portions: [
        for (var i = 0; i < 7; i++) ...[
          LoggedPortion(
            day: _monday.addDays(i),
            food: const FoodIdentity(id: 1, name: 'Barley porridge'),
            serving: const Serving(food: _porridge, grams: 350),
          ),
          if (i.isEven)
            LoggedPortion(
              day: _monday.addDays(i),
              food: const FoodIdentity(
                id: 2,
                name: 'Salt pork',
                brand: 'Kaer Morhen',
              ),
              serving: const Serving(food: _saltPork, grams: 180),
            ),
        ],
      ],
    );

const _porridge = FoodPanel(
  kcal: 360,
  proteinG: 13,
  carbsG: 60,
  sugarG: 1,
  addedSugarG: 0,
  fatG: 7,
  satFatG: 1.4,
  fibreG: 10,
  sodiumMg: 12,
  glycemicIndex: 55,
  novaGroup: 1,
);

const _saltPork = FoodPanel(
  kcal: 420,
  proteinG: 16,
  carbsG: 2,
  sugarG: 1,
  addedSugarG: 1,
  fatG: 38,
  satFatG: 15,
  transFatG: 0.4,
  fibreG: 0,
  sodiumMg: 1850,
  novaGroup: 4,
  additives: ['E250', 'E301', 'E330'],
);
