/// Shared week fixtures for the tests that need a [WeekPattern] but are not
/// about one.
///
/// `NarrativeFacts` carries the descriptive half since T40, so every test that
/// builds one needs a pattern even when it is testing the guard rather than
/// the content.
library;

import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/nutrition.dart';
import 'package:cal_tracker/domain/week_pattern.dart';

const fixtureMonday = Day(20260914);
const fixtureSunday = Day(20260920);

const fixtureFood = FoodIdentity(id: 1, name: 'Stew');

const fixturePanel = FoodPanel(
  kcal: 120,
  proteinG: 9,
  carbsG: 8,
  fatG: 5,
  satFatG: 2,
  fibreG: 3,
  sodiumMg: 200,
  novaGroup: 3,
  additives: ['E330'],
);

/// A plain seven-day week, enough for any test that only needs *a* pattern.
WeekPattern fixturePattern({
  Day weekStart = fixtureMonday,
  int days = 7,
}) =>
    readWeek(
      weekStart: weekStart,
      weekEnd: weekStart.addDays(6),
      throughDay: weekStart.addDays(6),
      portions: [
        for (var i = 0; i < days; i++)
          LoggedPortion(
            day: weekStart.addDays(i),
            food: fixtureFood,
            serving: const Serving(food: fixturePanel, grams: 1500),
          ),
      ],
    );

/// A week with nothing in it.
WeekPattern emptyPattern({Day weekStart = fixtureMonday}) =>
    fixturePattern(weekStart: weekStart, days: 0);
