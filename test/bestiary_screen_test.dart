import 'package:cal_tracker/domain/bestiary.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/harm.dart';
import 'package:cal_tracker/domain/nutrition.dart';
import 'package:cal_tracker/features/bestiary/bestiary_providers.dart';
import 'package:cal_tracker/features/bestiary/bestiary_screen.dart';
import 'package:cal_tracker/features/bestiary/creature_sheet.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:cal_tracker/widgets/creature_plate.dart';
import 'package:cal_tracker/widgets/food_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/painted_image.dart';

const _lentils = FoodPanel(
  kcal: 352,
  proteinG: 25,
  carbsG: 60,
  fibreG: 11,
  glycemicIndex: 32,
  novaGroup: 1,
);

const _drink = FoodPanel(
  kcal: 45,
  carbsG: 11,
  sugarG: 11,
  addedSugarG: 11,
  sodiumMg: 100,
  novaGroup: 4,
  additiveCount: 6,
);

final _creatures = [
  Creature.of(
    id: 1,
    name: 'Red lentils, dry',
    panel: _lentils,
    timesEaten: 7,
    firstSeen: const Day(20260901),
  ),
  Creature.of(
    id: 2,
    name: 'Energy drink',
    brand: 'Some Brand',
    panel: _drink,
    timesEaten: 2,
    firstSeen: const Day(20260910),
  ),
  Creature.of(id: 3, name: 'Never eaten', panel: _lentils),
];

void main() {
  Future<void> pump(
    WidgetTester tester, {
    List<Creature>? creatures,
    ImageProvider? plate,
  }) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The real provider runs three drift queries, and a widget test's
          // fake async never lets them finish. See CLAUDE.md §2.
          creaturesProvider.overrideWith(
            (ref) async => creatures ?? _creatures,
          ),
          // Overridden for the usual reason and one more: the real store would
          // reach `path_provider`, which a widget test has no plugin for, and
          // then the network. `PaintedTestImage` is also ready on the first
          // frame, which an ordinary decode never is under fake async.
          creaturePlateProvider.overrideWith((ref, key) async => plate),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(body: BestiaryScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => (t.data ?? '').toLowerCase())
      .join(' | ');

  group('the collection', () {
    testWidgets('shows what has been eaten, not the whole library',
        (tester) async {
      // The seed table is in the library from first launch; a Bestiary that
      // claimed 132 creatures on day one would mean nothing.
      await pump(tester);

      final text = visibleText(tester);
      expect(text, contains('red lentils'));
      expect(text, contains('energy drink'));
      expect(text, isNot(contains('never eaten |')));
    });

    testWidgets('counts caught against known', (tester) async {
      await pump(tester);

      expect(visibleText(tester), contains('2 of 3 known'));
    });

    testWidgets('says so plainly when nothing has been caught',
        (tester) async {
      await pump(tester, creatures: []);

      expect(visibleText(tester), contains('nothing caught yet'));
    });

    testWidgets('shows how often each creature was eaten', (tester) async {
      await pump(tester);

      final text = visibleText(tester);
      expect(text, contains('eaten 7 times'));
      expect(text, contains('eaten 2 times'));
    });
  });

  group('the plate', () {
    testWidgets('a food with no picture shows no frame at all', (tester) async {
      // Most foods have none. An empty frame announcing the absence would be
      // worse than the space it takes.
      await pump(tester);

      await tester.tap(find.text('Red lentils, dry').first);
      await tester.pumpAndSettle();

      expect(find.byType(CreatureSheet), findsOneWidget);
      expect(find.byType(CreaturePlate), findsNothing);
    });

    testWidgets('a food with a picture shows it above the name',
        (tester) async {
      await pump(tester, plate: const PaintedTestImage());

      await tester.tap(find.text('Red lentils, dry').first);
      await tester.pumpAndSettle();

      expect(find.byType(CreaturePlate), findsOneWidget);
      // Above the name, not beside it — the sheet has the width the list row
      // does not.
      final plate = tester.getRect(find.byType(CreaturePlate));
      final name = tester.getRect(find.text('Red lentils, dry').last);
      expect(plate.bottom, lessThanOrEqualTo(name.top));
    });

    testWidgets('the frame takes the rarity accent', (tester) async {
      await pump(tester, plate: const PaintedTestImage());

      await tester.tap(find.text('Red lentils, dry').first);
      await tester.pumpAndSettle();

      final widget = tester.widget<CreaturePlate>(find.byType(CreaturePlate));
      expect(widget.accent, _creatures.first.rarity.color);
    });
  });

  group('a creature entry', () {
    testWidgets('opens its full sheet', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Red lentils, dry').first);
      await tester.pumpAndSettle();

      expect(find.byType(CreatureSheet), findsOneWidget);
      expect(visibleText(tester), contains('per 100 g'));
    });

    testWidgets('states an unknown index rather than guessing zero',
        (tester) async {
      await pump(tester, creatures: [
        Creature.of(
          id: 1,
          name: 'Chicken',
          panel: const FoodPanel(kcal: 165, proteinG: 31, novaGroup: 1),
          timesEaten: 1,
        ),
      ]);

      await tester.tap(find.text('Chicken').first);
      await tester.pumpAndSettle();

      // A food with too little carbohydrate has no GI, which is not zero.
      expect(visibleText(tester), contains('unknown'));
    });

    testWidgets('carries the harm disclaimer on its weaknesses',
        (tester) async {
      // Required on every harm surface by CLAUDE.md §7.
      await pump(tester);

      await tester.tap(find.text('Energy drink').first);
      await tester.pumpAndSettle();

      final text = visibleText(tester);
      expect(text, contains('weaknesses'));
      expect(text, contains('not medical advice'));
      expect(text, contains('physician'));
    });

    testWidgets('states the guideline behind each weakness', (tester) async {
      // A flag is never a bare accusation.
      await pump(tester);

      await tester.tap(find.text('Energy drink').first);
      await tester.pumpAndSettle();

      final text = visibleText(tester);
      expect(text, contains(HarmKind.ultraProcessed.basis.toLowerCase()));
    });

    testWidgets('never phrases a weakness as a diagnosis', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Energy drink').first);
      await tester.pumpAndSettle();

      final text = visibleText(tester);
      for (final banned in const [
        'you will',
        'causes',
        'disease',
        'unhealthy',
        'dangerous',
      ]) {
        expect(
          text.contains(banned),
          isFalse,
          reason: 'the Bestiary diagnosed: "$banned"',
        );
      }
    });
  });

  group('the blackout', () {
    testWidgets('the Bestiary says nothing about the week', (tester) async {
      await pump(tester);

      final text = visibleText(tester);
      for (final leak in const [
        'deficit',
        'surplus',
        'losing',
        'gaining',
        'tdee',
        'remaining',
      ]) {
        expect(
          text.contains(leak),
          isFalse,
          reason: 'the Bestiary showed "$leak": $text',
        );
      }
    });
  });
}
