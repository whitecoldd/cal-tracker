import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/reckoning.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_tabs.dart';
import 'reckoning_providers.dart';
import 'tale_view.dart';
import 'tally_view.dart';
import 'verdict_panels.dart';

/// The Reckoning — the week, in two readings.
///
/// The spine of the screen never moves: which week, then the verdict panel
/// (sealed or open), then the switch. Only what hangs below the switch
/// changes, so the mode can never hide *whether* the week is sealed — which
/// would be a far worse failure than showing the wrong tab.
///
/// The verdict half lives in `verdict_panels.dart`, the figures in
/// `tally_view.dart`, the prose in `tale_view.dart`. This file was 535 lines
/// before T41 and would have been well past 1,500 after it.
class ReckoningScreen extends ConsumerWidget {
  const ReckoningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reckoning = ref.watch(weekReckoningProvider);

    return switch (reckoning) {
      AsyncData(:final value) => _Body(reckoning: value),
      AsyncError(:final error) => _Failed(error: error),
      _ => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Hue.goldDim,
            ),
          ),
        ),
    };
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.reckoning});

  final Reckoning reckoning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(reckoningModeProvider);

    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        _WeekBar(reckoning: reckoning),
        const SizedBox(height: Space.lg),
        VerdictPanel(reckoning: reckoning),
        const SizedBox(height: Space.lg),
        const LevelUpMark(),
        RunicTabs<ReckoningMode>(
          tabs: [
            for (final value in ReckoningMode.values)
              RunicTab(value: value, label: value.label, lore: value.lore),
          ],
          selected: mode,
          onSelected: ref.read(reckoningModeProvider.notifier).select,
        ),
        const SizedBox(height: Space.lg),
        switch (mode) {
          ReckoningMode.tally => TallyView(reckoning: reckoning),
          ReckoningMode.tale => TaleView(reckoning: reckoning),
        },
        const SizedBox(height: Space.huge),
      ],
    );
  }
}

/// Which week is being read, and how to walk back through them.
class _WeekBar extends ConsumerWidget {
  const _WeekBar({required this.reckoning});

  final Reckoning reckoning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(reckoningWeekProvider.notifier);
    final format = DateFormat('d MMM');

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous week',
          onPressed: () => notifier.shiftWeeks(-1),
        ),
        Expanded(
          child: GestureDetector(
            onTap: notifier.thisWeek,
            child: Column(
              children: [
                Text(
                  'THE RECKONING',
                  textAlign: TextAlign.center,
                  style: Type.heading(size: 15, letterSpacing: 2.4),
                ),
                Text(
                  '${format.format(reckoning.weekStart.toDateTime())} — '
                  '${format.format(reckoning.weekEnd.toDateTime())}',
                  style: Type.lore(size: 11, color: Hue.parchmentFaint),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next week',
          onPressed: notifier.canGoForward ? () => notifier.shiftWeeks(1) : null,
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: OrnatePanel(
          title: 'The week will not read',
          accent: Hue.bloodRed,
          child: Text('$error', style: Type.lore(size: 12)),
        ),
      ),
    );
  }
}
