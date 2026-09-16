import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/harm.dart';
import '../../domain/nutrition.dart';
import '../../domain/scoring.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/alchemy_vial.dart';
import '../../widgets/curse_line.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../../widgets/stat_bar.dart';
import 'alchemy_providers.dart';

/// Alchemy — what the day was made of.
///
/// Every figure on this screen is intake-relative. The macro vials fill
/// against each macro's share of the day's *own* energy, never against a
/// target derived from expenditure, because intake measured against a
/// TDEE-derived target can be subtracted back into a deficit. That would
/// answer "am I losing weight?" on a daily screen, which is the one thing the
/// app must not do. See CLAUDE.md §1.
class AlchemyScreen extends ConsumerWidget {
  const AlchemyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(alchemyTotalsProvider);
    final shares = ref.watch(macroSharesProvider);
    final vitality = ref.watch(vitalityProvider);
    final toxins = ref.watch(toxinsProvider);
    final toxicity = ref.watch(toxicityProvider);

    if (totals.isEmpty) return const _NothingYet();

    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        _Decoctions(shares: shares, totals: totals),
        const SizedBox(height: Space.lg),
        _Condition(vitality: vitality, toxicity: toxicity),
        const SizedBox(height: Space.lg),
        _Humours(totals: totals),
        const SizedBox(height: Space.lg),
        _Curses(toxins: toxins),
        const SizedBox(height: Space.huge),
      ],
    );
  }
}

/// The macro vials.
class _Decoctions extends StatelessWidget {
  const _Decoctions({required this.shares, required this.totals});

  final List<MacroShare> shares;
  final NutrientTotals totals;

  static const _colours = {
    'Protein': Hue.vitality,
    'Carbs': Hue.stamina,
    'Fat': Hue.adrenaline,
  };

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      title: 'Decoctions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final share in shares)
                AlchemyVial(
                  label: share.label,
                  // The vial is told a share and a range, not grams against a
                  // goal: `value` is where the macro sits inside its usual
                  // band, so a full flask means "typical composition", never
                  // "you have eaten enough".
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
          for (final share in shares) _ShareLine(share: share),
          const SizedBox(height: Space.sm),
          Text(
            'Vials show how the day was composed, not how much of it there '
            'was. The bands are the usual ranges for a diet, not a target set '
            'for you.',
            style: Type.lore(size: 12),
          ),
        ],
      ),
    );
  }
}

class _ShareLine extends StatelessWidget {
  const _ShareLine({required this.share});

  final MacroShare share;

  String get _verdict {
    if (share.isBelowRange) return 'below the usual range';
    if (share.isAboveRange) return 'above the usual range';
    return 'within the usual range';
  }

  Color get _colour => share.isInRange ? Hue.parchmentDim : Hue.gold;

  @override
  Widget build(BuildContext context) {
    final low = (share.rangeLow * 100).round();
    final high = (share.rangeHigh * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(share.label.toUpperCase(), style: Type.label()),
          ),
          SizedBox(
            width: 44,
            child: Text('${share.grams.round()} g', style: Type.prose(size: 13)),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              '${(share.share * 100).round()}% of energy — $_verdict '
              '($low–$high%)',
              style: Type.lore(size: 12, color: _colour),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vitality and Toxicity, the two meters.
class _Condition extends StatelessWidget {
  const _Condition({required this.vitality, required this.toxicity});

  final Vitality vitality;
  final AsyncValue<double> toxicity;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      title: 'Condition',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatBar(
            label: 'Vitality',
            value: vitality.score,
            color: Hue.vitality,
            valueLabel: '${vitality.score.round()} / 100',
          ),
          const SizedBox(height: Space.md),
          StatBar(
            label: 'Toxicity',
            value: toxicity.valueOrNull ?? 0,
            color: Hue.toxicity,
            valueLabel: switch (toxicity) {
              AsyncData(:final value) => '${value.round()} / 100',
              _ => '—',
            },
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Toxicity carries between days and drains slowly, so a heavy '
            'evening still colours tomorrow.',
            style: Type.lore(size: 12),
          ),
          const RunicDivider(),
          Text('WHAT FEEDS VITALITY', style: Type.label(color: Hue.gold)),
          const SizedBox(height: Space.sm),
          _Component(label: 'Fibre density', value: vitality.fibre),
          _Component(label: 'Whole food', value: vitality.wholeFood),
          _Component(label: 'Protein', value: vitality.protein),
          _Component(label: 'Sugar restraint', value: vitality.sugarRestraint),
        ],
      ),
    );
  }
}

/// One component of Vitality, so the score can be argued with rather than
/// simply believed.
class _Component extends StatelessWidget {
  const _Component({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label.toUpperCase(), style: Type.label()),
          ),
          Expanded(
            child: ClipRect(
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: Hue.steelDim,
                valueColor: const AlwaysStoppedAnimation(Hue.goldDim),
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          Text('${(value * 100).round()}%', style: Type.prose(size: 12)),
        ],
      ),
    );
  }
}

/// Fibre, sugar and the glycemic reading — the things that are neither macro
/// nor harm.
class _Humours extends StatelessWidget {
  const _Humours({required this.totals});

  final NutrientTotals totals;

  @override
  Widget build(BuildContext context) {
    final gi = totals.averageGlycemicIndex;

    return OrnatePanel(
      title: 'Humours',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatBar(
            label: 'Fibre',
            value: totals.fibreG,
            max: fibreTargetG,
            color: Hue.toxicity,
            valueLabel: '${totals.fibreG.round()} g of '
                '${fibreTargetG.round()} g',
          ),
          const SizedBox(height: Space.md),
          _Reading(
            label: 'Glycemic load',
            value: totals.glycemicLoad.round().toString(),
            note: 'Sum over foods with a known index. '
                'Under 80 is a low-load day.',
          ),
          _Reading(
            label: 'Glycemic index',
            value: gi == null ? 'Unknown' : gi.round().toString(),
            note: gi == null
                ? 'Nothing eaten today carried an index.'
                : 'Carbohydrate-weighted mean of what you ate.',
          ),
          _Reading(
            label: 'Sugars',
            value: '${totals.sugarG.round()} g',
            note: totals.addedSugarG > 0
                ? '${totals.addedSugarG.round()} g of it free sugars.'
                : 'No free sugars recorded.',
          ),
          _Reading(
            label: 'Whole food',
            value: '${(totals.wholeFoodShare * 100).round()}%',
            note: 'Share of energy from unprocessed or minimally '
                'processed food.',
          ),
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // A label like "GLYCEMIC LOAD" beside a numeral leaves no slack
              // on a narrow phone, so both sides have to be allowed to shrink.
              Expanded(
                child: Text(label.toUpperCase(), style: Type.label()),
              ),
              const SizedBox(width: Space.sm),
              Text(value, style: Type.numeral(size: 18)),
            ],
          ),
          Text(note, style: Type.lore(size: 12)),
        ],
      ),
    );
  }
}

/// The harm readings, worst first.
class _Curses extends StatelessWidget {
  const _Curses({required this.toxins});

  final Toxins toxins;

  @override
  Widget build(BuildContext context) {
    final notable = toxins.notable;

    return OrnatePanel(
      title: 'Curses',
      accent: Hue.bloodRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notable.isEmpty)
            Text(
              'Nothing of note in what you ate today.',
              style: Type.lore(),
            )
          else
            for (final flag in notable)
              CurseLine(
                title: flag.kind.title,
                detail: flag.detail,
                basis: flag.kind.basis,
                isPastGuideline: flag.severity >= 1,
              ),
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


/// Nothing logged yet.
///
/// Says so plainly rather than rendering empty meters: a Vitality of zero and
/// a Toxicity of zero on an unlogged day would read as a verdict on the day
/// rather than an absence of data.
class _NothingYet extends StatelessWidget {
  const _NothingYet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NO DECOCTION BREWED', style: Type.heading(size: 16)),
            const SizedBox(height: Space.sm),
            Text(
              'Log something in the Journal and its parts will be read here.',
              textAlign: TextAlign.center,
              style: Type.lore(),
            ),
          ],
        ),
      ),
    );
  }
}
