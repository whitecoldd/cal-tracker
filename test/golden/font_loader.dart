import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real fonts into a golden test.
///
/// Without this every golden renders in the placeholder Ahem font, which hides
/// exactly what the goldens exist to show — and, worse, hides text-width bugs,
/// since Ahem's metrics are nothing like Cinzel's wide engraved capitals.
Future<void> loadAppFonts() async {
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

  // Otherwise every Icon renders as a .notdef box.
  final iconFont = File(
    '${_flutterRoot()}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (iconFont.existsSync()) {
    await (FontLoader('MaterialIcons')
          ..addFont(iconFont.readAsBytes().then((b) => ByteData.view(b.buffer))))
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
