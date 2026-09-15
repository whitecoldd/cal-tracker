import 'package:clock/clock.dart';

import '../domain/day.dart';
import '../domain/reckoning.dart';
import '../domain/week_summary.dart';
import 'ai/openrouter_client.dart';
import 'daos/weeks_dao.dart';
import 'database.dart';

/// A week as the reveal screen should show it.
class ArchivedWeek {
  const ArchivedWeek({
    required this.weekStart,
    required this.summary,
    this.narrative,
  });

  final Day weekStart;
  final WeekSummary summary;
  final String? narrative;
}

/// Freezes a week when it closes, and reads it back afterwards.
///
/// Two rules, and they are the whole class:
///
/// - **A sealed week is never recomputed.** Later changes to the scoring maths
///   must not rewrite what the user was already told. A history that edits
///   itself is not a history.
/// - **The narrative costs exactly one call, once.** If a week already has
///   one, it is never asked for again — not on a re-open, not after a restart.
///   That is the fourth permitted AI use and its entire budget (CLAUDE.md §4).
class WeekArchive {
  const WeekArchive({
    required WeeksDao weeks,
    required OpenRouterClient ai,
  })  : _weeks = weeks,
        _ai = ai;

  final WeeksDao _weeks;
  final OpenRouterClient _ai;

  /// The frozen week, if it has been sealed.
  Future<ArchivedWeek?> read(Day weekStart) async {
    final row = await _weeks.forWeekStart(weekStart);
    if (row == null || !row.revealed) return null;

    final summary = WeekSummary.decode(row.summaryJson);
    if (summary == null) return null;

    return ArchivedWeek(
      weekStart: weekStart,
      summary: summary,
      narrative: row.narrative,
    );
  }

  /// Seals a week, writing its summary and asking for its narrative.
  ///
  /// Idempotent: a week already sealed is returned as it stands. That is what
  /// makes it safe to call every time the reveal screen opens, which is the
  /// only sensible trigger — there is no background job in a serverless app,
  /// and a week seals when the user comes to read it.
  ///
  /// [facts] being null means the week is not revealed, and nothing is written.
  Future<ArchivedWeek?> seal({
    required Reckoning reckoning,
    required WeekSummary summary,
    NarrativeFacts? facts,
  }) async {
    if (!reckoning.isRevealed) return null;

    final existing = await read(reckoning.weekStart);
    if (existing != null) return existing;

    final stamp = clock.now().toIso8601String();

    // The row has to exist before it can be sealed.
    await _weeks.upsert(
      WeeksCompanion.insert(
        weekStart: reckoning.weekStart,
        weekEnd: reckoning.weekEnd,
        createdAt: stamp,
      ),
    );

    final narrative = facts == null ? null : await _narrative(facts);

    await _weeks.seal(
      reckoning.weekStart,
      summaryJson: WeekSummary.encode(summary),
      narrative: narrative,
      xpAwarded: summary.xp,
    );

    return ArchivedWeek(
      weekStart: reckoning.weekStart,
      summary: summary,
      narrative: narrative,
    );
  }

  /// Asks for the narrative, and shrugs if it cannot be had.
  ///
  /// Every failure is swallowed deliberately. A week with no key, no network,
  /// or no budget left still has all its figures — the account is flavour on
  /// top of them, and refusing to seal the week because a model was
  /// unreachable would lose the numbers to save the prose.
  Future<String?> _narrative(NarrativeFacts facts) async {
    try {
      return await _ai.weeklyNarrative(facts);
    } on AiFailure {
      return null;
    }
  }

  /// Every sealed week, newest first.
  Stream<List<Week>> watchHistory() => _weeks.watchHistory();
}
