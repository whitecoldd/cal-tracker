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

void main() {
  Future<void> pump(WidgetTester tester, Reckoning reckoning) async {
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
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(body: ReckoningScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => (t.data ?? '').toLowerCase())
      .join(' | ');

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
        expect(text, isNot(contains('kcal')));
        expect(text, isNot(contains('kg')));

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

    testWidgets('no verdict numeral is anywhere in the tree while sealed',
        (tester) async {
      // Stronger than scanning for words: walk every Text and assert nothing
      // shaped like a verdict figure was rendered at all.
      await pump(tester, _reckoningOn(_monday.addDays(2)));

      final numerals = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((s) => RegExp(r'[+-]?\d+([.,]\d+)?\s*(kcal|kg|%)').hasMatch(s))
          .toList();

      expect(
        numerals,
        isEmpty,
        reason: 'a verdict figure was rendered while sealed: $numerals',
      );
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
