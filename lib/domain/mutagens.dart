/// Mutagens — weekly perks. Pure Dart.
///
/// The only mechanic that carries forward: a mutagen is earned at one reveal
/// and modifies the *following* week. See [[03-Game-Design]].
///
/// **Every condition is behaviour, never outcome.** No mutagen may read weight,
/// weight change, or energy balance. Two reasons, the same ones that shape XP
/// in `week_summary.dart`:
///
/// - Paying for a falling scale pays for a number that moves on water, and
///   punishes an honest week that went sideways.
/// - A perk that depended on the verdict would *be* the verdict — it would
///   appear on the character sheet the following Monday and answer the question
///   the whole app exists to defer. See CLAUDE.md §1.
///
/// There is a test asserting every condition ignores weight entirely.
library;

import 'week_summary.dart';

/// What a mutagen changes about the week that follows it.
enum MutagenEffect {
  /// Multiplies XP earned.
  experience,

  /// Raises the Adrenaline ceiling.
  adrenaline,

  /// Softens toxicity carry-over, so a bad day fades faster.
  purge,
}

/// A weekly perk.
enum Mutagen {
  greenBlood(
    code: 'green_blood',
    title: 'Green Blood',
    lore: 'Seven days written down. Nothing escaped the ledger.',
    effect: MutagenEffect.experience,
    magnitude: 0.10,
  ),
  redVitriol(
    code: 'red_vitriol',
    title: 'Red Vitriol',
    lore: 'The week was eaten well, and the body noticed.',
    effect: MutagenEffect.experience,
    magnitude: 0.10,
  ),
  blueEssence(
    code: 'blue_essence',
    title: 'Blue Essence',
    lore: 'Miles under the boots, most days of the week.',
    effect: MutagenEffect.adrenaline,
    magnitude: 0.10,
  ),
  whiteHoney(
    code: 'white_honey',
    title: 'White Honey',
    lore: 'Little of the week came out of a packet.',
    effect: MutagenEffect.purge,
    magnitude: 0.15,
  );

  const Mutagen({
    required this.code,
    required this.title,
    required this.lore,
    required this.effect,
    required this.magnitude,
  });

  /// Stable identifier, stored in `achievements.code`.
  final String code;

  final String title;
  final String lore;
  final MutagenEffect effect;

  /// How much it changes its effect, as a fraction.
  final double magnitude;

  static Mutagen? byCode(String code) {
    for (final mutagen in Mutagen.values) {
      if (mutagen.code == code) return mutagen;
    }
    return null;
  }
}

/// Thresholds a week must clear to earn each mutagen.
abstract final class MutagenThresholds {
  /// Green Blood: every day of the week logged.
  static const int completeWeekDays = 7;

  /// Red Vitriol: average diet quality.
  static const double vitality = 70;

  /// Blue Essence: days at the step goal.
  static const int goalDays = 5;

  /// White Honey: average toxicity must stay under this.
  static const double toxicity = 25;
}

/// Which mutagens a closed week earned.
///
/// Takes the frozen [WeekSummary] rather than a live reckoning, so a perk is
/// decided from exactly the figures the user was shown — and re-running this
/// on an archived week always gives the same answer.
Set<Mutagen> earnedBy(WeekSummary summary) {
  // A week with nothing logged earns nothing. Not a punishment: there is
  // simply no behaviour to reward, and the restraint-shaped conditions would
  // otherwise all pass on an empty week.
  if (summary.loggedDays <= 0) return const {};

  return {
    if (summary.loggedDays >= MutagenThresholds.completeWeekDays)
      Mutagen.greenBlood,
    if (summary.averageVitality >= MutagenThresholds.vitality)
      Mutagen.redVitriol,
    if (summary.goalDays >= MutagenThresholds.goalDays) Mutagen.blueEssence,
    if (summary.averageToxicity <= MutagenThresholds.toxicity)
      Mutagen.whiteHoney,
  };
}

/// The combined effect of a set of mutagens.
class MutagenBonus {
  const MutagenBonus({
    this.experience = 0,
    this.adrenaline = 0,
    this.purge = 0,
  });

  static const none = MutagenBonus();

  /// Extra XP, as a fraction. 0.2 means +20%.
  final double experience;

  /// Extra Adrenaline ceiling, as a fraction.
  final double adrenaline;

  /// How much faster toxicity fades, as a fraction.
  final double purge;

  bool get isEmpty => experience == 0 && adrenaline == 0 && purge == 0;

  /// Applies the XP bonus to a week's award.
  int applyToXp(int xp) => (xp * (1 + experience)).round();
}

/// Sums what a set of mutagens does.
MutagenBonus bonusOf(Iterable<Mutagen> mutagens) {
  var experience = 0.0;
  var adrenaline = 0.0;
  var purge = 0.0;

  for (final mutagen in mutagens) {
    switch (mutagen.effect) {
      case MutagenEffect.experience:
        experience += mutagen.magnitude;
      case MutagenEffect.adrenaline:
        adrenaline += mutagen.magnitude;
      case MutagenEffect.purge:
        purge += mutagen.magnitude;
    }
  }

  return MutagenBonus(
    // Capped so a long run of good weeks cannot compound into a figure that
    // makes the earlier ones look worthless.
    experience: experience.clamp(0.0, maxStackedBonus),
    adrenaline: adrenaline.clamp(0.0, maxStackedBonus),
    purge: purge.clamp(0.0, maxStackedBonus),
  );
}

/// The most any one effect can be raised by, however many mutagens stack.
const double maxStackedBonus = 0.5;
