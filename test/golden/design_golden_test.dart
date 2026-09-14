@Tags(['golden'])
library;

import 'dart:io';

import 'package:cal_tracker/features/design_gallery/design_gallery_screen.dart';
import 'package:cal_tracker/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
Future<void> _loadFonts() async {
  // Golden tests otherwise render everything in the placeholder Ahem font,
  // which would hide exactly what we are trying to look at.
  for (final entry in <String, List<String>>{
    'Cinzel': ['assets/fonts/Cinzel.ttf'],
    'EBGaramond': [
      'assets/fonts/EBGaramond.ttf',
      'assets/fonts/EBGaramond-Italic.ttf',
    ],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(
        File(path).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();
  }

  // Without this the golden renders every Icon as a .notdef box, which would
  // hide whether the button icons actually sit correctly.
  final iconFont = File(
    '${_flutterRoot()}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (iconFont.existsSync()) {
    await (FontLoader('MaterialIcons')
          ..addFont(
            iconFont.readAsBytes().then((b) => ByteData.view(b.buffer)),
          ))
        .load();
  }
}

/// Locates the Flutter SDK so the icon font can be loaded from its cache.
String _flutterRoot() {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  // `flutter test` runs a Dart binary inside the SDK's own cache.
  final exe = Platform.resolvedExecutable.replaceAll(r'\', '/');
  final marker = exe.indexOf('/bin/cache/');
  return marker == -1 ? '' : exe.substring(0, marker);
}

void main() {
  setUpAll(_loadFonts);

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
