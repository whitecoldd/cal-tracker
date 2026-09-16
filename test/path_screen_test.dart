import 'package:cal_tracker/domain/mutagens.dart';
import 'package:cal_tracker/domain/progression.dart';
import 'package:cal_tracker/domain/sealed_value.dart';
import 'package:cal_tracker/domain/signs.dart';
import 'package:cal_tracker/features/path/mutagen_providers.dart';
import 'package:cal_tracker/features/path/path_providers.dart';
import 'package:cal_tracker/features/path/path_screen.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:cal_tracker/widgets/sign_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Pumps the sheet with everything handed in settled.
  ///
  /// Every provider here awaits a drift query, and a widget-test body runs in
  /// fake async that never turns the real event loop. See CLAUDE.md §2.
  Future<void> pump(
    WidgetTester tester, {
    int totalXp = 600,
    int streak = 12,
    int recentDays = 6,
    List<Mutagen> active = const [Mutagen.greenBlood],
    SealedValue<double?> change = const Sealed<double?>(),
    int daysUntilReveal = 3,
    double? weight = 81.4,
    SignCharges charges = const SignCharges({
      Sign.igni: 0.8,
      Sign.quen: 0.65,
      Sign.aard: 0.9,
      Sign.axii: 0.7,
      Sign.yrden: 0.3,
    }),
  }) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          totalXpProvider.overrideWith((ref) async => totalXp),
          progressionProvider.overrideWith((ref) async => levelFor(totalXp)),
          streakProvider.overrideWith((ref) async => streak),
          recentLoggedDaysProvider.overrideWith((ref) async => recentDays),
          adrenalineProvider.overrideWith(
            (ref) async => adrenalineFor(loggedDaysInLastWeek: recentDays),
          ),
          signChargesProvider.overrideWith((ref) async => charges),
          currentWeightProvider.overrideWithValue(weight),
          weightChangeProvider.overrideWithValue(AsyncData(change)),
          daysUntilRevealProvider.overrideWithValue(daysUntilReveal),
          earnedMutagensProvider.overrideWith(
            (ref) async => const [Mutagen.greenBlood, Mutagen.whiteHoney],
          ),
          activeMutagensProvider.overrideWith((ref) async => active),
          activeMutagenBonusProvider.overrideWith(
            (ref) async => bonusOf(active),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(body: PathScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => (t.data ?? '').toLowerCase())
      .join(' | ');

  group('standing', () {
    testWidgets('shows level, rank and progress', (tester) async {
      await pump(tester, totalXp: 600);

      final expected = levelFor(600);
      final text = visibleText(tester);

      expect(text, contains('${expected.level}'));
      expect(text, contains(expected.rank.title.toLowerCase()));
      expect(text, contains('600 xp earned'));
    });

    testWidgets('says out loud that XP is not about the scale',
        (tester) async {
      await pump(tester);

      expect(
        visibleText(tester),
        contains('none of it for which way the scale went'),
      );
    });
  });

  group('discipline', () {
    testWidgets('shows the streak and the multiplier', (tester) async {
      await pump(tester, streak: 12, recentDays: 6);

      final text = visibleText(tester);
      expect(text, contains('12 days'));
      expect(text, contains('6 of 7 logged'));
    });

    testWidgets('a one-day streak reads in the singular', (tester) async {
      await pump(tester, streak: 1);

      expect(visibleText(tester), contains('1 day'));
    });

    testWidgets('explains that a missed day is not fatal', (tester) async {
      // A streak a single missed day destroyed would give the user a reason to
      // invent a meal to save it, and the app's one demand is honest logging.
      await pump(tester);

      final text = visibleText(tester);
      expect(text, contains('not the streak'));
      expect(text, contains('never everything'));
    });
  });

  group('signs', () {
    testWidgets('renders all five with their charge', (tester) async {
      await pump(tester);

      expect(find.byType(SignGlyph), findsNWidgets(Sign.values.length));

      final text = visibleText(tester);
      for (final sign in Sign.values) {
        expect(text, contains(sign.title.toLowerCase()));
      }
      // Aard at 0.9.
      expect(text, contains('90%'));
    });
  });

  group('the weight node', () {
    testWidgets('stays chained mid-week', (tester) async {
      await pump(tester, daysUntilReveal: 3);

      final text = visibleText(tester);

      expect(text, contains('the scales are covered'));
      expect(text, contains('3 days until the week closes'));
      // The current weigh-in is always visible; only its meaning waits.
      expect(text, contains('81.4 kg'));
    });

    testWidgets('renders no change figure while sealed', (tester) async {
      await pump(tester);

      // Stronger than scanning words: nothing shaped like a weight *change*
      // may be in the tree. The last weigh-in is allowed; a delta is not.
      final deltas = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((s) => RegExp(r'[+-]\d+([.,]\d+)?\s*kg').hasMatch(s))
          .toList();

      expect(
        deltas,
        isEmpty,
        reason: 'a weight change was rendered while sealed: $deltas',
      );
    });

    testWidgets('opens when the week closes', (tester) async {
      await pump(
        tester,
        change: const Revealed<double?>(-0.9),
        daysUntilReveal: 0,
      );

      final text = visibleText(tester);
      expect(text, contains('-0.90 kg'));
      expect(text, isNot(contains('the scales are covered')));
    });

    testWidgets('a week with no second weigh-in shows a dash, not a zero',
        (tester) async {
      await pump(tester, change: const Revealed<double?>(null));

      // Zero would claim the weight held steady, which is a different claim
      // from "there was nothing to compare".
      expect(visibleText(tester), contains('—'));
    });
  });

  group('mutagens', () {
    testWidgets('lists everything earned but claims only what is in force',
        (tester) async {
      // The panel is overridden with two mutagens earned and one of them
      // active. Both must appear — a perk that was earned was still earned —
      // and the footnote must describe the active one only.
      await pump(tester);

      final text = visibleText(tester);
      expect(text, contains('green blood'));
      expect(text, contains('white honey'));

      expect(text, contains('in force this week'));
      expect(text, contains('experience'));
      // White Honey is the purge perk and is not active, so its effect must
      // not be claimed. Before T24 the bonus was the sum of everything ever
      // earned and this line would have named it.
      expect(text, isNot(contains('fades')));
    });

    testWidgets('says plainly when nothing is in force', (tester) async {
      await pump(tester, active: const []);

      final text = visibleText(tester);
      // Still listed as earned...
      expect(text, contains('green blood'));
      // ...but the panel does not pretend it is doing anything.
      expect(text, isNot(contains('in force this week:')));
      expect(text, contains('none in force this week'));
    });
  });

  group('the blackout', () {
    testWidgets('the character sheet never states a direction',
        (tester) async {
      await pump(tester);

      final text = visibleText(tester);
      for (final leak in const [
        'losing',
        'gaining',
        'deficit',
        'surplus',
        'tdee',
        'maintenance',
        'burned',
      ]) {
        expect(
          text.contains(leak),
          isFalse,
          reason: 'The Path showed "$leak": $text',
        );
      }
    });
  });
}
