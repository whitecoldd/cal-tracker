/// The frozen account of a closed week. Pure Dart.
///
/// Once a week is sealed this is what the app shows, forever. Later changes to
/// the scoring maths must not rewrite what the user was already told — a
/// history that edits itself is not a history.
library;

import 'dart:convert';

import 'reckoning.dart';
import 'sealed_value.dart';

/// Experience earned in a week.
///
/// **Rewards behaviour, never outcome.** Nothing here reads the direction of
/// the scale. Two reasons, and the second is the load-bearing one:
///
/// - The app's only demand on the user is that they log honestly. Paying them
///   for losing weight instead would pay them for a number that moves on water
///   and gut contents, and punish an honest week that happened to go sideways.
/// - XP that depended on weight would be a verdict in disguise. It could not
///   then be shown on a daily screen without leaking the answer — and a score
///   that only appears once a week is a much weaker motivator.
class WeekXp {
  const WeekXp({
    required this.forLogging,
    required this.forQuality,
    required this.forMovement,
    required this.forCompleteness,
  });

  static const empty = WeekXp(
    forLogging: 0,
    forQuality: 0,
    forMovement: 0,
    forCompleteness: 0,
  );

  final int forLogging;
  final int forQuality;
  final int forMovement;
  final int forCompleteness;

  int get total => forLogging + forQuality + forMovement + forCompleteness;

  /// Per day on which anything was logged.
  static const int perLoggedDay = 10;

  /// The most a week of good eating can add.
  static const int maxQuality = 30;

  /// Per day the step goal was met.
  static const int perGoalDay = 5;

  /// For logging all seven days.
  static const int completeWeekBonus = 20;
}

/// Awards a week's XP.
///
/// [averageVitality] is 0..100 across the logged days; [goalDays] is how many
/// days met the step goal.
WeekXp awardXp({
  required int loggedDays,
  required double averageVitality,
  required int goalDays,
}) {
  if (loggedDays <= 0) return WeekXp.empty;

  return WeekXp(
    forLogging: loggedDays * WeekXp.perLoggedDay,
    forQuality:
        (averageVitality.clamp(0, 100) / 100 * WeekXp.maxQuality).round(),
    forMovement: goalDays.clamp(0, 7) * WeekXp.perGoalDay,
    forCompleteness: loggedDays >= 7 ? WeekXp.completeWeekBonus : 0,
  );
}

/// Everything the reveal screen shows, frozen at the moment the week closed.
class WeekSummary {
  const WeekSummary({
    required this.loggedDays,
    required this.energyBalanceKcal,
    required this.averageDailyBalanceKcal,
    required this.projectedChangeKg,
    required this.averageVitality,
    required this.averageToxicity,
    required this.steps,
    required this.goalDays,
    required this.xp,
    this.weightDeltaKg,
    this.trend,
    this.bodyFatPercent,
    this.dailyBalances = const [],
    this.dailyWeights = const [],
  });

  final int loggedDays;
  final double energyBalanceKcal;
  final double averageDailyBalanceKcal;
  final double projectedChangeKg;
  final double averageVitality;
  final double averageToxicity;
  final int steps;
  final int goalDays;
  final int xp;

  final double? weightDeltaKg;
  final WeightTrend? trend;
  final double? bodyFatPercent;

  /// Seven entries where known, oldest first, for the chart.
  final List<double> dailyBalances;

  /// Weigh-ins across the week, oldest first. Gaps are simply absent.
  final List<double> dailyWeights;

  Map<String, dynamic> toJson() => {
        'loggedDays': loggedDays,
        'energyBalanceKcal': energyBalanceKcal,
        'averageDailyBalanceKcal': averageDailyBalanceKcal,
        'projectedChangeKg': projectedChangeKg,
        'averageVitality': averageVitality,
        'averageToxicity': averageToxicity,
        'steps': steps,
        'goalDays': goalDays,
        'xp': xp,
        'weightDeltaKg': weightDeltaKg,
        'trend': trend?.name,
        'bodyFatPercent': bodyFatPercent,
        'dailyBalances': dailyBalances,
        'dailyWeights': dailyWeights,
      };

  static WeekSummary fromJson(Map<String, dynamic> json) {
    double num_(Object? v) => (v as num?)?.toDouble() ?? 0;

    return WeekSummary(
      loggedDays: (json['loggedDays'] as num?)?.toInt() ?? 0,
      energyBalanceKcal: num_(json['energyBalanceKcal']),
      averageDailyBalanceKcal: num_(json['averageDailyBalanceKcal']),
      projectedChangeKg: num_(json['projectedChangeKg']),
      averageVitality: num_(json['averageVitality']),
      averageToxicity: num_(json['averageToxicity']),
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      goalDays: (json['goalDays'] as num?)?.toInt() ?? 0,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      weightDeltaKg: (json['weightDeltaKg'] as num?)?.toDouble(),
      trend: _trend(json['trend']),
      bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble(),
      dailyBalances: _doubles(json['dailyBalances']),
      dailyWeights: _doubles(json['dailyWeights']),
    );
  }

  static String encode(WeekSummary summary) => jsonEncode(summary.toJson());

  /// Decodes a stored summary, or null if it cannot be read.
  ///
  /// A summary written by an older version of the app is worth showing
  /// partially rather than throwing away — but an unreadable one is not worth
  /// crashing the screen for.
  static WeekSummary? decode(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      return fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  static WeightTrend? _trend(Object? value) {
    if (value is! String) return null;
    for (final trend in WeightTrend.values) {
      if (trend.name == value) return trend;
    }
    return null;
  }

  static List<double> _doubles(Object? value) => [
        if (value is List)
          for (final v in value)
            if (v is num) v.toDouble(),
      ];
}

/// The verdict data the weekly narrative is allowed to see.
///
/// **This type is the guard.** It can only be built from a [Reckoning] that is
/// actually revealed — [from] returns null otherwise — and the narrative call
/// takes nothing else. So there is no way to write code that asks a model to
/// describe a week that has not closed, which is the one exception to
/// CLAUDE.md §1 and therefore the one place worth making unwriteable rather
/// than merely discouraged.
class NarrativeFacts {
  const NarrativeFacts._({
    required this.loggedDays,
    required this.energyBalanceKcal,
    required this.averageDailyBalanceKcal,
    required this.projectedChangeKg,
    required this.averageVitality,
    required this.steps,
    this.weightDeltaKg,
    this.trend,
  });

  /// Builds the facts, or returns null if the week is still sealed.
  static NarrativeFacts? from(
    Reckoning reckoning, {
    required double averageVitality,
    required int steps,
  }) {
    if (!reckoning.isRevealed) return null;

    final balance = reckoning.energyBalanceKcal;
    final average = reckoning.averageDailyBalanceKcal;
    final projected = reckoning.projectedChangeKg;

    if (balance is! Revealed<double> ||
        average is! Revealed<double> ||
        projected is! Revealed<double>) {
      return null;
    }

    return NarrativeFacts._(
      loggedDays: reckoning.loggedDays,
      energyBalanceKcal: balance.value,
      averageDailyBalanceKcal: average.value,
      projectedChangeKg: projected.value,
      averageVitality: averageVitality,
      steps: steps,
      weightDeltaKg: reckoning.weightDeltaKg.valueOrNull,
      trend: reckoning.trend.valueOrNull,
    );
  }

  final int loggedDays;
  final double energyBalanceKcal;
  final double averageDailyBalanceKcal;
  final double projectedChangeKg;
  final double averageVitality;
  final int steps;
  final double? weightDeltaKg;
  final WeightTrend? trend;
}
