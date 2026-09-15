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
double adrenalineFor({required int loggedDaysInLastWeek}) {
  final days = loggedDaysInLastWeek.clamp(0, 7);
  return 1 + days / 7 * (maxAdrenaline - 1);
}

/// The most Adrenaline can multiply XP by, at seven days out of seven.
const double maxAdrenaline = 1.5;

/// Applies Adrenaline to a week's XP.
int withAdrenaline(int xp, {required int loggedDaysInLastWeek}) =>
    (xp * adrenalineFor(loggedDaysInLastWeek: loggedDaysInLastWeek)).round();
