import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/design_gallery/design_gallery_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: WitchersDietApp()));
}

/// Root of the application.
///
/// Until the real shell exists (Journal / Alchemy / The Path / Bestiary), the
/// app opens on the design gallery so the skin can be judged on a device.
class WitchersDietApp extends StatelessWidget {
  const WitchersDietApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "The Witcher's Diet",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const DesignGalleryScreen(),
    );
  }
}
