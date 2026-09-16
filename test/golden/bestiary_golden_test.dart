@Tags(['golden'])
library;

import 'package:cal_tracker/domain/bestiary.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/nutrition.dart';
import 'package:cal_tracker/features/bestiary/bestiary_providers.dart';
import 'package:cal_tracker/features/bestiary/creature_sheet.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/painted_image.dart';
import 'font_loader.dart';

/// Renders a creature's full entry, plate and all.
///
/// The Bestiary had no golden until T26, which is how `imagePath` could be
/// carried from Open Food Facts into `Creature` and rendered by nothing for
/// four tasks without anything noticing. A screen with no picture of itself is
/// a screen nobody reviews.
///
/// What this is actually checking is the *treatment*: whether a supermarket
/// photograph can sit on void black without fighting everything around it.
/// That is not a thing an assertion can read — it is why CLAUDE.md §5 asks for
/// a golden rather than a test.
void main() {
  setUpAll(loadAppFonts);

  final creature = Creature.of(
    id: 42,
    name: 'Salted almonds',
    brand: 'Alesto',
    panel: const FoodPanel(
      kcal: 627,
      proteinG: 21,
      carbsG: 6.4,
      fatG: 53,
      satFatG: 4.1,
      fibreG: 12,
      sodiumMg: 420,
      novaGroup: 3,
      additives: ['E322'],
    ),
    timesEaten: 4,
    firstSeen: const Day(20260901),
    imagePath: 'https://images.example/almonds.jpg',
  );

  testWidgets('bestiary golden: a creature with its plate', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // A painted image rather than a real one: `FileImage` decodes
          // asynchronously and a golden's fake async never turns the event
          // loop, so a real picture would render as an empty frame and the
          // golden would quietly record the wrong thing.
          creaturePlateProvider.overrideWith(
            (ref, key) async => const PaintedTestImage(size: 64),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(body: CreatureSheet(creature: creature)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CreatureSheet),
      matchesGoldenFile('bestiary_creature.png'),
    );
  });
}
