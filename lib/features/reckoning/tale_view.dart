/// The Tale — the week in words.
///
/// Three states, and the middle one is the reason this mode exists at all:
///
/// - **Sealed** (any day but the reveal): the descriptive passages, and a
///   chained seal over the rest. The AI is never asked about a week in
///   progress — CLAUDE.md §1 — so there is nothing written to show yet.
/// - **Revealed, with an account**: what a model set down at the seal, in its
///   sections.
/// - **Revealed, without one**: the same sections, written by the app from its
///   own figures. A user with no key, no network or no allowance left gets a
///   real Tale rather than an empty panel, per §4.
///
/// The Tale names curses, so it is a harm surface and carries the standing
/// disclaimer — §7.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/harm.dart';
import '../../domain/reckoning.dart';
import '../../domain/week_findings.dart';
import '../../domain/week_pattern.dart';
import '../../domain/week_summary.dart';
import '../../domain/weekly_tale.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import 'reckoning_providers.dart';

class TaleView extends ConsumerWidget {
  const TaleView({required this.reckoning, super.key});

  final Reckoning reckoning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pattern = ref.watch(weekPatternProvider).valueOrNull;
    if (pattern == null) return const _Waiting();

    final findings = ref.watch(weekFindingsProvider).valueOrNull ?? const [];

    // Gated on the reckoning itself rather than on whether the archive
    // happens to hold something. A screen that trusts its provider is one bad
    // override away from printing a verdict on a Tuesday.
    final stored = reckoning.isRevealed
        ? WeeklyTale.decode(ref.watch(archivedWeekProvider).valueOrNull?.narrative)
        : null;

    final tale = stored ??
        (reckoning.isRevealed
            ? tellWeek(pattern, findings, facts: _facts(ref, pattern, findings))
            : WeeklyTale(
                sections: tellPattern(pattern, findings),
                source: TaleSource.told,
              ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in tale.sections) ...[
          _Section(section: section),
          const SizedBox(height: Space.lg),
        ],
        if (!reckoning.isRevealed) ...[
          const _SealedRest(),
          const SizedBox(height: Space.lg),
        ],
        _Foot(source: tale.source),
      ],
    );
  }

  /// The verdict facts, or null — which is what leaves the last passage out.
  ///
  /// `NarrativeFacts.from` returns null unless the week has closed, so this
  /// cannot produce a verdict passage on any other day however it is called.
  NarrativeFacts? _facts(
    WidgetRef ref,
    WeekPattern pattern,
    List<Finding> findings,
  ) {
    final archived = ref.watch(archivedWeekProvider).valueOrNull;
    if (archived == null) return null;

    return NarrativeFacts.from(
      reckoning,
      averageVitality: archived.summary.averageVitality,
      steps: archived.summary.steps,
      pattern: pattern,
      findings: findings,
    );
  }
}

/// Shown while the week is still being read.
///
/// Deliberately **not** a spinner. A `CircularProgressIndicator` animates for
/// ever, so `pumpAndSettle` never settles and every widget test on this screen
/// times out with no useful error — which is exactly the fault CLAUDE.md §2
/// records from T21, reached by a different road.
class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xl),
        child: Center(
          child: Text('Reading the week…', style: Type.lore(size: 12)),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final TaleSection section;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      title: section.title,
      accent: Hue.goldDim,
      child: Text(section.body, style: Type.lore(size: 14)),
    );
  }
}

/// What the Tale will not say yet.
class _SealedRest extends StatelessWidget {
  const _SealedRest();

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      title: 'The rest of it',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'The last passage waits for the week to close. What the ledger '
            'came to, and what the scale made of it, is not written down '
            'until then — not by the app, and not by anything it asks.',
            style: Type.lore(size: 13),
          ),
        ],
      ),
    );
  }
}

class _Foot extends StatelessWidget {
  const _Foot({required this.source});

  final TaleSource source;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          source.provenance,
          textAlign: TextAlign.center,
          style: Type.lore(size: 11, color: Hue.parchmentFaint),
        ),
        const RunicDivider(),
        // The Tale names curses, so §7 applies here as much as to a panel of
        // harm flags.
        Text(
          harmDisclaimer,
          textAlign: TextAlign.center,
          style: Type.lore(size: 11, color: Hue.parchmentFaint),
        ),
      ],
    );
  }
}
