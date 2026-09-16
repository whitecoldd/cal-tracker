/// Levels, streaks and Adrenaline. Pure Dart.
///
/// Everything here is earned by *logging*, not by losing weight — see the XP
/// note in `week_summary.dart`. That keeps progression safe on a daily screen:
/// a level that moved with the scale would be the verdict wearing a hat.
library;

import 'dart:math' as math;

import 'day.dart';

/// What a witcher is called at each stage.
///
/// Bands rather than a name per level, so the title means something when it
/// changes.
enum Rank {
  novice('Novice', 1),
  wanderer('Wanderer', 4),
  pathfinder('Path-walker', 8),
  witcher('Witcher', 13),
  master('Master of the Path', 20);

  const Rank(this.title, this.fromLevel);

  final String title;
  final int fromLevel;

  static Rank forLevel(int level) {
    var found = Rank.novice;
    for (final rank in Rank.values) {
      if (level >= rank.fromLevel) found = rank;
    }
    return found;
  }
}

/// Where the user stands.
class Progression {
  const Progression({
    required this.totalXp,
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
  });

  static const empty = Progression(
    totalXp: 0,
    level: 1,
    xpIntoLevel: 0,
    xpForNextLevel: baseLevelCost,
  );

  final int totalXp;
  final int level;

  /// XP earned since this level began.
  final int xpIntoLevel;

  /// XP the whole of this level costs.
  final int xpForNextLevel;

  Rank get rank => Rank.forLevel(level);

  /// 0..1 towards the next level.
  double get fraction =>
      xpForNextLevel <= 0 ? 1 : (xpIntoLevel / xpForNextLevel).clamp(0.0, 1.0);

  int get xpRemaining => math.max(0, xpForNextLevel - xpIntoLevel);
}

/// XP the first level costs.
///
/// A good week earns about 145, so the first level lands after roughly one —
/// early progress should be quick enough to be worth having.
const int baseLevelCost = 150;

/// Added to each level's cost, so later levels take longer.
const int levelCostStep = 25;

/// What level [n] costs on its own.
int costOfLevel(int n) => baseLevelCost + (n - 1) * levelCostStep;

/// Total XP needed to *reach* level [n].
int xpToReach(int n) {
  var total = 0;
  for (var level = 1; level < n; level++) {
    total += costOfLevel(level);
  }
  return total;
}

/// Works out the level for a total XP figure.
Progression levelFor(int totalXp) {
  if (totalXp <= 0) return Progression.empty;

  var level = 1;
  var consumed = 0;

  while (true) {
    final cost = costOfLevel(level);
    if (totalXp - consumed < cost) break;
    consumed += cost;
    level++;
  }

  return Progression(
    totalXp: totalXp,
    level: level,
    xpIntoLevel: totalXp - consumed,
    xpForNextLevel: costOfLevel(level),
  );
}

/// A level boundary crossed by a single award.
///
/// Carries both sides rather than just the new level, because the interesting
/// thing about a level-up is the *crossing* — a screen that only knew the new
/// figure could not say what it replaced, and a week that took two levels at
/// once should be able to say so.
class LevelUp {
  const LevelUp({required this.from, required this.to});

  /// Where the user stood before the award.
  final Progression from;

  /// Where the award left them.
  final Progression to;

  /// How many boundaries were crossed. Always at least one.
  int get levels => to.level - from.level;

  /// Whether the crossing also earned a new title.
  ///
  /// Ranks are bands rather than a name per level, so this is rare and worth
  /// saying differently when it happens. See [Rank].
  bool get rankChanged => to.rank != from.rank;
}

/// The level-up a week's award caused, or null if it crossed no boundary.
///
/// Takes the total *before* the award and the award itself rather than reading
/// a running level, so it answers correctly for a week in the past: the
/// question is what that seal did at the time, not what the user's level is
/// today. A screen that can page backwards needs the first answer.
LevelUp? levelUpFrom({required int xpBefore, required int xpGained}) {
  if (xpGained <= 0) return null;

  final before = levelFor(xpBefore);
  final after = levelFor(xpBefore + xpGained);

  if (after.level <= before.level) return null;

  return LevelUp(from: before, to: after);
}

/// Consecutive days logged, ending at [today].
///
/// Counts backwards from today, and allows today itself to be empty — the day
/// is not over yet, and a streak that breaks at breakfast would be absurd.
int streakEndingAt(Day today, Set<Day> loggedDays, {int maxLookback = 400}) {
  var streak = 0;
  var cursor = today;

  // Today not being logged yet does not break anything; start from yesterday.
  if (!loggedDays.contains(cursor)) cursor = cursor.addDays(-1);

  while (streak < maxLookback && loggedDays.contains(cursor)) {
    streak++;
    cursor = cursor.addDays(-1);
  }

  return streak;
}

/// The XP multiplier from recent consistency, 1.0 upwards.
///
/// **Deliberately driven by days-logged-in-the-last-week, not by the streak.**
///
/// A streak is a good thing to *show* — it is legible and it feels earned. It
/// is a bad thing to *pay*, because an all-or-nothing reward that a single
/// missed day destroys gives the user a reason to invent a meal to keep it
/// alive. This app's one demand is honest logging; a mechanic that pays for
/// dishonesty would corrupt the only data it has.
///
/// So the streak is display and Adrenaline is reward, and the reward degrades
/// one seventh at a time.
///
/// [ceilingBonus] raises the top of the scale, and is where the Blue Essence
/// mutagen lands. It moves the *ceiling* rather than the figure itself, so a
/// perk cannot pay anything to a week that was not logged: at zero days out of
/// seven the multiplier is 1.0 however many mutagens are in force. A perk is a
/// bigger reward for the same behaviour, never a reward for none.
double adrenalineFor({
  required int loggedDaysInLastWeek,
  double ceilingBonus = 0,
}) {
  final days = loggedDaysInLastWeek.clamp(0, 7);
  final ceiling = maxAdrenaline * (1 + ceilingBonus.clamp(0.0, 1.0));
  return 1 + days / 7 * (ceiling - 1);
}

/// The most Adrenaline can multiply XP by, at seven days out of seven and with
/// no mutagen raising the ceiling.
const double maxAdrenaline = 1.5;

/// A week's XP after every multiplier, rounded once.
///
/// Two multipliers act on the same figure and they come from different places:
/// Adrenaline pays for how much of *this* week was logged, and [experienceBonus]
/// is a perk earned by the week before. Both are applied here rather than in
/// two steps for an arithmetic reason — `(x * a).round() * b` rounds twice,
/// loses up to half a point each time, and gives a different answer depending
/// on which multiplier went first. One multiplication, one rounding, no order.
///
/// This is the **only** way XP should be awarded. It replaced a `withAdrenaline`
/// and a `MutagenBonus.applyToXp` that between them had no callers at all: the
/// reward chain was disconnected at both joints from T12b until T24, and having
/// three functions that could each award XP is how that went unnoticed.
int withMultipliers(
  int xp, {
  required int loggedDaysInLastWeek,
  double experienceBonus = 0,
  double ceilingBonus = 0,
}) {
  final adrenaline = adrenalineFor(
    loggedDaysInLastWeek: loggedDaysInLastWeek,
    ceilingBonus: ceilingBonus,
  );
  return (xp * adrenaline * (1 + experienceBonus.clamp(0.0, 1.0))).round();
}
