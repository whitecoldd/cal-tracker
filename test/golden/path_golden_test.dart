@Tags(['golden'])
library;

import 'package:cal_tracker/domain/mutagens.dart';
import 'package:cal_tracker/domain/progression.dart';
import 'package:cal_tracker/domain/sealed_value.dart';
import 'package:cal_tracker/domain/signs.dart';
import 'package:cal_tracker/features/bestiary/bestiary_providers.dart';
import 'package:cal_tracker/features/path/path_providers.dart';
import 'package:cal_tracker/features/path/path_screen.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_loader.dart';

/// The character sheet, mid-week.
///
/// The picture that matters: five diamond glyphs at different charges, and the
/// weight node still chained. If the sheet ever starts answering "am I losing
/// weight?", it will show up here first.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('path golden: mid-week', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const totalXp = 640;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          totalXpProvider.overrideWith((ref) async => totalXp),
          progressionProvider.overrideWith((ref) async => levelFor(totalXp)),
          streakProvider.overrideWith((ref) async => 12),
          recentLoggedDaysProvider.overrideWith((ref) async => 6),
          adrenalineProvider.overrideWith(
            (ref) async => adrenalineFor(loggedDaysInLastWeek: 6),
          ),
          signChargesProvider.overrideWith(
            (ref) async => const SignCharges({
              Sign.igni: 0.79,
              Sign.quen: 0.62,
              Sign.aard: 0.88,
              Sign.axii: 0.71,
              Sign.yrden: 0.24,
            }),
          ),
          currentWeightProvider.overrideWithValue(81.4),
          weightChangeProvider
              .overrideWithValue(const AsyncData(Sealed<double?>())),
          daysUntilRevealProvider.overrideWithValue(3),
          earnedMutagensProvider.overrideWith(
            (ref) async => const [Mutagen.greenBlood, Mutagen.whiteHoney],
          ),
          mutagenBonusProvider.overrideWith(
            (ref) async =>
                bonusOf(const [Mutagen.greenBlood, Mutagen.whiteHoney]),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            appBar: AppBar(title: const Text('The Path')),
            body: const SafeArea(child: PathScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PathScreen),
      matchesGoldenFile('path_sheet.png'),
    );
  });
}
