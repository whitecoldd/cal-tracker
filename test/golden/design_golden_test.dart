@Tags(['golden'])
library;

import 'package:cal_tracker/features/design_gallery/design_gallery_screen.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_loader.dart';

/// Renders the design gallery to a PNG so the skin can be eyeballed without a
/// device.
///
/// Regenerate after an intentional visual change:
///
/// ```
/// flutter test --update-goldens --tags golden
/// ```
///
/// It also runs as part of a plain `flutter test`, so an accidental visual
/// regression fails the build. Golden images are renderer- and font-sensitive,
/// so if this ever fails on a different machine or after a Flutter upgrade,
/// look at the diff in `failures/` before assuming the code is wrong.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('design gallery golden', (tester) async {
    tester.view.physicalSize = const Size(1100, 5400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const DesignGalleryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DesignGalleryScreen),
      matchesGoldenFile('design_gallery.png'),
    );
  });
}
