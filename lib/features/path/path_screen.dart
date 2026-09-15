import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/mutagens.dart';
import '../../domain/progression.dart';
import '../../domain/sealed_value.dart';
import '../../domain/signs.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../../widgets/sealed_node.dart';
import '../../widgets/sign_glyph.dart';
import '../../widgets/stat_bar.dart';
import '../bestiary/bestiary_providers.dart';
import 'path_providers.dart';

/// The Path — the character sheet.
///
/// Level, rank, streak, Adrenaline and the five Signs, all earned by logging
/// and by what was eaten. **Nothing here moves with the scale**: a level that
/// did would be the verdict wearing a hat, and could not be shown on a daily
/// screen without leaking the answer.
///
/// The one weight figure on the page is the current weigh-in, which is always
/// visible. Its *change* sits chained until the week closes. See CLAUDE.md §1.
class PathScreen extends ConsumerWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: const [
        _Standing(),
        SizedBox(height: Space.lg),
        _Discipline(),
        SizedBox(height: Space.lg),
        _Signs(),
        SizedBox(height: Space.lg),
        _Mutagens(),
        SizedBox(height: Space.lg),
        _Body(),
        SizedBox(height: Space.huge),
      ],
    );
  }
}

/// Level, rank and the bar towards the next.
class _Standing extends ConsumerWidget {
  const _Standing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progression =
        ref.watch(progressionProvider).valueOrNull ?? Progression.empty;

    return OrnatePanel(
      title: 'Standing',
      accent: Hue.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LEVEL', style: Type.label()),
                    Text(
                      '${progression.level}',
                      style: Type.numeral(size: 40, color: Hue.gold),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  progression.rank.title.toUpperCase(),
                  textAlign: TextAlign.right,
                  style: Type.heading(size: 14, letterSpacing: 1.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          StatBar(
            label: 'Experience',
            value: progression.xpIntoLevel.toDouble(),
            max: progression.xpForNextLevel.toDouble(),
            color: Hue.gold,
            valueLabel: '${progression.xpRemaining} to go',
          ),
          const SizedBox(height: Space.sm),
          Text(
            '${progression.totalXp} XP earned in total, all of it for logging '
            'and for what was eaten. None of it for which way the scale went.',
            style: Type.lore(size: 11, color: Hue.parchmentFaint),
          ),
        ],
      ),
    );
  }
}

/// Streak and Adrenaline.
class _Discipline extends ConsumerWidget {
  const _Discipline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider).valueOrNull ?? 0;
    final recent = ref.watch(recentLoggedDaysProvider).valueOrNull ?? 0;
    final adrenaline = ref.watch(adrenalineProvider).valueOrNull ?? 1;

    return OrnatePanel(
      title: 'Discipline',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STREAK', style: Type.label()),
                    Text(
                      streak == 1 ? '1 day' : '$streak days',
                      style: Type.numeral(size: 24),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('ADRENALINE', style: Type.label()),
                  Text(
                    '×${adrenaline.toStringAsFixed(2)}',
                    style: Type.numeral(size: 24, color: Hue.adrenaline),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          StatBar(
            label: 'Last seven days',
            value: recent.toDouble(),
            max: 7,
            color: Hue.adrenaline,
            valueLabel: '$recent of 7 logged',
          ),
          const SizedBox(height: Space.sm),
          // Said plainly because it is a deliberate mercy: a streak that a
          // single missed day destroyed would give the user a reason to invent
          // a meal to save it, and the app's one demand is honest logging.
          Text(
            'Adrenaline follows the last seven days, not the streak. A missed '
            'day costs a seventh, never everything.',
            style: Type.lore(size: 11, color: Hue.parchmentFaint),
          ),
        ],
      ),
    );
  }
}

/// The five Signs.
class _Signs extends ConsumerWidget {
  const _Signs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charges = ref.watch(signChargesProvider).valueOrNull;

    return OrnatePanel(
      title: 'Signs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final sign in Sign.values)
                SignGlyph(
                  sign: sign,
                  charge: charges?[sign] ?? 0,
                  showLabel: true,
                ),
            ],
          ),
          const RunicDivider(),
          for (final sign in Sign.values)
            _SignLine(sign: sign, charge: charges?[sign] ?? 0),
        ],
      ),
    );
  }
}

class _SignLine extends StatelessWidget {
  const _SignLine({required this.sign, required this.charge});

  final Sign sign;
  final double charge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(sign.title.toUpperCase(), style: Type.label()),
          ),
          Expanded(
            child: Text(
              sign.blurb,
              style: Type.lore(size: 11, color: Hue.parchmentFaint),
            ),
          ),
          Text(
            '${(charge * 100).round()}%',
            style: Type.prose(
              size: 12,
              color: charge >= 0.6 ? Hue.gold : Hue.parchmentDim,
            ),
          ),
        ],
      ),
    );
  }
}

/// Perks earned at past reveals.
///
/// The only mechanic that carries forward. Every condition is behaviour — a
/// perk that depended on the scale would *be* the verdict, arriving on the
/// character sheet the Monday after. See `domain/mutagens.dart`.
class _Mutagens extends ConsumerWidget {
  const _Mutagens();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earned = ref.watch(earnedMutagensProvider).valueOrNull ?? const [];
    final bonus = ref.watch(mutagenBonusProvider).valueOrNull;

    return OrnatePanel(
      title: 'Mutagens',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (earned.isEmpty)
            Text(
              'None yet. They are granted when a week closes, for how the '
              'week was lived rather than for what the scale did.',
              style: Type.lore(size: 12),
            )
          else ...[
            for (final mutagen in earned) _MutagenRow(mutagen: mutagen),
            if (bonus != null && !bonus.isEmpty) ...[
              const RunicDivider(),
              Text(
                _bonusLine(bonus),
                style: Type.lore(size: 11, color: Hue.parchmentFaint),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static String _bonusLine(MutagenBonus bonus) {
    final parts = <String>[
      if (bonus.experience > 0)
        '+${(bonus.experience * 100).round()}% experience',
      if (bonus.adrenaline > 0)
        '+${(bonus.adrenaline * 100).round()}% adrenaline',
      if (bonus.purge > 0) 'toxicity fades ${(bonus.purge * 100).round()}% faster',
    ];
    return 'Carried into the week ahead: ${parts.join(', ')}.';
  }
}

class _MutagenRow extends StatelessWidget {
  const _MutagenRow({required this.mutagen});

  final Mutagen mutagen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, size: 14, color: Hue.toxicity),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mutagen.title.toUpperCase(),
                  style: Type.label(color: Hue.gold),
                ),
                Text(mutagen.lore, style: Type.lore(size: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The weight node: the current figure, and its change still chained.
class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weight = ref.watch(currentWeightProvider);
    final change = ref.watch(weightChangeProvider).valueOrNull;
    final days = ref.watch(daysUntilRevealProvider);
    final revealed = change?.isRevealed ?? false;

    return OrnatePanel(
      title: 'The body',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Both sides shrink: an engraved label beside a numeral leaves
              // no slack at 360 logical pixels.
              Expanded(
                child: Text('LAST WEIGH-IN', style: Type.label()),
              ),
              const SizedBox(width: Space.sm),
              Text(
                weight == null ? '—' : '${weight.toStringAsFixed(1)} kg',
                style: Type.numeral(size: 20),
              ),
            ],
          ),
          const RunicDivider(),
          // The figure is logged every day and shown every day; only what it
          // *means* waits for the week to close.
          SealedNode(
            label: 'This week',
            value: _asNum(change),
            format: _kg,
            lore: 'The scales are covered until the week is done.',
          ),
          if (!revealed) ...[
            const SizedBox(height: Space.sm),
            Text(
              days == 0
                  ? 'The week closes today.'
                  : days == 1
                      ? 'One day until the week closes.'
                      : '$days days until the week closes.',
              textAlign: TextAlign.center,
              style: Type.lore(size: 11, color: Hue.parchmentFaint),
            ),
          ],
        ],
      ),
    );
  }

  /// Widens the sealed figure without unsealing it.
  static SealedValue<num> _asNum(SealedValue<double?>? value) =>
      value == null ? const Sealed<num>() : value.map<num>((v) => v ?? double.nan);

  static String _kg(num value) {
    if (value is double && value.isNaN) return '—';
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)} kg';
  }
}
