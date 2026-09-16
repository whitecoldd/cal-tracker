/// The Tally — the week in figures.
///
/// Everything above the "when the seal opens" divider is readable on **any**
/// day: it comes from a [WeekPattern], which has no field for an energy
/// balance, an expenditure or a weight. Everything below it is the verdict and
/// waits for the week to close, exactly as it always has.
///
/// The open half states **no quantity of energy and no weight** — shares,
/// densities, counts of days and milligrams, but never "you ate N kcal this
/// week". A weekly intake figure read by someone who knows their own
/// expenditure is the verdict with the subtraction done in their head.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/week_archive.dart';
import '../../domain/harm.dart';
import '../../domain/nutrition.dart';
import '../../domain/reckoning.dart';
import '../../domain/week_findings.dart';
import '../../domain/week_pattern.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/alchemy_vial.dart';
import '../../widgets/curse_line.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../../widgets/sign_glyph.dart';
import '../../widgets/stat_bar.dart';
import 'reckoning_providers.dart';
import 'verdict_panels.dart';
import 'week_charts.dart';

class TallyView extends ConsumerWidget {
  const TallyView({required this.reckoning, super.key});

  final Reckoning reckoning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pattern = ref.watch(weekPatternProvider).valueOrNull;
    final archived = reckoning.isRevealed
        ? ref.watch(archivedWeekProvider).valueOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pattern == null)
          const _Waiting()
        else ...[
          _Composition(pattern: pattern),
          const SizedBox(height: Space.lg),
          _Curses(pattern: pattern),
          const SizedBox(height: Space.lg),
          if (pattern.additives.isNotEmpty) ...[
            _Residue(pattern: pattern),
            const SizedBox(height: Space.lg),
          ],
          _Tendencies(findings: ref.watch(weekFindingsProvider).valueOrNull),
          const SizedBox(height: Space.lg),
          _TheDays(pattern: pattern),
          const SizedBox(height: Space.lg),
        ],
        const _SealDivider(),
        BodyPanel(reckoning: reckoning),
        const SizedBox(height: Space.lg),
        if (archived != null) ...[
          _Shape(archived: archived),
          const SizedBox(height: Space.lg),
          SpoilsPanel(summary: archived.summary),
          const SizedBox(height: Space.lg),
        ],
        EvidencePanel(reckoning: reckoning),
      ],
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

/// The line between what the week says and what it will not say yet.
class _SealDivider extends StatelessWidget {
  const _SealDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        children: [
          Text('WHEN THE SEAL OPENS', style: Type.label(color: Hue.gold)),
          const SizedBox(width: Space.md),
          const Expanded(child: RunicDivider(color: Hue.goldDim, height: 10)),
        ],
      ),
    );
  }
}

/// How the week was put together. Shares, never amounts.
class _Composition extends StatelessWidget {
  const _Composition({required this.pattern});

  final WeekPattern pattern;

  static const _colours = {
    'Protein': Hue.vitality,
    'Carbs': Hue.stamina,
    'Fat': Hue.adrenaline,
  };

  @override
  Widget build(BuildContext context) {
    final quality = pattern.quality;

    return OrnatePanel(
      title: 'The table',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pattern.macros.isEmpty)
            Text('Nothing written down this week.', style: Type.lore())
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final share in pattern.macros)
                  AlchemyVial(
                    label: share.label,
                    // The same reading as the Alchemy screen: where the macro
                    // sits inside its usual band, never how much of it there
                    // was. A full flask means "typical composition".
                    value: share.share,
                    target: share.rangeHigh,
                    color: _colours[share.label] ?? Hue.gold,
                    valueLabel: '${(share.share * 100).round()}%',
                    captionLabel: '${(share.rangeLow * 100).round()}–'
                        '${(share.rangeHigh * 100).round()}%',
                  ),
              ],
            ),
            const RunicDivider(),
            _Reading(
              label: 'Fibre',
              value: quality.meanFibrePer1000Kcal.toStringAsFixed(1),
              note: 'grams per 1000 kcal, averaged over the days you wrote '
                  'down. ${fibreTargetPer1000Kcal.round()} is the usual mark; '
                  'you reached it on ${quality.daysAtFibreDensity} of '
                  '${pattern.loggedDays}.',
            ),
            if (quality.proteinPerKg != null)
              _Reading(
                label: 'Protein',
                value: quality.proteinPerKg!.toStringAsFixed(1),
                note: 'grams per kg of body mass a day. $proteinTargetPerKg is '
                    'the usual mark; you reached it on '
                    '${quality.daysAtProteinTarget} of ${pattern.loggedDays}.',
              ),
            _Reading(
              label: 'Whole food',
              value: '${(quality.wholeFoodShare * 100).round()}%',
              note: 'of the week’s energy came from unprocessed or barely '
                  'processed food. '
                  '${(quality.ultraProcessedShare * 100).round()}% came from '
                  'ultra-processed.',
            ),
            if (quality.averageGlycemicIndex != null)
              _Reading(
                label: 'Glycemic index',
                value: quality.averageGlycemicIndex!.round().toString(),
                note: 'averaged across the carbohydrate that carried a '
                    'reading.',
              ),
            const SizedBox(height: Space.sm),
            Text(
              'The bands are the usual ranges for a diet, not a target set '
              'for you.',
              style: Type.lore(size: 11, color: Hue.parchmentFaint),
            ),
          ],
        ],
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(label.toUpperCase(), style: Type.label())),
              Text(value, style: Type.numeral(size: 18)),
            ],
          ),
          const SizedBox(height: Space.xxs),
          Text(note, style: Type.lore(size: 12)),
        ],
      ),
    );
  }
}

/// What the week carried, curse by curse, with the foods that carried it.
class _Curses extends StatelessWidget {
  const _Curses({required this.pattern});

  final WeekPattern pattern;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      title: 'The week’s curses',
      accent: Hue.bloodRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pattern.curses.isEmpty)
            Text(
              pattern.loggedDays == 0
                  ? 'Nothing was written down, so there is nothing to read.'
                  : 'Nothing of note in what you ate this week.',
              style: Type.lore(),
            )
          else
            for (final curse in pattern.curses) _Curse(curse: curse),
          const RunicDivider(),
          // Required on every harm surface. See CLAUDE.md §7.
          Text(
            harmDisclaimer,
            style: Type.lore(size: 11, color: Hue.parchmentFaint),
          ),
        ],
      ),
    );
  }
}

class _Curse extends StatelessWidget {
  const _Curse({required this.curse});

  final WeeklyCurse curse;

  @override
  Widget build(BuildContext context) {
    // The name leads once, with a short figure beside it; everything longer
    // hangs beneath. The weekly detail is a sentence, and a sentence
    // right-aligned against a title reads as a mistake.
    return CurseLine(
      title: curse.kind.title,
      detail: '${curse.daysPastGuideline} of ${curse.loggedDays} days',
      basis: curse.basis,
      isPastGuideline: curse.daysPastGuideline > 0,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Only where it actually happened. Seven empty segments under a
          // curse that never passed the guideline is a row of noise saying
          // nothing, repeated for every curse the week did not have.
          if (curse.daysPastGuideline > 0) ...[
            // Seven segments, because the seven segments *are* the seven days.
            StatBar(
              label: 'Past the guideline',
              value: curse.daysPastGuideline.toDouble(),
              max: 7,
              segments: 7,
              color: Hue.bloodRed,
              valueLabel: '${curse.daysPastGuideline} of 7',
            ),
            const SizedBox(height: Space.sm),
          ],
          // The day count is already beside the title; this is the amount.
          if (_total != null)
            Text('$_total across the week.', style: Type.prose(size: 12)),
          if (curse.carriers.isNotEmpty) ...[
            const SizedBox(height: Space.xxs),
            Text(
              'Carried by ${curse.carriers.map(_carrier).join(', ')}.',
              style: Type.lore(size: 11, color: Hue.parchmentFaint),
            ),
          ],
        ],
      ),
    );
  }

  /// The week's amount, where there is one to state.
  ///
  /// Null for `ultraProcessed`, which is a share of energy rather than an
  /// amount of anything, and for additives, whose weekly figure is already the
  /// headline of its own panel.
  String? get _total {
    final total = curse.weeklyTotal;
    if (total == null || total <= 0) return null;
    if (curse.kind == HarmKind.additives) return null;
    return '${formatAmount(total)} ${curse.unit}';
  }

  String _carrier(FoodTally tally) {
    // Two kinds name the food and stop there.
    //
    // Additives, because the "12 listed" a sum produces is four days times
    // three codes and measures nothing. And **ultra-processed, because its
    // amount is kilocalories** — an energy quantity has no business on a
    // screen that may be six days from the reveal, whether or not it happens
    // to be printed with a unit beside it.
    if (curse.kind == HarmKind.additives ||
        curse.kind == HarmKind.ultraProcessed) {
      return tally.food.name;
    }
    return '${tally.food.name} (${formatAmount(tally.amount)} ${tally.unit})';
  }
}

/// The E-numbers themselves — the panel this whole feature was asked for.
class _Residue extends StatelessWidget {
  const _Residue({required this.pattern});

  final WeekPattern pattern;

  /// Beyond this the panel stops being a list and starts being a wall.
  static const _shown = 20;

  @override
  Widget build(BuildContext context) {
    final additives = pattern.additives;
    final shown = additives.take(_shown).toList();
    final rest = additives.length - shown.length;

    return OrnatePanel(
      title: 'Alchemical residue',
      accent: Hue.bloodRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${additives.length} distinct '
            '${additives.length == 1 ? 'additive' : 'additives'} across '
            'everything you ate this week.',
            style: Type.prose(size: 13),
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [for (final tally in shown) _Code(tally: tally)],
          ),
          if (rest > 0) ...[
            const SizedBox(height: Space.sm),
            Text('and $rest more.', style: Type.lore(size: 11)),
          ],
          const SizedBox(height: Space.md),
          Text(
            'Listed on the packets, not measured here. An E-number is a '
            'permitted ingredient with a code, and most of them are ordinary.',
            style: Type.lore(size: 11),
          ),
          const RunicDivider(),
          Text(
            harmDisclaimer,
            style: Type.lore(size: 11, color: Hue.parchmentFaint),
          ),
        ],
      ),
    );
  }
}

/// One E-number, engraved.
class _Code extends StatelessWidget {
  const _Code({required this.tally});

  final AdditiveTally tally;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: Hue.surfaceRaised,
        border: Border.all(color: Hue.steel, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tally.code.toUpperCase(),
            style: Type.label(size: 10, color: Hue.parchment),
          ),
          const SizedBox(height: Space.xxs),
          Text(
            '${tally.days} ${tally.days == 1 ? 'day' : 'days'}'
            '${tally.foods.isEmpty ? '' : ' · ${tally.foods.first.name}'}',
            style: Type.lore(size: 10, color: Hue.parchmentFaint),
          ),
        ],
      ),
    );
  }
}

/// What the week held, and what it carried, in two blocks.
class _Tendencies extends StatelessWidget {
  const _Tendencies({required this.findings});

  final List<Finding>? findings;

  @override
  Widget build(BuildContext context) {
    final all = findings ?? const <Finding>[];
    final held = topFindings(all, Tone.boon);
    final carried = topFindings(all, Tone.warning);

    if (held.isEmpty && carried.isEmpty) {
      return OrnatePanel(
        title: 'Tendencies',
        child: Text(
          'Not enough written down this week to say which way it leaned.',
          style: Type.lore(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (held.isNotEmpty)
          _Block(
            title: 'What the week held',
            accent: Hue.toxicity,
            findings: held,
          ),
        if (held.isNotEmpty && carried.isNotEmpty)
          const SizedBox(height: Space.lg),
        if (carried.isNotEmpty)
          _Block(
            title: 'What the week carried',
            accent: Hue.bloodRed,
            findings: carried,
            disclaimer: true,
          ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.title,
    required this.accent,
    required this.findings,
    this.disclaimer = false,
  });

  final String title;
  final Color accent;
  final List<Finding> findings;
  final bool disclaimer;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      title: title,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final finding in findings) _Tendency(finding: finding),
          if (disclaimer) ...[
            const RunicDivider(),
            Text(
              harmDisclaimer,
              style: Type.lore(size: 11, color: Hue.parchmentFaint),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tendency extends StatelessWidget {
  const _Tendency({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            finding.title.toUpperCase(),
            style: Type.label(
              color: finding.tone == Tone.boon
                  ? Hue.parchmentDim
                  : Hue.vitality,
            ),
          ),
          const SizedBox(height: Space.xxs),
          Text(finding.detail, style: Type.prose(size: 13)),
          if (finding.basis != null) ...[
            const SizedBox(height: Space.xxs),
            Text(finding.basis!, style: Type.lore(size: 11)),
          ],
        ],
      ),
    );
  }
}

/// The week day by day, and the Signs it lit.
class _TheDays extends StatelessWidget {
  const _TheDays({required this.pattern});

  final WeekPattern pattern;

  @override
  Widget build(BuildContext context) {
    final best = pattern.quality.best;
    final worst = pattern.quality.worst;

    return OrnatePanel(
      title: 'The days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('WHAT EACH DAY WAS MADE OF', style: Type.label(color: Hue.gold)),
          const SizedBox(height: Space.sm),
          VitalityChart(
            scores: [
              for (final day in pattern.days)
                day.wasLogged ? day.vitality.score : null,
            ],
          ),
          if (best != null && worst != null && best.day != worst.day) ...[
            const SizedBox(height: Space.sm),
            Text(
              'Best was ${_weekday(best.day.weekday)} at ${best.score.round()}; '
              'thinnest was ${_weekday(worst.day.weekday)} at '
              '${worst.score.round()}.',
              style: Type.lore(size: 12),
            ),
          ],
          const RunicDivider(),
          Text('SIGNS, ACROSS THE WEEK', style: Type.label(color: Hue.gold)),
          const SizedBox(height: Space.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final (sign, charge) in pattern.signs.all)
                SignGlyph(sign: sign, charge: charge, size: 38, showLabel: true),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('STEPS', style: Type.label()),
              Text(
                '${pattern.movement.steps}',
                style: Type.numeral(size: 16),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            '${pattern.movement.goalDays} of 7 days at your step goal, and '
            '${pattern.movement.daysAtWaterTarget} at two litres.',
            style: Type.lore(size: 12),
          ),
        ],
      ),
    );
  }
}

/// The two charts, which only exist once a week is archived.
class _Shape extends StatelessWidget {
  const _Shape({required this.archived});

  final ArchivedWeek archived;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      title: 'The shape of it',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('EACH DAY', style: Type.label(color: Hue.gold)),
          const SizedBox(height: Space.sm),
          BalanceChart(balances: archived.summary.dailyBalances),
          const RunicDivider(),
          Text('THE SCALE', style: Type.label(color: Hue.gold)),
          const SizedBox(height: Space.sm),
          WeightChart(weights: archived.summary.dailyWeights),
        ],
      ),
    );
  }
}

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _weekday(int isoWeekday) => _weekdayNames[isoWeekday - 1];
