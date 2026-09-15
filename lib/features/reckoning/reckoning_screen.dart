import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/week_archive.dart';
import '../../domain/reckoning.dart';
import '../../domain/sealed_value.dart';
import '../../domain/week_summary.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../../widgets/sealed_node.dart';
import 'reckoning_providers.dart';
import 'week_charts.dart';

/// The Reckoning — the week's verdict, or the seal over it.
///
/// Every number on this screen arrives as a [SealedValue] and is rendered
/// through an exhaustive `switch`, so a widget cannot print a figure it has
/// not unwrapped. `non_exhaustive_switch_expression` is an analyzer **error**,
/// which means a future verdict added without a sealed branch fails the build
/// rather than leaking. See CLAUDE.md §1.
///
/// T11 builds this out into the full Week's End: charts, the level-up, and the
/// one AI narrative. T7 establishes the gate and the seal.
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
    // Null while the week is still sealed — there is nothing to archive about
    // a week that has not finished.
    final archived = reckoning.isRevealed
        ? ref.watch(archivedWeekProvider).valueOrNull
        : null;

    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        _WeekBar(reckoning: reckoning),
        const SizedBox(height: Space.lg),
        _Verdict(reckoning: reckoning),
        const SizedBox(height: Space.lg),
        if (archived != null) ...[
          _Account(archived: archived),
          const SizedBox(height: Space.lg),
          _Shape(summary: archived.summary),
          const SizedBox(height: Space.lg),
          _Spoils(summary: archived.summary),
          const SizedBox(height: Space.lg),
        ],
        _Body2(reckoning: reckoning),
        const SizedBox(height: Space.lg),
        _Evidence(reckoning: reckoning),
        const SizedBox(height: Space.huge),
      ],
    );
  }
}

/// The week's written account.
///
/// One AI call per week, and the week keeps whatever it got. A week with no
/// key, no network or no budget left still has every figure — the account is
/// flavour on top of them.
class _Account extends StatelessWidget {
  const _Account({required this.archived});

  final ArchivedWeek archived;

  @override
  Widget build(BuildContext context) {
    final narrative = archived.narrative;
    if (narrative == null) return const SizedBox.shrink();

    return OrnatePanel(
      title: 'The account',
      accent: Hue.goldDim,
      child: Text(narrative, style: Type.lore(size: 14)),
    );
  }
}

/// The shape of the week, drawn.
class _Shape extends StatelessWidget {
  const _Shape({required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      title: 'The shape of it',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('EACH DAY', style: Type.label(color: Hue.gold)),
          const SizedBox(height: Space.sm),
          BalanceChart(balances: summary.dailyBalances),
          const RunicDivider(),
          Text('THE SCALE', style: Type.label(color: Hue.gold)),
          const SizedBox(height: Space.sm),
          WeightChart(weights: summary.dailyWeights),
        ],
      ),
    );
  }
}

/// XP earned, and what earned it.
class _Spoils extends StatelessWidget {
  const _Spoils({required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      title: 'Spoils',
      accent: Hue.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

/// The two figures that answer the question.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.reckoning});

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
                  format: _kcal,
                  lore: 'The scales are covered until the week is done.',
                ),
              ),
              Expanded(
                child: SealedNode(
                  label: 'Weight change',
                  value: _asNum(reckoning.weightDeltaKg),
                  format: _kg,
                  lore: 'Ask again when the week is done.',
                ),
              ),
            ],
          ),
          const RunicDivider(),
          _Trend(reckoning: reckoning),
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
class _Trend extends StatelessWidget {
  const _Trend({required this.reckoning});

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
class _Body2 extends StatelessWidget {
  const _Body2({required this.reckoning});

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
              value: _asNum(reckoning.projectedChangeKg.map<double?>((v) => v)),
              format: _kg,
              lore: 'What the ledger predicts.',
              accent: Hue.steelLight,
            ),
          ),
          Expanded(
            child: SealedNode(
              label: 'Body fat',
              value: _asNum(reckoning.bodyFatPercent),
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
class _Evidence extends StatelessWidget {
  const _Evidence({required this.reckoning});

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
SealedValue<num> _asNum(SealedValue<double?> value) =>
    value.map<num>((v) => v ?? double.nan);

String _kcal(num value) {
  final kcal = value.round();
  // The sign carries the whole meaning here, so it is always shown — and the
  // unit with it, because a bare "-3850" beside a weight in kg is ambiguous.
  final sign = kcal > 0 ? '+' : '';
  return '$sign$kcal kcal';
}

String _kg(num value) {
  if (value is double && value.isNaN) return '—';
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)} kg';
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
