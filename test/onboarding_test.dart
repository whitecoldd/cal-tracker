import 'package:cal_tracker/data/daos/profile_dao.dart';
import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/energy.dart';
import 'package:cal_tracker/domain/patch.dart';
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

/// A draft with every required field filled in.
const _complete = OnboardingDraft(
  sex: Sex.male,
  birthYear: 1995,
  heightCm: 180,
  weightKg: 80,
  goal: Goal.loseFat,
  activityLevel: ActivityLevel.villageWalker,
);

void main() {
  group('OnboardingDraft completeness', () {
    test('an empty draft is incomplete at every step', () {
      const draft = OnboardingDraft();
      expect(draft.hasIdentity, isFalse);
      expect(draft.hasBody, isFalse);
      expect(draft.hasRoad, isFalse);
      expect(draft.isComplete, isFalse);
    });

    test('a filled draft is complete', () {
      withClock(Clock.fixed(DateTime(2026, 9, 14)), () {
        expect(_complete.isComplete, isTrue);
      });
    });

    test('rejects implausible heights and weights', () {
      withClock(Clock.fixed(DateTime(2026, 9, 14)), () {
        // The classic slip: height typed in metres.
        expect(_complete.copyWith(heightCm: 1.8).hasIdentity, isFalse);
        expect(_complete.copyWith(heightCm: 300).hasIdentity, isFalse);
        expect(_complete.copyWith(weightKg: 8).hasBody, isFalse);
        expect(_complete.copyWith(weightKg: 800).hasBody, isFalse);
      });
    });

    test('rejects a birth year implying an implausible age', () {
      withClock(Clock.fixed(DateTime(2026, 9, 14)), () {
        expect(_complete.copyWith(birthYear: 2025).hasIdentity, isFalse);
        expect(_complete.copyWith(birthYear: 1850).hasIdentity, isFalse);
        expect(_complete.copyWith(birthYear: 2010).hasIdentity, isTrue);
      });
    });

    test('stride falls back to an estimate from height', () {
      const draft = OnboardingDraft(heightCm: 180);
      expect(draft.strideCm, isNull);
      expect(draft.effectiveStrideCm, closeTo(74.52, 0.01));

      expect(draft.copyWith(strideCm: const Patch(80.0)).effectiveStrideCm, 80);
    });

    test('the road step needs an activity level and a usable stride', () {
      expect(_complete.hasRoad, isTrue);
      expect(
        const OnboardingDraft(activityLevel: ActivityLevel.roadWorn).hasRoad,
        isFalse,
        reason: 'no height, so no stride to fall back on',
      );
    });

    test('a target weight can be cleared, not just replaced', () {
      // `?? this.value` reads an explicit null as "no change", which is why
      // clearable fields take a typed Patch rather than a bare double?.
      final withTarget = _complete.copyWith(targetWeightKg: const Patch(74.0));
      expect(withTarget.targetWeightKg, 74);
      expect(
        withTarget.copyWith(targetWeightKg: const Patch.clear()).targetWeightKg,
        isNull,
      );
      expect(withTarget.copyWith(weightKg: 79).targetWeightKg, 74,
          reason: 'an unrelated edit must not clear it');
    });

    test('derived figures appear only once their inputs exist', () {
      withClock(Clock.fixed(DateTime(2026, 9, 14)), () {
        expect(const OnboardingDraft().bmr, isNull);
        expect(const OnboardingDraft(sex: Sex.male).maintenance, isNull);

        // BMR for a 31-year-old, 80kg, 180cm male: 800 + 1125 - 155 + 5.
        expect(_complete.bmr, closeTo(1775, 0.01));
        expect(_complete.maintenance, closeTo(1775 * 1.375, 0.01));
        expect(
          _complete.dailyTarget,
          closeTo(1775 * 1.375 - 500, 0.01),
        );
      });
    });
  });

  group('committing the profile', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('writes the profile and the first weigh-in together', () async {
      await withClock(Clock.fixed(DateTime(2026, 9, 14, 9)), () async {
        container.read(onboardingDraftProvider.notifier)
          ..update((_) => _complete)
          ..update(
            (d) => d.copyWith(
              targetWeightKg: const Patch(74.0),
              weekEndsOn: DateTime.wednesday,
            ),
          );

        await container.read(onboardingDraftProvider.notifier).commit();

        final profile = (await db.profileDao.get())!;
        expect(profile.sex, Sex.male);
        expect(profile.heightCm, 180);
        expect(profile.goal, Goal.loseFat);
        expect(profile.targetWeightKg, 74);
        expect(profile.weekEndsOn, DateTime.wednesday);
        // Stride was never set by hand, so it is derived from height.
        expect(profile.strideCm, closeTo(74.52, 0.01));

        // The starting weight must land too — a profile without one cannot
        // produce a BMR, leaving the app half-configured.
        final weight = await db.trackingDao.weightFor(Day.of(2026, 9, 14));
        expect(weight?.kg, 80);
      });
    });

    test('refuses to commit an incomplete draft', () async {
      container
          .read(onboardingDraftProvider.notifier)
          .update((d) => d.copyWith(sex: Sex.female));

      await expectLater(
        container.read(onboardingDraftProvider.notifier).commit(),
        throwsA(isA<StateError>()),
      );
      expect(await db.profileDao.get(), isNull);
    });

    test('re-running onboarding replaces the profile rather than adding one',
        () async {
      await withClock(Clock.fixed(DateTime(2026, 9, 14, 9)), () async {
        final notifier = container.read(onboardingDraftProvider.notifier);
        notifier.update((_) => _complete);
        await notifier.commit();
        notifier.update((d) => d.copyWith(heightCm: 175));
        await notifier.commit();

        expect((await db.profileDao.get())!.heightCm, 175);
      });
    });

    test('profile energy extensions use the stored figures', () async {
      await withClock(Clock.fixed(DateTime(2026, 9, 14, 9)), () async {
        final notifier = container.read(onboardingDraftProvider.notifier);
        notifier.update((_) => _complete);
        await notifier.commit();

        final profile = (await db.profileDao.get())!;
        expect(profile.ageYears, 31);
        expect(profile.bmrAt(80), closeTo(1775, 0.01));
        expect(profile.estimatedMaintenanceAt(80), closeTo(1775 * 1.375, 0.01));

        // Measured beats estimated: 1775 * 1.2 + walking for 10k steps.
        final measured = profile.measuredMaintenanceAt(80, steps: 10000);
        expect(
          measured,
          closeTo(1775 * 1.2 + 0.5 * 80 * (7000 * 74.52 / 100 / 1000), 0.5),
        );
      });
    });
  });

  group('onboarding screen', () {
    late AppDatabase db;

    Future<void> pump(WidgetTester tester, {VoidCallback? onComplete}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.build(),
            home: OnboardingScreen(onComplete: onComplete),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    testWidgets('opens on the terms, explaining the blackout up front',
        (tester) async {
      await pump(tester);

      expect(find.text("The Witcher's Diet"), findsOneWidget);
      expect(
        find.textContaining('will not tell you whether you are losing'),
        findsOneWidget,
      );
      expect(find.text('Nothing here is medical advice.'), findsOneWidget);
    });

    testWidgets('gates each step until it has what it needs', (tester) async {
      await pump(tester);

      Future<void> tapContinue() async {
        await tester.tap(find.widgetWithText(WitcherButton, 'CONTINUE'));
        await tester.pumpAndSettle();
      }

      bool continueEnabled() =>
          tester
              .widget<WitcherButton>(
                find.widgetWithText(WitcherButton, 'CONTINUE'),
              )
              .onPressed !=
          null;

      // The terms page has nothing to fill in, so it advances freely.
      expect(continueEnabled(), isTrue);
      await tapContinue();
      expect(find.text('Who walks the Path'), findsOneWidget);

      // Identity is empty, so the way forward is closed.
      expect(continueEnabled(), isFalse);

      await tester.tap(find.text('Male'));
      await tester.enterText(find.widgetWithText(TextFormField, '1995'), '1995');
      await tester.pumpAndSettle();
      expect(continueEnabled(), isFalse, reason: 'height still missing');

      await tester.enterText(find.widgetWithText(TextFormField, '178'), '180');
      await tester.pumpAndSettle();
      expect(continueEnabled(), isTrue);
    });

    testWidgets('the final page names the chosen day in plain words',
        (tester) async {
      await pump(tester);

      final notifier = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingScreen)),
      ).read(onboardingDraftProvider.notifier);
      notifier.update((_) => _complete);
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.widgetWithText(WitcherButton, 'CONTINUE'));
        await tester.pumpAndSettle();
      }

      expect(find.text('The Reckoning'), findsOneWidget);
      expect(find.textContaining('On Sunday the week closes'), findsOneWidget);

      // The figures are shown once, here, before committing.
      expect(find.text('MAINTENANCE'), findsOneWidget);
      expect(find.text('DAILY TARGET'), findsOneWidget);
      expect(find.widgetWithText(WitcherButton, 'BEGIN THE PATH'), findsOneWidget);
    });
  });
}
