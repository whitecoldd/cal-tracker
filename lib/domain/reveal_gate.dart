import 'day.dart';
import 'sealed_value.dart';

/// Decides when a verdict may be read.
///
/// The single place that answers "is the week closed yet?". Every
/// verdict-bearing value in the app passes through here on its way to a
/// [SealedValue], so the blackout in CLAUDE.md §1 has exactly one definition
/// rather than a condition repeated at each call site — which is how one screen
/// ends up a day out of step with another.
class RevealGate {
  const RevealGate({required this.weekEndsOn})
      : assert(
          weekEndsOn >= DateTime.monday && weekEndsOn <= DateTime.sunday,
          'weekEndsOn is an ISO weekday: Monday 1 .. Sunday 7',
        );

  /// ISO weekday the week closes on. Monday is 1, Sunday is 7.
  final int weekEndsOn;

  /// Whether a value belonging to [subject] may be shown on [today].
  ///
  /// Two ways to be readable, and only two:
  ///
  /// - **The week has closed.** A past week is history; there is nothing left
  ///   to influence by reading it, and refusing would make the app useless as
  ///   a record.
  /// - **Today is the week-end day**, and the value belongs to the week that
  ///   day closes. This is the reveal.
  ///
  /// Anything else — the current week on any other day, or a future week — is
  /// sealed.
  bool isRevealed(Day subject, {required Day today}) {
    final subjectWeek = subject.endOfWeek(weekEndsOn: weekEndsOn);
    final currentWeek = today.endOfWeek(weekEndsOn: weekEndsOn);

    if (subjectWeek.isBefore(currentWeek)) return true;
    if (subjectWeek.isAfter(currentWeek)) return false;

    // The live week. Readable only on the day it closes.
    return today == currentWeek;
  }

  /// Whether today is a reveal day at all.
  bool isRevealDay(Day today) => today.weekday == weekEndsOn;

  /// Gates a value, computing it **only if it may be shown**.
  ///
  /// [compute] is a callback rather than a value on purpose. A sealed verdict
  /// is never calculated at all, so there is no number in memory to be caught
  /// by a log line, a `toString`, a crash report or a future refactor that
  /// reaches past the type. The seal is not a curtain drawn over an answer;
  /// there is no answer yet.
  SealedValue<T> gate<T>(
    Day subject, {
    required Day today,
    required T Function() compute,
  }) =>
      isRevealed(subject, today: today)
          ? Revealed<T>(compute())
          : Sealed<T>();

  /// Value equality, and not merely for tidiness.
  ///
  /// The gate is rebuilt whenever the profile stream emits. Without `==`, each
  /// rebuild produces an instance Riverpod considers *different*, needlessly
  /// invalidating every provider that watches it — including the one that
  /// assembles the week, which then re-runs a handful of database queries for
  /// a configuration that has not changed.
  @override
  bool operator ==(Object other) =>
      other is RevealGate && other.weekEndsOn == weekEndsOn;

  @override
  int get hashCode => weekEndsOn.hashCode;

  @override
  String toString() => 'RevealGate(weekEndsOn: $weekEndsOn)';

  /// How many days until [subject]'s week closes. Zero on the day itself.
  ///
  /// For telling the user when to come back, which is the difference between a
  /// seal that feels deliberate and one that feels broken.
  int daysUntilReveal(Day subject, {required Day today}) {
    final close = subject.endOfWeek(weekEndsOn: weekEndsOn);
    final remaining = today.daysUntil(close);
    return remaining < 0 ? 0 : remaining;
  }
}
