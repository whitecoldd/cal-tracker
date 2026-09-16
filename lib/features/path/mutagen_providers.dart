/// Mutagens — the perks, and what they are currently worth.
///
/// Two different questions, and conflating them was the bug T24 fixed:
///
/// - **What have I earned?** Every perk ever unlocked. A trophy case. It only
///   grows, and it is what The Path lists.
/// - **What is helping me this week?** The perks earned by the week that just
///   closed, and nothing else. It can go down. It is what the maths reads.
///
/// Until T24 there was one provider answering the first question and the panel
/// under it claiming "carried into the week ahead" — the second. Nothing spent
/// either, so nothing made the difference visible.
///
/// These live here rather than beside the Bestiary, where T12b first put them,
/// because Alchemy and the Reckoning both read them now and neither should
/// have to import a screen about food to do it.
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/day.dart';
import '../../domain/mutagens.dart';
import '../../providers/app_providers.dart';
import '../journal/journal_providers.dart';
import '../reckoning/reckoning_providers.dart';

/// The start of the week whose perks are in force on [day].
///
/// One week back: a mutagen is earned at a reveal and modifies the week that
/// follows it. See `domain/mutagens.dart`.
Day _perkWeekFor(Day day, {required int weekEndsOn}) =>
    day.startOfWeek(weekEndsOn: weekEndsOn).addDays(-7);

/// Every mutagen ever earned, for the character sheet.
///
/// A code this build no longer recognises is dropped rather than shown as a
/// blank — a perk removed in a later version should disappear, not haunt the
/// sheet.
final earnedMutagensProvider = FutureProvider<List<Mutagen>>((ref) async {
  ref.watch(journalEntriesProvider);

  final rows = await ref.watch(databaseProvider).weeksDao.allAchievements();

  final seen = <Mutagen>{};
  for (final row in rows) {
    final mutagen = Mutagen.byCode(row.code);
    if (mutagen != null) seen.add(mutagen);
  }

  return seen.toList();
});

/// The mutagens modifying the current week — last week's earnings, only.
final activeMutagensProvider = FutureProvider<List<Mutagen>>((ref) async {
  ref.watch(journalEntriesProvider);

  final gate = ref.watch(revealGateProvider);
  final earnedIn = _perkWeekFor(
    Day.from(clock.now()),
    weekEndsOn: gate.weekEndsOn,
  );

  final mutagens =
      await ref.watch(databaseProvider).weeksDao.mutagensForWeek(earnedIn);

  return mutagens.toList();
});

/// What the active mutagens are worth.
///
/// Read by Adrenaline on The Path, by toxicity on Alchemy, and by the XP award
/// at the seal. Every one of those is on the always-visible side of CLAUDE.md
/// §1, and every mutagen condition is behaviour rather than outcome, so none of
/// this can carry the verdict onto a daily screen.
final activeMutagenBonusProvider = FutureProvider<MutagenBonus>(
  (ref) async => bonusOf(await ref.watch(activeMutagensProvider.future)),
);

/// The bonus in force on an arbitrary day, for a screen that can page backwards.
///
/// Alchemy's toxicity meter reads a chosen day, not today. Using the *current*
/// bonus there would rewrite what a past day looked like every time a new perk
/// was earned; a day's carry-over should read the same in a month as it does
/// now.
final bonusOnDayProvider =
    FutureProvider.family<MutagenBonus, Day>((ref, day) async {
  ref.watch(journalEntriesProvider);

  final gate = ref.watch(revealGateProvider);
  final earnedIn = _perkWeekFor(day, weekEndsOn: gate.weekEndsOn);

  return bonusOf(
    await ref.watch(databaseProvider).weeksDao.mutagensForWeek(earnedIn),
  );
});
