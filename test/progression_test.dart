import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/progression.dart';
import 'package:flutter_test/flutter_test.dart';

const _today = Day(20260915);

void main() {
  group('the level curve', () {
    test('a fresh character is level one with nothing spent', () {
      final start = levelFor(0);

      expect(start.level, 1);
      expect(start.xpIntoLevel, 0);
      expect(start.fraction, 0);
      expect(start.rank, Rank.novice);
    });

    test('the first level lands after roughly one good week', () {
      // A strong week earns about 145 XP, so the first level should be close
      // enough to be worth having. Early progress that takes a month is
      // progress nobody waits for.
      expect(baseLevelCost, lessThanOrEqualTo(200));
      expect(levelFor(149).level, 1);
      expect(levelFor(150).level, 2);
    });

    test('later levels cost more', () {
      expect(costOfLevel(1), baseLevelCost);
      expect(costOfLevel(2), baseLevelCost + levelCostStep);
      expect(costOfLevel(5), baseLevelCost + 4 * levelCostStep);
    });

    test('xpToReach matches walking the costs', () {
      expect(xpToReach(1), 0);
      expect(xpToReach(2), costOfLevel(1));
      expect(xpToReach(4), costOfLevel(1) + costOfLevel(2) + costOfLevel(3));
    });

    test('levelFor is the inverse of xpToReach', () {
      // The property that matters: the two must never disagree, or the bar
      // fills to somewhere other than where the level changes.
      for (var level = 1; level <= 25; level++) {
        expect(levelFor(xpToReach(level)).level, level, reason: 'at $level');
        expect(levelFor(xpToReach(level)).xpIntoLevel, 0);
        expect(
          levelFor(xpToReach(level) - 1).level,
          level == 1 ? 1 : level - 1,
        );
      }
    });

    test('reports progress within the current level', () {
      final part = levelFor(baseLevelCost + 50);

      expect(part.level, 2);
      expect(part.xpIntoLevel, 50);
      expect(part.xpForNextLevel, costOfLevel(2));
      expect(part.xpRemaining, costOfLevel(2) - 50);
      expect(part.fraction, closeTo(50 / costOfLevel(2), 0.001));
    });

    test('negative XP does not produce a negative level', () {
      expect(levelFor(-500).level, 1);
    });
  });

  group('ranks', () {
    test('change in bands, so a new title means something', () {
      expect(Rank.forLevel(1), Rank.novice);
      expect(Rank.forLevel(3), Rank.novice);
      expect(Rank.forLevel(4), Rank.wanderer);
      expect(Rank.forLevel(13), Rank.witcher);
      expect(Rank.forLevel(99), Rank.master);
    });

    test('every rank has a title', () {
      for (final rank in Rank.values) {
        expect(rank.title, isNotEmpty);
      }
    });
  });

  group('the streak', () {
    Set<Day> daysBack(int count, {int from = 0}) => {
          for (var i = 0; i < count; i++) _today.addDays(-from - i),
        };

    test('counts consecutive days ending today', () {
      expect(streakEndingAt(_today, daysBack(5)), 5);
    });

    test('an unlogged today does not break it', () {
      // The day is not over. A streak that broke at breakfast would be absurd.
      expect(streakEndingAt(_today, daysBack(4, from: 1)), 4);
    });

    test('a gap ends it', () {
      final withGap = {
        _today,
        _today.addDays(-1),
        // -2 missing
        _today.addDays(-3),
        _today.addDays(-4),
      };

      expect(streakEndingAt(_today, withGap), 2);
    });

    test('nothing logged is a streak of zero', () {
      expect(streakEndingAt(_today, {}), 0);
    });

    test('does not run away on a long history', () {
      expect(
        streakEndingAt(_today, daysBack(900), maxLookback: 400),
        400,
      );
    });
  });

  group('Adrenaline', () {
    test('is driven by the last week, not by the streak', () {
      // The design decision this whole function exists for. A streak is good
      // to *show* — legible, feels earned. It is bad to *pay*, because an
      // all-or-nothing reward that one missed day destroys gives the user a
      // reason to invent a meal to keep it alive. This app's only demand is
      // honest logging; a mechanic that pays for dishonesty corrupts the one
      // dataset it has.
      expect(adrenalineFor(loggedDaysInLastWeek: 7), maxAdrenaline);
      expect(adrenalineFor(loggedDaysInLastWeek: 0), 1.0);
    });

    test('degrades a seventh at a time', () {
      final full = adrenalineFor(loggedDaysInLastWeek: 7);
      final missedOne = adrenalineFor(loggedDaysInLastWeek: 6);

      // A single missed day costs a little, never everything.
      expect(missedOne, lessThan(full));
      expect(missedOne, greaterThan(1.3));
    });

    test('is monotonic', () {
      var previous = 0.0;
      for (var days = 0; days <= 7; days++) {
        final value = adrenalineFor(loggedDaysInLastWeek: days);
        expect(value, greaterThan(previous));
        previous = value;
      }
    });

    test('is not thrown by a figure outside the week', () {
      expect(adrenalineFor(loggedDaysInLastWeek: 40), maxAdrenaline);
      expect(adrenalineFor(loggedDaysInLastWeek: -3), 1.0);
    });

    test('multiplies a week of XP', () {
      expect(withMultipliers(100, loggedDaysInLastWeek: 7), 150);
      expect(withMultipliers(100, loggedDaysInLastWeek: 0), 100);
    });

    test('a mutagen raises the ceiling, not the floor', () {
      // The perk pays for a week that was logged. A week that was not logged
      // earns nothing however many mutagens are in force — otherwise a good
      // week would buy a free bad one.
      expect(
        adrenalineFor(loggedDaysInLastWeek: 0, ceilingBonus: 0.10),
        1.0,
      );
      expect(
        adrenalineFor(loggedDaysInLastWeek: 7, ceilingBonus: 0.10),
        closeTo(maxAdrenaline * 1.10, 0.0001),
      );
    });

    test('both multipliers are applied together and rounded once', () {
      // A real divergence, not a decorative one. Six days logged is a ×1.4285…
      // Adrenaline, and a 20% experience perk on top:
      //
      //   one rounding:  100 * 1.42857… * 1.2 = 171.428… -> 171
      //   two roundings: (100 * 1.42857…).round() = 143, * 1.2 = 171.6 -> 172
      //
      // A point of XP either way is nothing; a reward that depends on the order
      // two multipliers happened to be applied in is the kind of thing that
      // cannot be reasoned about later. Pinned here so it stays one rounding.
      expect(
        withMultipliers(100, loggedDaysInLastWeek: 6, experienceBonus: 0.20),
        171,
      );

      final twiceRounded =
          ((100 * adrenalineFor(loggedDaysInLastWeek: 6)).round() * 1.20)
              .round();
      expect(twiceRounded, 172);
    });
  });

  group('progression never reads the scale', () {
    test('the same logging earns the same level whatever the weight did', () {
      // A level that moved with the scale would be the verdict wearing a hat —
      // it could not be shown daily without leaking the answer. See
      // CLAUDE.md §1 and the XP note in week_summary.dart.
      final a = levelFor(600);
      final b = levelFor(600);

      expect(a.level, b.level);
      expect(a.rank, b.rank);
    });
  });
}
