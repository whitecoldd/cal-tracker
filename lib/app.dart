import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/ai/ai_providers.dart';
import 'features/backup/backup_providers.dart';
import 'features/backup/restore_offer_screen.dart';
import 'features/journal/journal_screen.dart';
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

class _Routed extends ConsumerStatefulWidget {
  const _Routed();

  @override
  ConsumerState<_Routed> createState() => _RoutedState();
}

class _RoutedState extends ConsumerState<_Routed> with WidgetsBindingObserver {
  /// Set when the user chooses to start fresh despite a backup being there.
  bool _declinedRestore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The mirror is written when the app goes to the background.
    //
    // "Continuous" without a background job: leaving the app is both the
    // moment the user has finished changing things and the last moment the
    // process is reliably alive. Writing on every log would spend a file write
    // per meal for a file nobody reads between meals.
    if (state == AppLifecycleState.paused) {
      unawaited(_mirror());
      unawaited(_sweepPhotos());
    }
  }

  Future<void> _mirror() async {
    final service = ref.read(backupServiceProvider);
    // Quietly does nothing without access, which is the common case until the
    // user has been to Settings.
    await service.writeMirror();
  }

  /// Deletes photographs no entry points at any more.
  ///
  /// Here rather than on deleting an entry, because one photograph belongs to
  /// several entries — a dish breaks into its components and they all carry the
  /// same path — so no single deletion can decide the file is unwanted. The same
  /// moment as the mirror, and for the same reason: the user has finished
  /// changing things and the process is still alive.
  Future<void> _sweepPhotos() async {
    final inUse = await ref.read(databaseProvider).journalDao.photoPathsInUse();
    await ref.read(mealPhotoStoreProvider).prune(inUse);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return switch (profile) {
      AsyncError(:final error) => _Failed(error: error),
      AsyncData(value: null) => _beforeOnboarding(),
      AsyncData() => const JournalScreen(),
      _ => const _Waiting(),
    };
  }

  /// A fresh install with a backup in the folder is offered it first.
  ///
  /// Asking after onboarding would mean restoring over a profile the user had
  /// just finished typing.
  Widget _beforeOnboarding() {
    if (_declinedRestore) return const OnboardingScreen();

    final offer = ref.watch(offerRestoreProvider).valueOrNull;
    if (offer == null) return const OnboardingScreen();

    return RestoreOfferScreen(
      found: offer,
      onDecline: () => setState(() => _declinedRestore = true),
    );
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
