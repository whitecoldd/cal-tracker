import 'package:cal_tracker/data/week_archive.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/energy.dart';
import 'package:cal_tracker/domain/progression.dart';
import 'package:cal_tracker/domain/reckoning.dart';
import 'package:cal_tracker/domain/reveal_gate.dart';
import 'package:cal_tracker/domain/week_pattern.dart';
import 'package:cal_tracker/domain/week_summary.dart';
import 'package:cal_tracker/features/reckoning/reckoning_providers.dart';
import 'package:cal_tracker/features/reckoning/reckoning_screen.dart';
import 'package:cal_tracker/features/reckoning/verdict_panels.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/week_fixtures.dart';

/// Monday 14 September 2026 .. Sunday 20 September 2026.
const _monday = Day(20260914);

String _name(int weekday) => const {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    }[weekday]!;

/// A week of real deficits, with weigh-ins at both ends.
///
/// Built through `reckon` rather than read from a database on purpose: the
/// screen's whole job is rendering a [Reckoning], and the reckoning itself is
/// pure. Putting drift in the way would only add the fake-async trap that
/// CLAUDE.md §2 warns about, and buy no extra coverage — the provider that
/// assembles this from the database is tested separately, off the widget
/// binding, below.
Reckoning _reckoningOn(
  Day today, {
  double startWeight = 82,
  double endWeight = 81.1,
  int loggedDays = 7,
}) {
  return reckon(
    anyDayOfWeek: today,
    today: today,
    gate: const RevealGate(weekEndsOn: DateTime.sunday),
    days: [
      for (var i = 0; i < loggedDays; i++)
        DayEnergy(
          day: _monday.addDays(i),
          intakeKcal: 1800,
          expenditureKcal: 2400,
        ),
    ],
    startWeightKg: startWeight,
    endWeightKg: endWeight,
    heightCm: 180,
    ageYears: 34,
    sex: Sex.male,
  );
}

const _summary = WeekSummary(
  loggedDays: 7,
  energyBalanceKcal: -4200,
  averageDailyBalanceKcal: -600,
  projectedChangeKg: -0.54,
  averageVitality: 61,
  averageToxicity: 22,
  steps: 54000,
  goalDays: 4,
  xp: 145,
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    Reckoning reckoning, {
    ArchivedWeek? archived,
    LevelUp? levelUp,
    WeekPattern? pattern,
    ReckoningMode mode = ReckoningMode.tally,
  }) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Overridden rather than derived from a profile: the real one reads
          // a live drift stream, which a widget test has no business waking.
          revealGateProvider.overrideWithValue(
            const RevealGate(weekEndsOn: DateTime.sunday),
          ),
          weekReckoningProvider.overrideWith((ref) async => reckoning),
          // Not overridden, this reaches a real database through
          // path_provider, which a widget test has no plugin for. The same
          // goes for the level-up, which reads the sealed weeks behind it.
          archivedWeekProvider.overrideWith((ref) async => archived),
          levelUpProvider.overrideWith((ref) async => levelUp),
          // The open half reads the journal directly, so it gets the same
          // settled-snapshot treatment as everything else here.
          weekPatternProvider.overrideWith(
            (ref) async => pattern ?? fixturePattern(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(body: ReckoningScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (mode != ReckoningMode.tally) {
      await tester.tap(find.text(mode.label.toUpperCase()));
      await tester.pumpAndSettle();
    }
  }

  String visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => (t.data ?? '').toLowerCase())
      .join(' | ');

  const archived0 = ArchivedWeek(
    weekStart: _monday,
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
  );

  group('the level-up', () {
    testWidgets('an ordinary week says nothing about levels', (tester) async {
      // Most weeks cross no boundary, and a panel that announced "no level
      // this time" would make the ordinary case read as a failure.
      await pump(tester, _reckoningOn(_monday.addDays(6)), archived: archived0);

      expect(visibleText(tester), contains('145'));
      expect(visibleText(tester), isNot(contains('level')));
    });

    testWidgets('a crossing names both sides and the new rank',
        (tester) async {
      await pump(
        tester,
        _reckoningOn(_monday.addDays(6)),
        archived: archived0,
        levelUp: levelUpFrom(xpBefore: 420, xpGained: 145),
      );

      final text = visibleText(tester);
      expect(text, contains('level gained'));
      // Both sides, because the crossing is the interesting part.
      expect(text, contains('3'));
      expect(text, contains('4'));
      // Level 4 is where Wanderer begins.
      expect(text, contains('wanderer'));

      // No arrow, and no other glyph the two bundled text faces do not carry.
      // A missing glyph renders as a tofu box, which every assertion above
      // passes straight through — the first draft of this panel shipped a
      // '→' and only the golden showed it. Arrows and geometric shapes are
      // the blocks a text font reliably lacks.
      expect(
        text,
        isNot(matches(RegExp(r'[←-⇿■-◿]'))),
      );
    });

    testWidgets('two levels at once say so', (tester) async {
      await pump(
        tester,
        _reckoningOn(_monday.addDays(6)),
        archived: archived0,
        levelUp: levelUpFrom(xpBefore: 140, xpGained: 340),
      );

      expect(visibleText(tester), contains('2 levels gained'));
    });

    testWidgets('the mark settles — nothing is left animating',
        (tester) async {
      // `pump` ends in `pumpAndSettle`, which would time out if anything here
      // ran forever. That is not hypothetical: a zero-opacity spinner left
      // spinning broke every search-sheet test in T21. Asserting it explicitly
      // so the reason survives.
      await pump(
        tester,
        _reckoningOn(_monday.addDays(6)),
        archived: archived0,
        levelUp: levelUpFrom(xpBefore: 420, xpGained: 145),
      );

      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('the seal holds at the glass', () {
    // The domain is covered by reckoning_test.dart. This asserts the same rule
    // where it actually matters: the pixels.
    for (var offset = 0; offset < 6; offset++) {
      final today = _monday.addDays(offset);

      testWidgets('${_name(today.weekday)} shows no verdict', (tester) async {
        await pump(tester, _reckoningOn(today));

        final text = visibleText(tester);

        expect(text, contains('the week, sealed'));
        expect(text, contains('the path is not yet clear'));

        // `kcal` and `kg` are still forbidden across the whole screen — but a
        // *density* is not a quantity, and since T41 the open half prints two
        // of them: "14 g per 1000 kcal" and "1.6 g per kg". Those say how the
        // food was composed and contain no amount of anything.
        //
        // "1,850 kcal a day" is an amount, and a reader who knows their own
        // expenditure subtracts it into a verdict in their head. "81.4 kg" is
        // the verdict outright. So the units are stripped and the assertion is
        // then exactly as strict as it was before — do not widen this by
        // deleting the two expectations below.
        final withoutUnits =
            text.replaceAll(RegExp(r'per (\d[\d,]* )?(kcal|kg)'), '');

        expect(withoutUnits, isNot(contains('kcal')));
        expect(withoutUnits, isNot(contains('kg')));

        // And the open half must actually have rendered, or this test is
        // asserting the absence of a screen rather than the absence of a leak.
        expect(text, contains('the table'));

        for (final leak in const [
          'falling',
          'rising',
          'holding',
          'deficit',
          'surplus',
          'losing',
          'gaining',
        ]) {
          expect(
            text.contains(leak),
            isFalse,
            reason: 'the Reckoning leaked "$leak" on '
                '${_name(today.weekday)}: $text',
          );
        }
      });
    }

    testWidgets('Sunday opens it', (tester) async {
      await pump(tester, _reckoningOn(_monday.addDays(6)));

      final text = visibleText(tester);

      expect(text, contains('the week, told'));
      expect(text, contains('kg'));
      // 82.0 to 81.1 is a real fall, past the noise band.
      expect(text, contains('falling'));
      expect(text, isNot(contains('the path is not yet clear')));
    });

    testWidgets('no verdict numeral is inside the verdict panel while sealed',
        (tester) async {
      // Stronger than scanning for words: walk every Text and assert nothing
      // shaped like a verdict figure was rendered.
      //
      // **Scoped to [VerdictPanel] since T41, and narrowed nowhere else.**
      // The old form swept the whole tree, which was right when the screen
      // showed nothing but the verdict. The Tally now prints macro shares —
      // "34%" — which are compositions of the week's own energy and cannot be
      // rearranged into a balance. Sweeping the whole tree for `%` would
      // therefore fail on a figure that is not a verdict, and the tempting fix
      // is to delete the assertion. This keeps it, exactly as strict, over the
      // panel that actually owns the verdict.
      await pump(tester, _reckoningOn(_monday.addDays(2)));

      final numerals = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(VerdictPanel),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .where((s) => RegExp(r'[+-]?\d+([.,]\d+)?\s*(kcal|kg|%)').hasMatch(s))
          .toList();

      expect(
        numerals,
        isEmpty,
        reason: 'a verdict figure was rendered while sealed: $numerals',
      );
    });

    testWidgets('and no signed energy figure anywhere on the screen',
        (tester) async {
      // The whole-tree guard the test above used to be, kept in the form that
      // still holds: a *signed* kcal figure or any weight in kilograms is the
      // verdict wherever it appears, in either mode.
      for (final mode in ReckoningMode.values) {
        await pump(tester, _reckoningOn(_monday.addDays(2)), mode: mode);

        final verdicts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .where(
              (s) => RegExp(r'[+-]\s?\d[\d,.]*\s*kcal|\d[\d.,]*\s*kg')
                  .hasMatch(s),
            )
            .toList();

        expect(
          verdicts,
          isEmpty,
          reason: 'a verdict figure reached ${mode.label}: $verdicts',
        );
      }
    });
  });

  group('the two modes', () {
    testWidgets('opens on The Tally', (tester) async {
      await pump(tester, _reckoningOn(_monday.addDays(2)));

      expect(find.text('THE TALLY'), findsOneWidget);
      expect(find.text('THE TALE'), findsOneWidget);
      expect(visibleText(tester), contains('the table'));
    });

    testWidgets('switching shows the other reading', (tester) async {
      await pump(tester, _reckoningOn(_monday.addDays(2)));
      expect(visibleText(tester), contains('the week’s curses'));

      await tester.tap(find.text('THE TALE'));
      await tester.pumpAndSettle();

      final text = visibleText(tester);
      expect(text, contains('the opening'));
      expect(text, isNot(contains('the week’s curses')));
    });

    testWidgets('the spine survives both modes', (tester) async {
      // The switch must never be able to hide *whether* the week is sealed.
      for (final mode in ReckoningMode.values) {
        await pump(tester, _reckoningOn(_monday.addDays(2)), mode: mode);

        final text = visibleText(tester);
        expect(text, contains('the reckoning'));
        expect(text, contains('the week, sealed'));
      }
    });

    testWidgets('both modes carry the harm disclaimer', (tester) async {
      // Both name curses, so §7 applies to both.
      for (final mode in ReckoningMode.values) {
        await pump(tester, _reckoningOn(_monday.addDays(2)), mode: mode);

        final text = visibleText(tester);
        expect(text, contains('not medical advice'), reason: mode.label);
        expect(text, contains('physician'), reason: mode.label);
      }
    });
  });

  group('The Tally names what the count used to hide', () {
    testWidgets('lists the actual E-numbers', (tester) async {
      await pump(tester, _reckoningOn(_monday.addDays(2)));

      final text = visibleText(tester);
      expect(text, contains('alchemical residue'));
      expect(text, contains('e330'));
    });

    testWidgets('names the food that carried a curse', (tester) async {
      await pump(tester, _reckoningOn(_monday.addDays(2)));

      expect(visibleText(tester), contains('carried by stew'));
    });

    testWidgets('says so plainly when there is nothing to read',
        (tester) async {
      await pump(
        tester,
        _reckoningOn(_monday.addDays(2)),
        pattern: emptyPattern(),
      );

      expect(visibleText(tester), contains('nothing was written down'));
    });
  });

  group('The Tale', () {
    testWidgets('is sealed over the verdict mid-week', (tester) async {
      await pump(
        tester,
        _reckoningOn(_monday.addDays(2)),
        mode: ReckoningMode.tale,
      );

      final text = visibleText(tester);
      expect(text, contains('the rest of it'));
      expect(text, contains('waits for the week to close'));
    });

    testWidgets('shows no account mid-week even if one is handed to it',
        (tester) async {
      // A screen that trusts its provider is one bad override away from
      // printing a verdict on a Tuesday. This forces exactly that mistake.
      await pump(
        tester,
        _reckoningOn(_monday.addDays(2)),
        archived: const ArchivedWeek(
          weekStart: _monday,
          summary: _summary,
          narrative: 'The week came out four thousand kcal short.',
        ),
        mode: ReckoningMode.tale,
      );

      final text = visibleText(tester);
      expect(text, isNot(contains('four thousand')));
      expect(text, contains('the rest of it'));
    });

    testWidgets('reads the stored account on the reveal day', (tester) async {
      await pump(
        tester,
        _reckoningOn(_monday.addDays(6)),
        archived: const ArchivedWeek(
          weekStart: _monday,
          summary: _summary,
          narrative: 'A hard week, and the ledger knows it.',
        ),
        mode: ReckoningMode.tale,
      );

      expect(visibleText(tester), contains('a hard week'));
    });

    testWidgets('writes its own when no model did', (tester) async {
      // No key, no network, no allowance — The Tale is never an empty panel.
      await pump(
        tester,
        _reckoningOn(_monday.addDays(6)),
        archived: const ArchivedWeek(
          weekStart: _monday,
          summary: _summary,
        ),
        mode: ReckoningMode.tale,
      );

      final text = visibleText(tester);
      expect(text, contains('the opening'));
      expect(text, contains('no model was asked'));
    });
  });

  group('the evidence is never sealed', () {
    testWidgets('days logged is readable mid-week', (tester) async {
      // It says nothing about gaining or losing, and it is what tells the user
      // how much the sealed figures will be worth.
      await pump(tester, _reckoningOn(_monday.addDays(2)));

      expect(find.text('DAYS LOGGED'), findsOneWidget);
      expect(visibleText(tester), contains('7 of 7'));
    });

    testWidgets('an empty week says there is nothing to read', (tester) async {
      await pump(tester, _reckoningOn(_monday.addDays(2), loggedDays: 0));

      expect(visibleText(tester), contains('nothing was written down'));
    });

    testWidgets('a thin week warns that the verdict rests on little',
        (tester) async {
      await pump(tester, _reckoningOn(_monday.addDays(2), loggedDays: 2));

      expect(visibleText(tester), contains('a thin week'));
    });
  });

  group('the countdown', () {
    testWidgets('tells the user when to come back', (tester) async {
      // A seal that says when it opens reads as deliberate; one that does not
      // reads as broken.
      await pump(tester, _reckoningOn(_monday));

      expect(visibleText(tester), contains('days until the week closes'));
    });
  });
}
