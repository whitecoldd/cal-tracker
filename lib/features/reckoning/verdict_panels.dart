/// The verdict half of the Reckoning: everything that waits for the week to
/// close.
///
/// Split out of `reckoning_screen.dart` in T41, when the screen gained two
/// modes and tripled in length. Every figure here arrives as a [SealedValue]
/// and is rendered through an exhaustive `switch`, so a widget cannot print
/// one it has not unwrapped. `non_exhaustive_switch_expression` is an analyzer
/// **error**, which means a future verdict added without a sealed branch fails
/// the build rather than leaking. See CLAUDE.md §1.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/reckoning.dart';
import '../../domain/sealed_value.dart';
import '../../domain/week_summary.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../../widgets/sealed_node.dart';
import 'reckoning_providers.dart';

/// XP earned, and what earned it.
class SpoilsPanel extends StatelessWidget {
  const SpoilsPanel({required this.summary, super.key});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      title: 'Spoils',
      accent: Hue.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LevelUpMark(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${summary.xp}',
                style: Type.numeral(size: 40, color: Hue.gold),
              ),
              const SizedBox(width: Space.sm),
              Text('XP', style: Type.label(color: Hue.gold)),
            ],
          ),
          const SizedBox(height: Space.sm),
          // Said plainly, because it is the app's position: the score is for
          // logging honestly and eating well, never for which way the scale
          // moved.
          Text(
            'Earned for ${summary.loggedDays} days logged, '
            'diet quality of ${summary.averageVitality.round()}, and '
            '${summary.goalDays} days at your step goal. '
            'Never for which way the scale went.',
            textAlign: TextAlign.center,
            style: Type.lore(size: 12),
          ),
        ],
      ),
    );
  }
}

/// The level a week's seal crossed.
///
/// Renders nothing at all when no boundary was crossed, which is most weeks —
/// a panel that said "no level this time" would make the ordinary case feel
/// like a failure.
///
/// The one place in the app that dwells. It is earned: XP moves only when a
/// week seals, so this can happen at most once a week, on a screen the user
/// opened deliberately. It plays again if the week is opened again, and that is
/// a choice rather than an oversight — suppressing a replay costs a stored flag,
/// which is a schema version for a cosmetic.
class LevelUpMark extends ConsumerWidget {
  const LevelUpMark({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelUp = ref.watch(levelUpProvider).valueOrNull;
    if (levelUp == null) return const SizedBox.shrink();

    // A plain one-shot tween rather than a controller: it runs once, ends, and
    // leaves nothing animating in the tree. Anything still moving after this
    // would stop `pumpAndSettle` settling and time out every widget test on
    // this screen — which is exactly what a zero-opacity spinner did in T21.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.reveal,
      curve: Motion.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          // Rises into place. The same small travel as a page turn, so the
          // whole app moves the same distance.
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            levelUp.levels == 1 ? 'LEVEL GAINED' : '${levelUp.levels} LEVELS GAINED',
            textAlign: TextAlign.center,
            style: Type.label(color: Hue.goldDim),
          ),
          const SizedBox(height: Space.xs),
          // The old level small and dim, the new one large and gold, with the
          // app's own diamond between them. No arrow: the two bundled fonts
          // are text faces with no glyph in the arrows block, and a missing
          // glyph renders as a tofu box that only a golden would ever show.
          // The size difference carries the direction better than an arrow
          // would anyway.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${levelUp.from.level}',
                style: Type.numeral(size: 22, color: Hue.parchmentDim),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(width: 7, height: 7, color: Hue.gold),
                ),
              ),
              Text(
                '${levelUp.to.level}',
                style: Type.numeral(size: 36, color: Hue.gold),
              ),
            ],
          ),
          if (levelUp.rankChanged) ...[
            const SizedBox(height: Space.xs),
            Text(
              levelUp.to.rank.title.toUpperCase(),
              textAlign: TextAlign.center,
              style: Type.heading(size: 16, color: Hue.gold),
            ),
          ],
          const RunicDivider(),
        ],
      ),
    );
  }
}

/// The two figures that answer the question.
class VerdictPanel extends StatelessWidget {
  const VerdictPanel({required this.reckoning, super.key});

  final Reckoning reckoning;

  @override
  Widget build(BuildContext context) {
    final days = reckoning.daysUntilReveal;

    return OrnatePanel(
      title: reckoning.isRevealed ? 'The week, told' : 'The week, sealed',
      accent: reckoning.isRevealed ? Hue.gold : Hue.steel,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SealedNode(
                  label: 'Energy balance',
                  // A SealedValue crosses the boundary; the widget cannot
                  // render what it has not unwrapped.
                  value: reckoning.energyBalanceKcal
                      .map<num>((kcal) => roundBalance(kcal)),
                  format: kcalLabel,
                  lore: 'The scales are covered until the week is done.',
                ),
              ),
              Expanded(
                child: SealedNode(
                  label: 'Weight change',
                  value: asSealedNum(reckoning.weightDeltaKg),
                  format: kgLabel,
                  lore: 'Ask again when the week is done.',
                ),
              ),
            ],
          ),
          const RunicDivider(),
          TrendLine(reckoning: reckoning),
          if (!reckoning.isRevealed) ...[
            const SizedBox(height: Space.sm),
            Text(
              days == 0
                  ? 'The week closes today.'
                  : days == 1
                      ? 'One day until the week closes.'
                      : '$days days until the week closes.',
              textAlign: TextAlign.center,
              style: Type.lore(size: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// The measured direction, in words.
class TrendLine extends StatelessWidget {
  const TrendLine({required this.reckoning, super.key});

  final Reckoning reckoning;

  @override
  Widget build(BuildContext context) {
    // The exhaustive switch is the guard. There is no path from Sealed to a
    // rendered direction.
    final (text, colour) = switch (reckoning.trend) {
      Sealed() => (
          'The path is not yet clear.',
          Hue.parchmentFaint,
        ),
      Revealed(value: null) => (
          'Not enough weigh-ins this week to say.',
          Hue.parchmentDim,
        ),
      Revealed(value: WeightTrend.falling) => (
          'Falling.',
          Hue.toxicity,
        ),
      Revealed(value: WeightTrend.rising) => (
          'Rising.',
          Hue.adrenaline,
        ),
      Revealed(value: WeightTrend.holding) => (
          'Holding. The scale moved less than it wanders.',
          Hue.parchmentDim,
        ),
    };

    return Text(
      text,
      textAlign: TextAlign.center,
      style: Type.lore(size: 13, color: colour),
    );
  }
}

/// Projection and composition — the second-order figures.
class BodyPanel extends StatelessWidget {
  const BodyPanel({required this.reckoning, super.key});

  final Reckoning reckoning;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      title: 'The body',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SealedNode(
              label: 'Projected',
              value: asSealedNum(reckoning.projectedChangeKg.map<double?>((v) => v)),
              format: kgLabel,
              lore: 'What the ledger predicts.',
              accent: Hue.steelLight,
            ),
          ),
          Expanded(
            child: SealedNode(
              label: 'Body fat',
              value: asSealedNum(reckoning.bodyFatPercent),
              format: (n) => '${n.toStringAsFixed(1)}%',
              lore: 'An estimate, not a measurement.',
              accent: Hue.steelLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the verdict rests on. Never sealed — it is not a verdict.
class EvidencePanel extends StatelessWidget {
  const EvidencePanel({required this.reckoning, super.key});

  final Reckoning reckoning;

  @override
  Widget build(BuildContext context) {
    final logged = reckoning.loggedDays;

    return OrnatePanel(
      title: 'The evidence',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('DAYS LOGGED', style: Type.label()),
              Text('$logged of 7', style: Type.numeral(size: 18)),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            switch (logged) {
              0 => 'Nothing was written down this week. There is nothing to '
                  'read, sealed or otherwise.',
              < 4 => 'A thin week. Whatever the seal opens on will rest on '
                  'very little, and deserves to be read with suspicion.',
              < 7 => 'Most of the week is accounted for.',
              _ => 'Every day accounted for.',
            },
            style: Type.lore(size: 12),
          ),
        ],
      ),
    );
  }
}

/// Widens a sealed number so [SealedNode] can take it, without unsealing.
///
/// `map` is applied inside the sealed type, so this is a type change and not a
/// read — a `Sealed` stays sealed all the way through.
SealedValue<num> asSealedNum(SealedValue<double?> value) =>
    value.map<num>((v) => v ?? double.nan);

String kcalLabel(num value) {
  final kcal = value.round();
  // The sign carries the whole meaning here, so it is always shown — and the
  // unit with it, because a bare "-3850" beside a weight in kg is ambiguous.
  final sign = kcal > 0 ? '+' : '';
  return '$sign$kcal kcal';
}

String kgLabel(num value) {
  if (value is double && value.isNaN) return '—';
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)} kg';
}

