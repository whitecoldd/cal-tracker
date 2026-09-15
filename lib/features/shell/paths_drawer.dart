import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/runic_divider.dart';
import '../alchemy/alchemy_screen.dart';
import '../bestiary/bestiary_screen.dart';
import '../path/path_screen.dart';
import '../reckoning/reckoning_screen.dart';
import '../settings/settings_screen.dart';

/// Where the app can go.
///
/// The Journal carried these as app-bar actions until T12b, when the fifth
/// destination arrived and five 48-pixel buttons plus a title stopped fitting
/// across 360 logical pixels. A drawer holds as many as the app grows, and
/// gives each one room for the word that names it — the vocabulary is
/// load-bearing here (CLAUDE.md §5), and an icon alone does not carry it.
enum Destination {
  alchemy(
    'Alchemy',
    'What the day was made of',
    Icons.science_outlined,
  ),
  path(
    'The Path',
    'Your character sheet',
    Icons.hexagon_outlined,
  ),
  bestiary(
    'Bestiary',
    'Every creature you have eaten',
    Icons.menu_book_outlined,
  ),
  reckoning(
    "Week's End",
    'The Reckoning',
    Icons.lock_outline,
  ),
  settings(
    'Settings',
    'The key, the allowance, Health Connect',
    Icons.settings_outlined,
  );

  const Destination(this.title, this.blurb, this.icon);

  final String title;
  final String blurb;
  final IconData icon;

  /// The screen behind this destination, and the name on its bar.
  (String, Widget) get screen => switch (this) {
        Destination.alchemy => ('Alchemy', const AlchemyScreen()),
        Destination.path => ('The Path', const PathScreen()),
        Destination.bestiary => ('Bestiary', const BestiaryScreen()),
        Destination.reckoning => ('Week', const ReckoningScreen()),
        Destination.settings => ('Settings', const SettingsScreen()),
      };
}

/// The menu.
class PathsDrawer extends StatelessWidget {
  const PathsDrawer({super.key});

  static void go(BuildContext context, Destination destination) {
    final (title, screen) = destination.screen;

    Navigator.of(context)
      ..pop()
      ..push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SafeArea(child: screen),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Hue.voidBlack,
      shape: const BeveledRectangleBorder(),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            Text("THE WITCHER'S DIET", style: Type.heading(size: 15)),
            Text(
              'Log honestly. The week will tell you the rest.',
              style: Type.lore(size: 12),
            ),
            const RunicDivider(),
            for (final destination in Destination.values)
              _Row(destination: destination),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => PathsDrawer.go(context, destination),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            Icon(destination.icon, size: 20, color: Hue.gold),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.title.toUpperCase(),
                    style: Type.label(color: Hue.parchment),
                  ),
                  Text(
                    destination.blurb,
                    style: Type.lore(size: 11, color: Hue.parchmentFaint),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: Hue.parchmentFaint,
            ),
          ],
        ),
      ),
    );
  }
}
