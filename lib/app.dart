import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/design_gallery/design_gallery_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'providers/app_providers.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'theme/typography.dart';
import 'widgets/ornate_panel.dart';

/// Root of the application.
class WitchersDietApp extends StatelessWidget {
  const WitchersDietApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "The Witcher's Diet",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const AppGate(),
    );
  }
}

/// Decides what the user sees first.
///
/// Startup work (loading the seed food table) has to finish before either
/// branch, so a brand new install can search food offline from the first
/// keystroke rather than discovering an empty library.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(startupProvider);

    return switch (startup) {
      AsyncError(:final error) => _Failed(error: error),
      AsyncLoading() => const _Waiting(),
      _ => const _Routed(),
    };
  }
}

class _Routed extends ConsumerWidget {
  const _Routed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return switch (profile) {
      AsyncError(:final error) => _Failed(error: error),
      AsyncData(value: null) => const OnboardingScreen(),
      AsyncData() => const DesignGalleryScreen(),
      _ => const _Waiting(),
    };
  }
}

/// The medallion, while the database wakes up.
class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'The Path begins.',
          style: Type.heading(size: 20, color: Hue.parchmentDim),
        ),
      ),
    );
  }
}

/// Startup failed. Says what happened rather than showing a blank screen —
/// this is a personal build, and the user is also the one who has to fix it.
class _Failed extends StatelessWidget {
  const _Failed({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: OrnatePanel(
            title: 'The Path is blocked',
            accent: Hue.bloodRed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Startup failed.', style: Type.prose(size: 15)),
                const SizedBox(height: Space.sm),
                Text('$error', style: Type.lore(size: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
